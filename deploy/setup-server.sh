#!/usr/bin/env bash
# Run as root only after cloning the NEW repository into this exact location.
set -Eeuo pipefail
umask 077
ROOT=/var/www/docia-monorepo/deploy
LEGACY=/var/www/docia/deploy
REPO=/var/www/docia-monorepo/repository
hosting=vps
if [[ ${1:-} == --netlify && $# == 1 ]]; then
  hosting=netlify
  export DOCIA_MIGRATION_SOURCE=legacy-cloud
elif (( $# != 0 )); then
  echo 'Usage: setup-server.sh [--netlify]'
  exit 1
fi
[[ $EUID == 0 && $(realpath "$(dirname "$0")/..") == "$REPO" ]] || { echo 'Run as root from /var/www/docia-monorepo/repository/deploy/setup-server.sh'; exit 1; }
id docia-deploy >/dev/null
[[ ! -L /var/www/docia-monorepo && ! -L "$ROOT" ]] || exit 1
[[ ! -e "$ROOT/shared/server.conf" ]] || { echo 'Already configured; existing configuration preserved.'; exit 1; }
for file in /etc/nginx/conf.d/docia-monorepo-preview.conf /etc/systemd/system/docia-monorepo-pm2.service; do
  [[ ! -e "$file" && ! -L "$file" ]] || { echo 'A monorepo configuration file already exists; inspect it before continuing.'; exit 1; }
done
for port in 3100 8088 8089; do
  if ss -H -ltn "sport = :$port" | grep -q .; then echo "Port $port is already in use; aborting."; exit 1; fi
done
for file in api.env migrations.env; do [[ -f "$LEGACY/shared/$file" && ! -L "$LEGACY/shared/$file" ]] || exit 1; done
[[ -d "$LEGACY/shared/storage" ]] || { echo 'Legacy storage is missing.'; exit 1; }
[[ -x /home/docia-deploy/.local/bin/pm2 && -x /home/docia-deploy/.local/node/bin/node ]] || exit 1
metadata="$LEGACY/current-web/web/downloads/android-release.json"
[[ -f "$metadata" ]] || { echo 'Cannot verify Android version continuity.'; exit 1; }
/home/docia-deploy/.local/node/bin/node "$REPO/deploy/prepare-api-env.cjs" --check-only "$LEGACY/shared/api.env"
/home/docia-deploy/.local/node/bin/node -e '
const fs=require("fs");const old=JSON.parse(fs.readFileSync(process.argv[1]));const base=JSON.parse(fs.readFileSync(process.argv[2])).versionCodeBase;
if(!Number.isSafeInteger(old.versionCode)||!Number.isSafeInteger(base)||base<=old.versionCode) process.exit(1);
' "$metadata" "$REPO/config/android-version.json" || { echo 'Increase config/android-version.json above the APK currently distributed.'; exit 1; }
install -d -m 755 /var/www/docia-monorepo
install -d -o docia-deploy -g docia-deploy -m 755 "$ROOT"
for dir in shared releases inbox logs pm2; do
  [[ ! -L "$ROOT/$dir" ]] || exit 1
  install -d -o docia-deploy -g docia-deploy -m 700 "$ROOT/$dir"
done
# Nginx traverses release paths but cannot read private logs/configuration.
chmod 755 "$ROOT/releases"
for file in api.env migrations.env; do
  [[ ! -e "$ROOT/shared/$file" ]] || exit 1
  install -o docia-deploy -g docia-deploy -m 600 "$LEGACY/shared/$file" "$ROOT/shared/$file"
done
# Only the new private copy is normalized, after checking every preserved value.
/home/docia-deploy/.local/node/bin/node "$REPO/deploy/prepare-api-env.cjs" "$ROOT/shared/api.env"
ln -s "$LEGACY/shared/storage" "$ROOT/shared/storage"
cat > "$ROOT/shared/server.conf" <<'EOF'
export PATH=/home/docia-deploy/.local/node/bin:/home/docia-deploy/.local/bin:/usr/local/bin:/usr/bin:/bin
PUBLIC_CHECKS=0
RUN_MIGRATIONS=0
HEALTH_ATTEMPTS=12
HEALTH_DELAY=3
EOF
chown docia-deploy:docia-deploy "$ROOT/shared/server.conf"
chmod 600 "$ROOT/shared/server.conf"
printf 'FRONTEND_HOSTING=%s\n' "$hosting" >> "$ROOT/shared/server.conf"
preview=/etc/nginx/conf.d/docia-monorepo-preview.conf
[[ ! -e "$preview" && ! -L "$preview" ]] || { echo 'Preview file exists; review it manually.'; exit 1; }
install -m 644 "$REPO/deploy/nginx-preview.conf" "$preview"
if ! nginx -t; then rm -f -- "$preview"; exit 1; fi
if ! systemctl reload nginx; then rm -f -- "$preview"; nginx -t && systemctl reload nginx; exit 1; fi
install -m 644 "$REPO/deploy/docia-monorepo-pm2.service" /etc/systemd/system/docia-monorepo-pm2.service
systemctl daemon-reload
echo 'PREPARADO: producción conserva sus rutas. Para API DuckDNS y frontends Netlify, seguir docs/NETLIFY.md; no ejecutar cutover.cjs.'
