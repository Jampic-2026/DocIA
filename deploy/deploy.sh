#!/usr/bin/env bash
# Isolated monorepo protocol. Never administer the legacy PM2 daemon here.
set -Eeuo pipefail
umask 077
readonly ROOT=/var/www/docia/monorepo/deploy
export PM2_HOME="$ROOT/pm2"
stage=preflight activated=0 previous='' log=/dev/null
say() { printf '[DocIA] %s\n' "$*"; }
fail() { say "ERROR: $*" >&2; exit 1; }
valid_id() { [[ "$1" =~ ^[0-9a-f]{40}-[0-9]+-[0-9]+$ ]]; }
switch_link() {
  ln -sfn "$1" "$ROOT/current-$component.next" &&
    mv -Tf "$ROOT/current-$component.next" "$ROOT/current-$component"
}
start_api() {
  pm2 delete docia-api-monorepo >>"$log" 2>&1 || true
  pm2 start "$1/ecosystem.config.cjs" --only docia-api-monorepo >>"$log" 2>&1
}
probe_api() {
  local url=$1 expected=$2 body label=publica code
  if [[ $url == "$API_READY_URL" ]]; then label=local; fi
  body=$(curl --silent --fail --connect-timeout 3 --max-time 10 "$url" 2>>"$log") || {
    code=$?
    say "Readiness API $label: fallo HTTP/conexión (curl $code)." >&2
    return 1
  }
  printf '%s' "$body" | node -e '
    let body = "";
    process.stdin.on("data", c => body += c);
    process.stdin.on("end", () => {
      try {
        const data = JSON.parse(body);
        process.exit(data.status === "ok" && data.service === "api-docia" &&
          data.release === process.argv[1] ? 0 : 1);
      } catch { process.exit(1); }
    });' "$expected" || {
    say "Readiness API $label: respuesta de salud o versión incorrecta." >&2
    return 1
  }
}
probe_web() {
  local expected=$1 body base=$2
  body=$(curl --silent --fail --connect-timeout 3 --max-time 10 \
    "${base%/}/docia-release.txt?deployment=$expected" 2>>"$log") || {
    say 'Web: fallo HTTP/conexión al consultar el marcador.' >&2
    return 1
  }
  [[ "$body" == "$expected" ]] || {
    say 'Web: el marcador no corresponde a esta versión; revisar root y caché.' >&2
    return 1
  }
  curl --silent --fail --connect-timeout 3 --max-time 10 --output /dev/null \
    "${base%/}/flutter_bootstrap.js?deployment=$expected" 2>>"$log" || {
    say 'Web: flutter_bootstrap.js no está disponible.' >&2
    return 1
  }
  probe_apk "$base" "$expected"
}
probe_apk() {
  local base=$1 expected=$2 expected_apk remote_apk probe actual_apk
  # Previous Flutter releases created before APK automation remain valid rollback targets.
  if [[ -f "$ROOT/releases/$expected/web/downloads/DocIA.apk.sha256" ]]; then
    expected_apk=$(cat "$ROOT/releases/$expected/web/downloads/DocIA.apk.sha256")
    remote_apk=$(curl --silent --fail --connect-timeout 3 --max-time 10 \
      "${base%/}/downloads/DocIA.apk.sha256?deployment=$expected" 2>>"$log") || {
      say 'Android: checksum público no disponible.' >&2
      return 1
    }
    [[ "$remote_apk" == "$expected_apk" ]] || {
      say 'Android: el checksum público no corresponde a esta versión.' >&2
      return 1
    }
    probe=$(mktemp "$ROOT/logs/apk-probe.XXXXXX") || return 1
    if ! curl --silent --fail --connect-timeout 3 --max-time 90 --output "$probe" \
      "${base%/}/downloads/DocIA.apk?deployment=$expected" 2>>"$log"; then
      rm -f -- "$probe"
      say 'Android: no se pudo descargar el APK publicado.' >&2
      return 1
    fi
    actual_apk=$(sha256sum "$probe")
    rm -f -- "$probe"
    [[ ${actual_apk%% *} == "$expected_apk" ]] || {
      say 'Android: el APK descargado no coincide con el artefacto verificado.' >&2
      return 1
    }
  fi
}
validate_landing() {
  local directory=$1 digest asset actual has_index=0 has_js=0
  [[ -f "$directory/index.html" && -s "$directory/docia-assets.sha256" ]] || fail 'Landing incompleta: falta index.html o el manifiesto de assets.'
  while read -r digest asset; do
    asset=${asset#\*}
    [[ "$digest" =~ ^[0-9a-f]{64}$ && "$asset" =~ ^(index\.html|assets/[a-zA-Z0-9._/-]+)$ &&
      "$asset" != *..* && -f "$directory/$asset" ]] || fail 'Manifiesto de landing inválido o asset ausente.'
    actual=$(sha256sum "$directory/$asset")
    [[ ${actual%% *} == "$digest" ]] || fail "Landing: checksum incorrecto de $asset."
    if [[ $asset == index.html ]]; then has_index=1; fi
    if [[ $asset == assets/*.js ]]; then has_js=1; fi
  done < "$directory/docia-assets.sha256"
  (( has_index == 1 && has_js == 1 )) || fail 'El manifiesto de landing debe incluir index.html y JavaScript.'
}
probe_landing() {
  local expected=$1 base=$2 body digest asset probe actual web_release
  body=$(curl --silent --fail --connect-timeout 3 --max-time 10 \
    "${base%/}/docia-release.txt?deployment=$expected" 2>>"$log") || return 1
  [[ "$body" == "$expected" ]] || { say 'Landing: marcador de versión incorrecto.' >&2; return 1; }
  while read -r digest asset; do
    asset=${asset#\*}
    probe=$(mktemp "$ROOT/logs/landing-probe.XXXXXX") || return 1
    if ! curl --silent --fail --connect-timeout 3 --max-time 15 --output "$probe" \
      "${base%/}/$asset?deployment=$expected" 2>>"$log"; then
      rm -f -- "$probe"
      say "Landing: no se pudo descargar $asset." >&2
      return 1
    fi
    actual=$(sha256sum "$probe")
    rm -f -- "$probe"
    [[ ${actual%% *} == "$digest" ]] || { say "Landing: contenido incorrecto en $asset." >&2; return 1; }
  done < "$ROOT/releases/$expected/landing/docia-assets.sha256"
  web_release=$(readlink -f "$ROOT/current-web")
  [[ -f "$web_release/web/downloads/DocIA.apk.sha256" ]] || {
    say 'Landing: publicar primero el APK firmado desde Flutter.' >&2
    return 1
  }
  probe_apk "$base" "$(basename "$web_release")"
}
validate_web_apk() {
  local web=$1 digest actual
  [[ -f "$web/downloads/DocIA.apk" && -f "$web/downloads/DocIA.apk.sha256" &&
    -f "$web/downloads/android-release.json" ]] || fail 'Release web incompleta: falta el APK, su checksum o sus metadatos.'
  digest=$(cat "$web/downloads/DocIA.apk.sha256")
  [[ "$digest" =~ ^[0-9a-f]{64}$ ]] || fail 'Checksum Android inválido.'
  actual=$(sha256sum "$web/downloads/DocIA.apk")
  [[ ${actual%% *} == "$digest" ]] || fail 'El APK recibido no coincide con su checksum.'
}
load_public() {
  local file=$1 key value count=0
  [[ -f "$file" && ! -L "$file" ]] || fail 'Missing PUBLIC_CONFIG.env.'
  unset PUBLIC_API_URL PUBLIC_WEB_URL PUBLIC_LANDING_URL API_PREFIX
  while IFS='=' read -r key value; do
    case "$key" in
      PUBLIC_API_URL|PUBLIC_WEB_URL|PUBLIC_LANDING_URL)
        [[ "$value" =~ ^https://[a-zA-Z0-9][a-zA-Z0-9.-]*[a-zA-Z0-9]$ && ! -v $key ]] || fail 'Invalid or repeated public origin.' ;;
      API_PREFIX) [[ "$value" =~ ^[a-zA-Z0-9_-]+(/[a-zA-Z0-9_-]+)*$ && ! -v API_PREFIX ]] || fail 'Invalid API_PREFIX.' ;;
      *) fail 'Unexpected public configuration.' ;;
    esac
    printf -v "$key" '%s' "$value"
    count=$((count + 1))
  done < "$file"
  (( count == 4 )) || fail 'Incomplete public configuration.'
  API_READY_URL="http://127.0.0.1:3200/$API_PREFIX/health/ready"
  PUBLIC_API_READY_URL="$PUBLIC_API_URL/$API_PREFIX/health/ready"
  WEB_BASE_URL=$PUBLIC_WEB_URL
  LANDING_BASE_URL=$PUBLIC_LANDING_URL
}
wait_health() {
  local expected=$1 attempt
  for ((attempt=1; attempt<=HEALTH_ATTEMPTS; attempt++)); do
    if [[ $component == web ]]; then
      if probe_web "$expected" http://127.0.0.1:8088; then
        if [[ $PUBLIC_CHECKS == 0 ]]; then return 0; fi
        if [[ $FRONTEND_HOSTING == netlify ]]; then
          if probe_apk "$PUBLIC_API_URL" "$expected"; then return 0; fi
        elif probe_web "$expected" "$WEB_BASE_URL"; then return 0
        fi
      fi
    elif [[ $component == landing ]]; then
      if probe_landing "$expected" http://127.0.0.1:8089 && { [[ $PUBLIC_CHECKS == 0 ]] || probe_landing "$expected" "$LANDING_BASE_URL"; }; then return 0; fi
    elif probe_api "$API_READY_URL" "$expected" && { [[ $PUBLIC_CHECKS == 0 ]] || probe_api "$PUBLIC_API_READY_URL" "$expected"; }; then return 0
    fi
    sleep "$HEALTH_DELAY"
  done
  return 1
}
on_exit() {
  local code=$?
  trap - EXIT HUP INT TERM
  if (( code != 0 )); then
    say "ERROR en etapa '$stage' (código $code). Detalle privado en $log." >&2
    if (( activated == 1 )); then
      say "Restaurando la versión anterior de $component."
      if [[ -z "$previous" ]]; then
        rm -f -- "$ROOT/current-$component"
        if [[ $component == api ]]; then pm2 delete docia-api-monorepo >>"$log" 2>&1 || true; pm2 save --force >>"$log" 2>&1 || true; fi
        say "First installation removed; legacy production remains untouched."
      elif load_public "$previous/PUBLIC_CONFIG.env" && switch_link "$previous" && { [[ $component != api ]] || start_api "$previous"; }; then
        if wait_health "$(basename "$previous")"; then
          say 'Rollback saludable. La publicación sigue marcada como fallida.'
        else
          say 'ERROR: rollback aplicado, pero falló su salud. Revisar DocIA en el VPS.' >&2
        fi
        if [[ $component == api ]]; then
          pm2 save >>"$log" 2>&1 || say 'ERROR: no se pudo guardar el estado PM2 de DocIA.' >&2
        fi
      else
        say 'ERROR: rollback incompleto. Revisar DocIA en el VPS.' >&2
      fi
    fi
  fi
  exit "$code"
}
trap on_exit EXIT
trap 'exit 130' INT
trap 'exit 143' HUP TERM

[[ $EUID -ne 0 ]] || fail 'Ejecutar como docia-deploy, sin sudo.'
mode=deploy
if [[ ${1:-} == --rollback ]]; then mode=rollback; shift; fi
[[ $# == 2 ]] || fail 'Uso: deploy.sh [--rollback] api|web|landing RELEASE_ID'
component=$1 id=$2
[[ $component == api || $component == web || $component == landing ]] || fail 'Componente inválido.'
valid_id "$id" || fail 'Identificador de versión inválido.'
name="$component-$id"
[[ $(readlink -f "$ROOT") == "$ROOT" ]] || fail 'La raíz de despliegue no puede ser un enlace.'
for directory in shared releases inbox logs pm2; do
  [[ -d "$ROOT/$directory" && ! -L "$ROOT/$directory" ]] || fail "Falta el directorio real $directory."
done
[[ -r "$ROOT/shared/server.conf" ]] || fail 'Missing shared/server.conf.'
# shellcheck source=/dev/null
source "$ROOT/shared/server.conf"
[[ $PUBLIC_CHECKS =~ ^[01]$ && $RUN_MIGRATIONS =~ ^[01]$ ]] || fail 'Invalid server flags.'
FRONTEND_HOSTING=${FRONTEND_HOSTING:-vps}
[[ $FRONTEND_HOSTING == vps || $FRONTEND_HOSTING == netlify ]] || fail 'Invalid FRONTEND_HOSTING.'
[[ $FRONTEND_HOSTING != netlify || $component != landing ]] || fail 'La landing se publica en Netlify desde Actions.'
export PM2_HOME="$ROOT/pm2"
for binary in curl tar sha256sum flock; do
  command -v "$binary" >/dev/null || fail "No se encontró $binary en PATH."
done
if [[ $component == api ]]; then
  for binary in node npm pm2 timeout; do
    command -v "$binary" >/dev/null || fail "No se encontró $binary en PATH."
  done
  [[ $(node -p 'process.versions.node.split(".")[0]') == 22 ]] || fail 'Este despliegue requiere Node 22, igual que CI.'
fi
[[ ${HEALTH_ATTEMPTS:-} =~ ^[1-9][0-9]?$ && ${HEALTH_DELAY:-} =~ ^[0-5]$ ]] || fail 'Configurar reintentos y delay (0..5).'
(( HEALTH_ATTEMPTS <= 15 )) || fail 'HEALTH_ATTEMPTS no puede exceder 15.'
exec 9>"$ROOT/deploy.lock"
say 'Esperando el bloqueo exclusivo de DocIA (máximo 15 minutos).'
flock --wait 900 9 || fail 'Timeout esperando otro despliegue o rollback de DocIA.'
log="$ROOT/logs/$name-$(date -u +%Y%m%dT%H%M%SZ).log"
touch "$log"
chmod 600 "$log"
if [[ -L "$ROOT/current-$component" ]]; then
  previous=$(readlink -f "$ROOT/current-$component")
  [[ $previous == "$ROOT/releases/$component-"* && $previous == "$ROOT/releases/$(basename "$previous")" ]] || fail 'Active version outside releases.'
  valid_id "$(basename "$previous" | sed "s/^$component-//")" || fail 'Invalid active version.'
  [[ -f "$previous/PUBLIC_CONFIG.env" ]] || fail 'Previous version lacks public configuration.'
elif [[ -e "$ROOT/current-$component" ]]; then
  fail 'current must be a managed symlink.'
fi
[[ ! -e "$ROOT/current-$component.next" && ! -L "$ROOT/current-$component.next" ]] || fail 'Revisar el enlace temporal de un deploy interrumpido.'
release="$ROOT/releases/$name"
if [[ $mode == deploy ]]; then
  [[ ! -e "$release" && ! -L "$release" ]] || fail 'La versión ya existe; reejecutar Actions para obtener otro ID.'
  [[ -f "$ROOT/inbox/$name.tar.gz" && ! -L "$ROOT/inbox/$name.tar.gz" ]] || fail 'Falta el artefacto.'
  [[ -f "$ROOT/inbox/$name.sha256" && ! -L "$ROOT/inbox/$name.sha256" ]] || fail 'Falta el checksum.'
  stage=checksum
  expected=$(cat "$ROOT/inbox/$name.sha256")
  [[ $expected =~ ^[0-9a-f]{64}$ ]] || fail 'Checksum inválido.'
  actual=$(sha256sum "$ROOT/inbox/$name.tar.gz")
  [[ ${actual%% *} == "$expected" ]] || fail 'El artefacto no coincide con SHA-256.'
  stage=extract
  mkdir "$release"
  tar -tzf "$ROOT/inbox/$name.tar.gz" > "$ROOT/logs/$name-files.txt" 2>>"$log"
  while IFS= read -r entry; do
    [[ $entry != /* && $entry != ../* && $entry != */../* && $entry != */.. ]] || fail 'Ruta insegura en el artefacto.'
    case "$entry" in
      "$component/"|"$component/"*|DEPLOYMENT_ID|PUBLIC_CONFIG.env) ;;
      ecosystem.config.cjs) [[ $component == api ]] || fail 'Contenido inesperado.' ;;
      *) fail 'Contenido inesperado en el artefacto.' ;;
    esac
  done < "$ROOT/logs/$name-files.txt"
  tar -tvzf "$ROOT/inbox/$name.tar.gz" > "$ROOT/logs/$name-metadata.txt" 2>>"$log"
  while IFS= read -r entry; do
    [[ ${entry:0:1} == - || ${entry:0:1} == d ]] || fail 'El artefacto no puede contener enlaces ni archivos especiales.'
  done < "$ROOT/logs/$name-metadata.txt"
  tar -xzf "$ROOT/inbox/$name.tar.gz" -C "$release" --no-same-owner >>"$log" 2>&1
  [[ $(cat "$release/DEPLOYMENT_ID") == "$name" ]] || fail 'El artefacto pertenece a otra publicación.'
  if [[ $component == api ]]; then
    [[ -f "$release/api/dist/main.js" && -f "$release/ecosystem.config.cjs" ]] || fail 'API incompleta.'
    [[ -f "$ROOT/shared/api.env" && ! -L "$ROOT/shared/api.env" ]] || fail 'Falta el entorno runtime compartido.'
    [[ ! -e "$release/api/.env" && ! -L "$release/api/.env" ]] || fail 'El artefacto no debe incluir .env.'
    ln -s "$ROOT/shared/api.env" "$release/api/.env"
    stage=dependencies
    say "Instalando dependencias para $name; salida privada en el VPS."
    (cd "$release/api" && timeout --kill-after=30s 300s npm ci --include=dev --no-audit --no-fund) >>"$log" 2>&1
    if [[ $RUN_MIGRATIONS == 1 ]]; then
      [[ -f "$ROOT/shared/migrations.env" && ! -L "$ROOT/shared/migrations.env" ]] || fail 'Falta el entorno administrativo de migraciones.'
      stage=migrations
      say 'Aplicando migraciones incrementales de DocIA.'
      (cd "$release/api" && DOTENV_CONFIG_PATH="$ROOT/shared/migrations.env" timeout --kill-after=30s 300s npm run db:migrate) >>"$log" 2>&1
    else
      say 'Migraciones desactivadas explícitamente; el esquema debe estar actualizado.'
    fi
  else
    [[ -f "$release/$component/index.html" ]] || fail 'Sitio incompleto.'
    [[ $(cat "$release/$component/docia-release.txt") == "$name" ]] || fail 'Marcador del sitio inválido.'
    if [[ $component == web ]]; then
      [[ -f "$release/web/flutter_bootstrap.js" ]] || fail 'Falta el bootstrap Flutter.'
      validate_web_apk "$release/web"
    else
      validate_landing "$release/landing"
    fi
    chmod 755 "$release"
    find "$release/$component" -type d -exec chmod 755 {} +
    find "$release/$component" -type f -exec chmod 644 {} +
  fi
else
  [[ -d "$release" && ! -L "$release" ]] || fail 'No existe la versión de rollback.'
  if [[ $component == api ]]; then
    [[ -f "$release/api/dist/main.js" && -f "$release/ecosystem.config.cjs" ]] || fail 'Rollback API incompleto.'
  elif [[ $component == web ]]; then
    [[ -f "$release/web/index.html" && -f "$release/web/docia-release.txt" ]] || fail 'Rollback web incompleto.'
    if [[ -f "$release/web/downloads/DocIA.apk.sha256" ]]; then validate_web_apk "$release/web"; fi
  else
    [[ -f "$release/landing/docia-release.txt" ]] || fail 'Rollback landing incompleto.'
    validate_landing "$release/landing"
  fi
fi
load_public "$release/PUBLIC_CONFIG.env"
stage=activate
say "Activando $name."
activated=1
switch_link "$release"
if [[ $component == api ]]; then start_api "$release"; fi
stage=health
say "Comprobando salud y versión de $component."
wait_health "$name" || fail 'Salud incorrecta: revisar log privado, URLs, proceso, PostgreSQL o root/caché Nginx de DocIA.'
stage=save
if [[ $component == api ]]; then pm2 save >>"$log" 2>&1; fi
if [[ -n "$previous" ]]; then
  ln -sfn "$previous" "$ROOT/previous-$component.next"
  mv -Tf "$ROOT/previous-$component.next" "$ROOT/previous-$component"
fi
activated=0
say "Publicación saludable: $name."
