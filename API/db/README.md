# Base de datos DocIA

Esta carpeta contiene la fuente de verdad reproducible de la base de datos.
La estructura se mantiene consolidada en ocho SQL con responsabilidades fijas.

## Archivos SQL

- `01_database.sql`: extensiones, enums, tablas e índices.
- `02_functions.sql`: funciones internas, helpers de autorización y RPC.
- `03_triggers.sql`: triggers de integridad y automatización.
- `04_policies.sql`: todas las policies y configuraciones RLS.
- `05_init.sql`: catálogo inicial, roles, permisos, consentimientos y
  configuración base.
- `06_jobs.sql`: tareas SQL programadas o de mantenimiento.
- `07_permission_catalog.sql`: catálogo idempotente de permisos y matriz de
  asignación por rol.
- `08_local_test_users.sql`: usuarios, perfiles, aliados y disponibilidad
  exclusivamente para desarrollo local.
- `local_full_flow_test_data.sql`: escenario integral y opcional para pruebas
  locales. No está numerado y nunca se ejecuta automáticamente.

No deben crearse SQL numerados posteriores dentro de `db/`. Cada cambio se
integra en el archivo consolidado correspondiente según su responsabilidad.
Para bases ya existentes se agrega además una migración incremental en
`db/migrations/`.

## Reglas de organización

- Toda tabla, enum o índice nuevo va en `01_database.sql`.
- Toda función o RPC va en `02_functions.sql`.
- Todo trigger va en `03_triggers.sql`.
- Toda policy, habilitación RLS o restricción de acceso va en
  `04_policies.sql`.
- Los datos semilla funcionales van en `05_init.sql`.
- Los datos locales de prueba van en `08_local_test_users.sql`.
- Los permisos y asignaciones por rol deben mantenerse sincronizados entre
  `05_init.sql` y `07_permission_catalog.sql`.
- Los archivos deben continuar siendo idempotentes.

## Variables de conexión local

```env
DB_HOST=localhost
DB_PORT=5432
DB_NAME=jampic_local
DB_USER=tu_user
DB_PASSWORD=tu_password
DB_SSL=disable
DB_ADMIN_DATABASE=postgres
```

`DATABASE_URL` es opcional y tiene prioridad si está definida.

## Rol runtime en producción

Las migraciones y los archivos base deben ejecutarse con el propietario de la
base. La API, en cambio, debe conectarse con un rol distinto que no sea
superusuario, no tenga `BYPASSRLS` y no sea propietario de las tablas. De ese
modo las policies RLS siguen protegiendo los datos aunque exista un error en
una consulta de la aplicación.

Ejemplo, ejecutado por el propietario después de aplicar el esquema:

```sql
CREATE ROLE docia_app LOGIN PASSWORD 'reemplazar-por-un-secreto-fuerte'
  NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT NOREPLICATION NOBYPASSRLS;
GRANT CONNECT ON DATABASE docia TO docia_app;
GRANT USAGE ON SCHEMA public TO docia_app;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO docia_app;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO docia_app;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO docia_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO docia_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT USAGE, SELECT ON SEQUENCES TO docia_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA public
  GRANT EXECUTE ON FUNCTIONS TO docia_app;
```

El `DATABASE_URL` del proceso PM2 debe usar `docia_app`; los comandos
`db:apply` y `db:migrate` deben conservar una conexión administrativa
independiente. Con `DB_ENFORCE_RLS_ROLE=true`, la API se niega a arrancar en
producción si detecta un rol que pueda eludir RLS.

## Ejecución local

```bash
npm run db:create
npm run db:apply
```

El runner ejecuta los ocho archivos en orden y registra nombre, fecha y
checksum SHA-256 en `schema_sql_files`. Si cambia el contenido de un archivo
consolidado, vuelve a ejecutarlo; por eso todos deben permanecer idempotentes.

Para incluir el contenido de `08_local_test_users.sql`:

```env
DB_APPLY_LOCAL_SEEDS=true
```

La contraseña común de los usuarios locales es:

```text
Jampic123!
```

Después de aplicar los ocho archivos con semillas locales, el escenario
integral puede cargarse manualmente:

```bash
npm run db:seed:local-flow
```

El archivo requiere los usuarios del 08, es idempotente y cubre perfil,
consentimiento, consulta, historia clínica, receta, catálogo, pago, monedas,
beneficios, empresa asociada, solicitud, diagnóstico, incidentes, recursos
humanos y notificaciones.

## Base existente

La consolidación no elimina las filas históricas de `schema_sql_files`.
Una base ya creada conserva sus policies y datos. Para comprobar la
reproducibilidad completa de los ocho archivos se debe usar una base vacía.

Para aplicar cambios nuevos sobre una base ya creada:

```bash
npm run db:migrate
```

El runner ejecuta `db/migrations/*.sql` en orden, registra cada archivo en
`schema_migrations` y no permite editar una migración ya aplicada: si un cambio
nuevo hace falta, se crea el siguiente archivo, por ejemplo:

```text
db/migrations/0002_nombre_del_cambio.sql
```

Cada migración debe dejar una copia/auditoría del cambio en los documentos base
correspondientes:

- cambios de tablas, enums o índices: `01_database.sql`
- funciones: `02_functions.sql`
- triggers: `03_triggers.sql`
- policies/RLS: `04_policies.sql`
- semillas funcionales: `05_init.sql`
- jobs: `06_jobs.sql`
- permisos: `05_init.sql` y `07_permission_catalog.sql`

La regla es: una base nueva se crea con `npm run db:apply` y no debe necesitar
`npm run db:migrate`. Las migraciones existen únicamente para llevar una base
ya creada desde su estado actual hasta el estado definido por los SQL
consolidados.

## Criterio de implementación API

La lógica se implementa verticalmente:

```text
interfaces/http -> application/use-case -> domain/ports -> infrastructure/persistence
```

La matriz de trazabilidad indica las tablas, operaciones y requisitos de
auditoría de cada caso de uso.
