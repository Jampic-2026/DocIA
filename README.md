# DocIA

API NestJS, aplicación Flutter (web y Android) y landing React en un repositorio. La arquitectura interna de cada aplicación se conserva, incluyendo las capas de la API. Esta carpeta es una copia independiente: los repositorios hermanos `API`, `APP-MVP` y `Landing` no se modifican.

```text
DocIA/
  API/                         API y migraciones PostgreSQL
  APP-MVP/                     Flutter web y Android
  Landing/                     Landing y enlace al APK
  config/environments/production.env  Única configuración de dominios
  config/android-version.json  Continuidad del versionCode Android
  deploy/                      CI, empaquetado, salud y recuperación
  docs/NETLIFY.md              API DuckDNS y frontends Netlify en paralelo
```

Los dominios actuales siguen configurados: `api.doc-ia.cloud`, `app.doc-ia.cloud` y `doc-ia.cloud`. Las credenciales se conservan en el VPS; no se incluyen `.env` privados, keystores ni la carpeta `secrets`.

El esquema elegido es **API y APK en el VPS con DuckDNS; Flutter web y landing en Netlify**. Seguí [la guía de instalación paralela](docs/NETLIFY.md) para crear las direcciones, configurar GitHub y preparar el VPS. Los nombres reales todavía deben reemplazarse en el archivo central; no se registraron servicios ni se modificó el VPS desde esta carpeta. El primer push ejecuta las verificaciones; el despliegue se habilita después de preparar el servidor con la variable de GitHub `DOCIA_DEPLOY_ENABLED=true`.

Cada push a `main`, con esa variable activada, verifica API, Flutter y landing, compila web y APK con el certificado existente y publica API/APK en el VPS → web en Netlify → landing en Netlify. La descarga de APK de ambos sitios redirige al VPS. Las pull requests verifican código sin usar claves SSH, tokens Netlify ni firma Android. Las Actions están fijadas a commits y usan sus versiones de Node 24; la API ejecuta Node 22.

La instalación nueva usa `/var/www/docia/monorepo` y API en `127.0.0.1:3100`. Dentro de esa carpeta, `repository` contiene el código y `deploy` sus releases y configuración privada. Las claves SSH se conservan en `/root`; la carpeta actual de la terminal no determina dónde se clona el código. La anterior mantiene sus carpetas y su proceso en 3000 hasta que se retire expresamente. Ambas usan la misma base y archivos de pacientes; no se duplica información ni se cambian usuarios PostgreSQL. Para este esquema no ejecutar `cutover.cjs` ni reemplazar los virtual hosts `.cloud`.

Para desarrollo, instalá las dependencias por aplicación (`npm ci` en API y Landing, `flutter pub get --enforce-lockfile` en APP-MVP). Los README internos conservan la documentación funcional; los procedimientos antiguos de despliegue quedan sustituidos por esta guía.

Para revisar la configuración pública generada:

```bash
node deploy/public-config.cjs render-api config/environments/production.env
```

Esto genera archivos ignorados en `deploy/generated`; no instala Nginx ni modifica el servidor. Para cambiar a DuckDNS u otro dominio hay que actualizar el archivo central, DNS, certificados y las autorizaciones externas que correspondan. Las URL de una APK ya instalada permanecen compiladas: será necesario distribuir e instalar una versión nueva.

[SOURCE-SNAPSHOT.json](docs/SOURCE-SNAPSHOT.json) registra los commits de origen y hashes de sus archivos, incluyendo los cambios locales de centralización existentes al iniciar esta copia. Se inicia un historial nuevo; los historiales anteriores permanecen en sus repositorios.

Las comprobaciones realizadas y sus límites están en [VALIDATION.md](docs/VALIDATION.md).
La comparación de código y recursos visuales con los commits originales está en [PARITY.md](docs/PARITY.md).
La comparación de 56 escenarios con Chrome y datos simulados está en [VISUAL.md](docs/VISUAL.md). El destino de las 66 variables originales de API y los dos campos adicionales está en [API-ENV-MAP.md](docs/API-ENV-MAP.md).
