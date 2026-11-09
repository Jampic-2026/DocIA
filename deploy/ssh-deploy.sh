#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
die() { printf '::error::%s\n' "$1" >&2; exit 1; }
[[ $# == 1 && ( $1 == api || $1 == web || $1 == landing ) ]] || die 'Indicar el componente api, web o landing.'
component=$1
[[ ${RELEASE_ID:-} =~ ^[0-9a-f]{40}-[0-9]+-[0-9]+$ ]] || die 'RELEASE_ID inválido.'
[[ ${VPS_HOST:-} =~ ^[a-zA-Z0-9][a-zA-Z0-9.-]*$ ]] || die 'Configurar VPS_HOST con hostname o IPv4, sin protocolo.'
[[ ${VPS_USER:-} == docia-deploy ]] || die 'VPS_USER debe ser docia-deploy, el usuario aislado de DocIA.'
VPS_PORT=${VPS_PORT:-22}
[[ $VPS_PORT =~ ^[0-9]{1,5}$ ]] || die 'VPS_PORT inválido.'
(( 10#$VPS_PORT >= 1 && 10#$VPS_PORT <= 65535 )) || die 'VPS_PORT fuera de rango.'
[[ -n ${VPS_SSH_KEY:-} && -n ${VPS_KNOWN_HOSTS:-} ]] || die 'Faltan VPS_SSH_KEY o VPS_KNOWN_HOSTS.'
[[ -n ${RUNNER_TEMP:-} && -d $RUNNER_TEMP ]] || die 'Este script debe ejecutarse en GitHub Actions.'
ssh_dir=$(mktemp -d "$RUNNER_TEMP/docia-ssh.XXXXXX")
cleanup() {
  rm -f -- "$ssh_dir/key" "$ssh_dir/known_hosts" "$ssh_dir/config"
  rmdir -- "$ssh_dir"
}
trap cleanup EXIT
printf '%s\n' "$VPS_SSH_KEY" | tr -d '\r' > "$ssh_dir/key"
printf '%s\n' "$VPS_KNOWN_HOSTS" | tr -d '\r' > "$ssh_dir/known_hosts"
chmod 600 "$ssh_dir/key" "$ssh_dir/known_hosts"
# Never scan and trust the server's key during deployment. Pin a verified key.
cat > "$ssh_dir/config" <<EOF
Host docia-vps
  HostName $VPS_HOST
  User $VPS_USER
  Port $VPS_PORT
  IdentityFile $ssh_dir/key
  UserKnownHostsFile $ssh_dir/known_hosts
  GlobalKnownHostsFile /dev/null
  StrictHostKeyChecking yes
  IdentitiesOnly yes
  BatchMode yes
  ConnectTimeout 15
  ServerAliveInterval 15
  ServerAliveCountMax 4
  LogLevel ERROR
EOF
unset VPS_SSH_KEY VPS_KNOWN_HOSTS
scp -F "$ssh_dir/config" -- "release/$component-$RELEASE_ID.tar.gz" "release/$component-$RELEASE_ID.sha256" \
  docia-vps:/var/www/docia-monorepo/deploy/inbox/
ssh -F "$ssh_dir/config" docia-vps "bash -s -- $component $RELEASE_ID" < deploy/deploy.sh
