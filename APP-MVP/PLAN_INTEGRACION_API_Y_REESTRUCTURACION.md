# Plan de integración de API y reestructuración de APP-MVP

## 1. Objetivo

Integrar `APP-MVP` con la API de Doc IA y preparar el frontend para que:

- Mantenga una arquitectura hexagonal separada por capas.
- Pueda desarrollarse en paralelo por módulos y experiencias de usuario.
- Reutilice casos de uso comunes entre distintos roles.
- Consuma autenticación, sesiones, roles y permisos reales de la API.
- Funcione como aplicación móvil responsive y como aplicación web accesible mediante URL.
- Permita abrir enlaces internos directamente cuando sea publicada.
- Evolucione sin acoplar las pantallas a una versión específica de la API.

`Landing_V2` queda fuera del alcance de este trabajo.

---

## 1.1 Convenciones obligatorias del frontend

Estas reglas se aplican a toda modificación futura de `APP-MVP`:

- Todas las carpetas, archivos, clases, variables, rutas internas y nombres técnicos se escriben en inglés.
- Solamente los textos visibles para el usuario se escriben en español.
- El español visible debe ser español de Bolivia, con redacción neutral y sin modismos argentinos.
- Los colores se declaran en una única fuente de verdad y no se escriben valores hexadecimales directamente en pantallas o componentes.
- El diseño se construye con tokens y componentes reutilizables.
- Las pantallas no deben repetir componentes, estilos ni reglas de layout.
- Las URLs, flags y valores variables por ambiente se configuran fuera de los módulos funcionales.
- Nunca se incluyen contraseñas, secretos privados ni credenciales de base de datos dentro del código Flutter.
- Cada cambio realizado en `APP-MVP` debe registrarse en `APP_MVP_CHANGES.md`.
- El registro de cambios describe modificaciones realizadas y no incluye comprobaciones, comandos ejecutados ni resultados de pruebas.

---

## 2. Estado actual

### 2.1 API

La API está organizada por dominios funcionales y utiliza una arquitectura hexagonal:

```text
interfaces/http -> application -> domain
infrastructure -> application/domain ports
domain -> sin dependencias externas
```

Características disponibles:

- NestJS con Fastify.
- Prefijo versionado `api/v1`.
- PostgreSQL con RLS y claims de sesión.
- JWT de acceso.
- Refresh token rotativo.
- Sesiones persistidas en `user_sessions`.
- Roles múltiples por usuario.
- Permisos incluidos en el JWT.
- Login mediante correo o teléfono.
- Endpoints de login, refresh, logout y usuario actual.

Endpoints iniciales de sesión:

```http
POST /api/v1/auth/login
POST /api/v1/auth/refresh
POST /api/v1/auth/logout
GET  /api/v1/auth/me
```

La mayoría de los demás endpoints todavía son contratos placeholder. Deben implementarse verticalmente por caso de uso antes de conectarlos como funcionalidades reales.

### 2.2 APP-MVP

La aplicación Flutter actualmente:

- Está organizada principalmente por roles: `patient`, `doctor` y `admin`.
- Utiliza Riverpod.
- Utiliza `go_router`.
- Mantiene la sesión solamente en memoria.
- Autentica mediante usuarios mock.
- Obtiene información clínica y operativa desde `MockClinicData`.
- Solo reconoce un rol por usuario.
- Centraliza todas las rutas en un único archivo.
- Usa navegación inferior tanto en móvil como en escritorio.
- No cuenta con cliente HTTP.
- No cuenta con persistencia segura de sesión.
- No restaura la sesión al iniciar.
- No conserva la URL solicitada después del login.

### 2.3 Diferencias que deben resolverse

| Área | API/Base de datos | APP-MVP actual |
| --- | --- | --- |
| Roles | 11 roles y múltiples roles por usuario | 3 roles exclusivos |
| Autorización | Roles y permisos | El rol decide toda la navegación |
| Sesión | JWT, refresh rotativo y sesión persistida | Estado temporal en memoria |
| Identidad | Usuario, persona, paciente y profesional separados | `AppUser` mezcla los conceptos |
| Organización | Dominios funcionales | Pantallas agrupadas por rol |
| Datos | API y PostgreSQL | Mocks importados desde la UI |
| Web | CORS configurable | Sin estrategia completa de deep links |
| Responsive | Cliente independiente | Navegación inferior en todos los tamaños |

---

## 3. Principios para la nueva estructura

### 3.1 Organizar por módulos de negocio

Los casos de uso deben vivir en módulos funcionales, no dentro de carpetas exclusivas de cada rol.

Ejemplo:

- El módulo `appointments` contiene los casos de uso de citas y agenda.
- La experiencia de paciente presenta sus citas.
- La experiencia profesional presenta su agenda.
- Ambos consumen contratos del mismo módulo.

### 3.2 Separar módulos de experiencias

Un módulo representa una capacidad del negocio.

Una experiencia representa:

- El shell de navegación.
- El dashboard.
- Los accesos disponibles para un conjunto de roles.
- La composición visual de distintos módulos.

### 3.3 Compartir contratos, no implementaciones visuales completas

Las experiencias pueden utilizar widgets especializados, pero deben compartir:

- Entidades de dominio.
- Casos de uso.
- Puertos de repositorio.
- Adaptadores HTTP.
- Manejo de errores.
- Reglas de autorización.

### 3.4 La UI no debe importar mocks directamente

Las pantallas deben depender de providers o controladores de aplicación.

Los mocks deben implementar los mismos puertos que la API:

```text
AppointmentsRepository
├── ApiAppointmentsRepository
└── MockAppointmentsRepository
```

La selección del adaptador debe realizarse durante el bootstrap de la aplicación.

---

## 4. Estructura objetivo de APP-MVP

```text
lib/
  main.dart

  app/
    app.dart
    bootstrap.dart
    config/
      app_environment.dart
      api_config.dart
      build_config.dart
    routing/
      app_router.dart
      route_guards.dart
      route_paths.dart
      route_registry.dart
    session/
      session_controller.dart
      session_state.dart

  core/
    authorization/
      access_control.dart
      access_policy.dart
      permission.dart
      role.dart
    errors/
      app_exception.dart
      error_mapper.dart
      failure.dart
    network/
      api_client.dart
      api_exception.dart
      auth_interceptor.dart
      token_refresh_coordinator.dart
    responsive/
      breakpoints.dart
      responsive_layout.dart
      responsive_shell.dart
    storage/
      session_storage.dart
      secure_session_storage.dart
      web_session_storage.dart
    theme/
      app_colors.dart
      app_dimensions.dart
      app_elevations.dart
      app_icons.dart
      app_radius.dart
      app_spacing.dart
      app_theme.dart
      app_typography.dart
    widgets/
      buttons/
      cards/
      dialogs/
      feedback/
      fields/
      layout/
      navigation/

  modules/
    auth/
      domain/
        authenticated_user.dart
        auth_repository.dart
        auth_session.dart
      application/
        login.dart
        logout.dart
        refresh_session.dart
        restore_session.dart
      infrastructure/
        api_auth_repository.dart
        auth_api.dart
        auth_dto.dart
        auth_mapper.dart
      presentation/
        auth_controller.dart
        login_screen.dart
        splash_screen.dart

    account/
    patients/
    family/
    clinical_records/
    appointments/
    professionals/
    prescriptions/
    emergencies/
    ai_assistant/
    telemedicine/
    administration/
    human_resources/
    partners/
    deliveries/
    notifications/
    payments/
    coins/

  experiences/
    patient/
      patient_dashboard.dart
      patient_navigation.dart
      patient_shell.dart
    guardian/
    professional/
    operator/
    clinical_supervisor/
    partner/
    delivery/
    human_resources/
    administration/
```

### 4.1 Estructura interna recomendada para cada módulo

Los módulos deben crecer únicamente cuando exista una responsabilidad real:

```text
modules/<module>/
  domain/
    entities/
    value_objects/
    repositories/
  application/
    use_cases/
    controllers/
  infrastructure/
    api/
    dto/
    mappers/
    repositories/
  presentation/
    screens/
    widgets/
    providers/
  routing/
    <module>_routes.dart
```

Regla de dependencias:

```text
presentation -> application -> domain
infrastructure -> domain/application
domain -> sin Flutter, Riverpod, Dio ni almacenamiento
```

---

## 5. Roles, permisos y experiencias

### 5.1 Roles reales

La base de datos define actualmente:

```text
admin
patient
guardian
doctor_general
doctor_specialist
nurse
operator
clinical_supervisor
health_partner
delivery_assistant
human_resources
```

La aplicación no debe limitar el usuario a un único rol.

### 5.2 Nuevo modelo de usuario autenticado

El modelo de sesión debe representar el contrato real:

```dart
class AuthenticatedUser {
  const AuthenticatedUser({
    required this.id,
    required this.sessionId,
    required this.email,
    required this.primaryRole,
    required this.roles,
    required this.permissions,
    this.phone,
  });

  final String id;
  final String sessionId;
  final String email;
  final String? phone;
  final String primaryRole;
  final Set<String> roles;
  final Set<String> permissions;
}
```

No se recomienda usar un `enum` cerrado para todos los roles. La API debe poder agregar un rol sin provocar un fallo de deserialización en clientes existentes.

Se puede mantener un catálogo visual para los códigos conocidos:

```dart
RolePresentation.fromCode(roleCode)
```

Los códigos desconocidos deben tener un comportamiento seguro y una presentación genérica.

### 5.3 Autorización por permisos

La visibilidad de las acciones debe depender de permisos:

```dart
accessControl.can('appointments.read');
accessControl.can('clinical_notes.create');
```

El frontend puede:

- Ocultar una opción.
- Mostrarla deshabilitada.
- Evitar la navegación.
- Mostrar una pantalla de acceso denegado.

Sin embargo, la API debe validar nuevamente todos los permisos. Ocultar un botón no es una medida de seguridad.

### 5.4 Experiencias

Los roles pueden agruparse en experiencias:

| Experiencia | Roles iniciales |
| --- | --- |
| Paciente | `patient` |
| Familia/Tutor | `guardian` |
| Profesional | `doctor_general`, `doctor_specialist`, `nurse` |
| Operaciones clínicas | `operator`, `clinical_supervisor` |
| Empresa asociada | `health_partner` |
| Entregas | `delivery_assistant` |
| Recursos Humanos | `human_resources` |
| Administración | `admin` |

Un mismo usuario puede acceder a varias experiencias.

La experiencia activa es una preferencia de interfaz y no debe reemplazar los roles ni modificar arbitrariamente el JWT.

---

## 5.5 División de trabajo por módulos y roles

La división del equipo se debe realizar en dos niveles:

### Responsables transversales

Mantienen piezas que afectan a toda la aplicación:

- `app/`: bootstrap, configuración y composición principal.
- `core/network/`: cliente HTTP, interceptores y errores de transporte.
- `core/storage/`: persistencia local y almacenamiento seguro.
- `core/authorization/`: roles, permisos y políticas de acceso.
- `core/theme/`: tokens visuales.
- `core/widgets/`: componentes compartidos.
- `app/routing/`: composición global de rutas.
- `modules/auth/`: sesión y autenticación común.

Los integrantes responsables de experiencias no deben copiar ni modificar localmente estas piezas para resolver necesidades particulares. Los cambios transversales deben acordarse e implementarse en su módulo común.

### Responsables por experiencia

Cada experiencia tiene su propio shell, dashboard y composición:

```text
experiences/
  patient/
  guardian/
  professional/
  clinical_operations/
  partner/
  delivery/
  human_resources/
  administration/
```

La experiencia profesional agrupa inicialmente médicos y enfermería. La experiencia de operaciones clínicas agrupa operador y supervisor clínico. Si el comportamiento futuro exige una separación real, se crean experiencias adicionales sin duplicar módulos de negocio.

### Responsables por módulo funcional

Los módulos se asignan por capacidad:

```text
appointments
clinical_records
professionals
prescriptions
emergencies
telemedicine
family
partners
deliveries
payments
coins
notifications
```

Una experiencia consume módulos; no es propietaria de su lógica.

Ejemplo:

```text
experiences/patient       -> modules/appointments
experiences/professional  -> modules/appointments
experiences/administration -> modules/appointments
```

Esto permite que distintos integrantes trabajen sobre experiencias diferentes sin crear tres implementaciones de citas.

### Límites para evitar conflictos

- Cada módulo expone providers, casos de uso, entidades y rutas públicas claramente definidos.
- Ninguna experiencia importa archivos internos de `infrastructure/`.
- Ningún módulo importa pantallas de una experiencia.
- Los widgets exclusivos permanecen dentro de su módulo o experiencia.
- Los widgets que se repiten se promueven a `core/widgets/`.
- No se crean archivos globales de datos mock compartidos entre módulos.
- No se agregan rutas de todos los roles directamente en un único archivo.
- Los dashboards componen módulos y no concentran reglas de negocio.

---

## 6. Autenticación común

### 6.1 Eliminar la selección de rol previa al login

El login debe ser único y común para todos:

```text
/login
   ↓
POST /auth/login
   ↓
guardar sesión
   ↓
cargar usuario y perfiles
   ↓
resolver experiencias disponibles
   ↓
ingresar o mostrar selector de experiencia
```

El usuario no debe indicar qué rol posee antes de validar sus credenciales.

### 6.2 Contrato actual de login

La aplicación debe mapear una respuesta equivalente a:

```json
{
  "accessToken": "...",
  "refreshToken": "...",
  "tokenType": "Bearer",
  "user": {
    "id": "...",
    "sessionId": "...",
    "email": "...",
    "phone": "...",
    "roleCode": "doctor_general",
    "roles": ["doctor_general", "patient"],
    "permissions": ["appointments.read"]
  }
}
```

### 6.3 Estados de sesión

La sesión no debe representarse solamente con `user != null`.

Estados recomendados:

```text
unknown
restoring
unauthenticated
authenticating
authenticated
refreshing
expired
failure
```

Esto permite que el router espere la restauración antes de redirigir.

### 6.4 Restauración

Al iniciar la aplicación:

1. Leer la sesión almacenada.
2. Si existe refresh token, intentar renovar.
3. Validar la sesión con `/auth/me`.
4. Cargar el perfil inicial.
5. Marcar la sesión como autenticada.
6. Si falla el refresh, limpiar la sesión y mostrar el login.

### 6.5 Refresh rotativo

El cliente HTTP debe:

1. Adjuntar el access token.
2. Detectar respuestas `401`.
3. Ejecutar un único refresh aunque varias solicitudes fallen al mismo tiempo.
4. Guardar los tokens rotados.
5. Reintentar una vez la solicitud original.
6. Cerrar la sesión si el refresh falla.

Debe evitarse un bucle infinito de refresh.

### 6.6 Logout

El logout debe:

1. Enviar el refresh token a `/auth/logout`.
2. Limpiar tokens y datos locales aunque la API no responda.
3. Invalidar providers con información sensible.
4. Redirigir al login.
5. Impedir volver mediante el historial a pantallas protegidas.

---

## 7. Separación entre identidad y perfiles

El usuario autenticado no debe contener toda la información clínica o profesional.

Modelos separados:

- `AuthenticatedUser`: sesión, roles y permisos.
- `PersonProfile`: nombres, documento, teléfono y dirección.
- `PatientProfile`: datos propios del paciente.
- `ProfessionalProfile`: matrícula, especialidades y habilitación.
- `PartnerProfile`: empresa asociada y permisos dentro de ella.

### 7.1 Caso de uso de bootstrap

Para reducir múltiples solicitudes al iniciar, se recomienda agregar en la API:

```http
GET /api/v1/account/bootstrap
```

Respuesta sugerida:

```json
{
  "user": {},
  "person": {},
  "patient": null,
  "professional": null,
  "partner": null,
  "roles": [],
  "permissions": [],
  "availableExperiences": []
}
```

Este endpoint es un caso de uso de composición. No reemplaza los endpoints específicos de cada dominio.

---

## 8. Cliente HTTP y configuración

### 8.1 Dependencias sugeridas

- `dio`: cliente HTTP e interceptores.
- `flutter_secure_storage`: almacenamiento seguro en Android/iOS.
- Una solución explícita para cookies web si el refresh se migra a cookie `HttpOnly`.

Las versiones deben definirse al momento de implementar y validarse contra la versión actual de Flutter.

### 8.2 URL de la API

La URL no debe estar escrita directamente en el código:

```bash
flutter run \
  --dart-define=API_BASE_URL=http://localhost:3000/api/v1/
```

```bash
flutter build web \
  --dart-define=API_BASE_URL=https://api.jampic.com/api/v1/
```

Debe existir validación de configuración durante el bootstrap.

### 8.2.1 Configuración de ambientes de Flutter

Flutter no debe leer directamente el `.env` de la API. Son aplicaciones separadas y pueden publicarse en servidores distintos.

La API mantiene en su propio `.env`:

- Credenciales de PostgreSQL.
- Secretos JWT.
- Configuración interna del servidor.
- Orígenes CORS.
- Cualquier secreto utilizado exclusivamente por el backend.

La aplicación Flutter solamente recibe configuración pública del cliente:

- URL base de la API.
- Nombre del ambiente.
- Flags funcionales públicos.
- URLs públicas de soporte, privacidad o términos.
- Identificadores públicos requeridos por SDK de terceros.

Estructura recomendada:

```text
lib/app/config/
  app_environment.dart
  api_config.dart
  build_config.dart
```

Ejemplo conceptual:

```dart
enum AppEnvironment {
  development,
  staging,
  production,
}

abstract final class BuildConfig {
  static const apiBaseUrl = String.fromEnvironment('API_BASE_URL');
  static const environment = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'development',
  );
}
```

Ejecución local:

```bash
flutter run \
  --dart-define=APP_ENV=development \
  --dart-define=API_BASE_URL=http://localhost:3000/api/v1/
```

También se puede utilizar `--dart-define-from-file` con archivos locales no versionados:

```text
config/
  development.example.json
  staging.example.json
  production.example.json
```

Ejemplo local:

```json
{
  "APP_ENV": "development",
  "API_BASE_URL": "http://localhost:3000/api/v1/"
}
```

Reglas:

- Versionar solamente archivos `.example`.
- Ignorar archivos con configuración local real.
- No guardar contraseñas ni secretos en archivos Dart.
- No guardar credenciales de PostgreSQL en Flutter.
- No colocar secretos esperando que la compilación móvil o web los proteja.
- Todo valor incluido en Flutter debe considerarse públicamente recuperable.
- Los tokens de sesión recibidos después del login no pertenecen a la configuración; se gestionan mediante `SessionStorage`.
- Si un proveedor exige un secreto privado, la integración debe realizarse desde la API.

### 8.3 Responsabilidades del cliente

`ApiClient` debe centralizar:

- Base URL.
- Timeouts.
- Headers comunes.
- Serialización.
- Token de acceso.
- Refresh.
- Conversión de errores.
- Identificador de correlación cuando la API lo implemente.
- Logging seguro solo en desarrollo.

Nunca se deben registrar contraseñas, access tokens, refresh tokens ni datos clínicos sensibles.

### 8.4 DTO y mappers

Los DTO representan el contrato HTTP y no deben utilizarse directamente en la UI.

```text
JSON -> DTO -> Mapper -> Entidad de dominio
```

Esto permite que una futura versión de la API cambie nombres o estructuras sin modificar todas las pantallas.

---

## 9. Almacenamiento de tokens

### 9.1 Android e iOS

- Access token preferentemente en memoria.
- Refresh token en almacenamiento seguro.
- Eliminar la sesión al cerrar sesión.
- No almacenar contraseñas.

### 9.2 Web

Guardar refresh tokens en `localStorage` aumenta el impacto de una vulnerabilidad XSS.

La solución recomendada para producción web es:

- Refresh token en cookie `HttpOnly`.
- Cookie `Secure`.
- Configuración `SameSite` según los dominios elegidos.
- Access token de corta duración en memoria.
- CORS limitado a orígenes explícitos.

Esto requiere adaptar login, refresh y logout de la API para el cliente web.

Si durante el MVP se almacena temporalmente el refresh token desde JavaScript, la decisión debe:

- Estar documentada.
- Considerarse transitoria.
- Incluir una política CSP estricta.
- Evitar scripts de terceros innecesarios.
- Tener una tarea explícita para migrar a cookies seguras.

---

## 10. Navegación y acceso mediante URL

### 10.1 Rutas limpias

Para usar direcciones como:

```text
https://app.jampic.com/appointments/123
```

Flutter web debe utilizar estrategia de rutas por path:

```dart
usePathUrlStrategy();
```

### 10.2 Deep links

El flujo debe conservar la ruta solicitada:

```text
usuario abre /appointments/123
→ se restaura la sesión
→ si no está autenticado: /login?redirect=/appointments/123
→ login correcto
→ vuelve a /appointments/123
→ se verifica autorización
```

La URL de retorno debe validarse para evitar redirecciones externas no autorizadas.

### 10.3 Router modular

El archivo actual de rutas debe dividirse:

```text
app/routing/app_router.dart
modules/auth/routing/auth_routes.dart
modules/appointments/routing/appointments_routes.dart
modules/clinical_records/routing/clinical_records_routes.dart
experiences/patient/patient_routes.dart
experiences/professional/professional_routes.dart
```

El router principal compone los registros de rutas.

### 10.4 Guards de navegación

Se requieren controles para:

- Sesión no restaurada.
- Usuario no autenticado.
- Sesión expirada.
- Permiso faltante.
- Experiencia no disponible.
- Ruta desconocida.

Debe existir una página `403` y una página `404`.

### 10.5 Configuración del hosting

El servidor debe devolver `index.html` para rutas que no correspondan a archivos estáticos.

Ejemplo conceptual para Nginx:

```nginx
location / {
  try_files $uri $uri/ /index.html;
}
```

Otros proveedores deben usar un rewrite equivalente:

- Firebase Hosting: rewrite de `**` a `/index.html`.
- Netlify: fallback a `/index.html`.
- Vercel: rewrite de las rutas de aplicación.

Si la app se publica en una subruta, debe construirse con el `base-href` correcto.

---

## 11. Diseño responsive

## 11.1 Sistema de diseño y fuente única de colores

Los colores deben declararse exclusivamente en:

```text
lib/core/theme/app_colors.dart
```

`app_colors.dart` contiene tokens semánticos, no colores asociados a una pantalla concreta:

```dart
abstract final class AppColors {
  static const primary = Color(0xFF...);
  static const secondary = Color(0xFF...);
  static const success = Color(0xFF...);
  static const warning = Color(0xFF...);
  static const danger = Color(0xFF...);
  static const info = Color(0xFF...);

  static const backgroundLight = Color(0xFF...);
  static const surfaceLight = Color(0xFF...);
  static const textPrimaryLight = Color(0xFF...);

  static const backgroundDark = Color(0xFF...);
  static const surfaceDark = Color(0xFF...);
  static const textPrimaryDark = Color(0xFF...);
}
```

Reglas:

- No usar `Color(0x...)` fuera de `core/theme/`.
- No definir colores dentro de una pantalla.
- No usar nombres como `patientBlue` o `appointmentGreen` si el significado es únicamente visual.
- Preferir nombres semánticos como `success`, `warning`, `surface` o `onPrimary`.
- `AppTheme` transforma los tokens en `ColorScheme`, temas de botones, campos, cards y navegación.
- Los componentes consumen `Theme.of(context)` siempre que sea posible.
- Los módulos solo acceden directamente a `AppColors` cuando no existe un equivalente apropiado en el tema.

Antes de cambiar un color global debe evaluarse su impacto en contraste, modo oscuro, estados deshabilitados y accesibilidad.

### 11.2 Tokens del diseño

El sistema visual debe centralizar:

```text
core/theme/
  app_colors.dart
  app_dimensions.dart
  app_elevations.dart
  app_icons.dart
  app_radius.dart
  app_spacing.dart
  app_theme.dart
  app_typography.dart
```

Responsabilidades:

- `app_colors.dart`: paleta y colores semánticos.
- `app_spacing.dart`: escala de márgenes y padding.
- `app_radius.dart`: radios de borde.
- `app_dimensions.dart`: alturas, anchos y tamaños recurrentes.
- `app_elevations.dart`: niveles de elevación.
- `app_typography.dart`: escala tipográfica.
- `app_icons.dart`: iconos semánticos reutilizados.
- `app_theme.dart`: composición de `ThemeData`.

No deben declararse números repetidos en las pantallas cuando representen decisiones del sistema de diseño.

### 11.3 Componentes reutilizables

Los componentes comunes deben organizarse por propósito:

```text
core/widgets/
  buttons/
  cards/
  dialogs/
  feedback/
  fields/
  layout/
  navigation/
```

Ejemplos:

```text
AppPrimaryButton
AppSecondaryButton
AppTextField
AppSearchField
AppCard
AppDialog
AppEmptyState
AppErrorState
AppLoadingState
AppSectionHeader
AppResponsiveContainer
```

Regla para decidir ubicación:

- Si se utiliza en toda la app: `core/widgets/`.
- Si se comparte dentro de un módulo: `modules/<module>/presentation/widgets/`.
- Si solo pertenece a una experiencia: `experiences/<experience>/widgets/`.
- Si solo se utiliza una vez y no representa un patrón: puede permanecer privado en la pantalla.

Un componente compartido debe:

- Recibir datos y callbacks.
- No consultar repositorios directamente.
- No contener reglas de permisos ocultas.
- Respetar tokens del tema.
- Tener estados de carga, error y deshabilitado cuando corresponda.
- Ser adaptable a móvil y web.
- Evitar textos rígidos cuando el texto cambia según el caso de uso.

### 11.4 Breakpoints compartidos

```text
compact:  < 600 px
medium:   600 a 1023 px
expanded: >= 1024 px
```

### 11.5 Navegación

| Tamaño | Navegación |
| --- | --- |
| Compact | `NavigationBar` inferior |
| Medium | `NavigationRail` |
| Expanded | Sidebar persistente |

### 11.6 Contenido

- Aplicar ancho máximo a formularios.
- Evitar estirar tarjetas y texto en pantallas grandes.
- Usar grids adaptativos.
- Mostrar tablas en escritorio y tarjetas equivalentes en móvil.
- Mantener áreas táctiles adecuadas.
- Permitir teclado, mouse y foco visible en web.
- Probar orientación vertical y horizontal.

La lógica de aplicación no debe cambiar según el breakpoint.

---

## 12. Seguridad de API pendiente

La API ya tiene `JwtAuthGuard` como guard global.

El `PermissionsGuard` existe, pero se debe completar su integración:

1. Registrarlo como guard global después de `JwtAuthGuard`.
2. Definir un catálogo estable de permisos.
3. Aplicar `@Permissions()` a endpoints reales.
4. Autorizar por acción, no solamente por nombre de tabla.
5. Mantener RLS como última barrera.
6. Auditar accesos sensibles.
7. No confiar en permisos enviados por el frontend.

Ejemplos conceptuales:

```text
appointments.read.own
appointments.read.assigned
appointments.manage
clinical_records.read.own
clinical_records.read.authorized
clinical_notes.create
prescriptions.create
users.manage
```

Los códigos definitivos deben alinearse con la matriz de casos de uso y las políticas de la base.

---

## 13. Estrategia de versionamiento

La aplicación debe consumir un contrato versionado:

```text
/api/v1
```

Para evitar acoplamiento:

- Las pantallas no conocen DTO HTTP.
- Los repositorios traducen DTO a dominio.
- `ApiConfig` selecciona la base URL.
- Los adaptadores específicos contienen cualquier diferencia entre `v1` y una futura `v2`.
- El dominio y los casos de uso se mantienen estables cuando cambia el transporte.

Ejemplo:

```text
AppointmentsRepository
└── ApiV1AppointmentsRepository
```

Si aparece `v2`, se agrega otro adaptador sin duplicar presentación ni dominio.

---

## 14. Migración de los mocks

Los mocks no deben eliminarse todos al mismo tiempo.

### 14.1 Estado objetivo

```text
Módulo
├── Puerto de repositorio
├── Repositorio API
└── Repositorio mock
```

### 14.2 Selección por entorno

Ejemplo conceptual:

```text
DATA_SOURCE=mock
DATA_SOURCE=api
```

Las pantallas no deben conocer cuál adaptador se está utilizando.

### 14.3 Eliminación de `MockClinicData`

`MockClinicData` debe dividirse gradualmente:

- Datos de citas al módulo `appointments`.
- Datos clínicos a `clinical_records`.
- Profesionales a `professionals`.
- Familiares a `family`.
- Métricas administrativas a `administration`.
- Respuestas mock de IA a `ai_assistant`.

El archivo global puede eliminarse cuando ningún módulo lo importe.

---

## 15. Fases de implementación

### Fase 0 — Documentación y contratos

- Acordar estructura de carpetas.
- Definir nombres de permisos.
- Confirmar estrategia de tokens para web.
- Definir dominios de producción.
- Definir contrato de `account/bootstrap`.
- Documentar errores comunes de API.

### Fase 1 — Fundación de APP-MVP

- Crear `app/`, `core/`, `modules/` y `experiences/`.
- Normalizar nombres técnicos y carpetas en inglés.
- Centralizar colores y tokens de diseño en `core/theme/`.
- Organizar componentes reutilizables en `core/widgets/`.
- Crear configuración mediante `--dart-define`.
- Crear ejemplos de configuración por ambiente.
- Implementar `ApiClient`.
- Implementar modelo de errores.
- Implementar almacenamiento de sesión.
- Mantener las pantallas existentes funcionando durante la migración.

### Fase 2 — Autenticación real

- Implementar login contra la API.
- Eliminar selección de rol previa al login.
- Implementar refresh rotativo.
- Implementar logout.
- Implementar `/auth/me`.
- Restaurar la sesión al iniciar.
- Eliminar dependencia de `MockAuthRepository` en producción.
- Mantener repositorio mock solo para desarrollo/pruebas.

### Fase 3 — Roles, permisos y router

- Sustituir `UserRole` único.
- Implementar roles múltiples.
- Implementar `AccessControl`.
- Crear selector de experiencia cuando corresponda.
- Modularizar rutas.
- Conservar redirect solicitado.
- Crear páginas 403 y 404.
- Proteger rutas por permiso.

### Fase 4 — Web y responsive

- Activar URLs por path.
- Crear `ResponsiveShell`.
- Implementar navegación inferior, rail y sidebar.
- Configurar fallback del hosting.
- Probar deep links autenticados y no autenticados.
- Actualizar `web/index.html` y `manifest.json`.
- Definir metadata, nombre, colores e iconos finales.

### Fase 5 — Primer módulo vertical

Se recomienda comenzar por `appointments`:

```text
API controller/DTO
→ caso de uso
→ puerto
→ repositorio PostgreSQL
→ permisos/RLS
→ cliente Flutter
→ repositorio Flutter
→ controller/provider
→ UI paciente/profesional
→ pruebas
```

Este módulo permite validar:

- Reutilización entre roles.
- Autorización.
- Navegación.
- Estados de carga.
- Errores.
- Responsive.

### Fase 6 — Migración progresiva

Orden sugerido:

1. Account/perfil.
2. Appointments.
3. Professionals/directorio.
4. Clinical records.
5. Family/guardian.
6. Prescriptions.
7. Emergencies.
8. Telemedicine.
9. AI assistant.
10. Administration.
11. Human resources.
12. Partners.
13. Deliveries.
14. Coins y payments.
15. Notifications.

El orden puede ajustarse según prioridad comercial, pero cada módulo debe completarse verticalmente.

---

## 16. Trabajo paralelo del equipo

Para evitar conflictos:

- Una persona o equipo mantiene `core/network`, sesión y autenticación.
- Una persona o equipo mantiene el router y shells.
- Cada módulo tiene responsables claros.
- Los módulos no importan internamente otros módulos sin un contrato acordado.
- Los contratos compartidos se revisan antes de modificarse.
- No se agregan datos nuevos a un archivo mock global.
- Cada módulo registra sus rutas y providers.
- Todo texto visible se revisa en español de Bolivia.
- Todo nombre técnico nuevo se escribe en inglés.
- Cada modificación se registra en `APP_MVP_CHANGES.md`.

Los cambios transversales deben ser pequeños y coordinados.

---

## 17. Pruebas requeridas

### 17.1 Unitarias

- Mappers de DTO.
- Casos de uso.
- Access control.
- Restauración de sesión.
- Coordinador de refresh.
- Conversión de errores.

### 17.2 Widgets

- Login.
- Estados de carga y error.
- Navegación según permisos.
- Shell compacto, medio y expandido.
- Pantallas 403 y 404.

### 17.3 Integración

- Login real.
- Refresh rotativo.
- Logout.
- Sesión expirada.
- Apertura de una URL interna.
- Retorno a la URL después del login.
- Usuario con múltiples roles.
- Usuario sin permisos.

### 17.4 Contrato

- Validar DTO del frontend contra respuestas reales de la API.
- Evitar depender de campos no documentados.
- Detectar cambios incompatibles en CI.

---

## 18. Criterios de aceptación de la primera integración

La primera etapa se considera completa cuando:

- La aplicación inicia contra una API configurable.
- No existen credenciales privadas dentro de Flutter.
- La configuración pública cambia por ambiente sin modificar módulos funcionales.
- Los colores se obtienen desde la fuente central de tokens.
- Los componentes reutilizables no duplican estilos ni reglas comunes.
- Los nombres técnicos y carpetas están en inglés.
- Los textos visibles utilizan español apropiado para Bolivia.
- El login usa la API real.
- El usuario no selecciona un rol antes de autenticarse.
- La sesión sobrevive al reinicio de la aplicación.
- El refresh token rota correctamente.
- El logout revoca y limpia la sesión.
- Se soportan múltiples roles y permisos.
- La navegación se construye según la experiencia y permisos.
- Una URL interna puede abrirse directamente en web.
- Después del login se recupera la URL solicitada.
- El hosting devuelve la aplicación para rutas internas.
- El shell cambia según el ancho disponible.
- Las pantallas no importan repositorios concretos ni mocks globales.
- Al menos un módulo funcional consume la API verticalmente.
- Existen pruebas para login, refresh, permisos y deep links.
- `flutter analyze` y las pruebas terminan sin errores.
- La API compila y sus pruebas correspondientes terminan sin errores.
- Los cambios realizados están registrados en `APP_MVP_CHANGES.md`.

---

## 19. Riesgos y decisiones pendientes

### Decisiones que deben cerrarse antes de producción

- Dominio final de la app web.
- Dominio final de la API.
- Uso de cookies `HttpOnly` para refresh web.
- Proveedor de hosting.
- Política de CORS.
- Catálogo definitivo de permisos.
- Contrato de bootstrap de cuenta.
- Estrategia de actualización de sesiones cuando cambian los permisos.
- Política de expiración y cierre remoto de sesiones.

### Riesgos principales

- Conectar pantallas directamente a endpoints placeholder.
- Reproducir reglas de negocio en Flutter.
- Autorizar solamente por rol.
- Guardar refresh tokens web sin protección adecuada.
- Mantener un router monolítico.
- Crear carpetas por rol que dupliquen módulos funcionales.
- Compartir DTO directamente con la UI.
- Migrar todos los mocks simultáneamente.
- Publicar Flutter web sin fallback a `index.html`.

---

## 20. Resultado esperado

Al finalizar la reestructuración:

- La API conserva su arquitectura por dominios.
- APP-MVP utiliza módulos equivalentes desde la perspectiva del cliente.
- Los roles componen experiencias, pero no duplican la lógica funcional.
- Login, cuenta, sesión, notificaciones y otros elementos comunes se reutilizan.
- Los permisos controlan las acciones disponibles.
- La app funciona en Android, iOS y web.
- Las rutas web pueden compartirse y abrirse directamente.
- Los módulos pueden desarrollarse y versionarse con menor interferencia entre equipos.
- Una futura `api/v2` puede integrarse mediante adaptadores sin reescribir la aplicación.
