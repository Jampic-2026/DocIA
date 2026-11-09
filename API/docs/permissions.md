# Catálogo de permisos

La autorización de Doc IA se aplica en tres niveles:

```text
JWT y sesión activa
-> PermissionsGuard en la interfaz HTTP
-> transactionAsUser en infraestructura
-> policies RLS de PostgreSQL
```

## Convención

Los permisos usan códigos estables en inglés:

```text
<domain>.read
<domain>.manage
```

Excepciones existentes:

- `auth.sessions.manage`
- `ai.use`
- `ai.manage`
- `users.update`

Los controladores de consulta requieren el permiso `read` de su dominio. Los
endpoints de escritura usan el permiso `manage` correspondiente o un permiso
más específico si el caso de uso lo necesita.

La fuente de verdad de códigos para TypeScript es:

```text
src/common/auth/permission-codes.ts
```

La fuente reproducible de permisos y asignaciones por rol es:

```text
db/07_permission_catalog.sql
```

## Reglas

- El frontend usa los permisos para navegación y presentación, no como barrera de seguridad.
- La API valida permisos mediante `PermissionsGuard`.
- Cada repositorio sensible debe ejecutar dentro de `DatabaseService.transactionAsUser`.
- Las policies RLS deciden qué filas puede leer o modificar el usuario.
- Un permiso de módulo no concede acceso ilimitado a todas sus filas.
- Los cambios de permisos requieren renovar o revocar las sesiones existentes para actualizar sus JWT.
- Los permisos nuevos deben agregarse al catálogo de API, SQL y Flutter.

## Cobertura RLS actual

Las policies existentes cubren usuarios, sesiones, las tablas principales de
monedas y las citas. En `appointments`, la lectura está limitada al paciente,
profesional asignado o rol operativo autorizado. La inserción de una cuenta
paciente exige que `created_by_user_id` coincida con la sesión y que la cita
pertenezca a su propio perfil de paciente. Los demás dominios deben incorporar
sus policies durante su implementación vertical. No se deben crear policies
genéricas que expongan todas las filas de un dominio clínico.

El directorio usa `professionals.read`. La creación de citas usa
`appointments.manage`; poseer este permiso no evita las verificaciones de
propiedad ni reemplaza las policies RLS.

Las lecturas de perfil e historial clínico requieren `clinical_records.read`.
Las policies permiten el acceso al propio paciente, tutor verificado,
profesional con una cita activa relacionada, administración o supervisión
clínica.

La consulta de recetas requiere `prescriptions.read`. RLS limita cada receta al
paciente relacionado, profesional emisor o roles clínicos autorizados. La
emisión futura requerirá `prescriptions.manage`, además de contexto clínico y
firma digital.
