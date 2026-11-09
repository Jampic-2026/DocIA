# Registro de cambios de APP-MVP

Este archivo registra exclusivamente los cambios realizados en `APP-MVP`.

No se deben incluir aquí comprobaciones, comandos ejecutados, resultados de análisis ni resultados de pruebas.

## Formato

Cada modificación futura debe agregarse al inicio del historial con:

```text
## YYYY-MM-DD — Título breve

- Cambio realizado.
- Archivos o áreas afectadas.
- Decisión de arquitectura relevante, si corresponde.
```

## Historial

## 2026-10-11 — Contraste del acceso a Meet

- «Ingresar a Meet» usa un botón con fondo sólido, texto de contraste e icono de videollamada, respetando el tema y la fila de acciones existente en orientación humana.
- Archivo afectado: `lib/modules/guidance/presentation/support_calls_screen.dart`.

## 2026-10-11 — Navegación desde notificaciones

- Los avisos conservan el tipo e identificador del elemento notificado y abren el módulo correspondiente según el rol y los permisos.
- Las notificaciones de orientación abren las llamadas del paciente o profesional, priorizando visualmente la solicitud referenciada; coordinación abre su cola.
- Se añaden rutas de orientación y casos profesionales dentro del panel lateral.
- El clic navega también en avisos ya leídos y cuando falla el marcado de lectura; avisos sin destino autorizado muestran un mensaje.
- Los avisos push móviles y locales reutilizan los mismos destinos internos.

## 2026-10-11 — Menú lateral en las vistas profesionales

- Expediente, nota clínica, receta y teleconsulta se abren dentro de su rama de navegación profesional, conservando el panel lateral web.
- Se mantiene el acceso a orientación asignada desde la cuadrícula de Acciones del inicio profesional.

## 2026-10-11 — Eliminación de horarios y bloqueos

- Las solicitudes para eliminar horarios y bloqueos envían un objeto JSON explícito, compatible con el tipo de contenido del cliente.
- Los botones de eliminación muestran los errores en pantalla y actualizan la disponibilidad después de una eliminación satisfactoria.

## 2026-10-11 — Personal disponible y motivos de indisponibilidad

- El selector de asignación de orientación muestra dos pestañas con cantidades: Disponibles y No disponibles.
- El personal no disponible permanece visible con sus motivos, incluyendo falta de horario vigente, y no puede seleccionarse.
- Si no hay personal disponible, el selector abre directamente la pestaña No disponibles cuando contiene profesionales.
- El modelo de personal recibe disponibilidad y motivos desde la API; la API conserva la validación de asignación.

## 2026-10-11 — Mensaje de disponibilidad en orientación

- El selector de personal explica que la disponibilidad depende también de turnos u horarios, bloqueos y atenciones activas, además de otras llamadas.

## 2026-10-11 — Acceso a orientación desde Acciones

- El acceso a llamadas de orientación asignadas se integra en la cuadrícula de Acciones del panel profesional mediante el mismo componente visual que Nota clínica, Casos asignados y Teleconsulta.
- Se retira el enlace situado encima de la bienvenida y se conserva su navegación.

## 2026-10-11 — Visibilidad de llamadas por asignación

- La vista del profesional muestra únicamente sus llamadas asignadas y oculta las solicitudes pendientes y las de otros profesionales.
- Operaciones, Supervisión clínica y Admin conservan la cola de asignación cuando cuentan con el permiso de gestión de emergencias.
- La vista del paciente limita las solicitudes a las propias.

## 2026-10-11 — Ingreso a llamadas de orientación

- El ingreso a Meet desde Orientación humana envía un objeto JSON explícito para evitar el rechazo de solicitudes POST vacías.

## 2026-10-11 — Registro de menores y completitud del perfil

- El registro de menores distribuye los campos en dos columnas cuando dispone de al menos 600 píxeles y mantiene una columna en espacios menores, con la separación del diseño existente.
- Las solicitudes de completitud del perfil envían un objeto JSON vacío explícito para el paciente propio y los pacientes autorizados.

## 2026-10-11 — Diseño de acciones y navegación web

- Web conserva el panel lateral en cualquier ancho de ventana; el contenido permite desplazamiento horizontal en ventanas estrechas.
- Revisar documentos abre la vista dentro del área de Gestión y cierra el diálogo previo, conservando la navegación lateral.
- Requisitos, documentos profesionales, reglas clínicas y orientación reutilizan las acciones de diálogo establecidas en una sola fila.
- Las acciones de las vistas nuevas mantienen una fila, altura y separación uniformes, con etiquetas de una línea.

## 2026-10-11 — Contexto del diálogo de profesionales

- El detalle de un profesional obtiene el tema desde el contexto del propio diálogo, evitando consultar una pantalla de origen que pudo desmontarse durante la navegación.

## 2026-10-11 — Accesos de Gestión y Operaciones en escritorio

- El menú lateral administrativo incorpora Requisitos, Turnos, Completitud, Orientación y Reglas clínicas con los mismos permisos que sus pestañas móviles.
- Operaciones incorpora Orientación y Reglas clínicas en el menú lateral.
- El control de entrada a las rutas contempla los permisos de los módulos nuevos, conservando las restricciones particulares de cada pantalla.
- Gestión abre Profesionales por defecto y Operaciones conserva Emergencias o Entregas según el rol; los enlaces seleccionan módulos por código y actualizan también la pestaña móvil al cambiar la URL.

## 2026-10-11 — Integración de fase 3

- Telemedicina incorpora cierre explícito de conferencia y distingue salas finalizadas.
- Recetas presenta alergias vigentes y exige revisión justificada antes de emitir cuando existen advertencias.
- El asistente conserva evaluaciones y decisiones, permite compartir antecedentes por elección y conecta orientación con emergencias, reservas y atención humana.
- Orientación humana incorpora solicitud, cola, asignación, inicio en Meet, rechazo, cancelación y resultado de atención; se separan dominio, controlador y adaptador HTTP.
- Las emergencias propias activas permiten solicitar apoyo por Meet vinculado al caso y con prioridad urgente; la cola informa cuando no hay estimación de espera disponible.
- Supervisión configura reglas de riesgo y registra la aprobación clínica de una revisión; las reglas permanecen desactivadas hasta su validación.

## 2026-10-11 — Cierre de integraciones de fases 1 y 2

- Los formularios esperan el cierre completo del diálogo antes de liberar sus controladores, incluidos documentos, habilitación, atención y citas.

- La carga documental permite elegir los nombres exactos configurados por RR. HH. y distingue documentos adicionales.

- Entregas separa presentación, controlador, puerto de dominio y adaptador HTTP.
- Directorio y reservas utilizan horarios libres reales y fechas de Bolivia, con exclusión de bloqueos y citas ocupadas.
- RR. HH. muestra formación y certificaciones antes de habilitar. Estudios permite abrir el resultado autorizado.
- Emergencias recupera exclusivamente el paciente seleccionado e incluye falsa alarma con motivo. La ficha actualiza la completitud después de guardar; tendencias identifica unidades, origen y contexto.

## 2026-10-11 — Flujos pendientes de fases 1 y 2

- Se incorporaron recepción y decisión de casos asignados, atención estructurada, signos vinculados a cita o emergencia, derivación y cierre desde el módulo profesional.
- Se añadieron turnos de enfermería y consulta administrativa de disponibilidad del personal.
- Familiares permite registrar menores a cargo y abrir ficha, agenda y emergencia del paciente autorizado, respetando permisos vigentes.
- Se añadieron historial por categorías, evolución, exportación clínica y completitud configurable con pendientes por actor; la recompensa permanece desactivada hasta definir su campaña.
- La agenda profesional permite registrar inasistencia y el expediente permite solicitar estudios diagnósticos.

## 2026-10-10 — Requisitos y revisión de habilitación profesional

- Se agregó configuración administrativa de documentos obligatorios por rol, visible en la postulación y requerida antes de habilitar profesionales.
- Las decisiones de aprobación permiten seleccionar el rol y la especialidad validada del catálogo.
- Se incorporó revisión individual de documentos de profesionales existentes y apertura autorizada de archivos, incluidos PDF, mediante un componente compartido.
- El perfil permite solicitar cambios de especialidad e informa que los cambios de credenciales requieren revalidación.
- Se añadió atención de casos asignados con aceptación o rechazo motivado, seguimiento del traslado, registro de valoración, intervención, derivación y cierre.
- Se agregó un formulario compartido de signos vitales profesionales vinculado a cita o emergencia, accesible desde el expediente y los casos asignados.

## 2026-09-02 — Actualización automática de notificaciones e icono en segundo plano

- Se agregó polling periódico silencioso (cada 12 segundos) e invalidación reactiva inmediata al recibir mensajes push en primer plano (`onMessage`), eliminando la necesidad de refrescar manualmente la pantalla de notificaciones.
- Se configuraron los metadatos `default_notification_icon` (`@mipmap/ic_launcher`) y `default_notification_channel_id` (`docia_notifications`) en `AndroidManifest.xml` para que las notificaciones en segundo plano muestren el icono oficial de la app.
- Se integró el envío de push en la API para la revisión (aprobación/rechazo) de pagos.

## 2026-09-02 — Compatibilidad web de Firebase (`firebase_core_web`)

- Se fijó `firebase_core_web: 3.10.0` mediante `dependency_overrides` en `pubspec.yaml` para resolver la incompatibilidad de la versión `3.11.0` con la extensión `isA<JSObject>()` en el compilador web de Dart SDK.

## 2026-09-02 — Desugaring de librerías Java en Android (`flutter_local_notifications`)

- Se habilitó `isCoreLibraryDesugaringEnabled = true` en `android/app/build.gradle.kts`.
- Se agregó la dependencia `desugar_jdk_libs` (`com.android.tools:desugar_jdk_libs:2.1.4`) para dar soporte a APIs modernas de Java 8+ requeridas por el paquete `flutter_local_notifications`.
- Se activó `multiDexEnabled = true` en la configuración por defecto de Android.

## 2026-09-02 — Notificaciones push móviles

- La app registra el token Firebase del dispositivo al restaurar/iniciar sesión.
- Se agregó visualización local de notificaciones recibidas mientras la app está en primer plano.
- Se añadieron dependencias Firebase Messaging, Firebase Core y Local Notifications.
- Android solicita permiso `POST_NOTIFICATIONS` para versiones recientes del sistema.
- Android aplica el plugin de Google Services para leer `google-services.json`.

## 2026-09-02 — Motivo de rechazo visible para usuarios

- Las órdenes de pago incluyen el motivo de rechazo del último intento de pago.
- La tarjeta de orden del usuario muestra el motivo cuando el último comprobante fue rechazado.
- La API expone `latestPaymentRejectionReason` en el listado de órdenes.

## 2026-09-02 — Historial admin de comprobantes

- La sección administrativa de pagos separa comprobantes pendientes e historial revisado.
- Los comprobantes aprobados o rechazados permanecen visibles para consulta posterior.
- El rechazo valida el motivo dentro del modal y muestra un mensaje antes de permitir continuar.
- La API devuelve pagos QR/transferencia recientes, no sólo los pendientes, para alimentar el historial admin.

## 2026-09-02 — Corrección de controller en rechazo de pago

- El modal de rechazo de pagos deja de usar `TextEditingController` para evitar uso posterior a `dispose` durante el cierre.
- El motivo se captura por cambios del campo y permite confirmar con Enter cuando corresponde.

## 2026-09-02 — Modal compacto de rechazo de pago

- El rechazo administrativo de pagos usa un diálogo propio de altura intrínseca para evitar espacio blanco excesivo en móvil.
- Las acciones de cancelar y rechazar se mantienen alineadas dentro del modal compacto.

## 2026-09-02 — Ajuste visual de QR y rechazo admin

- El QR mostrado al usuario para pagos por paquete/servicio usa un tamaño adaptativo más grande en móvil.
- El modal administrativo de rechazo de pagos reduce ancho y altura del campo de motivo para evitar espacio vacío.

## 2026-09-02 — Revisión administrativa de pagos

- El modal de rechazo de pagos se compactó en móvil.
- La acción de aprobar/rechazar pagos muestra resultado o error mediante snackbar controlado.
- La API tipa explícitamente el estado en la query de revisión para evitar errores internos al aprobar o rechazar comprobantes.

## 2026-09-02 — Corrección de revisión de pagos QR

- El frontend distingue órdenes en validación por estado de orden o último pago asociado.
- La vista administrativa de comprobantes agranda la previsualización inicial de imágenes en móvil.
- La API corrige consultas relacionadas con compras de monedas para evitar columnas/alias inconsistentes al revisar pagos.

## 2026-09-02 — Validación manual y tamaño de comprobantes

- Las órdenes ocultan acciones de pago si la orden o su último pago están en validación manual.
- El estado visible de la orden prioriza `pending_validation` del último pago para evitar confundir pagos QR con tarjeta pendiente.
- La vista inicial de comprobantes en imagen usa más espacio disponible en móvil antes de abrir el zoom.

## 2026-09-02 — Estado de comprobantes QR en validación

- Las órdenes con comprobante QR enviado ya no muestran la acción de pago con tarjeta.
- La tarjeta de orden informa que el comprobante quedó pendiente de validación.
- El botón del modal de comprobante se simplificó de `Enviar comprobante` a `Enviar`.

## 2026-09-02 — Envío simplificado de comprobantes QR

- El modal de pago por QR ya no solicita referencia de transacción al usuario.
- Los nuevos comprobantes QR se envían sólo con el archivo adjunto y el monto de la orden.
- La visualización administrativa conserva referencias antiguas si existieran en pagos previos.

## 2026-09-02 — Detalle de empresas en administración

- La pestaña administrativa de Empresas permite abrir el detalle completo al tocar la tarjeta o el botón de detalle.
- El modal muestra datos generales, contacto, sedes, plan, suscripción y estado operativo con filas responsivas.
- La vista usa los datos ya entregados por el módulo de empresas sin requerir nuevos endpoints.

## 2026-09-02 — Gestión de QR general de pagos

- La pantalla administrativa de Pagos muestra y permite editar el QR general de cobro.
- El QR general muestra vista previa en la tarjeta administrativa y dentro del modal de edición.
- El texto visible aclara que ese QR aplica a servicios, citas y otros cobros manuales, mientras los paquetes de monedas conservan su QR individual.
- La configuración genérica mantiene ocultas esas claves para evitar editar el QR desde parámetros crudos.

## 2026-09-02 — Ocultamiento de QR general en configuración

- La configuración administrativa genérica deja de listar las claves de QR general de pagos.
- Se bloquea la creación manual de esas claves desde `Agregar parámetro` para evitar editar el QR desde parámetros crudos.
- La gestión visible del QR general queda concentrada en Pagos y la de monedas en cada paquete individual.

## 2026-09-02 — Detalle ampliado de imágenes firmadas

- El modal compartido de imágenes firmadas corrige la estructura del pie de acciones para renderizar correctamente el contenido.
- La vista ampliada solicita una URL firmada fresca al abrirse, evitando enlaces cacheados o vencidos.
- El ajuste aplica a QR de paquetes, QR de pagos y comprobantes que usen `AppSignedImage`.

## 2026-09-01 — Corrección integral de visualización de imágenes y URLs firmadas

- Se creó el widget unificado `AppSignedImage` y el modal interactivo `showImagePreviewDialog` con zoom (`InteractiveViewer`), soporte para imágenes locales y remotas firmadas, y descarga/apertura externa.
- Se configuró Fastify Helmet y las cabeceras de respuesta en la API (`Cross-Origin-Resource-Policy: cross-origin`, `Access-Control-Allow-Origin: *`) para permitir la carga correcta de imágenes y recursos cross-origin en navegadores y aplicaciones web/móviles.
- Se corrigió la resolución de endpoints firmados en `ApiFilesRepository` para alinear dinámicamente el host/puerto del cliente API activo y evitar fallos por discrepancias entre `localhost` y la IP configurada.
- Se flexibilizó `accessUrlForUser` en el backend para permitir la visualización de imágenes públicas (códigos QR de paquetes y pagos) y archivos recién subidos por el usuario sin requerir asociaciones previas restrictivas.
- Se integró `AppSignedImage` en las pantallas de Monedas (`CoinsScreen`) y Pagos (`PaymentsScreen`) para miniaturas y vistas ampliadas.

## 2026-09-01 — Previsualización de QR por paquete

- La edición de paquetes muestra la imagen QR apenas se selecciona desde el dispositivo.
- Los paquetes muestran la imagen QR guardada en administración y compra, usando el acceso firmado existente.
- El preview del QR se puede tocar para abrirlo ampliado con zoom y revisar el detalle.

## 2026-09-01 — Refresh automático de pagos y monedas

- Pagos refresca automáticamente órdenes, historial, cola de validación,
  configuración QR y saldo de monedas mientras la pantalla está abierta.
- Pagos también refresca al volver la app al foreground, cubriendo el retorno
  desde Stripe o selectores externos.
- Monedas refresca automáticamente saldo, paquetes y movimientos, incluyendo
  retorno al foreground.
- Los refrescos manuales posteriores a pagos QR, revisión y tarjeta reutilizan
  el mismo flujo para mantener sincronizados órdenes, pagos y contador.

## 2026-09-01 — Sincronización de pagos Stripe móvil

- Después de confirmar un pago con tarjeta en móvil, la app sincroniza el
  PaymentIntent con la API antes de refrescar órdenes, historial y monedas.
- La API expone una sincronización protegida de PaymentIntent para consultar a
  Stripe y acreditar monedas inmediatamente cuando el pago está `succeeded`.
- El flujo móvil deja de depender exclusivamente del webhook para cambiar la
  orden a pagada y acreditar el paquete de monedas.

## 2026-09-01 — Pago QR de monedas y gestión de paquetes

- Pagos consulta la configuración de QR antes de ofrecer pago manual por QR.
- Las órdenes sólo muestran `Pagar por QR` cuando existe un QR configurado en
  `payments.qr_image_url`.
- El flujo QR muestra el QR configurado para escanear y permite adjuntar el
  comprobante como imagen o PDF mediante selector de archivos.
- Se retiró la entrada manual de URL de comprobante en pagos QR de usuarios.
- El PaymentSheet de Stripe móvil prellena Bolivia como país de facturación,
  editable por el usuario.
- Stripe Checkout web se solicita en español desde la API.
- La gestión administrativa de paquetes de monedas permite baja lógica desde
  la app y conserva auditoría/historial.

## 2026-09-01 — Visualización y acceso completo a la información de dependientes

- Se agregaron pestañas/chips selectores en `ClinicalProfileScreen` para alternar entre "Mi ficha" y la ficha clínica completa de los dependientes a cargo.
- Se agregó la sección "Salud y Familia" en la pantalla de Cuenta (`AccountScreen`) con acceso directo a `Mi perfil clínico`, `Familiares y dependientes` y `Mis recetas médicas`.
- Se integró un botón de acción modal en `FamilyScreen` ("Ver información y ficha clínica") y un banner directo en la pantalla de inicio del paciente.
- Se filtró el historial de postulaciones de Recursos Humanos para que cada postulante solo consulte sus propias postulaciones.

## 2026-09-01 — Restauración de Servicios para pacientes/tutores y perfil clínico de tutor

- Se restauró la sección de `Servicios` (Monedas Doc IA, Servicios y tarifas, Beneficios, Pagos) en la pantalla de Cuenta de forma exclusiva para la experiencia de paciente y tutor, manteniéndola excluida de roles de operaciones, administración y profesionales.
- Se aseguró la creación y consulta automática del perfil clínico para tutores y pacientes en la API (`/clinical-records/profile`), evitando excepciones cuando un usuario autenticado consulta o actualiza su ficha clínica.
- Se incorporaron semillas de prueba con dependientes y consentimientos para el rol de tutor.

## 2026-09-01 — Optimización y nitidez del logotipo oficial

- Se generaron variantes de resolución `1.5x`, `2.0x` y `3.0x` con interpolación bicúbica de alta calidad para los logotipos oficiales de la aplicación.
- `AppLogo` decodifica la imagen calculando `cacheHeight` según el `devicePixelRatio` del dispositivo y aplica filtrado con mipmaps (`FilterQuality.medium`) para eliminar artefactos de pixelado y aliasing al reducir imágenes de alta resolución en web y móvil.

## 2026-09-01 — Unificación de navegación en menú lateral de operaciones

- Se ocultó el destino genérico `Operaciones` del menú lateral en web/escritorio para evitar duplicidad con el módulo de `Emergencias`, conservándolo en la barra inferior móvil.
- Las acciones laterales de Operaciones manejan directamente el estado activo de la pestaña seleccionada.

## 2026-09-01 — Limpieza de cuenta y corrección de acceso al perfil

- Se removió la sección redundante de `Servicios` de la pantalla de Cuenta para focalizar la vista en datos personales, privacidad, ayuda y apariencia.
- Se ajustó el controlador de personas en la API para permitir a cualquier usuario autenticado consultar y actualizar su propio perfil en `/people/me`, manteniendo `people.read` reservado para recursos globales.

## 2026-09-01 — Menú lateral y shell adaptativo para operaciones

- Se integró la experiencia de Operaciones con `AppShell` y navegación adaptativa con menú lateral para web/escritorio y barra inferior en móvil.
- Se crearon las rutas dedicadas de operaciones en `operations_routes.dart` con soporte de pestañas por query parameter (`?tab=...`) y sección de Cuenta.
- `OperationsScreen` detecta `usesSidebar` para mostrar el contenido limpio con `AppBar` en pantallas grandes y `TabBar` desplazable en móvil.
- Se habilitó la navegación hacia Mi Cuenta y subrutas de perfil para usuarios con experiencia de operaciones.
- Se actualizaron las políticas de acceso a rutas para reconocer las subrutas de cuenta bajo `/operations/profile`.

## 2026-09-01 — Panel operativo por rol

- Operaciones deja de mostrar una única vista para `operator` y arma pestañas
  según rol/permisos.
- El operador puede acceder desde su panel a Emergencias, Incidentes/Reclamos y
  Alertas cuando su sesión incluye esos permisos.
- El supervisor clínico conserva Correcciones clínicas además de los módulos
  operativos permitidos.
- Incidentes y Notificaciones pueden renderizarse embebidos dentro de un panel
  con pestañas sin duplicar AppBars.
- La política de rutas de `/operations` reconoce permisos de incidentes,
  notificaciones y gestión clínica, además de emergencias y entregas.

## 2026-09-01 — Agenda y disponibilidad independientes

- El sidebar vuelve a la raíz de una sección cuando se toca una opción
  principal estando dentro de una subpantalla de la misma rama.
- En la experiencia profesional, las acciones laterales como Disponibilidad,
  Perfil profesional, Ayuda, Privacidad e Incidentes se resaltan sin marcar
  también Agenda o Cuenta.
- Agenda deja de quedar visual y funcionalmente pegada a Disponibilidad.

## 2026-09-01 — Acciones de diálogo unificadas

- Se reemplazaron pares manuales de `Cancelar` y acción principal por
  `AppDialogActions` en diálogos de cuenta, citas, familiares, postulaciones,
  consentimientos, emergencias, pagos, validaciones clínicas y administración.
- Los diálogos pendientes usan anchos controlados para mantener botones
  alineados en web/tablet y consistentes en móvil.
- El único botón de cancelación especializado queda encapsulado en el
  componente compartido, evitando que nuevas pantallas repliquen estilos
  manuales.

## 2026-09-01 — Perfil profesional y tipo de médico

- El modal de edición del perfil profesional usa un ancho mayor para evitar
  que las acciones queden apiladas.
- Los modales de editar perfil y agregar documento profesional usan
  `AppDialogActions` para alinear `Cancelar` y `Guardar/Enviar`.
- El perfil profesional muestra el tipo de profesional derivado del rol de la
  cuenta, diferenciando médico general, especialista y enfermería.

## 2026-09-01 — Calendario mensual en agenda profesional

- La agenda profesional muestra un calendario del mes con navegación entre
  meses.
- Cada día indica visualmente cuántas citas tiene programadas.
- Al seleccionar un día se muestra debajo el detalle de las citas de esa fecha,
  manteniendo acciones para nota clínica y teleconsulta.

## 2026-09-01 — Accesos generales del profesional

- El menú profesional conserva accesos generales como Incidentes para reportar
  problemas desde cuentas profesionales.
- Las rutas profesionales de perfil, disponibilidad, privacidad, ayuda e
  incidentes quedan autorizadas por permisos específicos antes de caer en la
  regla general de `/doctor`.

## 2026-09-01 — Cuenta profesional y tarjetas de inicio

- Cuenta deja de duplicar accesos que ahora viven en el menú lateral de la
  experiencia profesional.
- El inicio profesional calcula columnas según el ancho real disponible dentro
  del contenido, evitando overflow cuando el sidebar reduce el espacio útil.
- Las tarjetas de métricas y acciones del inicio profesional usan proporciones
  más altas para resoluciones intermedias.
- La política de rutas reconoce perfil profesional, disponibilidad, privacidad,
  ayuda e incidentes bajo `/doctor/profile` y `/doctor/agenda`.

## 2026-09-01 — Menú profesional y disponibilidad

- El menú lateral de la experiencia profesional separa `Menú profesional` y
  `Menú general`.
- Se agregan accesos laterales a Perfil profesional y Disponibilidad para
  médicos generales/especialistas.
- Disponibilidad se abre dentro del shell profesional en web/tablet para
  mantener visible el menú lateral.
- Cuenta muestra Perfil profesional para usuarios con experiencia profesional,
  sin depender de permisos administrativos.
- Privacidad y consentimientos navega por la ruta interna de Cuenta para no
  abrir una vista fuera del perfil activo.
- El mapper de disponibilidad acepta `weekday` numérico o string.
- Los diálogos de disponibilidad usan acciones alineadas de cancelar/guardar.

## 2026-08-31 — Ajustes de experiencia RRHH

- El shell permite que un destino visible apunte a una rama interna específica,
  evitando desfasar navegación cuando un rol oculta accesos.
- Recursos Humanos deja de mostrar `Panel` y conserva accesos directos a sus
  apartados de gestión.
- Las tarjetas de profesionales en Gestión abren un detalle al tocarlas para
  administración y Recursos Humanos.
- Cuenta oculta para Recursos Humanos la sección de Servicios y deja en General
  sólo el acceso a Ayuda, preguntas y demo.

## 2026-08-31 — Ajustes admin de modales y filtros

- Incidentes y reclamos usa diálogo centrado con scroll interno y acción
  `Cancelar` junto a `Registrar solicitud`.
- Gestión de servicios y tarifas excluye servicios y tarifas de categoría
  `coin_package`, dejando los paquetes sólo en Monedas Doc IA.
- El formulario de paquetes de monedas limita alto y usa scroll interno para
  evitar overflow al editar.
- Auditoría agrega filtros locales por texto, módulo, acción y rango de fechas.
- Los filtros de Auditoría se distribuyen en máximo dos filas en layouts
  amplios y vuelven a wrap flexible en anchos menores.
- El buscador de Auditoría usa etiqueta interna para alinearse visualmente con
  los selectores de módulo y acción.
- Los eventos de Auditoría dejan de usar `ListTile` para evitar overflow con
  textos largos y fecha lateral.
- Auditoría pagina los resultados filtrados de a 25 eventos por página.
- Configuración del sistema agranda el diálogo de parámetros y alinea
  `Cancelar`/`Guardar` con las acciones compartidas.

## 2026-08-31 — Catálogo tolera montos de API

- El mapper de catálogo acepta precios y montos en monedas tanto numéricos
  como string, evitando errores cuando PostgreSQL devuelve `numeric` como texto.
- El mapper de monedas aplica la misma tolerancia para balances, movimientos y
  precios de paquetes.
- La vista administrativa de servicios y tarifas reemplaza `ListTile` con
  trailing complejo por filas controladas para evitar overflow/layout roto.
- La vista administrativa de paquetes de monedas usa el mismo patrón de filas
  controladas para que el botón de edición no rompa el layout.

## 2026-08-31 — Cuenta y validación QR

- Las opciones de Cuenta para servicios, monedas y pagos navegan siempre a la
  ruta interna del shell según la experiencia activa, evitando fallos por
  nombres globales inexistentes.
- El diálogo móvil de cerrar sesión en Cuenta usa acciones alineadas.
- La vista administrativa de Pagos filtra la cola para mostrar sólo
  comprobantes manuales QR o transferencia, excluyendo pagos con tarjeta.
- Cada comprobante manual puede abrirse en un visor amplio: las imágenes se
  muestran con zoom y los PDF/enlaces se abren desde una acción dedicada.

## 2026-08-31 — Acciones alineadas en roles

- El diálogo de edición de roles de usuario en administración usa las acciones
  compartidas para mantener `Cancelar` y `Guardar` alineados.

## 2026-08-31 — Gestión admin consistente por layout

- El shell expone si la experiencia activa usa sidebar o navegación inferior.
- Gestión administrativa usa esa señal para mostrar menú lateral en
  web/tablet y pestañas sólo cuando el shell está en modo móvil.
- Se evita que aparezcan al mismo tiempo el menú lateral y las pestañas estilo
  móvil dentro de Gestión.

## 2026-08-31 — Sidebar admin sin overflow

- El destino principal `Gestión` puede ocultarse del sidebar web cuando sus
  apartados ya están desplegados como acciones laterales.
- El sidebar permite desplazamiento interno en la zona de navegación para
  evitar overflow cuando un rol tiene muchas opciones.
- El cierre de sesión permanece fijo en la parte inferior del menú lateral.

## 2026-08-31 — Login y registro web

- El cambio de tema desde login toma como referencia el brillo visible actual,
  evitando que el primer tap no produzca cambio cuando el modo estaba en
  `system`.
- `AppLogo` dejó de forzar dimensiones de caché para evitar decodificación
  borrosa del PNG en Flutter Web.
- El registro usa layout dividido en desktop: panel de marca a la izquierda y
  formulario contenido a la derecha, manteniendo el flujo móvil anterior.
- En desktop, el logo del registro se muestra sólo en el panel de marca para
  conservar la misma estructura visual del login.
- El retorno desde registro al login se muestra como texto contextual
  `¿Ya tienes cuenta? Inicia sesión` debajo de la acción principal del primer
  paso de registro.
- Recuperar contraseña adopta el mismo layout web que login/registro: panel de
  marca a la izquierda y formulario contenido a la derecha.
- El enlace de recuperación para volver al login se muestra debajo de la acción
  principal como `¿Ya tienes cuenta? Inicia sesión`.

## 2026-08-31 — Navegación y cuenta administrativa

- El diálogo de cerrar sesión usa las acciones compartidas para mostrar
  `Cancelar` y `Salir` alineados en una sola fila.
- En web/tablet, los apartados internos de Gestión administrativa se muestran
  como accesos del menú lateral; las pestañas se conservan para móvil.
- La pantalla de Gestión muestra directamente el apartado seleccionado desde
  el menú lateral en layouts amplios.
- Cuenta oculta para administradores las opciones de perfil profesional,
  beneficios y privacidad/consentimientos, que corresponden a otros flujos.
- Postulaciones separa pendientes/en revisión del historial de decisiones y
  muestra también postulaciones aprobadas o rechazadas con su motivo.
- `Servicios y tarifas` muestra una vista de gestión para cuentas con
  `catalog.manage`, con creación/edición de servicios y alta de tarifas.
- `Monedas Doc IA` muestra una vista de gestión para cuentas con
  `coins.manage`, sin compra de paquetes desde cuentas administrativas.
- `Pagos` muestra para cuentas con `payments.manage` una cola de comprobantes
  QR pendientes de validación con acciones de aprobar o rechazar.

## 2026-08-31 — Notificaciones dentro del shell paciente

- El acceso a notificaciones desde el inicio paciente navega a
  `/patient/notifications` para conservar el sidebar visible en web/tablet.
- La pantalla de notificaciones limita el ancho del contenido en layouts
  amplios usando el layout adaptativo compartido.
- La política de rutas reconoce la ruta interna de notificaciones del paciente
  con el mismo permiso `notifications.read`.

## 2026-08-31 — Retorno visible en agendamiento

- `Directorio médico` vuelve a mostrar la flecha de retorno cuando se abre
  desde Inicio o desde Citas para agendar una consulta.
- La navegación web mantiene el sidebar visible, pero conserva el retorno
  contextual del flujo de agendamiento.

## 2026-08-31 — Acciones de diálogo consistentes

- Se agregó `AppDialogActions` como componente compartido para acciones
  `Cancelar`/`Guardar` o `Cancelar`/`Confirmar`.
- Los formularios de perfil clínico, signos vitales, documentos clínicos,
  familiares y agendamiento usan el nuevo componente para mantener ambos
  botones alineados en una misma línea.

## 2026-08-31 — Ajustes de navegación clínica y catálogo

- `Emergencia médica` y `Directorio médico` quedan como ramas internas del
  shell paciente para conservar el sidebar visible en web/tablet.
- `Signos vitales`, `Documentos clínicos`, `Servicios y tarifas` y `Monedas
  Doc IA` conservan flecha de retorno porque se abren como pantallas internas.
- `Perfil clínico` dejó de duplicar la tarjeta de datos personales y domicilio;
  esa información queda concentrada en Cuenta.
- El logo reutilizable de Doc IA calcula ancho y alto de caché según la
  proporción real del PNG y el sidebar lo muestra a mayor tamaño.

## 2026-08-30 — Signos, documentos y servicios dentro del shell

- `Signos vitales` y `Documentos clínicos` dejaron de abrirse sobre el
  navegador raíz para conservar visible el sidebar en web/tablet.
- Ambas pantallas ocultan la flecha de retorno sólo en layout amplio, mantienen
  contenido centrado y usan formularios como diálogos centrados.
- Los formularios de signos vitales y documentos clínicos agregan acción
  `Cancelar` junto a la acción principal con tamaño consistente.
- `Servicios y tarifas` y `Monedas Doc IA` agregaron layout contenido con ancho
  máximo en web/tablet.
- Las rutas internas de Cuenta para `catalog` y `coins` quedaron mapeadas bajo
  `/patient/profile` y autorizadas por el policy de permisos.
- Al crear una orden desde `Monedas Doc IA`, la navegación a pagos en web se
  mantiene bajo la misma rama de Cuenta.

## 2026-08-30 — Pulido de modales, logos y rutas de cuenta

- `AppLogo` ahora renderiza los PNG oficiales con filtrado de alta calidad y
  antialiasing para reducir pixelado en web al escalar el recurso.
- El splash inicial dejó de animar/mostrar loader interno para evitar la
  sensación de splash doble antes de entrar al login o a la sesión restaurada.
- Las opciones de Cuenta del paciente que antes salían a rutas globales ahora
  pueden abrirse dentro del shell en web para conservar visible el menú
  izquierdo.
- El directorio médico y el flujo de agendar cita permanecen dentro del shell
  paciente en web/tablet.
- El agendamiento se muestra como diálogo centrado con ancho máximo, selector
  de horario tipo reloj y botones `Cancelar`/`Confirmar cita` consistentes.
- La edición de ficha clínica se muestra como diálogo centrado y agrega acción
  `Cancelar` junto a `Guardar ficha`.
- Los formularios de `Familiares` para vincular dependiente y autorizar familiar
  se muestran como diálogos centrados y agregan acción `Cancelar` junto a la
  acción principal.

## 2026-08-30 — Agendamiento contenido en web

- `Directorio médico` dejó de abrirse sobre el navegador raíz para conservar el
  sidebar visible en web/tablet durante el flujo de agendar cita.
- La pantalla de directorio oculta la flecha de retorno sólo en layout amplio,
  manteniendo la navegación móvil como estaba.
- El formulario de agendamiento usa ancho máximo en web y agrega acciones
  `Cancelar`/`Confirmar cita` alineadas al mismo nivel.
- En móvil, las acciones del agendamiento quedan como botones de ancho completo
  y altura consistente para evitar tamaños disparejos.

## 2026-08-30 — Accesos secundarios como ramas independientes

- `Perfil clínico`, `Familiares` y `Recetas` pasaron a ramas independientes
  del shell paciente para evitar que contaminen el historial de `Inicio`.
- El sidebar web navega a esas ramas secundarias sin limpiar stacks ni forzar
  reconstrucciones visibles.
- La barra inferior móvil mantiene las cuatro opciones principales y, si una
  rama secundaria está activa, conserva `Inicio` como sección visual base.
- El campo contraseña del login ejecuta el acceso al presionar Enter tras
  completar las credenciales.

## 2026-08-30 — Retorno suave al inicio paciente en sidebar web

- El shell puede recibir navigator keys de ramas para limpiar subrutas sin
  forzar una reconstrucción completa.
- La rama de inicio paciente ahora vuelve a su pantalla raíz con `popUntil`
  cuando se selecciona `Inicio` desde el sidebar después de visitar accesos
  secundarios.
- Se elimina el refresh visual producido por reiniciar la rama con
  `initialLocation`.

## 2026-08-30 — Sidebar navega sin refresh forzado

- El sidebar web/tablet usa la ruta raíz explícita de cada destino principal en
  lugar de reiniciar siempre la rama completa.
- Al volver de una pantalla secundaria a `Inicio`, `Citas`, `Asistente` o
  `Cuenta`, se corrige el estado pegado sin producir el refresh visual forzado.
- La navegación inferior móvil conserva el comportamiento previo.

## 2026-08-30 — Navegación principal reinicia su sección

- Las opciones principales del shell (`Inicio`, `Citas`, `Asistente`,
  `Cuenta`, y equivalentes por rol) ahora vuelven siempre a la pantalla raíz de
  su sección al seleccionarse.
- Esto evita que una subpantalla secundaria como `Familiares`, `Perfil clínico`
  o `Recetas` quede pegada al volver a `Inicio` desde otra sección.

## 2026-08-30 — Selección independiente de accesos secundarios

- El sidebar web separa el destino principal activo de las acciones
  secundarias activas.
- Al entrar en `Perfil clínico`, `Familiares` o `Recetas`, deja de quedar
  resaltado `Inicio` y se marca únicamente la opción secundaria correspondiente.

## 2026-08-30 — Estado activo en accesos secundarios del sidebar

- Las acciones secundarias del sidebar web pueden marcarse como seleccionadas.
- En paciente, `Perfil clínico`, `Familiares` y `Recetas` ahora resaltan con el
  mismo tratamiento visual que las cuatro opciones principales cuando la ruta
  activa corresponde a cada sección.

## 2026-08-30 — Ajustes de navegación secundaria en web

- `Perfil clínico`, `Familiares` y `Recetas` ocultan la flecha de retorno sólo
  en tablet/web, ya que el sidebar izquierdo permanece visible.
- En móvil esas pantallas conservan el comportamiento previo con navegación de
  retorno en el AppBar.
- El recuadro de `Cerrar sesión` del sidebar cambió a un tratamiento azul de
  marca con texto blanco para reducir la carga visual roja.

## 2026-08-30 — Rutas paciente dentro del shell web

- `Perfil clínico`, `Familiares` y `Recetas` dejaron de abrirse sobre el
  navegador raíz para que en web conserven siempre el menú lateral izquierdo.
- Los accesos del sidebar paciente ahora navegan dentro de la experiencia
  principal en lugar de ocultar la navegación global.

## 2026-08-30 — Ajustes visuales de sidebar y login

- El botón `Cerrar sesión` del sidebar web ahora queda dentro de un recuadro
  diferenciado para separarlo visualmente de la navegación principal.
- El recuadro informativo inferior del login web dejó de mostrar iconos/avatar
  y mantiene sólo el texto de confianza.

## 2026-08-30 — Cierre de sesión fijo en sidebar web

- El menú lateral web muestra `Cerrar sesión` fijo en la parte inferior para
  todos los roles que usan el shell principal.
- La sección Cuenta mantiene el control de apariencia como ajuste propio de la
  pantalla.
- El botón inline de `Cerrar sesión` en Cuenta se conserva sólo en móvil, donde
  no existe el sidebar lateral.

## 2026-08-30 — Sidebar siempre visible en web

- El shell dejó de usar el rail lateral compacto en tamaños tablet/web.
- Desde pantallas no compactas se muestra siempre el menú izquierdo completo
  con logo, etiquetas y acciones secundarias visibles.
- La navegación inferior se mantiene exclusivamente para pantallas compactas.

## 2026-08-30 — Sidebar web con marca y accesos del paciente

- El shell de navegación lateral ahora muestra el logo de Doc IA en la parte
  superior cuando la app usa rail/sidebar en tablet o web.
- El shell puede recibir acciones secundarias para mostrarlas en el sidebar
  extendido de desktop sin depender de menús flotantes.
- En la experiencia paciente, los accesos de los tres puntos del inicio
  (`Perfil clínico`, `Familiares` y `Recetas`) se movieron al lateral izquierdo
  en web.
- El botón de tres puntos del header paciente se conserva en móvil y se oculta
  en desktop para evitar duplicar opciones.

## 2026-08-30 — Layouts adaptativos en vistas principales

- Se agregó una base reutilizable de layout adaptativo para limitar el ancho de
  contenido en web/tablet y mantener flujo móvil en pantallas pequeñas.
- La pantalla de inicio del paciente ahora reorganiza acciones y próxima cita
  en dos columnas desde desktop, evitando que la vista móvil quede estirada.
- Cuenta, citas, directorio médico, agenda médica, pacientes del médico y
  gestión administrativa usan anchos máximos consistentes para web.
- La ficha clínica del paciente se reorganizó en dos columnas desde desktop:
  datos clínicos principales a la izquierda e información complementaria a la
  derecha.
- Los dashboards médico y administrativo centran su contenido en un contenedor
  amplio y usan grillas para tarjetas/acciones en pantallas grandes.

## 2026-08-30 — Login responsive y base oscura de marca

- El login ahora usa una composición adaptativa: en móvil mantiene el flujo
  vertical existente y desde desktop divide la pantalla entre panel de marca y
  formulario contenido.
- Se incorporó un panel visual de Doc IA con logotipo blanco, mensaje de valor,
  patrón sutil y tarjeta de confianza para evitar que la versión web se vea
  como una pantalla móvil estirada.
- El formulario de login se extrajo en componentes internos reutilizables para
  conservar los mismos campos, validaciones, errores, recuperación de
  contraseña y acceso a registro.
- Se ajustó la paleta oscura global hacia tonos azul petróleo de la marca,
  reemplazando la base gris/azulada anterior que desentonaba con Doc IA.

## 2026-08-30 — Limpieza de restos visibles de Jampic

- Se actualizó el script de generación de APK para emitir artefactos con el
  patrón `DocIA_V<version>.apk`.
- Se actualizó el README de APP-MVP para documentar el nuevo nombre del
  artefacto de distribución.
- Se corrigió el texto de prueba de splash para referirse a Doc IA.
- El widget raíz técnico se renombró de `JampicApp` a `DocIaApp`.
- Se mantuvieron sin cambios los identificadores técnicos del paquete,
  imports, storage y rutas internas que todavía dependen del nombre técnico
  histórico.

## 2026-08-30 — Mapeo de roles y vistas por experiencia

- Se mapearon en frontend los roles backend que quedaban sin experiencia:
  `guardian`, `human_resources`, `health_partner` y `delivery_assistant`.
- `guardian` usa la experiencia de paciente; `human_resources` y
  `health_partner` usan administración; `delivery_assistant` usa operaciones.
- La protección de rutas ahora permite validar acceso por cualquiera de los
  permisos compatibles con la experiencia, no sólo por el permiso
  administrativo global.
- La gestión administrativa arma sus pestañas según permisos para que RRHH y
  aliados no vean módulos fuera de su alcance.
- Las cuentas administrativas no globales aterrizan directamente en gestión en
  lugar de intentar cargar el panel general de administración.
- Se agregó una bandeja operativa mínima de entregas conectada al endpoint
  `deliveries/deliveries` para el rol `delivery_assistant`.
- Se documentó en `README.md` el catálogo de roles contemplados, su experiencia
  frontend, alcance funcional esperado y brechas conocidas.

## 2026-08-22 — Stripe, compra de monedas y retorno de pago

- La pantalla de pagos permite pagar órdenes fiat con tarjeta cuando existe
  `STRIPE_PUBLISHABLE_KEY` configurada en la app.
- En Android e iOS se usa Stripe PaymentSheet mediante `flutter_stripe`.
- En Web se usa Stripe Checkout: la app solicita una sesión de checkout a la
  API y abre la URL de Stripe en la misma ventana.
- Se agregó la ruta `/payments/return` para recibir el retorno de Stripe,
  mostrar el resultado del pago, sincronizar la sesión de checkout con la API
  cuando llega `session_id`, refrescar pagos y monedas, y redirigir a
  `Monedas Doc IA` si el pago fue exitoso.
- La pantalla de pagos también interpreta retornos de Stripe que lleguen a
  `/payments` con parámetros de resultado, y la navegación final usa la ruta
  absoluta `/patient/coins` para evitar volver a la pestaña de cuenta.
- Se incorporaron los modelos y métodos de repositorio para `StripePaymentIntent`,
  `StripeCheckoutSession`, creación de sesiones de checkout y sincronización de
  sesiones finalizadas.
- La compra de paquetes de monedas desde `Monedas Doc IA` crea una orden de
  pago y lleva al usuario al módulo de pagos para completar el cobro con
  tarjeta.
- Se agregaron `flutter_stripe`, `flutter_stripe_web`, el script web de Stripe
  en `web/index.html`, la inicialización de Stripe en el bootstrap y la variable
  `STRIPE_PUBLISHABLE_KEY` en los archivos de configuración por entorno.
- El flujo requiere que la API tenga configurada la URL de retorno hacia
  `/payments/return` y que procese los endpoints de Stripe para PaymentIntent,
  Checkout y sincronización.

## 2026-08-13 — Ícono de aplicación redondeado

- El ícono de Android utiliza una placa blanca con esquinas redondeadas y
  exterior transparente para integrarse mejor con los lanzadores que muestran
  el recurso sin aplicar una máscara propia.
- Se aumentó el margen de seguridad alrededor del isotipo para evitar recortes;
  las variantes de iOS y PWA maskable mantienen el fondo opaco requerido por
  sus respectivas plataformas.

## 2026-08-13 — Primera fase de rebranding Doc IA

- La identidad visible de la aplicación cambió de Doc IA a Doc IA en la
  interfaz y en los nombres mostrados por Android, iOS y Web, sin modificar
  identificadores técnicos, almacenamiento, paquetes ni infraestructura.
- La paleta central adoptó el azul oficial `#009FE3` y el rojo oficial
  `#E30613`; se mantuvieron tonos funcionales derivados para contraste,
  estados, fondos y jerarquía visual.
- El componente compartido de logotipo utiliza los assets oficiales positivo
  y blanco según el fondo, preservando su proporción y sin efectos externos.
- Se generó el ícono de Doc IA desde el corazón y el símbolo IA del logotipo
  oficial, junto con sus tamaños para Android, iOS, favicon y PWA. El proceso
  reproducible quedó en `tool/generate_brand_icons.ps1`.
- Made Tommy queda pendiente de incorporación porque no existen archivos de
  fuente licenciados en los assets; se conserva temporalmente Plus Jakarta
  Sans como alternativa global.

## 2026-08-11 — Aceptación explícita durante el registro

- Términos y privacidad comienzan sin aceptar en el formulario de creación de
  cuenta y el botón de registro permanece deshabilitado hasta que la persona
  marque la casilla.
- El valor aceptado por la persona se envía explícitamente a la API en lugar de
  asumirlo desde la aplicación.

## 2026-08-11 — Botones de cancelación consistentes

- Se incorporó un botón secundario reutilizable para las acciones de
  cancelación en diálogos, con borde, área táctil y espaciado visibles.
- Se reemplazaron las acciones de cancelación que parecían enlaces de texto,
  incluido el diálogo de cierre de sesión, sin modificar los enlaces de
  navegación de la aplicación.

## 2026-08-06 — Sesión, permisos y diseño adaptable

- Los proveedores autenticados ahora dependen de la identidad activa y
  descartan los datos almacenados cuando se cierra sesión o cambia la cuenta.
- El asistente valida permiso y consentimiento antes de habilitar sugerencias,
  escritura o envío, y se corrigió el margen de su encabezado.
- Términos y privacidad se muestran como obligatorios y no permiten retirar su
  aceptación.
- Las métricas y tarjetas administrativas distribuyen su contenido con alturas
  y saltos seguros para celular, tableta y web.

## 2026-08-03 — Correcciones de integración de los módulos finales

- Se corrigieron cierres de diálogos y pantallas que impedían compilar los
  flujos de calificación, derivación, perfil profesional y administración.
- Se corrigió la evaluación de roles en las solicitudes de corrección clínica.
- Se eliminó una referencia de sala inexistente durante la creación de una
  videconsulta y se ajustó la actualización de sus datos.

## 2026-08-03 — Archivos privados y consola administrativa

- Los documentos clínicos y profesionales permiten seleccionar y subir
  archivos reales en web, Android y demás plataformas compatibles.
- Se agregó un módulo de archivos reutilizable que envía multipart a la API y
  conserva únicamente la referencia devuelta por el servidor.
- La apertura de archivos privados utiliza enlaces firmados de cinco minutos;
  la ruta física y el secreto de firma no se exponen en APP-MVP.
- Administración incorpora gestión de estados de usuario y asignación de
  múltiples roles vigentes.
- Se agregó una pestaña de configuración para consultar y editar parámetros
  JSON persistidos en `system_settings`.
- Los formularios administrativos reutilizan tarjetas, estados, campos y
  tokens visuales compartidos.

## 2026-08-03 — Historial de IA y actividad de telemedicina

- El asistente recupera conversaciones y mensajes persistidos desde la API,
  permite continuar una conversación activa, iniciar otra o archivar la
  anterior.
- Los mensajes, modelo utilizado, banderas de seguridad y evaluaciones de
  riesgo permanecen en las tablas existentes de IA.
- Las salas de telemedicina muestran participantes conectados y documentos
  clínicos compartidos durante la atención.
- Se conectaron el registro de ingreso, salida, fallos de conexión y eventos
  de archivo compartido.
- La visualización de actividad y archivos está limitada mediante RLS a los
  usuarios relacionados con la sala.

## 2026-08-03 — Perfil profesional y continuidad de atención

- El profesional dispone de una ficha laboral separada de la cuenta personal
  para editar matrícula, experiencia, biografía y visibilidad pública.
- La ficha muestra especialidades, estado de validación y documentos
  profesionales persistidos, con observaciones de revisión.
- Los documentos nuevos se cargan mediante el almacenamiento privado de la API
  y conservan su estado pendiente de revisión.
- El profesional puede emitir derivaciones desde el expediente del paciente
  cuando existe una relación clínica válida.
- El paciente puede consultar seguimientos y derivaciones desde sus citas y
  calificar una consulta completada una sola vez.
- Las calificaciones actualizan el promedio y cantidad del profesional y los
  nuevos registros respetan las policies RLS correspondientes.

## 2026-08-03 — Emisión de recetas y disponibilidad profesional

- Los profesionales pueden emitir un borrador de receta, definir su
  vencimiento y solicitar a la API su firma de integridad antes de notificar
  al paciente.
- Las recetas emitidas muestran su estado firmado y ya no notifican al
  paciente mientras permanecen como borrador.
- La agenda profesional incorpora configuración de horarios semanales por
  modalidad y bloqueos excepcionales con información persistida en la API.
- La interfaz permite retirar horarios y bloqueos, y vuelve a consultar la
  agenda después de cada modificación.
- Los formularios y tarjetas reutilizan colores, espaciados y componentes
  compartidos del proyecto.

## 2026-08-03 — Gestión familiar y cierre de consulta

- Las autorizaciones familiares permiten modificar parentesco y permisos, o
  revocar completamente el acceso desde la misma tarjeta reutilizable.
- La cuenta paciente puede generar un código de tutor de uso único con quince
  minutos de vigencia; el adulto puede canjearlo con el parentesco para
  vincular al dependiente con permisos de gestión y alertas.
- La interfaz permite copiar el código, canjearlo y actualizar inmediatamente
  la lista familiar sin almacenar el código en la aplicación.
- La nota clínica profesional mantiene el guardado de borrador SOAP y agrega
  un cierre formal con diagnóstico, tipo, tratamiento, indicaciones y
  seguimiento opcional.
- Al finalizar, la cita pasa a completada y el expediente del paciente recibe
  el registro clínico consolidado.
- El cierre genera una notificación interna para el paciente y actualiza la
  lista profesional de pacientes.

## 2026-08-03 — Solicitudes de corrección clínica

- El paciente puede solicitar una corrección desde el detalle de un registro
  de su historial, indicando la información propuesta y el motivo.
- El historial incorpora acceso al seguimiento de solicitudes pendientes,
  aceptadas y rechazadas con su resolución.
- Administración cuenta con una pestaña de correcciones clínicas y supervisión
  clínica comparte la misma bandeja junto con emergencias.
- Al aceptar una solicitud, la interfaz actualiza el historial sin permitir que
  el paciente edite directamente registros emitidos por profesionales.
- La bandeja y sus tarjetas se reutilizan entre administración, supervisión y
  paciente según los permisos del rol.
- El paciente recibe una notificación interna cuando la solicitud es aceptada
  o rechazada.

## 2026-08-03 — Expediente profesional y validación clínica

- “Mis pacientes” abre un expediente real con resumen, cobertura, contacto de
  emergencia, información clínica, signos vitales y documentos autorizados.
- El profesional puede validar u observar alergias, antecedentes y documentos
  no restringidos, registrando una nota cuando corresponde.
- La nota clínica continúa disponible únicamente cuando existe una cita apta
  para documentar la atención.
- Paciente y profesional reutilizan las mismas tarjetas de signos vitales y
  documentos para mantener consistente el diseño.
- Las nuevas alergias y antecedentes declarados por pacientes se presentan
  como información autodeclarada hasta su validación profesional.

## 2026-08-03 — Signos vitales y documentos clínicos

- La ficha clínica incorpora accesos reutilizables al historial de signos
  vitales y a los documentos del paciente.
- El paciente puede registrar presión arterial, frecuencia cardíaca,
  temperatura, saturación, glucosa, peso y estatura; los últimos valores de
  peso y estatura también actualizan el resumen clínico existente.
- Los documentos muestran tipo, nombre, fecha, restricción y estado de
  validación, y pueden abrirse mediante su enlace externo.
- En esta etapa los archivos se registran mediante enlaces privados o
  compartidos y quedan pendientes de validación. La carga binaria se conectará
  cuando se defina el proveedor de almacenamiento, sin cambiar el contrato de
  presentación.

## 2026-08-03 — Ficha integral del paciente

- El perfil clínico permite actualizar tipo de sangre, estatura, peso,
  cobertura y número de afiliación desde una única ficha.
- Se incorporó la edición por listas reutilizables de alergias, condiciones
  crónicas, medicación y antecedentes médicos, familiares y quirúrgicos.
- La ficha permite registrar el contacto de emergencia principal y
  observaciones relevantes para la atención.
- Los datos se leen nuevamente desde la API después de cada actualización y se
  reflejan también en el resumen de salud del inicio del paciente.
- Los datos personales, teléfono y domicilio permanecen en el componente común
  de cuenta y son accesibles desde la ficha clínica para evitar duplicación;
  su resumen ahora incluye documento, fecha de nacimiento, nacionalidad,
  municipio y zona.

## 2026-08-03 — Operación y seguimiento de emergencias

- Administración dispone de una bandeja priorizada de emergencias activas con
  paciente, riesgo, estado, ubicación y equipo asignado.
- El detalle permite llamar al paciente, visualizar el mapa, asignar
  profesionales u operadores y avanzar únicamente por estados válidos.
- Los cambios operativos actualizan la interfaz del paciente mediante los
  estados persistidos y generan una notificación interna.
- Los roles `operator` y `clinical_supervisor` cuentan con una experiencia
  operativa acotada a emergencias, sin acceso a las demás áreas administrativas.
- La información de contacto se obtiene mediante funciones seguras de la API y
  no se almacena como configuración en Flutter.

## 2026-08-03 — Detalle y gestión de citas del paciente

- Las tarjetas de citas abren una pantalla de detalle con profesional,
  especialidad, fecha, horario, modalidad, motivo y estado real.
- Las citas futuras permiten cancelación con motivo opcional y reprogramación
  dentro de la disponibilidad publicada por el profesional.
- Las acciones desaparecen para citas iniciadas, completadas, canceladas o
  marcadas como inasistencia.
- Una cita de telemedicina permite ingresar a Google Meet cuando su sala ya fue
  preparada por el profesional.
- Las citas canceladas o finalizadas se clasifican en historial aunque su fecha
  original todavía sea futura.

## 2026-08-03 — Google Workspace y telemedicina profesional

- Administración dispone de una pestaña para consultar, conectar, reautorizar
  o desconectar la cuenta institucional utilizada por Google Meet.
- El estado muestra quién realizó la autorización sin exponer tokens ni
  credenciales en APP-MVP.
- La experiencia de telemedicina distingue al profesional del paciente.
- Los profesionales pueden crear salas para sus citas de telemedicina
  pendientes y luego ingresar mediante el enlace generado por la API.
- La creación de salas queda deshabilitada mientras Workspace no esté
  conectado.

## 2026-07-28 — Retiro definitivo de datos demo

- Se eliminó la carpeta `lib/demo` porque sus datos clínicos, citas,
  profesionales, recetas, notas y respuestas simuladas ya no tenían
  consumidores.
- `EmergencyLevel`, la única definición todavía utilizada, se trasladó al
  dominio del módulo de emergencias.
- Los textos y colores del nivel de emergencia permanecen en presentación
  para mantener el dominio independiente de Flutter.

## 2026-07-28 — Acciones comunes y seguimiento de emergencias

- La campana del inicio del paciente abre las notificaciones y muestra la
  cantidad pendiente obtenida desde la API.
- Una emergencia activa se restaura al volver a abrir la pantalla y actualiza
  su estado, equipo asignado y ubicación periódicamente.
- La línea de tiempo de emergencia refleja el estado persistido y el botón de
  llamada solo aparece cuando la API entrega un teléfono del equipo asignado.
- La cuenta permite actualizar nombres, teléfono y dirección reutilizando los
  campos y botones compartidos del sistema de diseño.
- El correo y el documento permanecen sin edición directa porque requieren
  validación específica.

## 2026-07-28 — Enlaces de recuperación enviados por la API

- La ruta pública de recuperación acepta el token incluido por la API en el
  parámetro `?token=...`.
- Al abrir el enlace recibido por correo, la pantalla completa el token y
  muestra directamente el formulario para crear la nueva contraseña.
- APP-MVP permanece independiente de Resend y no almacena su API key; todo el
  envío de correo se realiza desde la API.

## 2026-07-28 — Notificaciones automáticas y recuperación de contraseña

- Las citas, recetas, emergencias e incidentes generan notificaciones internas
  al completar acciones importantes.
- La creación respeta las preferencias `in_app` del destinatario y utiliza el
  repositorio central de notificaciones.
- Se agregó la categoría de incidentes y reclamos a las preferencias.
- El botón de recuperación del login ahora abre un flujo público completo.
- La solicitud de recuperación no revela si un correo está registrado.
- Los tokens permanecen únicamente en la API, vencen después de 30 minutos y
  se invalidan al utilizarse.
- Al cambiar la contraseña se revocan las sesiones anteriores del usuario.
- En desarrollo local la API devuelve el token para completar el flujo sin un
  proveedor de correo; este comportamiento queda deshabilitado en producción.

## 2026-07-27 — Consolidación de SQL de la API

- La estructura reproducible de la base se redujo a los archivos `01` a `08`.
- Las tablas OAuth se integraron en `01_database.sql`.
- El helper de autorización clínica se integró en `02_functions.sql`.
- Todas las policies y habilitaciones RLS se consolidaron en
  `04_policies.sql`.
- Los permisos del paciente para incidentes se sincronizaron en los seeds de
  roles y permisos.
- La disponibilidad de profesionales locales se integró en
  `07_local_test_users.sql`.
- Se retiraron los SQL incrementales `09` a `30`.

## 2026-07-27 — Beneficios, pagos y órdenes de pago

- Se creó `modules/benefits` con capas de dominio, aplicación, infraestructura
  API y presentación.
- La cuenta permite consultar beneficios vigentes, disponibilidad personal,
  límites, aliados participantes e historial de descuentos utilizados.
- Se creó `modules/payments` con la misma separación por capas.
- La pantalla de pagos diferencia órdenes e historial y muestra importes en
  bolivianos o monedas Doc IA, vencimientos, métodos y estados reales.
- Se agregaron rutas compartidas protegidas por `benefits.read` y
  `payments.read`.
- Se conservaron las tablas existentes y se añadieron políticas RLS para
  limitar usos, órdenes y transacciones al usuario autorizado.
- Los cobros permanecen en modo consulta hasta conectar una pasarela o un
  mecanismo verificable de validación; no se generan aprobaciones simuladas.

## 2026-07-27 — Notificaciones e incidentes

- Se creó `modules/notifications` con dominio, aplicación, infraestructura API
  y presentación.
- La opción de notificaciones de la cuenta ahora muestra actividad real,
  permite marcar avisos como leídos y administrar preferencias por categoría.
- Se creó `modules/incidents` con las mismas capas y una experiencia para
  registrar, consultar y cerrar incidentes o reclamos propios.
- Las rutas compartidas validan los permisos de notificaciones e incidentes
  antes de mostrar cada pantalla.
- Los formularios, tarjetas, estados, colores y espaciados reutilizan el
  sistema de diseño centralizado.
- Se conservaron sin cambios las tablas existentes y se agregaron políticas
  RLS para aislar la información por usuario.
- Beneficios, pagos, servicios a domicilio y entregas permanecen postergados.

## 2026-07-27 — Cuerpo JSON en acciones sin formulario

- Las acciones de aceptar o retirar consentimientos envían un objeto JSON
  vacío compatible con el encabezado compartido del cliente HTTP.
- El registro de ingreso a telemedicina aplica el mismo contrato para evitar
  rechazos por cuerpo ausente.

## 2026-07-27 — Consentimiento contextual para ubicación

- La acción de obtener ubicación ahora consulta primero el consentimiento de
  geolocalización.
- Si está pendiente, se muestra una explicación y se permite aceptar sin salir
  de la pantalla de emergencias.
- Si el paciente no acepta, se mantiene disponible el ingreso manual de una
  dirección o referencia.
- La aceptación contextual utiliza el mismo repositorio compartido y actualiza
  la pantalla general de consentimientos.

## 2026-07-27 — Consentimientos y control de servicios sensibles

- Se creó `modules/consents` con capas de dominio, aplicación, infraestructura
  API y presentación.
- Se agregó una pantalla reutilizable de privacidad y consentimientos dentro
  de la cuenta del paciente.
- Los tipos, versiones, obligatoriedad y estados se consultan desde la API; la
  app no mantiene una copia paralela de esa configuración.
- Cada aceptación o retiro solicita confirmación y vuelve a consultar el
  estado persistido.
- La interfaz distingue consentimientos aceptados, pendientes y necesarios,
  manteniendo los componentes, espaciados y colores centralizados.
- Se protegieron orientación por IA, geolocalización y acceso del paciente a
  telemedicina con sus respectivos consentimientos vigentes.
- Las decisiones quedan auditadas en las tablas existentes con usuario, fecha,
  IP y agente del dispositivo, sin eliminar el historial al retirar una
  autorización.

## 2026-07-27 — Ubicación real y Google Maps en emergencias

- Se retiró el mapa simulado de la pantalla de emergencias.
- Se incorporó geolocalización reutilizable para web, Android e iOS mediante
  `core/location`.
- Se agregaron permisos de ubicación precisa y aproximada en Android y la
  descripción de uso correspondiente en iOS.
- El permiso se solicita únicamente por acción del usuario y rechazarlo no
  impide enviar una emergencia.
- Se mantuvo una alternativa de dirección o referencia manual.
- Se creó `modules/maps` con dominio, aplicación, infraestructura API y un
  componente visual compartido.
- La API realiza geocodificación inversa y genera la imagen real mediante
  Google Maps sin exponer la key de servidor en Flutter.
- Las coordenadas y la dirección se guardan en las columnas existentes de
  `emergency_events`.
- La ubicación se comparte únicamente a través del cliente autenticado y las
  políticas existentes de emergencias.

## 2026-07-27 — Integración de telemedicina con Google Meet

- Se creó `modules/telemedicine` con dominio, aplicación e infraestructura
  API.
- La pantalla dejó de simular una videollamada y ahora consulta salas reales
  asociadas con las citas visibles para el usuario autenticado.
- El acceso registra la participación en la API y abre Google Meet mediante el
  mecanismo externo correspondiente a web, Android o iOS.
- Se conservó la composición visual base con tarjeta profesional, estado,
  recomendaciones de cámara y micrófono y acción principal.
- La API incorporó un módulo independiente de integraciones con puerto de
  Google Meet y adaptador OAuth.
- Se agregó autorización OAuth con `state` temporal, intercambio de código,
  renovación automática y cifrado AES-256-GCM de access y refresh tokens.
- Las salas se crean de forma idempotente únicamente para citas de
  telemedicina y por personal autorizado.
- Se agregaron políticas RLS para salas, participantes y eventos.
- Las credenciales de Google y los tokens permanecen exclusivamente en la API.

## 2026-07-27 — Integración real del asistente de orientación

- Se creó `modules/ai` con dominio, aplicación e infraestructura API.
- Se retiraron las respuestas simuladas de la experiencia del paciente.
- La conversación utiliza el cliente HTTP autenticado común y conserva el
  identificador de conversación devuelto por la API.
- Se mantuvo el diseño existente del chat y se incorporó un estado de error
  visible mediante los colores centralizados.
- La API integra OpenAI mediante un puerto de dominio y un adaptador de
  infraestructura; la aplicación no conoce el proveedor ni sus credenciales.
- Los mensajes y evaluaciones de riesgo se persisten en las tablas existentes
  bajo políticas RLS vinculadas con el usuario y paciente autenticados.
- Se agregó una barrera determinista para señales de urgencia; esos casos no
  dependen de una respuesta del modelo.
- Google Meet permanece desactivado hasta completar el callback OAuth y el
  almacenamiento cifrado del refresh token.

## 2026-07-27 — Validaciones, borradores de recetas y familiares

- Los botones administrativos “Validar” y “Rechazar” ahora ejecutan transiciones reales sobre el profesional, sus documentos y la solicitud asociada.
- El rechazo exige un motivo y cada revisión genera un evento de auditoría.
- Los estados aprobado, rechazado, en revisión y vencido se presentan con etiquetas visuales diferenciadas.
- El módulo de recetas permite crear un borrador con paciente, cita, medicamento, dosis, frecuencia, duración e indicaciones.
- La API exige una atención en curso o completada y una nota clínica previa antes de aceptar el borrador.
- La interfaz identifica claramente los borradores antes de su emisión.
- El botón “Agregar” de familiares ahora autoriza una cuenta Doc IA activa mediante correo, parentesco y permisos seleccionados.
- La vinculación familiar evita autoautorizaciones, reemplaza permisos anteriores de forma atómica y registra auditoría.
- Los tres flujos reutilizan el cliente autenticado, providers y componentes compartidos.

## 2026-07-27 — Lectura de auditoría administrativa

- Se creó `modules/audit` con capas de dominio, aplicación e infraestructura.
- La pestaña de auditoría ahora consulta los últimos eventos reales visibles para la sesión administrativa.
- Se retiraron los eventos, personas y tiempos simulados de la pantalla de gestión.
- Los eventos muestran acción, módulo, actor y fecha registrados por la API.
- Se agregaron estados compartidos de carga, error, reintento, actualización y lista vacía.
- El acceso de auditoría del dashboard abre directamente la pestaña correspondiente.
- Los accesos clínicos detallados permanecen fuera de esta pantalla hasta integrar su contrato específico.

## 2026-07-25 — Dashboard administrativo

- El dashboard administrativo ahora compone sus métricas desde citas, recursos humanos y empresas asociadas mediante providers compartidos.
- Se retiró `MockClinicData`, el gráfico estático y los conteos escritos directamente en la pantalla.
- El resumen muestra personal registrado, consultas reales del mes, empresas activas y profesionales validados.
- El gráfico semanal se calcula con citas reales y excluye cancelaciones y ausencias.
- Las solicitudes pendientes de validación y las empresas activas se derivan de los estados recibidos desde la API.
- Se agregaron actualización manual, carga, error y reintento sin duplicar componentes ni fuentes de datos.
- La sección de auditoría permanece visible pero marcada como pendiente de integración porque los endpoints actuales de auditoría todavía son placeholders; no se muestran eventos simulados en el dashboard.
- Se conservó la estructura visual del mockup con encabezado, cuadrícula de indicadores, gráfico, secciones y filas de acción reutilizables.

## 2026-07-25 — Dashboard del profesional

- El dashboard profesional ahora compone sus indicadores y agenda del día desde el módulo real de citas.
- Se retiró la dependencia de `MockClinicData` y de los modelos médicos temporales de esta pantalla.
- Los indicadores de citas, teleconsultas y pendientes excluyen cancelaciones y ausencias y respetan la fecha local.
- La agenda muestra carga, error, reintento y estado vacío mediante componentes compartidos.
- Las tarjetas de atenciones en curso o completadas abren la nota clínica con el contexto real de paciente y cita.
- El acceso rápido a nota clínica deriva a “Mis pacientes” cuando no existe una atención válida para evitar registros sin contexto.
- Se conservó la estructura visual del mockup mediante encabezado, indicadores, acciones rápidas, secciones y tarjetas reutilizables.

## 2026-07-25 — Pacientes del profesional y notas clínicas

- Se crearon los módulos `professional_patients` y `clinical_notes` con capas de dominio, aplicación e infraestructura independientes.
- La pantalla “Mis pacientes” ahora consulta pacientes relacionados con citas reales del profesional autenticado.
- Se retiraron los pacientes, edades, diagnósticos y fechas simulados de la experiencia profesional.
- La selección del paciente transporta el contexto real de paciente y cita mediante una ruta enlazable.
- El formulario SOAP conserva el diseño existente y ahora registra la nota clínica mediante la API.
- El profesional y la autorización se derivan de la sesión autenticada; la aplicación no envía ni permite seleccionar la identidad profesional.
- Se incorporaron estados compartidos de carga, error, reintento, lista vacía y envío.

## 2026-07-24 — Identidad y nombre del artefacto

- Se configuró `assets/images/icon.png` como fuente única del icono de Android, iOS y web.
- Se estableció “Jampic” como nombre visible de la aplicación en todas las plataformas.
- Se agregó un comando de empaquetado que genera el APK con el patrón `jampic_V<version>.apk`.
- El nombre del artefacto se deriva de la versión declarada en `pubspec.yaml`, iniciando con `jampic_V1.0.0.apk`.

## 2026-07-24 — Catálogo, tarifario y Monedas Doc IA

- Se crearon los módulos `catalog` y `coins` respetando las capas de dominio, aplicación, infraestructura y presentación.
- Catálogo combina servicios activos con la tarifa vigente sin modificar las tablas base.
- Monedas muestra la billetera del usuario autenticado, movimientos recientes y paquetes activos.
- Se agregaron accesos “Servicios y tarifas” y “Monedas Doc IA" en la pantalla compartida de cuenta.
- Se incorporaron rutas protegidas por `catalog.read` y `coins.read`.
- Las pantallas reutilizan tarjetas, indicadores, secciones y estados comunes del sistema de diseño.
- La compra de monedas permanece fuera de este corte hasta integrar pagos.

## 2026-07-24 — Recursos humanos y empresas asociadas

- Se crearon los módulos `human_resources` y `partners` con dominio, aplicación e infraestructura independientes.
- La pestaña de profesionales ahora consume personal, relación laboral, contrato, código y verificación desde la API.
- La pestaña de empresas ahora consume aliados, tipo, plan vigente, suscripción y cantidad de sedes desde la API.
- Se retiraron los profesionales y empresas simulados de la pantalla de gestión.
- Se conservaron tarjetas, avatares, indicadores, pestañas y estados mediante componentes y tokens compartidos.
- Las acciones de validación permanecen deshabilitadas hasta implementar transiciones auditadas.

## 2026-07-24 — Solicitudes de emergencia

- Se creó `modules/emergencies` con dominio, repositorio, adaptador API y provider.
- La solicitud de emergencia ahora se registra en la API para el paciente derivado del JWT.
- Se conectó la cancelación segura de solicitudes en estados iniciales.
- Se mantuvieron el selector de gravedad, mapa visual, cabecera, línea de avance y acciones del diseño original.
- Se retiraron la unidad y el tiempo de llegada simulados; la interfaz muestra evaluación pendiente hasta recibir una asignación real.
- Se agregaron estados de envío y errores sin duplicar estilos transversales.

## 2026-07-24 — Lectura de recetas digitales

- Se creó `modules/prescriptions` con capas de dominio, aplicación, infraestructura y presentación compartida.
- Pacientes y profesionales ahora consultan recetas e ítems reales desde la API.
- Se agregó una pantalla compartida que conserva tarjetas, estados, medicamentos, dosis, frecuencia, duración e indicaciones del diseño original.
- Se agregó una ruta protegida de recetas dentro de la experiencia del paciente.
- El acceso rápido “Recetas” del inicio ahora abre el módulo correspondiente en lugar del historial médico.
- La experiencia profesional reutiliza la misma presentación y muestra la acción de nueva receta únicamente con `prescriptions.manage`.
- La emisión permanece deshabilitada hasta incorporar contexto clínico y firma digital; la interfaz comunica esta condición sin crear datos simulados.
- Se agregaron estados compartidos de carga, error, reintento y lista vacía.

## 2026-07-24 — Familiares y dependientes

- Se creó `modules/family` con dominio, repositorio, adaptador API y provider Riverpod.
- La pantalla de familiares conserva las secciones, tarjetas, avatares, estados y filas de permisos del diseño original.
- Los dependientes ahora provienen de vínculos vigentes en `patient_guardians`.
- Los familiares autorizados y sus permisos ahora provienen de `family_authorizations` y `family_authorization_permissions`.
- Se agregaron estados reutilizables de carga, error, reintento y lista vacía.
- Se retiró la dependencia de `MockClinicData` y de los modelos clínicos temporales en esta pantalla.
- La acción de agregar conserva su ubicación visual para autorizaciones de
  familiares adultos.

## 2026-07-24 — Lectura del módulo de historia clínica

- Se creó `modules/clinical_records` con capas de dominio, aplicación e infraestructura.
- Se conectaron el perfil clínico y el historial médico al cliente autenticado común.
- El perfil clínico ahora obtiene tipo de sangre, estatura, peso, seguro, alergias, condiciones crónicas, medicación y contacto de emergencia desde la API.
- El historial médico ahora presenta registros clínicos reales y estados vacíos cuando la base no contiene información.
- Se retiró el uso de `MockClinicData` de las pantallas de perfil clínico, historial médico y resumen clínico del inicio.
- El inicio del paciente ahora reutiliza los providers reales de citas e información clínica.
- Se incorporaron estados compartidos de carga, error y reintento para las consultas clínicas.

## 2026-07-24 — Módulo compartido de cuenta

- Se organizó `modules/account` en capas `domain`, `application`, `infrastructure` y `presentation`.
- Se agregó un repositorio de cuenta que consume el perfil personal autenticado desde la API.
- La pantalla de cuenta ahora muestra nombre, correo, teléfono, documento y dirección obtenidos de PostgreSQL.
- Se incorporaron estados reutilizables de carga, error y reintento en la consulta del perfil.
- Se mantuvieron las preferencias visuales y el cierre de sesión dentro de la experiencia compartida.

## 2026-07-23 — Primer módulo vertical de citas

- Se creó `modules/appointments` con dominio, puerto de repositorio, infraestructura API, DTO, mapper y controlador Riverpod.
- Se conectó el listado de citas al cliente HTTP autenticado común.
- Se retiró el modelo de citas del archivo clínico temporal compartido.
- Se agregaron estados de modalidad y cita alineados con el contrato de PostgreSQL.
- Se movieron las etiquetas, iconos y colores de citas a la capa de presentación.
- La pantalla `Mis citas` ahora carga datos reales de la API.
- La pantalla `Mi agenda` ahora carga las citas asignadas al profesional desde la API.
- Se agregaron estados comunes de carga, error, reintento y lista vacía.
- Se mantuvieron temporalmente datos de citas adaptados para los dashboards que todavía no fueron migrados.
- Se agregó una prueba del mapeo entre DTO y dominio.

## 2026-07-23 — Protección de rutas por permisos

- Se agregó en Flutter el catálogo de códigos de permiso compartido con la API.
- Se creó una política central que relaciona rutas con permisos requeridos.
- Se agregó redirección a una pantalla de acceso denegado cuando falta un permiso.
- Se protegieron las rutas actuales de paciente, profesional y administración.
- Se agregó una pantalla común de acceso denegado.
- Se mantuvieron `PermissionGate` y `AnyPermissionGate` para proteger componentes y acciones.
- Se cambió la restauración para renovar la sesión y obtener roles y permisos actualizados al abrir la aplicación.

## 2026-07-23 — Cliente HTTP autenticado compartido

- Se creó un cliente HTTP común para solicitudes protegidas de todos los módulos.
- Se agregó automáticamente el access token más reciente antes de cada solicitud.
- Se implementó un coordinador que comparte una única renovación entre solicitudes concurrentes.
- Se agregó el reintento único de la solicitud original después de renovar la sesión.
- Se evitó el reintento infinito mediante una marca interna por solicitud.
- Se agregó invalidación global de sesión cuando el refresh token deja de ser válido.
- Se centralizó la conversión de errores HTTP en `ApiException`.
- Se expusieron operaciones autenticadas GET, POST, PUT, PATCH y DELETE.
- Se creó un provider común para inyectar el cliente autenticado en futuros repositorios.
- Se agregó `PermissionGate` para mostrar componentes según permisos.
- Se agregó `AnyPermissionGate` para acciones habilitadas por más de un permiso.
- Se agregó una prueba del refresh concurrente.

## 2026-07-23 — Autenticación real, sesión, roles y permisos

- Se agregó Dio como cliente HTTP.
- Se agregó almacenamiento persistente de sesión mediante `flutter_secure_storage`.
- Se creó el contrato `AuthSession` con access token, refresh token y usuario autenticado.
- Se amplió `AppUser` con identificador de sesión, teléfono, rol principal, roles múltiples y permisos.
- Se reemplazó el rol cerrado del MVP por una resolución de experiencias basada en códigos recibidos desde la API.
- Se agregaron las experiencias de paciente, profesional, administración y experiencia no soportada.
- Se creó `AccessControl` para consultar roles y permisos desde cualquier módulo.
- Se implementó el adaptador HTTP de autenticación para login, usuario actual, refresh y logout.
- Se implementó el repositorio real de autenticación con persistencia y rotación de tokens.
- Se incorporó restauración automática de sesión durante el inicio de la aplicación.
- Se actualizaron las redirecciones para esperar la restauración antes de resolver la experiencia.
- Se agregó una pantalla controlada para roles cuya experiencia todavía no está implementada.
- Se eliminó la selección manual de rol y las credenciales mock de la pantalla de login.
- Se retiró el repositorio mock de autenticación.
- Se mantuvieron los datos de perfil personal como campos opcionales hasta integrar el módulo de cuenta.
- Se estableció que `API_BASE_URL` debe terminar con `/` para conservar correctamente el prefijo versionado.
- Se actualizaron los archivos de configuración de ejemplo con el formato requerido.

## 2026-07-23 — Reorganización inicial por módulos y experiencias

- Se migró autenticación desde `features/auth` hacia `modules/auth`.
- Se separó autenticación en las capas `domain`, `application`, `infrastructure`, `presentation` y `routing`.
- Se ubicó el repositorio temporal de autenticación dentro del adaptador `infrastructure/mock`.
- Se eliminó la dependencia de Flutter, colores, iconos y rutas desde el modelo de rol de dominio.
- Se creó una extensión de presentación para los nombres, iconos y colores temporales de los roles.
- Se movió la pantalla común de cuenta a `modules/account`.
- Se crearon las experiencias `patient`, `professional` y `administration`.
- Se movieron las pantallas específicas de cada rol a su experiencia correspondiente.
- Se separaron las rutas de paciente, profesional y administración en archivos independientes.
- Se redujo el router principal a la composición de autenticación y experiencias.
- Se retiró la carpeta activa `features` de la estructura de la aplicación.
- Se aislaron los modelos y datos temporales compartidos dentro de `lib/demo`.
- Se reemplazaron los colores directos restantes por valores centralizados en `AppColors`.

## 2026-07-23 — Inicio de la estructura base de APP-MVP

- Se movió el widget raíz a `lib/app/app.dart`.
- Se creó un bootstrap central en `lib/app/bootstrap.dart`.
- Se configuró la localización de la aplicación para español de Bolivia.
- Se creó la configuración pública por ambiente en `lib/app/config/`.
- Se agregó validación de ambiente, URL de API y uso obligatorio de HTTPS en producción.
- Se estableció `http://localhost:3000/api/v1` como URL predeterminada para desarrollo local.
- Se agregaron archivos de configuración de ejemplo para desarrollo, staging y producción.
- Se agregó una configuración de ejemplo con `10.0.2.2` para acceder a la API local desde el emulador Android.
- Se excluyeron del versionado los archivos locales reales de configuración.
- Se ampliaron los tokens centrales de color.
- Se crearon tokens de dimensiones, elevaciones y tipografía.
- Se reemplazaron colores directos del tema global por tokens de `AppColors`.
- Se crearon utilidades responsive compartidas y breakpoints centralizados.
- Se convirtió `AppShell` en un shell adaptativo con navegación inferior, rail y sidebar.
- Se agregaron componentes compartidos para estados de carga y error.
- Se actualizó la metadata web para Jampic y español de Bolivia.
- Se eliminó la restricción de orientación vertical del manifiesto web.

## 2026-07-23 — Ampliación del plan de reestructuración

- Se estableció que todas las carpetas, archivos y nombres técnicos del frontend deben escribirse en inglés.
- Se estableció que solamente los textos visibles para el usuario deben estar en español.
- Se definió el uso de español de Bolivia y la exclusión de modismos argentinos.
- Se incorporó una fuente única de colores en `lib/core/theme/app_colors.dart`.
- Se definió la centralización de spacing, radios, dimensiones, elevaciones, tipografía, iconos y temas.
- Se documentó la organización de componentes reutilizables por propósito.
- Se definieron reglas para ubicar componentes globales, de módulo y de experiencia.
- Se agregó una estrategia de configuración pública por ambiente mediante `--dart-define` o `--dart-define-from-file`.
- Se aclaró que las credenciales de PostgreSQL y los secretos de backend permanecen exclusivamente en el `.env` de la API.
- Se estableció que Flutter no debe contener secretos privados ni credenciales de base de datos.
- Se documentó la división de responsabilidades entre elementos transversales, experiencias por rol y módulos funcionales.
- Se agregaron límites de dependencias para reducir conflictos entre integrantes.
- Se actualizó la primera fase de implementación para priorizar la estructura de `APP-MVP`.
- Se creó este registro exclusivo de cambios.

## 2026-07-23 — Creación del plan de integración

- Se creó `PLAN_INTEGRACION_API_Y_REESTRUCTURACION.md`.
- Se documentó la arquitectura objetivo de `APP-MVP`.
- Se definió la separación entre módulos funcionales y experiencias por rol.
- Se documentó la integración futura de autenticación, sesiones, roles y permisos.
- Se definieron lineamientos para navegación web, deep links y diseño responsive.
- Se propuso una migración progresiva de datos mock hacia repositorios por módulo.
# Agendamiento conectado a la API

- Se reemplazó el directorio médico de demostración por un módulo `professionals` organizado en `domain`, `application` e `infrastructure`.
- El directorio consume profesionales verificados, su especialidad principal y la disponibilidad semanal publicada por la API.
- La hoja de agendamiento utiliza únicamente fechas, modalidades y horarios derivados de esa disponibilidad.
- Se incorporó la creación de citas al repositorio y controlador de `appointments`; al completar una reserva, el estado compartido de citas se actualiza.
- La aplicación no envía ni conserva un identificador de paciente para agendar: la API deriva el perfil de paciente desde la sesión JWT.
- Se agregó a la API una operación protegida por `appointments.manage` que valida profesional, especialidad, modalidad, disponibilidad, bloqueos y citas superpuestas.
- La creación se serializa por profesional y fecha para evitar reservas simultáneas sobre el mismo horario.
- Se agregó una política RLS de inserción para que una cuenta paciente sólo pueda crear citas propias.
- Se añadió disponibilidad semanal exclusivamente local para los médicos de prueba, sin crear citas ni datos clínicos simulados.
# Correcciones de compilación web

- Se adaptó el estado de error del directorio médico a la interfaz vigente de `EmptyState`, utilizando un componente de acción reutilizable.
- Se restauraron las importaciones del sistema de diseño requeridas por la agenda profesional.
- Se restauró la importación de los colores centralizados requerida por `AppLogo`.
# Conectividad Android con API local

- Se agregó el permiso de Internet al manifiesto principal para que también
  esté presente en el APK generado.
- Los builds `debug` y `profile` permiten tráfico HTTP sin cifrar para consumir
  una API local dentro de la red Wi-Fi.
- El build `release` conserva la exigencia de HTTPS y no habilita tráfico HTTP
  sin cifrar.
- Se redujo el límite de memoria de Gradle y su paralelismo para evitar que la
  compilación Android deje sin memoria al compilador Dart en equipos de
  desarrollo.

# Registro público de pacientes

- Se conectó la creación de cuentas con los endpoints de solicitud y
  finalización de registro de la API.
- El registro público asigna exclusivamente el rol de paciente; los roles
  profesionales continúan sujetos al flujo separado de postulación,
  verificación y aprobación.
- Se agregó la recepción del token enviado por correo mediante la ruta web
  `/register/complete`.
- Se incorporaron datos personales, fecha de nacimiento, documento, domicilio,
  contraseña y vinculación obligatoria de un tutor adulto para menores.
- Los Términos y condiciones y la Política de privacidad permanecen aceptados
  como requisito no opcional para crear la cuenta.
- Se agregó la regla SPA de Netlify para que los enlaces directos y la
  verificación por correo se resuelvan dentro de Flutter Web.
- Se aplicó el diseño común de Jampic a las acciones del selector de fecha:
  cancelar utiliza un botón secundario con borde y aceptar una acción primaria.

# Rediseño del inicio del paciente

- Se reemplazó la cuadrícula de accesos rápidos por tres acciones prioritarias:
  emergencia médica, agendamiento de consulta y Jampic IA.
- Se agregó un saludo dinámico, notificaciones pendientes y un menú de accesos
  secundarios sin duplicar la navegación inferior.
- Los indicadores de tipo de sangre, peso e IMC usan el perfil clínico real y
  se ocultan por completo cuando no existe ningún dato disponible.
- La próxima cita utiliza la colección real de citas, excluye estados finales y
  se oculta cuando no hay una cita futura válida.
- Se crearon componentes mantenibles para el encabezado, métricas, acciones
  principales y próxima cita.
- La navegación inferior conserva el `AppShell` compartido y hereda los
  colores correspondientes al tema global.
- El contenido limita su ancho en web, permite desplazamiento vertical y usa
  `Wrap`, `Expanded` y restricciones mínimas para evitar desbordamientos.
- Se eliminó el modo oscuro forzado del inicio: fondo, textos, próxima cita y
  navegación ahora responden automáticamente al tema claro u oscuro del sistema.

# Ubicación de emergencias y contraste de encabezados

- Se corrigió el registro de auditoría de Maps tipando explícitamente latitud y
  longitud para PostgreSQL, evitando el error interno al activar el GPS.
- La vista de ubicación ya no bloquea una emergencia cuando Google Maps no
  responde: conserva las coordenadas y muestra una representación degradada.
- La imagen estática del mapa ahora es opcional en el contrato de API y APP-MVP.
- Se centralizó en `AppColors.onColoredHeader` el blanco utilizado por textos e
  iconos sobre encabezados con fondo de color.
- `GradientHeader` aplica ese contraste a los encabezados de paciente,
  profesional y administración; Emergencia Médica utiliza el mismo token.
- El título del `AppBar` de Emergencia Médica conserva la tipografía global y
  fuerza el contraste blanco, evitando que el color de texto general del tema
  tenga prioridad sobre el fondo rojo.

# Popover y próxima cita del inicio del paciente

- Se reemplazó el menú material amplio por un popover compacto anclado al
  botón de tres puntos, con punta visual, fondo adaptado al tema, sombra suave
  y animaciones de opacidad y escala.
- El popover se cierra al tocar fuera, volver a tocar el disparador o navegar,
  y conserva los accesos existentes a perfil clínico, historial, familiares y
  recetas.
- Se creó un componente reutilizable para cada opción, con icono azul en
  círculo tenue, fila táctil completa y chevron secundario.
- La sección de próxima cita ahora siempre ocupa un espacio contextual
  compacto: muestra datos reales y acceso al detalle o, si no hay citas,
  ofrece una acción discreta hacia el agendamiento existente.
- La tarjeta de cita prioriza fecha y hora, profesional, especialidad,
  modalidad y estado sin competir visualmente con las acciones principales.

# Simplificación de encabezados de Citas y Asistente

- Se retiró del encabezado de Citas el acceso a la hoja extensa de seguimientos
  y derivaciones; permanecen las pestañas de próximas e historial y la acción
  principal para agendar.
- Se retiró el icono `+` del encabezado de Jampic IA para evitar reinicios
  accidentales o una acción sin contexto.
- El asistente conserva la acción de iniciar otra conversación cuando la actual
  ya se encuentra cerrada, además del acceso al historial de conversaciones.

# Gestión administrativa de QR para pagos

- La pantalla administrativa de paquetes de monedas incorpora un bloque para
  editar el QR de cobro, banco y titular de cuenta.
- El menú lateral administrativo en web/tablet ahora expone accesos directos a
  Servicios y tarifas, Paquetes y QR, y Pagos cuando el usuario tiene permisos.
- Esos accesos también quedaron como pestañas dentro de Gestión para que sean
  visibles en móvil.
- Las pestañas administrativas de Servicios y tarifas, Paquetes y QR, y Pagos
  se renderizan en modo embebido para evitar doble título dentro de Gestión.
- La creación y edición de paquetes permite asociar, editar o quitar una imagen
  QR propia del paquete.
- En web, la tab seleccionada de Gestión se remonta por clave y builder propio
  para evitar que Paquetes y QR quede en blanco al volver desde el menú lateral.
- La imagen QR se guarda mediante el módulo privado de archivos y se resuelve
  con URL firmada antes de mostrarse al administrador o al paciente.
- El botón de pago por QR sigue ocultándose para pacientes cuando el paquete no
  tiene una imagen QR configurada.
- Para compras de paquetes se usa exclusivamente el QR propio del paquete; el
  QR general ya no se presenta como fallback en ese flujo.
- La tarjeta del QR y las acciones de paquetes usan layouts adaptativos para
  evitar desbordes o botones mal acomodados en móvil.
- Las imágenes QR vinculadas a paquetes se previsualizan con tamaño fijo para
  admin y pacientes, evitando errores de layout en web.
- Las imágenes QR y comprobantes en imagen ahora se seleccionan desde la galería
  nativa del dispositivo; los comprobantes PDF quedan como opción separada de
  archivos del dispositivo.

# Revisión de seguridad, Meet y notificaciones móviles

- El panel de Google Workspace muestra la URI OAuth efectiva que debe
  registrarse en Google Cloud, evitando autorizar por error un callback local.
- Al cerrar sesión se desregistra y elimina el token FCM del dispositivo; al
  cambiar de cuenta se genera y registra el token para la identidad nueva.
- Las preferencias de notificaciones distinguen los avisos dentro de Doc IA de
  los avisos push que aparecen en el celular.
- Los avisos del sistema operativo usan un texto neutro para no exponer datos
  de salud en la pantalla bloqueada; el detalle permanece dentro de Doc IA.
- El inicio profesional identifica por separado Medicina General, Especialidad
  y Enfermería; la acción de emitir recetas solo aparece con el permiso
  correspondiente.
- Las compilaciones Android `release` ya no reutilizan la firma debug: requieren
  `android/key.properties` y un keystore de producción.
- La configuración local de producción deja Stripe oculto hasta proporcionar
  una clave pública `pk_live_`; se retiró la clave de pruebas del perfil de
  compilación usado para producción.
- La validación de arranque impide compilar una configuración de producción
  con una clave pública Stripe de pruebas.
- La opción de tarjeta depende también de `STRIPE_ENABLED` en la API, por lo que
  puede desactivarse temporalmente sin retirar la integración del repositorio.
- Un pago Stripe fallido puede reintentarse y una confirmación posterior del
  webhook prevalece sobre el fallo anterior.
- Paciente y profesional reciben la actualización al crear, cancelar o
  reprogramar una cita; ambos participantes autorizados pueden modificarla.
- Se agregó un snippet Nginx con CSP y cabeceras de seguridad para el build web
  de producción.
