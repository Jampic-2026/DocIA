#!/usr/bin/env bash
# No real npm, PM2 or HTTP services are used.
set -Eeuo pipefail
test_dir=$(cd "$(dirname "$0")/.." && pwd)
scratch=$(mktemp -d)
cleanup() {
  [[ "$scratch" == "${TMPDIR:-/tmp}/"* ]] && rm -rf -- "$scratch"
}
trap cleanup EXIT
old=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa-1-1
new=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb-2-1
export TEST_OLD="$old" TEST_NEW="$new"
export TEST_REAL_NODE
TEST_REAL_NODE=$(command -v node)

fixture() {
  local component=$1 scenario=$2
  export TEST_ROOT="$scratch/$component-$scenario" TEST_MODE="$scenario" TEST_COMPONENT="$component"
  mkdir -p "$TEST_ROOT"/{shared,releases,inbox,logs,pm2,mocks,payload}
  mkdir -p "$TEST_ROOT/releases/$component-$old/$component"
  if [[ $component == api ]]; then
    mkdir -p "$TEST_ROOT/payload/api/dist" "$TEST_ROOT/releases/api-$old/api/dist"
    printf 'old' > "$TEST_ROOT/releases/api-$old/api/dist/main.js"
    printf 'new' > "$TEST_ROOT/payload/api/dist/main.js"
    printf 'module.exports={};' > "$TEST_ROOT/releases/api-$old/ecosystem.config.cjs"
    printf 'module.exports={};' > "$TEST_ROOT/payload/ecosystem.config.cjs"
  elif [[ $component == web ]]; then
    mkdir -p "$TEST_ROOT/payload/web"
    printf 'html' > "$TEST_ROOT/payload/web/index.html"
    printf 'js' > "$TEST_ROOT/payload/web/flutter_bootstrap.js"
    printf 'web-%s\n' "$new" > "$TEST_ROOT/payload/web/docia-release.txt"
    mkdir -p "$TEST_ROOT/payload/web/downloads" "$TEST_ROOT/releases/web-$old/web/downloads"
    printf 'PK-new-apk' > "$TEST_ROOT/payload/web/downloads/DocIA.apk"
    sha256sum "$TEST_ROOT/payload/web/downloads/DocIA.apk" | cut -d ' ' -f 1 > "$TEST_ROOT/payload/web/downloads/DocIA.apk.sha256"
    printf '{}' > "$TEST_ROOT/payload/web/downloads/android-release.json"
    cp "$TEST_ROOT/payload/web/downloads/"* "$TEST_ROOT/releases/web-$old/web/downloads/"
    cp "$TEST_ROOT/payload/web/"{index.html,flutter_bootstrap.js} "$TEST_ROOT/releases/web-$old/web/"
    printf 'web-%s\n' "$old" > "$TEST_ROOT/releases/web-$old/web/docia-release.txt"
  else
    mkdir -p "$TEST_ROOT/payload/landing/assets" "$TEST_ROOT/releases/web-$old/web/downloads"
    printf '<script src="/assets/app.js"></script>' > "$TEST_ROOT/payload/landing/index.html"
    printf 'landing-js' > "$TEST_ROOT/payload/landing/assets/app.js"
    printf 'landing-css' > "$TEST_ROOT/payload/landing/assets/app.css"
    (cd "$TEST_ROOT/payload/landing" && sha256sum index.html assets/app.js assets/app.css > docia-assets.sha256)
    cp -R "$TEST_ROOT/payload/landing/"* "$TEST_ROOT/releases/landing-$old/landing/"
    printf 'landing-%s\n' "$new" > "$TEST_ROOT/payload/landing/docia-release.txt"
    printf 'landing-%s\n' "$old" > "$TEST_ROOT/releases/landing-$old/landing/docia-release.txt"
    printf 'PK-existing-apk' > "$TEST_ROOT/releases/web-$old/web/downloads/DocIA.apk"
    sha256sum "$TEST_ROOT/releases/web-$old/web/downloads/DocIA.apk" | cut -d ' ' -f 1 > "$TEST_ROOT/releases/web-$old/web/downloads/DocIA.apk.sha256"
    ln -s "$TEST_ROOT/releases/web-$old" "$TEST_ROOT/current-web"
  fi
  ln -s "$TEST_ROOT/releases/$component-$old" "$TEST_ROOT/current-$component"
  mkdir "$TEST_ROOT/releases/other-component"
  if [[ $component == api ]]; then other=web; else other=api; fi
  ln -s "$TEST_ROOT/releases/other-component" "$TEST_ROOT/current-$other"
  printf '%s-%s\n' "$component" "$new" > "$TEST_ROOT/payload/DEPLOYMENT_ID"
  touch "$TEST_ROOT/shared/api.env" "$TEST_ROOT/shared/migrations.env"
  cat > "$TEST_ROOT/shared/server.conf" <<EOF
export PATH="$TEST_ROOT/mocks:$PATH"
API_READY_URL=http://127.0.0.1:3100/api/v1/health/ready
PUBLIC_CHECKS=1
PUBLIC_API_READY_URL=https://api.example.com/api/v1/health/ready
WEB_BASE_URL=https://app.example.com
LANDING_BASE_URL=https://landing.example.com
RUN_MIGRATIONS=1
HEALTH_ATTEMPTS=2
HEALTH_DELAY=0
EOF
  printf "PUBLIC_API_URL=https://api.example.com\nPUBLIC_WEB_URL=https://app.example.com\nPUBLIC_LANDING_URL=https://landing.example.com\nAPI_PREFIX=api/v1\n" > "$TEST_ROOT/payload/PUBLIC_CONFIG.env"
  if [[ $scenario == shared-sites ]]; then
    printf 'PUBLIC_API_URL=https://api-next.example.com\nPUBLIC_WEB_URL=https://app-next.example.com\nPUBLIC_LANDING_URL=https://landing-next.example.com\nAPI_PREFIX=api/v2\n' > "$TEST_ROOT/payload/PUBLIC_CONFIG.env"
  fi
  cp "$TEST_ROOT/payload/PUBLIC_CONFIG.env" "$TEST_ROOT/releases/$component-$old/PUBLIC_CONFIG.env"
  cat > "$TEST_ROOT/mocks/npm" <<'EOF'
#!/usr/bin/env bash
printf 'synthetic-private-value\n'
if [[ $TEST_MODE == dependency-failure && $1 == ci ]]; then exit 41; fi
if [[ $TEST_MODE == migration-failure && $* == *db:migrate* ]]; then exit 42; fi
EOF
  cat > "$TEST_ROOT/mocks/pm2" <<'EOF'
#!/usr/bin/env bash
[[ $PM2_HOME == "$TEST_ROOT/pm2" ]] || exit 90
[[ " $* " != *" all "* ]] || exit 91
printf '%s\n' "$*" >> "$TEST_ROOT/pm2-commands"
if [[ $TEST_MODE == restart-failure && $* == *"$TEST_NEW"* ]]; then exit 43; fi
EOF
  cat > "$TEST_ROOT/mocks/node" <<'EOF'
#!/usr/bin/env bash
if [[ $1 == -p ]]; then printf '22\n'; else exec "$TEST_REAL_NODE" "$@"; fi
EOF
  cat > "$TEST_ROOT/mocks/curl" <<'EOF'
#!/usr/bin/env bash
url=${*: -1}
printf '%s\n' "$url" >> "$TEST_ROOT/requests"
output=''
args=("$@")
for ((i=0; i<${#args[@]}; i++)); do
  if [[ ${args[$i]} == --output ]]; then output=${args[$((i+1))]}; fi
done
current=$(basename "$(readlink -f "$TEST_ROOT/current-$TEST_COMPONENT")")
if [[ $current == "$TEST_COMPONENT-$TEST_NEW" ]]; then
  if [[ $TEST_MODE == api-failure && $url == *health/ready ]]; then exit 22; fi
  if [[ $TEST_MODE == public-api-failure && $url == https://api.* ]]; then exit 22; fi
  if [[ $TEST_MODE == wrong-version && $url == *health/ready ]]; then current="api-$TEST_OLD"; fi
  if [[ $TEST_MODE == web-failure && $url == *docia-release.txt* ]]; then printf '<html>SPA fallback</html>'; exit; fi
  if [[ $TEST_MODE == landing-failure && $url == *docia-release.txt* ]]; then printf '<html>SPA fallback</html>'; exit; fi
  if [[ $TEST_MODE == landing-asset-failure && $url == *assets/app.js* ]]; then printf '<html>SPA fallback</html>' > "$output"; exit; fi
  if [[ $TEST_MODE == bootstrap-failure && $url == *flutter_bootstrap.js* ]]; then exit 22; fi
  if [[ $TEST_MODE == apk-download-failure && $url == *downloads/DocIA.apk\?* ]]; then exit 22; fi
  if [[ $TEST_MODE == apk-checksum-failure && $url == *downloads/DocIA.apk.sha256* ]]; then printf '%064d\n' 0; exit; fi
  if [[ $TEST_MODE == stale-apk && $url == *downloads/DocIA.apk\?* ]]; then printf 'stale-apk' > "$output"; exit; fi
fi
apk_release=$current
if [[ $TEST_COMPONENT == landing ]]; then apk_release=$(basename "$(readlink -f "$TEST_ROOT/current-web")"); fi
case "$url" in
  *health/ready) printf '{"status":"ok","service":"api-docia","release":"%s"}' "$current" ;;
  *docia-release.txt*) printf '%s\n' "$current" ;;
  *downloads/DocIA.apk.sha256*) cat "$TEST_ROOT/releases/$apk_release/web/downloads/DocIA.apk.sha256" ;;
  *downloads/DocIA.apk\?*) cp "$TEST_ROOT/releases/$apk_release/web/downloads/DocIA.apk" "$output" ;;
  https://landing.example.com/*|https://landing-next.example.com/*|http://127.0.0.1:8089/*)
    asset=${url#*://*/}
    asset=${asset%%\?*}
    cp "$TEST_ROOT/releases/$current/landing/$asset" "$output"
    ;;
esac
EOF
  cat > "$TEST_ROOT/mocks/timeout" <<'EOF'
#!/usr/bin/env bash
shift 2
exec "$@"
EOF
  # Git Bash has no flock; Linux CI uses the real OS lock.
  if ! command -v flock >/dev/null; then printf '#!/usr/bin/env bash\nexit 0\n' > "$TEST_ROOT/mocks/flock"; fi
  chmod +x "$TEST_ROOT/mocks/"*
  sed "s|readonly ROOT=/var/www/docia-monorepo/deploy|readonly ROOT=$TEST_ROOT|" "$test_dir/deploy.sh" > "$TEST_ROOT/deploy.sh"
  package
}
package() {
  local files=("$TEST_COMPONENT" DEPLOYMENT_ID PUBLIC_CONFIG.env)
  if [[ $TEST_COMPONENT == api ]]; then files+=(ecosystem.config.cjs); fi
  tar -czf "$TEST_ROOT/inbox/$TEST_COMPONENT-$new.tar.gz" -C "$TEST_ROOT/payload" "${files[@]}"
  sha256sum "$TEST_ROOT/inbox/$TEST_COMPONENT-$new.tar.gz" | cut -d ' ' -f 1 > "$TEST_ROOT/inbox/$TEST_COMPONENT-$new.sha256"
}
run_deploy() {
  local status=0 component=$TEST_COMPONENT
  bash "$TEST_ROOT/deploy.sh" "$component" "$new" > "$TEST_ROOT/output" 2>&1 || status=$?
  if [[ $TEST_MODE == success || $TEST_MODE == shared-sites ]]; then
    [[ $status == 0 ]] || { cat "$TEST_ROOT/output"; exit 1; }
    [[ $(readlink -f "$TEST_ROOT/current-$component") == "$TEST_ROOT/releases/$component-$new" ]]
    [[ $(readlink -f "$TEST_ROOT/previous-$component") == "$TEST_ROOT/releases/$component-$old" ]]
    bash "$TEST_ROOT/deploy.sh" --rollback "$component" "$old" > "$TEST_ROOT/rollback-output" 2>&1
    [[ $(readlink -f "$TEST_ROOT/current-$component") == "$TEST_ROOT/releases/$component-$old" ]]
    if [[ $TEST_MODE == shared-sites ]]; then
      case "$component" in
        api) grep -Fq 'https://api-next.example.com/api/v2/health/ready' "$TEST_ROOT/requests" ;;
        web) grep -Fq 'https://app-next.example.com/docia-release.txt' "$TEST_ROOT/requests" ;;
        landing) grep -Fq 'https://landing-next.example.com/docia-release.txt' "$TEST_ROOT/requests" ;;
      esac
      if grep -Eq 'https://(api|app|landing)\.example\.com' "$TEST_ROOT/requests"; then echo 'Legacy domain used despite public-sites.env'; exit 1; fi
    fi
  else
    [[ $status != 0 ]]
    [[ $(readlink -f "$TEST_ROOT/current-$component") == "$TEST_ROOT/releases/$component-$old" ]]
  fi
  [[ $(readlink -f "$TEST_ROOT/current-$other") == "$TEST_ROOT/releases/other-component" ]]
  [[ $(cat "$TEST_ROOT/output") != *synthetic-private-value* ]]
  if [[ $component != api ]]; then [[ ! -e "$TEST_ROOT/pm2-commands" ]]; fi
  if [[ $component == landing ]]; then
    [[ $(readlink -f "$TEST_ROOT/current-web") == "$TEST_ROOT/releases/web-$old" ]]
  fi
}
for scenario in success shared-sites dependency-failure migration-failure restart-failure api-failure public-api-failure wrong-version checksum-failure unsafe-archive; do
  fixture api "$scenario"
  if [[ $scenario == checksum-failure ]]; then printf '%064d\n' 0 > "$TEST_ROOT/inbox/api-$new.sha256"; fi
  if [[ $scenario == unsafe-archive ]]; then ln -s /etc "$TEST_ROOT/payload/api/escape"; package; fi
  run_deploy
  printf 'PASS api: %s\n' "$scenario"
done
for scenario in success shared-sites web-failure bootstrap-failure apk-download-failure apk-checksum-failure stale-apk missing-apk corrupt-apk; do
  fixture web "$scenario"
  if [[ $scenario == missing-apk ]]; then rm "$TEST_ROOT/payload/web/downloads/DocIA.apk"; package; fi
  if [[ $scenario == corrupt-apk ]]; then printf 'corrupt-apk' > "$TEST_ROOT/payload/web/downloads/DocIA.apk"; package; fi
  run_deploy
  printf 'PASS web: %s\n' "$scenario"
done
fixture web legacy-rollback
export TEST_MODE=success
rm -r "$TEST_ROOT/releases/web-$old/web/downloads"
run_deploy
printf 'PASS web: rollback to a release created before APK automation\n'
for scenario in success shared-sites landing-failure landing-asset-failure stale-apk missing-asset invalid-manifest; do
  fixture landing "$scenario"
  if [[ $scenario == missing-asset ]]; then rm "$TEST_ROOT/payload/landing/assets/app.js"; package; fi
  if [[ $scenario == invalid-manifest ]]; then printf '%064d  ../../shared/api.env\n' 0 > "$TEST_ROOT/payload/landing/docia-assets.sha256"; package; fi
  run_deploy
  printf 'PASS landing: %s\n' "$scenario"
done
if command -v flock >/dev/null; then
  fixture api locked
  sed -i 's/flock --wait 900 9/flock --wait 1 9/' "$TEST_ROOT/deploy.sh"
  exec 8>"$TEST_ROOT/deploy.lock"
  flock -n 8
  run_deploy
  exec 8>&-
  printf 'PASS: concurrent deployment waits for the OS lock\n'
fi


for component in api web landing; do
  for mode in success failure; do
    fixture "$component" "first-$mode"
    rm "$TEST_ROOT/current-$component"
    if [[ $mode == failure ]]; then
      if [[ $component == api ]]; then export TEST_MODE=api-failure; elif [[ $component == web ]]; then export TEST_MODE=web-failure; else export TEST_MODE=landing-failure; fi
    else export TEST_MODE=success; fi
    sed -i 's/PUBLIC_CHECKS=1/PUBLIC_CHECKS=0/' "$TEST_ROOT/shared/server.conf"
    status=0
    bash "$TEST_ROOT/deploy.sh" "$component" "$new" > "$TEST_ROOT/output" 2>&1 || status=$?
    if [[ $mode == success ]]; then
      [[ $status == 0 && -L "$TEST_ROOT/current-$component" ]] || { cat "$TEST_ROOT/output"; exit 1; }
    else
      [[ $status != 0 && ! -L "$TEST_ROOT/current-$component" ]] || { cat "$TEST_ROOT/output"; exit 1; }
    fi
    if grep -q 'https://' "$TEST_ROOT/requests"; then echo 'Public URL checked during staging'; exit 1; fi
    printf 'PASS first installation %s: %s\n' "$component" "$mode"
  done
done
