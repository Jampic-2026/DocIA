# Configuración de servicios externos

> Para cambiar de dominio o configurar DuckDNS, usar [la gu?a de configuraci?n central](../deploy/DOMAINS.md). Los dominios de esta gu?a son ejemplos.

Doc IA mantiene la API y PostgreSQL en la VPS de Hostinger. OpenAI, Google Maps,
Google Meet y Stripe se consumen como servicios externos desde la API cuando
corresponde; no implican mover el backend ni la base a Google Cloud.

## Fuente de configuración

El contrato versionado está en `.env.example`. Cada desarrollador crea su
archivo privado:

```powershell
Copy-Item .env.example .env
```

`.env` está ignorado por Git y no se comparte por repositorio, mensajería,
capturas ni documentación. En producción, las variables se configuran en el
entorno del proceso de la VPS o en el mecanismo de secretos disponible en
Hostinger.

Todas las llamadas HTTP externas usan un límite configurable:

```env
EXTERNAL_HTTP_TIMEOUT_MS=15000
```

OpenAI aplica además reintentos acotados. Google Maps y Meet convierten fallos
de conexión o timeout en respuestas controladas de la API.

## OpenAI

```env
AI_ENABLED=true
AI_PROVIDER=openai
OPENAI_API_KEY=...
OPENAI_MODEL=...
OPENAI_PROJECT_ID=...
OPENAI_ORGANIZATION_ID=...
```

`OPENAI_API_KEY` es obligatoria cuando `AI_ENABLED=true`.
`OPENAI_PROJECT_ID` y `OPENAI_ORGANIZATION_ID` son opcionales. El crédito y la
facturación de OpenAI son independientes de Google Cloud.

La aplicación Flutter nunca llama directamente a OpenAI. El flujo obligatorio
es:

```text
APP-MVP -> API Doc IA -> OpenAI
```

Así la clave permanece en el servidor, se aplican permisos, límites, auditoría
y controles clínicos antes y después de cada solicitud.

## Google Maps

Para geocodificación, cálculo de rutas u operaciones ejecutadas por la API:

```env
MAPS_ENABLED=true
MAPS_PROVIDER=google
GOOGLE_MAPS_SERVER_API_KEY=...
```

Esta key debe restringirse por API y, cuando sea posible, por IP pública de la
VPS.

El flujo actual de emergencias requiere habilitar para esa key:

- `Geocoding API`, para convertir coordenadas en una dirección.
- `Maps Static API`, para generar la vista del mapa desde el backend.

La imagen se entrega a Flutter mediante la API autenticada. La URL firmada y
la key de Google no se entregan a la aplicación.

El renderizado interactivo de mapas en Android, iOS o web puede requerir keys
de cliente independientes. Esas keys terminan incluidas en la aplicación y no
son secretos. Deben restringirse estrictamente:

- Android: nombre de paquete y certificado SHA.
- iOS: bundle identifier.
- Web: dominios HTTPS autorizados.
- Todas: habilitar únicamente las APIs necesarias y configurar cuotas.

No se debe reutilizar `GOOGLE_MAPS_SERVER_API_KEY` en Flutter.

## Google Meet

```env
TELEMEDICINE_ENABLED=true
TELEMEDICINE_PROVIDER=google_meet
GOOGLE_OAUTH_CLIENT_ID=...
GOOGLE_OAUTH_CLIENT_SECRET=...
GOOGLE_OAUTH_REDIRECT_URI=https://api.example.com/api/v1/integrations/google/callback
GOOGLE_OAUTH_TOKEN_ENCRYPTION_KEY=...
```

En desarrollo, la URI puede apuntar a `localhost`. En producción debe coincidir
exactamente con la URI HTTPS registrada en Google Cloud Console.

`GOOGLE_OAUTH_CLIENT_SECRET` y `GOOGLE_OAUTH_TOKEN_ENCRYPTION_KEY` solo existen
en la API. La clave de cifrado debe ser aleatoria, tener al menos 32 caracteres
y ser distinta de los secrets JWT.

Después de configurar las variables y aplicar las migraciones, el flujo de
activación es:

1. Iniciar la API con `TELEMEDICINE_ENABLED=true`.
2. Un usuario con `administration.manage` solicita
   `GET /api/v1/integrations/google/authorize`.
3. Abrir `authorizationUrl` e iniciar sesión con la cuenta Google que será
   propietaria de las salas.
4. Google retorna al callback configurado y la API almacena el refresh token
   cifrado.
5. El profesional asignado crea la sala desde la cita; pacientes y
   profesionales reciben únicamente la URL de Meet.

No se copia un access token manual al `.env`: la API lo obtiene y renueva
mediante OAuth.

## Correo para recuperación de contraseña

La API utiliza Resend para enviar el enlace de recuperación. La credencial y
el remitente se configuran únicamente en `API/.env`:

```env
EMAIL_ENABLED=true
EMAIL_PROVIDER=resend
RESEND_API_KEY=re_clave_privada
EMAIL_FROM=Doc IA <no-reply@landing.example.com>
PASSWORD_RESET_URL=https://app.example.com/password-reset
REGISTRATION_URL=https://app.example.com/register/complete
```

Antes de habilitar el envío se debe verificar en Resend el dominio utilizado
por `EMAIL_FROM` y crear una API key con permiso de envío. La clave no se
agrega a APP-MVP ni a sus archivos `config/*.json`.

`PASSWORD_RESET_URL` apunta a la ruta pública de APP-MVP. La API agrega el
token como `?token=...`; la pantalla web lo lee y permite definir la nueva
contraseña. El token vence en 30 minutos, se guarda como hash y deja de ser
válido después de usarlo.

Con `EMAIL_ENABLED=false`, el proveedor queda desactivado sin impedir el
desarrollo local. En `development`, la respuesta incluye `developmentToken`
para probar el flujo sin enviar correo. En `production` ese campo nunca se
devuelve.

## MFA y verificación telefónica

Los secretos TOTP se cifran en la API con una clave privada:

```env
MFA_ENCRYPTION_KEY=valor-privado-aleatorio-de-al-menos-32-caracteres
```

El proveedor SMS debe aceptar `POST` JSON con `to`, `message` y `sender`,
autenticado mediante Bearer token:

```env
SMS_ENABLED=true
SMS_API_URL=https://proveedor-sms.example/v1/messages
SMS_API_TOKEN=token-privado
SMS_SENDER=Doc IA
```

Estas variables nunca se distribuyen en APP-MVP.

## Activación progresiva

Los módulos permanecen desactivados con:

```env
AI_ENABLED=false
MAPS_ENABLED=false
TELEMEDICINE_ENABLED=false
EMAIL_ENABLED=false
```

Al cambiar un indicador a `true`, el arranque de la API valida que todas las
credenciales obligatorias del servicio estén presentes. Esto permite trabajar
en módulos independientes sin distribuir keys que todavía no se utilizan.

## Variables que nunca van en APP-MVP

- `OPENAI_API_KEY`
- `RESEND_API_KEY`
- `GOOGLE_MAPS_SERVER_API_KEY`
- `GOOGLE_OAUTH_CLIENT_SECRET`
- `GOOGLE_OAUTH_TOKEN_ENCRYPTION_KEY`
- `STRIPE_SECRET_KEY`
- `STRIPE_WEBHOOK_SECRET`
- credenciales de PostgreSQL
- secrets JWT
- tokens OAuth de usuarios

`APP-MVP/config/*.json` contiene únicamente configuración pública, como
`API_BASE_URL`.

## Rotación y despliegue

Los enlaces privados de archivos se firman con un secreto exclusivo:

```env
STORAGE_PROVIDER=local
STORAGE_ROOT=/var/www/docia/storage
STORAGE_SIGNING_SECRET=valor-aleatorio-de-al-menos-32-caracteres
STORAGE_SIGNED_URL_EXPIRES_SECONDS=300
```

En producción es obligatorio y debe ser diferente de los secretos JWT. Los
archivos sólo admiten categorías y tipos conocidos, tienen límite de tamaño y
se entregan mediante URLs temporales auditadas.

Para usar Google Cloud Storage desde una VPS:

```env
STORAGE_PROVIDER=gcs
GCS_BUCKET_NAME=docia-production-files
GOOGLE_APPLICATION_CREDENTIALS=/var/www/docia/secrets/gcs-service-account.json
STORAGE_SIGNING_SECRET=valor-aleatorio-de-al-menos-32-caracteres
STORAGE_SIGNED_URL_EXPIRES_SECONDS=300
```

El bucket debe permanecer privado. La cuenta de servicio configurada en
`GOOGLE_APPLICATION_CREDENTIALS` necesita permisos sobre los objetos del bucket.
La API conserva el mismo contrato público: la app sube a `POST /files`, guarda
la referencia recibida y solicita `POST /files/access` para obtener enlaces
temporales.

Cuando una credencial cambie:

1. Actualizarla en el `.env` privado local o en el entorno de Hostinger.
2. Reiniciar únicamente la API.
3. Verificar el endpoint de salud y el módulo afectado.
4. Revocar la credencial anterior desde el proveedor.

Cambiar una credencial privada no requiere recompilar Flutter. Una key de Maps
incluida en Android, iOS o web sí puede requerir un nuevo build de la app.

## Stripe

Stripe se consume exclusivamente desde la API. La aplicación cliente solicita
un `clientSecret` para una orden fiat y confirma el pago con el SDK cliente de
Stripe usando una publishable key restringida.

```env
STRIPE_ENABLED=true
STRIPE_SECRET_KEY=sk_test_...
STRIPE_WEBHOOK_SECRET=whsec_...
STRIPE_PAYMENT_RETURN_URL=https://app.example.com/payments/return
```

Endpoint autenticado para iniciar tarjeta:

```http
POST /api/v1/payments/orders/:orderId/stripe/payment-intent
```

Webhook público firmado por Stripe:

```http
POST /api/v1/payments/stripe/webhook
```

Eventos requeridos:

- `payment_intent.succeeded`
- `payment_intent.payment_failed`

`STRIPE_SECRET_KEY` y `STRIPE_WEBHOOK_SECRET` nunca van en `APP-MVP`.

Los cambios de Stripe y cobro por chat/voz IA quedaron consolidados en los SQL
versionados del esquema (`db/01_database.sql` y `db/04_policies.sql`). En bases
existentes ya actualizadas no se requieren scripts temporales adicionales.
