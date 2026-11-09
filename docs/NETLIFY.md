# API en DuckDNS y frontends en Netlify

Este es el esquema del workflow actual. La landing y Flutter web se publican en dos proyectos Netlify. API, PostgreSQL, almacenamiento y APK firmado continúan en el VPS, en `/var/www/docia/monorepo`. Los sitios `.cloud` anteriores siguen funcionando.

El nombre de API confirmado es `api-docia.duckdns.org`. Los nombres Netlify siguientes son ejemplos: **todavía deben crearse y comprobar su disponibilidad**.

| Componente  | Ejemplo                 |
| ----------- | ----------------------- |
| API         | `api-docia.duckdns.org` |
| Flutter web | `docia-app.netlify.app` |
| Landing     | `docia.netlify.app`     |

## 1. Crear las direcciones

En DuckDNS, registrar un nombre para la API y apuntarlo a la IP pública del VPS. Configurar IPv6 solamente si corresponde al mismo servidor y funciona. El token DuckDNS permanece privado; Actions no lo necesita. Si cambia la IP, actualizar el registro desde el panel o mediante un actualizador privado.

En Netlify, crear **dos proyectos mediante Deploy manually, sin vincular el repositorio Git**. GitHub compila y publica mediante la API, evitando builds simultáneos y la necesidad de conectar el repositorio privado de la organización a Netlify. Elegir sus nombres y copiar cada **Project ID** desde la configuración del proyecto: es un UUID, no una URL.

Inicializar ambos proyectos subiendo una carpeta con un `index.html` temporal, para disponer de una versión anterior recuperable. Se puede crear desde la raíz nueva en PowerShell:

```powershell
New-Item -ItemType Directory -Force ".validation/netlify-initial" | Out-Null
'<!doctype html><html lang="es"><meta charset="utf-8"><title>DocIA</title><p>Publicación pendiente.</p></html>' | Set-Content -Encoding ascii ".validation/netlify-initial/index.html"
```

Cargar esa carpeta mediante Deploy manually en ambos proyectos, establecer su visibilidad pública y comprobar sus URL HTTPS desde una ventana privada. Algunos proyectos pueden crearse privados por defecto. No habilitar contraseña, snippets, minificación ni otras transformaciones del sitio: se verifican los bytes del build. La página temporal se reemplaza al publicar la aplicación real.

## 2. Configuración central y GitHub

Editar `config/environments/production.env` con los tres nombres reales:

```dotenv
PUBLIC_API_URL=https://api-docia.duckdns.org
PUBLIC_WEB_URL=https://docia-app.netlify.app
PUBLIC_LANDING_URL=https://docia.netlify.app
API_PREFIX=api/v1
```

El archivo todavía conserva los `.cloud` hasta que se creen las direcciones reales. No activar el deploy con nombres de ejemplo. Los builds, enlaces de correo, pagos, callback Google y CORS usan esta fuente pública. `legacy-cloud.env` describe únicamente la instalación anterior para validar su copia privada durante la migración; no se edita para cambios futuros de la instalación nueva.

En GitHub, crear el environment **`production`** y cargar estos diez secrets:

| Secret                      | Contenido                                                                 |
| --------------------------- | ------------------------------------------------------------------------- |
| `VPS_HOST`                  | IP pública SSH del VPS, sin protocolo                                     |
| `VPS_PORT`                  | Puerto SSH actual                                                         |
| `VPS_USER`                  | `docia-deploy`                                                            |
| `VPS_SSH_KEY`               | Clave privada autorizada para ese usuario                                 |
| `VPS_KNOWN_HOSTS`           | Host key verificada para la misma IP y puerto                             |
| `ANDROID_KEYSTORE_BASE64`   | Keystore original codificado en Base64                                    |
| `ANDROID_KEYSTORE_PASSWORD` | Contraseña original del keystore                                          |
| `ANDROID_KEY_ALIAS`         | Alias original                                                            |
| `ANDROID_KEY_PASSWORD`      | Contraseña original de la clave                                           |
| `NETLIFY_AUTH_TOKEN`        | Personal access token con permiso para publicar los dos proyectos Netlify |

Reutilizar la firma Android y acceso SSH existentes. Los secretos de los repositorios anteriores no se copian automáticamente. No generar un keystore nuevo ni agregar acceso root/sudo al despliegue. Los entornos de PostgreSQL, JWT e integraciones continúan privados en el VPS; no se cargan en Netlify.

En **Settings → Secrets and variables → Actions → Variables**, agregar repository variables:

| Variable                  | Valor                                                                                        |
| ------------------------- | -------------------------------------------------------------------------------------------- |
| `NETLIFY_WEB_SITE_ID`     | Project ID de Flutter web                                                                    |
| `NETLIFY_LANDING_SITE_ID` | Project ID de la landing                                                                     |
| `DOCIA_DEPLOY_ENABLED`    | `false` mientras se prepara el VPS                                                           |
| `DOCIA_WEB_CONFIG_JSON`   | Opcional: `{"STRIPE_PUBLISHABLE_KEY":"pk_live_REEMPLAZAR"}`, usando la clave publicable real |

No duplicar las URL en GitHub. Los Project IDs son configuración pública. El token se crea en la configuración personal de Netlify, en Applications / Personal access tokens, y se carga únicamente como secret.

Revisar el nuevo callback en Google OAuth, dominios autorizados Firebase, retorno/webhooks Stripe y demás integraciones activas. Mantener las direcciones anteriores autorizadas durante la transición. Las APK instaladas siguen usando `.cloud` hasta actualizarse con la nueva APK, firmada con el mismo keystore.

Después de revisar `git status`, subir los cambios desde la raíz nueva:

```powershell
git add .github/workflows/deploy.yml config/environments deploy docs README.md package.json
git diff --cached --stat
git commit -m "feat: deploy DocIA frontends to Netlify and API to VPS"
git push origin main
```

El push verifica el proyecto; Android y despliegue se omiten mientras `DOCIA_DEPLOY_ENABLED` no sea `true`.

## 3. Preparar el VPS en paralelo

Las claves privadas se conservan en `/root/.ssh` y `/root/docia-actions-keys`, independientemente de la carpeta actual de la terminal. El código nuevo se instala en `/var/www/docia/monorepo/repository`; sus releases y entorno privado quedan en `/var/www/docia/monorepo/deploy`. Las carpetas existentes `api`, `web`, `landing`, `deploy` y `secrets` se conservan.

Como administrador, con el usuario `docia-deploy`, Node 22 aislado y las herramientas del despliegue actual disponibles. No actualizar paquetes globales. La clave de lectura `/root/.ssh/docia-monorepo-github` debe estar registrada en **Laura-Nu/DocIA → Settings → Deploy keys**, sin permiso de escritura. Es distinta de la clave usada por Actions para entrar al VPS.

Si todavía no se creó esa clave, generarla una única vez y registrar la parte pública que imprime este bloque. Si ya existe, conservarla y pasar al bloque de clonación:

```bash
bash -e <<'BASH'
install -d -m 700 /root/.ssh
test ! -e /root/.ssh/docia-monorepo-github
test ! -e /root/.ssh/docia-monorepo-github.pub
ssh-keygen -t ed25519 -f /root/.ssh/docia-monorepo-github -N "" -C "docia-monorepo-readonly"
cat /root/.ssh/docia-monorepo-github.pub
BASH
```

Clonar la versión actualizada del repositorio nuevo:

```bash
bash -e <<'BASH'
test ! -e /var/www/docia/monorepo
test -f /root/.ssh/docia-monorepo-github
id docia-deploy
/home/docia-deploy/.local/node/bin/node --version
command -v git curl tar sha256sum flock nginx ss certbot
install -d -m 755 /var/www/docia/monorepo
export GIT_SSH_COMMAND="ssh -F /dev/null -i /root/.ssh/docia-monorepo-github -o IdentitiesOnly=yes -o StrictHostKeyChecking=yes"
git clone git@github.com:Laura-Nu/DocIA.git /var/www/docia/monorepo/repository
cd /var/www/docia/monorepo/repository
git config core.sshCommand "$GIT_SSH_COMMAND"
bash deploy/setup-server.sh --netlify
BASH
```

El instalador copia en privado los entornos de API/migraciones y conserva sus valores. Valida las URL anteriores contra `legacy-cloud.env` antes de retirar las URL derivadas **solo de la copia**. Enlaza almacenamiento, prepara vistas privadas en loopback y el servicio PM2 nuevo. Aborta ante callbacks personalizados, falta de continuidad Android, puertos ocupados o configuración existente; no ignorar esos errores. No reinicia la API anterior.

Si esta instalación nueva ya existe, no repetir el instalador ni borrarla. Revisar su estado y actualizar su checkout con `git pull --ff-only origin main`. Para una instalación preparada antes en modo VPS, establecer `FRONTEND_HOSTING=netlify` en su `deploy/shared/server.conf` y revisar las URL de la copia privada antes de continuar. Mantener `RUN_MIGRATIONS=0`.

## 4. Preparar solamente el nuevo Nginx de API y su certificado

Comprobar que DuckDNS resuelve al VPS y que los puertos públicos 80/443 funcionan. El bloque siguiente no sobrescribe archivos existentes y genera únicamente el sitio API. Conserva los virtual hosts y certificados `.cloud`:

```bash
bash -e <<'BASH'
cd /var/www/docia/monorepo/repository
task_node=/home/docia-deploy/.local/node/bin/node
"$task_node" deploy/public-config.cjs render-api config/environments/production.env deploy/generated/netlify
api_host=$("$task_node" -e 'const fs=require("fs"); const c=require("./deploy/public-config.cjs").parseEnv(fs.readFileSync("config/environments/production.env","utf8")); process.stdout.write(new URL(c.PUBLIC_API_URL).hostname)')
case "$api_host" in *.duckdns.org) ;; *) echo 'Configurar antes el nombre real DuckDNS de API.'; exit 1 ;; esac
site=/etc/nginx/conf.d/docia-monorepo-api.conf
test ! -e "$site"
test ! -L "$site"
install -d -m 755 /var/www/docia/monorepo/deploy/acme /var/www/docia/monorepo/deploy/acme/.well-known /var/www/docia/monorepo/deploy/acme/.well-known/acme-challenge
install -m 644 deploy/generated/netlify/docia-http-bootstrap.conf "$site"
if ! nginx -t; then rm -f -- "$site"; exit 1; fi
if ! systemctl reload nginx; then rm -f -- "$site"; nginx -t && systemctl reload nginx; exit 1; fi
certbot certonly --webroot -w /var/www/docia/monorepo/deploy/acme -d "$api_host" --deploy-hook 'nginx -t && systemctl reload nginx'
install -m 644 deploy/generated/netlify/docia-api.conf "$site"
if ! nginx -t; then install -m 644 deploy/generated/netlify/docia-http-bootstrap.conf "$site"; nginx -t; exit 1; fi
if ! systemctl reload nginx; then install -m 644 deploy/generated/netlify/docia-http-bootstrap.conf "$site"; nginx -t && systemctl reload nginx; exit 1; fi
systemctl list-timers --all | grep -F certbot || true
BASH
```

Certbot puede pedir correo y aceptación de condiciones. Ante un fallo de emisión, corregir DNS/acceso y repetir únicamente la emisión, conservando el bootstrap HTTP. Confirmar que la renovación automática de Certbot ya existente sigue activa y recarga Nginx cuando renueva certificados. **No ejecutar `cutover.cjs`**: corresponde al cambio de los sitios `.cloud`.

## 5. Primer despliegue y arranque automático

Después de emitir el certificado, establecer en `/var/www/docia/monorepo/deploy/shared/server.conf`:

```bash
FRONTEND_HOSTING=netlify
PUBLIC_CHECKS=1
RUN_MIGRATIONS=0
```

Activar `DOCIA_DEPLOY_ENABLED=true` en GitHub y ejecutar **Actions → Verify and deploy DocIA → Run workflow → main**. Se verifica el acceso y URL de ambos proyectos Netlify antes de cambiar el VPS. Después se publican API/APK → web → landing. El VPS conserva una copia privada del build Flutter para versionar y comprobar su APK; no tiene un virtual host público para la nueva web. La landing no se despliega al VPS.

Cada publicación Netlify comprueba un borrador antes de activarlo y verifica después la URL pública. Ante un fallo público, intenta restaurar la versión anterior del mismo sitio y Actions falla. La recuperación es por componente: un fallo de landing no deshace una API/web saludable ya publicada. Los fallos API/APK mantienen el rollback del VPS. Los errores no imprimen tokens ni respuestas privadas.

Comprobar con las direcciones reales:

```bash
curl --fail --silent --show-error https://api-docia.duckdns.org/api/v1/health/ready
curl --fail --silent --show-error https://api-docia.duckdns.org/downloads/android-release.json
curl --fail --silent --show-error https://docia-app.netlify.app/docia-release.txt
curl --fail --silent --show-error https://docia.netlify.app/docia-release.txt
curl --fail --silent --show-error --head https://docia.netlify.app/downloads/DocIA.apk
```

La última URL redirige al APK en DuckDNS. El deploy del VPS comprueba también el SHA-256 del APK descargado. Netlify no almacena ni transfiere ese binario.

Habilitar el servicio nuevo cuando el primer deploy haya guardado su lista; estos comandos reinician exclusivamente la API nueva:

```bash
bash -e <<'BASH'
test -s /var/www/docia/monorepo/deploy/pm2/dump.pm2
sudo -u docia-deploy env PATH=/home/docia-deploy/.local/node/bin:/home/docia-deploy/.local/bin:/usr/bin:/bin PM2_HOME=/var/www/docia/monorepo/deploy/pm2 /home/docia-deploy/.local/bin/pm2 kill
systemctl enable --now docia-monorepo-pm2.service
systemctl status docia-monorepo-pm2.service --no-pager
curl --fail --silent --show-error --retry 10 --retry-connrefused --retry-delay 2 http://127.0.0.1:3100/api/v1/health/ready
BASH
```

Probar acceso, formularios, roles, archivos, correo, pagos y Google con cuentas de prueba, además de instalar la APK como actualización. No usar comandos PM2 globales sin especificar su `PM2_HOME`.

## 6. Convivencia y siguientes pushes

Los sitios `.cloud` siguen apuntando a la instalación anterior. La base y los archivos son compartidos: una escritura afecta a ambas y el rollback del código no revierte datos. Mantener `RUN_MIGRATIONS=0` mientras convivan. Revisar respaldo y compatibilidad antes de activar futuras migraciones y evitar despliegues antiguos que cambien simultáneamente el esquema.

Con la preparación completa, cada push a `main` ejecuta el circuito sin entrar al VPS. Vigilar la cuota de Netlify: deploys de producción y tráfico consumen créditos y los sitios pueden pausarse al agotarla. Los cambios futuros de dominio parten de `production.env` y requieren preparar DNS/certificados/autorizaciones externas y recompilar la APK. El preflight compara las URL HTTPS de Netlify con el archivo central para evitar publicar en un proyecto equivocado.

Referencias: [API y despliegues Netlify](https://docs.netlify.com/api-and-cli-guides/api-guides/get-started-with-api/), [redirecciones](https://docs.netlify.com/manage/routing/redirects/redirect-options/), [cuotas](https://www.netlify.com/pricing/), [DuckDNS](https://www.duckdns.org/spec.jsp), [certificados](https://letsencrypt.org/docs/challenge-types/).
