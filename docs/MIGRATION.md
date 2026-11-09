# Migración a un repositorio único

> El workflow actual publica los frontends en Netlify y API/APK en el VPS. Seguir **[NETLIFY.md](NETLIFY.md)** para ese esquema. Este documento conserva la propuesta anterior con los tres sitios en el VPS; sus pasos de cutover no corresponden a la instalación paralela DuckDNS/Netlify.

## 1. Crear y subir el repositorio nuevo

Crear un repositorio **privado y vacío** llamado `DocIA` en `Jampic-2026`. No agregar README ni `.gitignore` desde GitHub. Usar esta carpeta nueva, que está dentro de la carpeta de trabajo general y junto a las aplicaciones originales:

```powershell
cd 'C:\Users\launu\OneDrive\Documentos\GitHub\DocIA\DocIA'
node deploy/check-upload.cjs
git init -b main
git add .
git diff --cached --stat
git status --short
git commit -m "feat: consolidate DocIA apps with isolated automated deployment"
git remote add origin git@github.com:Jampic-2026/DocIA.git
git push -u origin main
```

Si elegís otro nombre, reemplazar `Jampic-2026/DocIA` en todos los comandos. No ejecutar estos comandos desde la carpeta padre. No copiar `.git` de los repositorios originales. `git status` debe mostrar código y configuración pública, sin `.env` reales, `key.properties`, `.jks`, APK, dependencias ni builds. La revisión automática detecta formatos privados conocidos; también revisar manualmente el listado antes del commit.

El primer workflow verifica el proyecto; Android y SSH permanecen deshabilitados hasta configurar `DOCIA_DEPLOY_ENABLED`. Si existe una protección de rama, permitir la primera subida según las reglas de la organización y después exigir los jobs `tools`, `api`, `web`, `landing` en las pull requests.

## 2. Configurar GitHub

En el repositorio nuevo: **Settings → Environments → New environment → `production`**. Agregar los mismos secrets que ya funcionan, con estos nombres:

| Secret                      | Contenido                                           |
| --------------------------- | --------------------------------------------------- |
| `VPS_HOST`                  | IP o hostname SSH del VPS, sin `https://`           |
| `VPS_PORT`                  | Puerto SSH, normalmente `22`                        |
| `VPS_USER`                  | `docia-deploy`                                      |
| `VPS_SSH_KEY`               | Clave privada SSH autorizada para ese usuario       |
| `VPS_KNOWN_HOSTS`           | Host key verificada del mismo VPS y puerto          |
| `ANDROID_KEYSTORE_BASE64`   | El mismo keystore de la APK actualmente distribuida |
| `ANDROID_KEYSTORE_PASSWORD` | Contraseña de ese keystore                          |
| `ANDROID_KEY_ALIAS`         | Alias existente                                     |
| `ANDROID_KEY_PASSWORD`      | Contraseña de la clave existente                    |

GitHub no permite leer un secret guardado: volver a cargarlo desde su fuente privada. Para este primer cambio se puede reutilizar la clave SSH de un workflow existente que ya acceda como `docia-deploy`, sin modificar sus archivos. No agregar claves a root ni permisos sudo. Si se genera otra clave, incorporar únicamente su parte pública con `restrict` en `/home/docia-deploy/.ssh/authorized_keys`, conservando las entradas actuales.

No usar `ssh-keyscan` como confianza automática durante el workflow. Verificar la huella desde la consola del VPS contra la clave que se carga en `VPS_KNOWN_HOSTS`. Para puertos distintos de 22, el formato es `[HOST]:PUERTO`.

Si la aplicación utiliza Stripe, agregar en **Settings → Secrets and variables → Actions → Variables** la variable opcional `DOCIA_WEB_CONFIG_JSON` únicamente con la clave publicable real existente, por ejemplo `{"STRIPE_PUBLISHABLE_KEY":"pk_live_REEMPLAZAR"}`. Si no usa Stripe, omitirla. Las URL se obtienen siempre del archivo central; no configurar `DOCIA_PUBLIC_CONFIG_JSON` ni `API_BASE_URL` por separado.

**Todavía no crear `DOCIA_DEPLOY_ENABLED=true`.** Primero completar el paso 3.

## 3. Preparar una instalación paralela en el VPS

Entrar por SSH como administrador. Los siguientes comandos no hacen `git pull`, limpiezas ni reinicios en las carpetas antiguas.

Comprobar espacio y herramientas, sin actualizar paquetes globales:

```bash
df -h /var/www
command -v git curl tar sha256sum flock nginx ss
id docia-deploy
/home/docia-deploy/.local/node/bin/node --version
```

Se requiere Node 22, que ya utiliza el despliegue actual. El instalador reutiliza sus binarios aislados y el usuario, sin cambiar versiones globales. Si falta alguna herramienta, instalar únicamente el paquete faltante.

Clonar el repositorio nuevo utilizando el acceso GitHub del administrador. Autorizar esa clave de lectura también para el repositorio nuevo en GitHub si fuera necesario; la clave utilizada para entrar al VPS desde Actions es un acceso diferente. El ejemplo usa el alias SSH existente `github-jampic`; si no tiene acceso al repositorio nuevo, ajustarlo antes de continuar:

```bash
test ! -e /var/www/docia/monorepo
install -d -m 755 /var/www/docia/monorepo
git clone git@github-jampic:Jampic-2026/DocIA.git /var/www/docia/monorepo/repository
cd /var/www/docia/monorepo/repository
bash deploy/setup-server.sh
```

Si una comprobación falla, detenerse y corregir su causa; no seguir pegando los comandos posteriores. El instalador aborta si ya existe su configuración, un puerto está ocupado o hay un archivo Nginx previo con el mismo nombre.

El instalador comprueba primero que las rutas existentes de correo, pagos y OAuth sean equivalentes a las derivadas del archivo central. Ante rutas personalizadas, aborta antes de normalizar los entornos privados. No continuar ignorando ese diagnóstico: conservar la ruta y resolver su configuración explícitamente antes de instalar.

El instalador:

- Crea solamente `/var/www/docia/monorepo/deploy` y el archivo nuevo `/etc/nginx/conf.d/docia-monorepo-preview.conf`.
- Copia en privado `api.env` y `migrations.env` desde `/var/www/docia/deploy/shared`, sin imprimirlos. En la copia de API retira las URL derivadas antiguas para que se calculen desde la configuración central. Conserva contraseñas, JWT, cifrado, integraciones, opciones de enrutamiento y orígenes adicionales CORS.
- Enlaza el almacenamiento al directorio original. Los archivos y la base de datos siguen siendo los mismos; no borrar la instalación anterior mientras se use ese enlace. Las rutas de credenciales a `/var/www/docia/secrets` siguen funcionando.
- Prepara las vistas previas de Nginx solo en `127.0.0.1:8088` y `8089`, valida y recarga su configuración. No cambia los virtual hosts públicos.
- Instala el archivo del servicio nuevo, sin iniciar o detener el servicio anterior.

Revisar de forma privada `/var/www/docia/monorepo/deploy/shared/api.env` y `migrations.env` si la instalación anterior tenía URL de callback o rutas especiales distintas de las habituales del proyecto. El callback Google estándar es `https://api.doc-ia.cloud/api/v1/integrations/google/callback`; los enlaces Flutter se derivan con el modo de rutas configurado. Las credenciales PostgreSQL actuales se conservan: runtime con su rol restringido y migraciones con el rol administrativo existente. Una contraseña con `#` se cita correctamente en dotenv; no reemplazarla por un ejemplo.

El archivo nuevo `shared/server.conf` comienza con:

```bash
PUBLIC_CHECKS=0
RUN_MIGRATIONS=0
```

Esto habilita pruebas privadas y evita que la preparación cambie el esquema de la base compartida. Requiere que la versión que se prueba funcione con el esquema actual. Si hay migraciones nuevas pendientes, revisar compatibilidad y un respaldo antes de habilitarlas; no aplicarlas ciegamente mientras el código anterior atiende tráfico.

## 4. Primer despliegue privado

En GitHub, **Settings → Secrets and variables → Actions → Variables**, crear una **repository variable** `DOCIA_DEPLOY_ENABLED` con valor `true`. Luego **Actions → Verify and deploy DocIA → Run workflow → main**.

Los jobs verifican las tres aplicaciones y firman Android con el certificado original. `config/android-version.json` establece una base `200000` y se suma el número de ejecución del workflow para superar los versionCode del repositorio anterior; el instalador verifica que la base sea mayor al APK que está publicado. Si fuera necesario aumentarla, editar y subir el archivo antes del primer despliegue. No crear otra clave de firma ni reducir esa base.

El job `deploy` publica API → web con APK → landing. La API nueva se llama `docia-api-monorepo`, usa `PM2_HOME=/var/www/docia/monorepo/deploy/pm2` y escucha en 3100. La anterior mantiene su PM2 y puerto 3000. No requiere instalar Flutter en el VPS.

Comprobar en el VPS, con un comando por línea:

```bash
curl --fail --silent --show-error http://127.0.0.1:3100/api/v1/health/ready
curl --fail --silent --show-error http://127.0.0.1:8088/docia-release.txt
curl --fail --silent --show-error http://127.0.0.1:8089/docia-release.txt
curl --fail --silent --show-error http://127.0.0.1:8089/downloads/DocIA.apk.sha256
```

Los marcadores deben corresponder al SHA y ejecución nuevos. Los dominios públicos todavía muestran la versión anterior: es lo esperado. Si falla una activación, el script restaura su componente previo; en una primera instalación retira únicamente el componente nuevo que falló. El despliegue anterior permanece disponible.

Configurar el arranque del PM2 nuevo **antes del cambio público**, después de que el primer despliegue guardó su lista. Estos comandos solo detienen brevemente la API nueva de prueba:

```bash
test -s /var/www/docia/monorepo/deploy/pm2/dump.pm2
sudo -u docia-deploy env PATH=/home/docia-deploy/.local/node/bin:/home/docia-deploy/.local/bin:/usr/bin:/bin PM2_HOME=/var/www/docia/monorepo/deploy/pm2 /home/docia-deploy/.local/bin/pm2 kill
systemctl enable --now docia-monorepo-pm2.service
systemctl status docia-monorepo-pm2.service --no-pager
curl --fail --silent --show-error --retry 10 --retry-connrefused --retry-delay 2 http://127.0.0.1:3100/api/v1/health/ready
```

Nunca ejecutar `pm2 kill`, `delete all`, `restart all` ni `pm2 save` sin especificar ese `PM2_HOME` cuando se administra esta instalación. El servicio antiguo `docia-pm2.service` y otros proyectos del servidor no se tocan.

## 5. Cambiar los tres sitios públicos

Primero deshabilitar los workflows de despliegue de **los tres repositorios anteriores** en GitHub: Actions → workflow correspondiente → menú → Disable workflow. Esperar que terminen los despliegues en curso; no borrar sus repositorios ni la API antigua. Así se evita que sigan migrando la base o publicando sobre las rutas que se van a retirar.

Antes del cambio guardar un respaldo de **solo `jampic_db`**. Como root, en una terminal propia:

```bash
install -d -m 700 /root/docia-db-backups
backup_docia="/root/docia-db-backups/jampic_db-$(date -u +%Y%m%dT%H%M%SZ).dump"
sudo -u postgres pg_dump --format=custom --dbname=jampic_db > "$backup_docia"
chmod 600 "$backup_docia"
test -s "$backup_docia"
```

Comprobar los archivos de Nginx. Los de web y landing fueron confirmados; descubrir el de API sin adivinar:

```bash
grep -RlF 'api.doc-ia.cloud' /etc/nginx/sites-enabled /etc/nginx/conf.d
ls -l /etc/nginx/sites-enabled/app.doc-ia.cloud.conf /etc/nginx/sites-enabled/doc-ia.cloud.conf
```

Revisar el archivo devuelto para API y confirmar que es un virtual host exclusivo de DocIA. En el siguiente comando, reemplazar **solo el primer argumento de archivo** si el nombre de API difiere. Se requieren tres archivos separados. El script aborta ante rutas, upstreams o nombres de dominio inesperados, conserva certificados y demás directivas y respalda los tres archivos reales fuera de `sites-enabled`:

```bash
cd /var/www/docia/monorepo/repository
git pull --ff-only origin main
flock --wait 900 /var/www/docia/monorepo/deploy/deploy.lock \
  /home/docia-deploy/.local/node/bin/node deploy/cutover.cjs activate \
  /etc/nginx/sites-enabled/api.doc-ia.cloud.conf \
  /etc/nginx/sites-enabled/app.doc-ia.cloud.conf \
  /etc/nginx/sites-enabled/doc-ia.cloud.conf
```

El cambio apunta la API a 3100 y los sitios y el APK a las releases nuevas. Ejecuta `nginx -t`, recarga y comprueba API, marcadores, recursos HTML/JS/CSS y el APK descargable por HTTPS. Si falla, restaura los archivos anteriores y recarga. Al pasar, imprime `CAMBIO_OK` y la carpeta privada del respaldo, y activa `PUBLIC_CHECKS=1` para los despliegues siguientes.

No es necesario bajar los sitios antiguos para usar los mismos dominios: Nginx cambia los destinos con una recarga. La API anterior puede quedar encendida para la recuperación. Ambas instancias comparten la base; las colas existentes usan bloqueos SQL para reclamar trabajos. Conviene retirar el proceso anterior cuando se confirme la nueva instalación; no usar este período para probar operaciones reales de pacientes sin coordinación.

Probar desde navegador: inicio de sesión, recuperación de contraseña, subida/lectura de archivos, acceso a las pantallas principales, integración Google si está habilitada, y descarga e instalación de la APK como actualización. Las comprobaciones automáticas cubren disponibilidad y contenido publicado; no reemplazan estas pruebas con cuentas de prueba.

## 6. Activar las migraciones para pushes futuros

Cuando la nueva instalación atienda correctamente y se haya comprobado el respaldo, editar **solo** `/var/www/docia/monorepo/deploy/shared/server.conf`:

```bash
nano /var/www/docia/monorepo/deploy/shared/server.conf
```

Cambiar `RUN_MIGRATIONS=0` por `RUN_MIGRATIONS=1`; conservar `PUBLIC_CHECKS=1`. Guardar. Desde ese momento, cada push a main verificará, compilará, aplicará migraciones incrementales y desplegará. Los cambios de esquema deben seguir siendo compatibles con la versión anterior durante el cambio: una recuperación de código no deshace SQL.

Mantener los workflows anteriores deshabilitados. Cuando se decida retirar su API, administrar exclusivamente su PM2 original con `PM2_HOME=/var/www/docia/deploy/pm2`, conservar archivos y no borrar `shared/storage` ni `secrets`. El proceso de limpieza definitivo queda fuera de esta migración.

## 7. Recuperación y diagnóstico

Si falla un componente en Actions, el script informa etapa, código y ruta del log privado. Consultarlo **en el VPS**; no pegar el archivo completo ni subirlo como artifact, porque las herramientas de dependencias/migraciones pueden escribir datos privados. No ejecutar con `set -x`, no mostrar el entorno y no compartir `pm2 jlist`.

Para recuperar una release del monorepo, listar identificadores y ejecutar con el usuario aislado; reemplazar `ID_ANTERIOR` por el segmento `SHA-RUN-ATTEMPT` real de esa release:

```bash
ls -1 /var/www/docia/monorepo/deploy/releases
sudo -u docia-deploy bash /var/www/docia/monorepo/repository/deploy/deploy.sh --rollback api ID_ANTERIOR
```

Para web o landing cambiar el componente. El script vuelve a comprobar salud y conserva su configuración pública por release. No elimina releases automáticamente; vigilar espacio y conservar al menos la actual y la anterior.

Para volver a toda la instalación original, primero poner `DOCIA_DEPLOY_ENABLED=false` en el repositorio nuevo y esperar que termine cualquier despliegue. Confirmar que la API anterior sigue saludable en 3000. Usar la carpeta exacta que imprimió `CAMBIO_OK`:

```bash
cd /var/www/docia/monorepo/repository
flock --wait 900 /var/www/docia/monorepo/deploy/deploy.lock \
  /home/docia-deploy/.local/node/bin/node deploy/cutover.cjs restore \
  /root/docia-monorepo-nginx-backups/cutover-REEMPLAZAR
curl --fail --silent --show-error https://api.doc-ia.cloud/api/v1/health/ready
curl --fail --silent --show-error https://app.doc-ia.cloud/docia-release.txt
curl --fail --silent --show-error https://doc-ia.cloud/docia-release.txt
```

Esto restaura Nginx y desactiva migraciones y comprobaciones públicas en el despliegue nuevo. Si se aplicaron migraciones incompatibles después del cambio, resolver también la compatibilidad de datos antes de volver; no restaurar automáticamente una base que podría tener datos nuevos. Solo reactivar los workflows antiguos si se decide regresar a ellos.

## 8. Un cambio futuro de dominio

La fuente pública es `config/environments/production.env`; las URL no se duplican en secrets de GitHub. Mantener los dominios `.cloud` hasta completar esta migración. Después, cambiar los tres orígenes en ese archivo y revisar las plantillas generadas con `npm run config:render`.

Antes del push que publique nuevos dominios: crear DNS A/AAAA correctos, emitir certificados para los nombres nuevos, actualizar los tres virtual hosts DocIA y su CSP según las plantillas, y registrar callback/orígenes en Google, Stripe o Firebase según las integraciones activas. No instalar una plantilla a ciegas encima de un sitio con rutas personalizadas. El script de primer cambio `cutover.cjs` está destinado a migrar la instalación `.cloud` actual, no a renombrar futuros dominios.

La web y la APK incluyen las URL durante la compilación. Un push regenerará ambas; los móviles ya instalados necesitarán instalar la nueva APK firmada con la misma clave. Mantener el dominio anterior o una transición mientras se distribuye esa actualización si es posible.
