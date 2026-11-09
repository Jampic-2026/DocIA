# Estructura de la API

La API queda organizada por dominio de negocio y siguiendo arquitectura hexagonal (Ports and Adapters). La organizacion actual se alinea con `db/01_database.sql` y con la matriz `db/traceability_matriz_use_cases.md`.

## Capas globales

- `src/main.ts`: bootstrap HTTP, Fastify, CORS, Helmet, prefijo global y validacion.
- `src/app.module.ts`: composicion de modulos principales.
- `src/config`: lectura y validacion de variables de entorno.
- `src/database`: pool PostgreSQL y helper transaccional.
- `src/common`: decoradores, guards, tipos y utilidades transversales.
- `src/modules`: dominios funcionales.
- `db`: SQL numerados, SQL validado y matriz de trazabilidad.
- `scripts`: tareas operativas.

## Convencion SQL

La base no usa carpeta de migraciones. Los SQL reproducibles viven directamente en `db/`:

```text
01_database.sql   # extensiones, enums, tablas e indices
02_functions.sql  # funciones internas y RPC
03_triggers.sql   # triggers
04_policies.sql   # todas las policies y configuraciones RLS
05_init.sql       # seed inicial
06_jobs.sql       # jobs futuros
07_permission_catalog.sql
08_local_test_users.sql
```

`01_database.sql` mantiene solo estructura validada. No se crean SQL
posteriores a `08`; cada cambio se integra en el archivo consolidado que le
corresponde.

## Convencion por modulo

Forma minima:

```text
src/modules/<domain>/
  <domain>.module.ts
  application/
    <domain>.service.ts
  interfaces/
    http/
      <domain>.controller.ts
```

Cuando el modulo tenga reglas o integraciones reales, se agregan las capas necesarias:

```text
domain/
  entities/
  value-objects/
  ports/
  events/
infrastructure/
  persistence/
  external-services/
interfaces/http/
  dto/
```

No se mantienen carpetas vacias. La arquitectura es hexagonal por direccion de dependencias y responsabilidades.

## Regla de cobro

- Usuario final: paquetes de monedas, billetera, lotes con expiracion anual y movimientos.
- Servicio no presencial cobrable: `charge_mode = coins`.
- Atencion presencial: `charge_mode = fiat`, pago QR o efectivo cobrado por el responsable asistente.
- Usuarios finales: no tienen suscripciones ni planes.
- Empresa asociada: planes empresariales mediante `partner_subscription_plans` y `partner_subscriptions`.

## Flujo de monedas y pagos

El flujo completo está en `docs/coin-payment-flow.md`.

```text
coin_packages -> payment_orders/payments -> coin_purchases -> coin_lots -> coin_transactions -> coin_transaction_allocations
```

Para servicios no presenciales se consume saldo desde `coin_wallets` y lotes vigentes. Para atención presencial se crea orden fiat y pago QR/efectivo con responsable asistente. Los planes empresariales se mantienen en `partners` y no aplican a usuarios finales.

## Autenticacion y policies

La API usa JWT con access token y refresh token rotativo. El guard global protege todas las rutas salvo las marcadas con `@Public()`.

En operaciones con persistencia sensible, la capa de infraestructura debe usar `DatabaseService.transactionAsUser(user, work)`. Ese helper setea claims locales en PostgreSQL:

```text
app.user_id
app.session_id
app.role_code
app.roles
app.permissions
```

Las policies de `04_policies.sql` consumen esos valores mediante helpers de `02_functions.sql`.

## Regla de dependencias

```text
interfaces -> application -> domain
infrastructure -> application/domain ports
domain -> sin dependencias externas
```

Un controlador no debe consultar directamente PostgreSQL. Un caso de uso no debe depender de `pg`, Google, OpenAI ni pasarelas de pago; debe depender de puertos definidos por el dominio o la aplicacion.

## Dominios actuales

- `auth`: Autenticacion.
- `users`: Usuarios y seguridad.
- `people`: Personas.
- `patients`: Pacientes, familiares y dependientes.
- `consents`: Consentimientos.
- `professionals`: Profesionales, especialidades y turnos.
- `clinical-records`: Perfil clinico e historia clinica.
- `emergencies`: Emergencias y operador.
- `ai`: Inteligencia artificial.
- `appointments`: Consultas, agenda y telemedicina.
- `prescriptions`: Recetas digitales.
- `catalog`: Catalogo y tarifario.
- `coins`: Monedas Doc IA y billeteras.
- `payments`: Pagos fiat, QR, efectivo e incidencias.
- `benefits`: Beneficios y descuentos.
- `partners`: Empresas asociadas, planes, sedes y solicitudes.
- `home-services`: Servicios domiciliarios y seguimiento.
- `deliveries`: Entregas.
- `incidents`: Incidentes.
- `human-resources`: Recursos humanos.
- `notifications`: Notificaciones.
- `administration`: Administracion y reglas operativas.
- `audit`: Auditoria.

## Criterio de implementacion

El avance debe ser vertical por caso de uso: controlador/DTO, caso de uso, puertos, adaptador de persistencia, auditoria y pruebas. La matriz de trazabilidad define las tablas principales, relacionadas y criterios de auditoria por CU.

Los primeros cortes verticales implementados son:

- Listado de citas autorizadas en `appointments`.
- Creación de citas derivando el paciente desde el JWT.
- Directorio de médicos verificados con especialidad y disponibilidad.
- Perfil personal y dirección vigente de la cuenta autenticada.
- Perfil clínico e historial médico del paciente autenticado.
- Dependientes, familiares autorizados y permisos del vínculo familiar.
- Recetas digitales e ítems autorizados para paciente y profesional.

La reserva de una cita se ejecuta dentro de `transactionAsUser`, valida la
disponibilidad en `America/La_Paz` y obtiene un advisory lock por profesional y
fecha antes de comprobar superposiciones.

## Versionado

El prefijo global actual es `api/v1`, definido por `API_PREFIX`. Si se requiere una nueva version sin romper clientes existentes, se puede versionar desde interfaces:

```text
interfaces/http/v1/
interfaces/http/v2/
```

Los casos de uso y el dominio deben mantenerse estables siempre que sea posible; las diferencias de contrato entre versiones viven en la capa de interfaces.
