# API DocIA

Base inicial de la API para el MVP de DocIA, alineada con la base validada `db/01_database.sql` y la matriz de trazabilidad `db/traceability_matriz_use_cases.md`.

Dominios, GitHub y VPS: [guía del monorepo](../docs/MIGRATION.md).
La API deriva correo, CORS, pagos y OAuth de `PUBLIC_API_URL` y `PUBLIC_WEB_URL`;
en el VPS los carga desde `PUBLIC_CONFIG.env` de su release. Los secretos permanecen
en `.env` y no se comparten con el frontend.

## Stack

- NestJS 11 con Fastify.
- PostgreSQL con SQL validado y archivos numerados reproducibles.
- Autenticación JWT con sesiones, refresh token rotativo y base preparada para MFA/RBAC/permisos.
- Arquitectura hexagonal por dominio funcional.

## Primeros pasos

En PowerShell puedes crear el `.env` con:

```powershell
Copy-Item .env.example .env
```

Luego ajusta tus datos de PostgreSQL en `.env`:

```env
DB_HOST=localhost
DB_PORT=5432
DB_NAME=jampic_local
DB_USER=tu_user
DB_PASSWORD=tu_password
DB_SSL=disable
DB_ADMIN_DATABASE=postgres
```

`DATABASE_URL` es opcional. Si se define, tiene prioridad sobre las variables `DB_*` para la API y `db:apply`.

`db:create` se conecta a `DB_ADMIN_DATABASE` (`postgres` por defecto) o a `DB_ADMIN_URL` si se define, revisa si `DB_NAME` existe y la crea si falta.

## Servicios externos y credenciales

OpenAI, Google Maps, Google Meet y Stripe se configuran exclusivamente desde variables
de entorno de la API. El contrato sin secretos está en `.env.example` y la guía
completa está en
[`docs/external-services-configuration.md`](docs/external-services-configuration.md).

Los módulos pueden permanecer desactivados durante el desarrollo:

```env
AI_ENABLED=false
MAPS_ENABLED=false
TELEMEDICINE_ENABLED=false
STRIPE_ENABLED=false
```

Cuando un indicador cambia a `true`, la validación de arranque exige las
credenciales correspondientes. La API y PostgreSQL continúan alojándose en la
VPS de Hostinger; estos proveedores se consumen externamente y no cambian esa
arquitectura.

Las credenciales privadas nunca se colocan en `APP-MVP`, archivos
`config/*.json`, código Dart ni artefactos compilados. Las keys de Maps
necesarias para renderizar mapas en una plataforma cliente son la excepción
técnica: son visibles y deben ser keys independientes restringidas por
aplicación, certificado o dominio.

Luego instala, aplica los SQL numerados y levanta:

```bash
npm install
npm run db:create
npm run db:apply
npm run start:dev
```

La API queda publicada por defecto en:

```text
http://localhost:3000/api/v1
```

Salud de la API:

```http
GET /api/v1/health
```

## Fuente de verdad funcional

- Esquema validado: `db/01_database.sql`.
- Trazabilidad de 165 casos de uso: `db/traceability_matriz_use_cases.md`.
- Convención SQL numerada: `db/README.md`.
- Flujo de monedas y pagos: `docs/coin-payment-flow.md`.
- Inventario de endpoints: `docs/api-endpoints.md`.
- Alineación módulos/casos de uso: `docs/use-case-alignment.md`.
- Arquitectura: `docs/api-structure.md`.
- Catálogo de permisos: `docs/permissions.md`.

## Arquitectura

Cada dominio vive en `src/modules/<domain>` y se implementa siguiendo arquitectura hexagonal:

- `interfaces/http`: controladores REST y DTOs de entrada.
- `application`: servicios de aplicación y casos de uso.
- `domain`: entidades, objetos de valor, reglas y puertos del negocio. Se crea cuando el módulo tenga lógica de dominio real.
- `infrastructure`: repositorios SQL e integraciones externas. Se crea cuando el módulo necesite adaptadores concretos.

No se mantienen carpetas vacías solo por ceremonia. La estructura crece cuando aparece una responsabilidad real.

## Regla de cobro actual

- Los usuarios compran paquetes de monedas Doc IA; cada lote vence al año de acreditarse.
- Los servicios no presenciales cobrables se pagan con monedas.
- Las consultas y servicios presenciales se pagan en fiat mediante QR o efectivo al responsable que asistió.
- Los usuarios no tienen suscripciones.
- Las empresas asociadas sí pueden contratar planes empresariales.

## Flujo de monedas y pagos

El flujo completo está documentado en `docs/coin-payment-flow.md`.

Resumen operativo:

1. El usuario compra un paquete configurado en `coin_packages`.
2. Se crea una orden fiat en `payment_orders` y se valida el pago en `payments`.
3. La acreditación crea lotes en `coin_lots`, actualiza `coin_wallets` y registra `coin_transactions`.
4. Los servicios no presenciales consumen monedas con descuento FIFO por vencimiento y detalle en `coin_transaction_allocations`.
5. Las consultas y servicios presenciales se pagan por QR o efectivo y se registran en `payments` con profesional cobrador.
6. Las empresas asociadas usan `partner_subscription_plans`, `partner_subscriptions` y `partner_subscription_usage`.

## Usuarios locales de prueba

Existe un seed local opcional: `db/08_local_test_users.sql`.

Para aplicarlo en una base local nueva o recreada, configura temporalmente en `.env`:

```env
DB_APPLY_LOCAL_SEEDS=true
```

Luego ejecuta:

```bash
npm run db:apply
```

Contraseña común de prueba:

```text
Jampic123!
```

Usuarios incluidos:

```text
admin@jampic.local
patient@jampic.local
guardian@jampic.local
doctor.general@jampic.local
doctor.specialist@jampic.local
nurse@jampic.local
operator@jampic.local
clinical.supervisor@jampic.local
partner@jampic.local
delivery@jampic.local
hr@jampic.local
```

Después de ejecutar `npm run db:apply`, vuelve a dejar `DB_APPLY_LOCAL_SEEDS=false`. Si queda en `false`, el runner salta cualquier SQL con `_local_` en el nombre.

## Cómo consumir la API

Todas las rutas usan el prefijo global `api/v1` salvo que `API_PREFIX` cambie en `.env`.

Headers recomendados para pruebas:

```http
Content-Type: application/json
Accept: application/json
```

Las rutas privadas consumen JWT así:

```http
Authorization: Bearer <access_token>
```

La mayoría de los dominios conserva contratos placeholder mientras se
implementan cortes verticales. Autenticación, autorización, listado y creación
de citas, y directorio médico ya tienen persistencia real.

Respuesta típica:

```json
{
  "module": "patients",
  "resource": "patients",
  "action": "list",
  "status": "ready"
}
```

## Ejemplos rápidos

```http
GET http://localhost:3000/api/v1/health
GET http://localhost:3000/api/v1/patients/patients
GET http://localhost:3000/api/v1/clinical-records/clinical-records
GET http://localhost:3000/api/v1/home-services/home-service-requests
GET http://localhost:3000/api/v1/human-resources/personnel-applications
GET http://localhost:3000/api/v1/professionals/professionals
GET http://localhost:3000/api/v1/appointments/appointments
GET http://localhost:3000/api/v1/people/me
GET http://localhost:3000/api/v1/clinical-records/profile
GET http://localhost:3000/api/v1/clinical-records/history
GET http://localhost:3000/api/v1/patients/family
GET http://localhost:3000/api/v1/patients/patients
GET http://localhost:3000/api/v1/prescriptions/prescriptions
GET http://localhost:3000/api/v1/emergencies/events
GET http://localhost:3000/api/v1/human-resources/employment-records
GET http://localhost:3000/api/v1/partners/health-partners
GET http://localhost:3000/api/v1/catalog/service-catalog
GET http://localhost:3000/api/v1/coins/overview
```

Login:

```http
POST http://localhost:3000/api/v1/auth/login
Content-Type: application/json
```

```json
{
  "email": "admin@jampic.local",
  "password": "Jampic123!"
}
```

Refresh:

```http
POST http://localhost:3000/api/v1/auth/refresh
Content-Type: application/json
```

```json
{
  "refreshToken": "<refresh_token>"
}
```

Usuario actual:

```http
GET http://localhost:3000/api/v1/auth/me
Authorization: Bearer <access_token>
```

Logout:

```http
POST http://localhost:3000/api/v1/auth/logout
Content-Type: application/json
```

```json
{
  "refreshToken": "<refresh_token>"
}
```

Agendar una cita con el token del usuario paciente:

```http
POST http://localhost:3000/api/v1/appointments/appointments
Authorization: Bearer <access_token>
Content-Type: application/json
```

```json
{
  "professionalId": "<id obtenido del directorio>",
  "specialtyId": "<specialtyId obtenido del directorio>",
  "modality": "in_person",
  "startAt": "2026-07-24T14:00:00.000Z",
  "endAt": "2026-07-24T14:30:00.000Z",
  "reason": "Control general"
}
```

No se envía `patientId`; se obtiene desde el JWT. Para probar horarios locales
primero se deben aplicar los seeds con `DB_APPLY_LOCAL_SEEDS=true`.

## Consumo desde Postman

Hay una colección y un ambiente listos para importar:

- `docs/postman/Jampic_API.postman_collection.json`
- `docs/postman/Jampic_Local.postman_environment.json`

Pasos:

1. Abrir Postman.
2. Ir a `Import`.
3. Importar la colección y el ambiente.
4. Seleccionar el ambiente `Jampic Local`.
5. Verificar que `baseUrl` sea `http://localhost:3000/api/v1`.
6. Ejecutar `Health / Check`.
7. Ejecutar las rutas por dominio.

La colección usa `{{baseUrl}}`. Ejemplo:

```text
{{baseUrl}}/patients/patients
```

La colección guarda `accessToken` y `refreshToken` después de login/refresh. Para llamadas privadas usa:

```http
Authorization: Bearer {{accessToken}}
```

## Dominios preparados

- `auth`: Autenticación.
- `users`: Usuarios y seguridad.
- `people`: Personas.
- `patients`: Pacientes, familiares y dependientes.
- `consents`: Consentimientos.
- `professionals`: Profesionales, especialidades y turnos.
- `clinical-records`: Perfil clínico e historia clínica.
- `emergencies`: Emergencias y operador.
- `ai`: Inteligencia artificial.
- `appointments`: Consultas, agenda y telemedicina.
- `prescriptions`: Recetas digitales.
- `catalog`: Catálogo y tarifario.
- `coins`: Monedas Doc IA y billeteras.
- `payments`: Pagos fiat, QR, efectivo e incidencias.
- `benefits`: Beneficios y descuentos.
- `partners`: Empresas asociadas, planes, sedes y solicitudes.
- `home-services`: Servicios domiciliarios y seguimiento.
- `deliveries`: Entregas.
- `incidents`: Incidentes.
- `human-resources`: Recursos humanos.
- `notifications`: Notificaciones.
- `administration`: Administración y reglas operativas.
- `audit`: Auditoría.

## Verificación

```bash
npm run build
npm run lint
```

## Despliegue seguro en VPS

El workflow automático de este repositorio y la preparación aislada del VPS
están documentados en [`../docs/MIGRATION.md`](../docs/MIGRATION.md).

- La API y las versiones actuales de Firebase Admin/GCS requieren Node.js 22
  o posterior (`node -v`) tanto al instalar como al ejecutar con PM2.
- El proceso PM2 debe usar un rol PostgreSQL runtime sin `SUPERUSER`,
  `BYPASSRLS` ni propiedad sobre tablas. Los comandos de esquema usan una
  conexión administrativa separada; el ejemplo completo está en `db/README.md`.
- `PUBLIC_API_URL` debe ser la URL HTTPS pública de la API. El callback OAuth de
  Google Meet se deriva automáticamente como
  `PUBLIC_API_URL/API_PREFIX/integrations/google/callback`.
- `CORS_ORIGINS` es obligatorio en producción y debe listar únicamente los
  orígenes web autorizados, separados por coma.
- Tras actualizar una base existente se ejecuta `npm run db:migrate`; la
  migración `0012_notification_push_outbox.sql` habilita la entrega push para
  todos los módulos que creen notificaciones.
- Los secretos de GCS y FCM permanecen fuera del repositorio, por ejemplo en
  `/var/www/docia/secrets`, con acceso restringido al usuario que ejecuta PM2.

## SQL consolidados

Los SQL reproducibles viven directamente en `db/` y se ejecutan por orden
numérico con `npm run db:apply`:

```text
01_database.sql   # extensiones, enums, tablas e índices
02_functions.sql  # funciones, helpers de autorización y RPC
03_triggers.sql   # triggers
04_policies.sql   # todas las policies y configuraciones RLS
05_init.sql       # seed inicial
06_jobs.sql       # jobs
07_permission_catalog.sql # permisos y asignación por rol
08_local_test_users.sql # datos locales opcionales
```

No se crean archivos numerados posteriores. Cada cambio se integra en el
archivo correspondiente a su responsabilidad.
