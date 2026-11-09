# Endpoints iniciales

Todos los endpoints usan el prefijo global `api/v1` por defecto. `health`,
`auth/login`, `auth/refresh` y `auth/logout` son públicos; el resto consume
`Authorization: Bearer <access_token>`. Los endpoints marcados como
implementados usan PostgreSQL. La eliminación progresiva de contratos
provisionales se realiza por dominio, conservando las tablas de
`db/01_database.sql`.

## Servicios domiciliarios

- `GET|POST /home-services/home-service-requests`
- `PATCH /home-services/home-service-requests/:id/assignment`
- `PATCH /home-services/home-service-requests/:id/status`
- `GET /home-services/service-status-history`
- `GET /home-services/realtime-locations`
- `POST /home-services/home-service-requests/:id/locations`
- `GET /home-services/service-evidence`
- `POST /home-services/home-service-requests/:id/evidence`
- `GET /home-services/home-service-ratings`
- `POST /home-services/home-service-requests/:id/rating`

Las consultas respetan RLS. Las solicitudes validan que el servicio esté
activo, sea domiciliario y que la dirección pertenezca al paciente autenticado.

## Entregas

- `GET|POST /deliveries/deliveries`
- `PATCH /deliveries/deliveries/:id/assignment`
- `PATCH /deliveries/deliveries/:id/status`
- `GET /deliveries/delivery-status-history`
- `GET /deliveries/delivery-evidence`
- `POST /deliveries/deliveries/:id/evidence`

Las asignaciones y cambios de estado validan transiciones y registran historial.
Las evidencias conservan únicamente referencias privadas administradas por el
módulo de archivos.

## Catálogo, monedas y empresas asociadas

- `GET /catalog/service-catalog` y `GET /catalog/price-list` consultan el
  catálogo y tarifario vigentes.
- Las rutas `GET /coins/*` consultan billetera, paquetes, compras, lotes,
  transacciones y asignaciones reales bajo el contexto RLS del usuario.
- Las rutas `GET /partners/*` consultan las tablas del dominio de empresas
  asociadas mediante un conjunto cerrado de recursos permitido por el puerto
  del repositorio; no se aceptan nombres de tabla enviados por el cliente.

## Archivos privados

- `POST /files`: recibe un único archivo multipart junto con `category`,
  valida una categoría cerrada, tipo y tamaño, genera un nombre aleatorio,
  registra auditoría y lo guarda bajo `STORAGE_ROOT`.
- `POST /files/access`: genera para un archivo autorizado una URL firmada con
  vigencia configurable y registra quién solicitó el acceso.
- `GET /files/:category/:fileName`: entrega el archivo únicamente con firma y
  vencimiento válidos. Esta descarga es pública solo respecto al JWT; el enlace
  temporal continúa siendo obligatorio.

La firma usa `STORAGE_SIGNING_SECRET`, independiente de JWT. El acceso se
resuelve contra documentos clínicos, profesionales, de personal y empresas,
comprobantes de pago y evidencias de servicios o entregas bajo sus respectivas
políticas RLS.

## Salud

- `GET /health`

## Auth

- `POST /auth/login`
- `POST /auth/registration/request`: genera un enlace de correo de un solo uso.
- `POST /auth/registration/complete`: crea usuario, persona, paciente,
  dirección, consentimientos y tutor cuando corresponda.
- `POST /auth/refresh`
- `POST /auth/logout`
- `POST /auth/password-reset/request`: genera un token de recuperación con
  vigencia de 30 minutos, envía mediante Resend el enlace configurado en
  `PASSWORD_RESET_URL` y responde siempre con un mensaje neutro.
- `POST /auth/password-reset/confirm`: consume el token, actualiza la
  contraseña y revoca las sesiones anteriores.
- `GET /auth/me`
- `GET /auth/sessions` y `PATCH /auth/sessions/:sessionId/revoke`: consulta y
  revocación de sesiones propias.
- `PATCH /auth/password`: cambio autenticado de contraseña y revocación de las
  demás sesiones.
- `POST /auth/mfa/setup`, `POST /auth/mfa/confirm` y
  `POST /auth/mfa/disable`: MFA TOTP con secreto cifrado.
- `POST /auth/phone-verification/request` y
  `POST /auth/phone-verification/confirm`: código SMS con vencimiento y límite
  de intentos.

## Autenticación

- `GET /auth`
- `GET /auth/registration-email-tokens`
- `GET /auth/password-reset-tokens`
- `GET /auth/user-sessions`

## Usuarios y seguridad

- `GET /users`
- `GET /users/users`
- `GET /users/roles`

## Cuenta personal

- `GET /people/me`: devuelve el perfil propio y su dirección vigente.
- `PATCH /people/me`: actualiza nombres, teléfono y dirección de la cuenta
  autenticada. No modifica correo ni documento.
- `GET /users/permissions`
- `GET /users/role-permissions`
- `GET /users/user-roles`

## Personas

- `GET /people`
- `GET /people/me`: perfil personal de la cuenta autenticada, incluida su
  dirección vigente. Requiere `people.read` y sólo expone la persona vinculada
  al JWT.
- `GET /people/persons`
- `GET /people/addresses`

## Pacientes, familiares y dependientes

- `GET /patients`
- `GET /patients/family`: lista dependientes bajo tutela y familiares
  autorizados del paciente asociado a la sesión, incluidos los permisos
  vigentes de cada vínculo.
- `POST /patients/family-authorizations`: autoriza una cuenta activa mediante
  correo y asigna los permisos familiares elegidos. La cuenta paciente y el
  autor de la concesión se derivan del JWT. Requiere `patients.manage`.
- `PATCH /patients/family-authorizations/:id`: modifica parentesco y permisos
  de una autorización otorgada por el paciente autenticado.
- `DELETE /patients/family-authorizations/:id`: revoca la autorización y
  elimina sus permisos vigentes sin borrar el historial.
- `POST /patients/guardian-link-codes`: genera para el paciente autenticado un
  código temporal de uso único. La base conserva solamente su hash y la
  respuesta entrega el código y su vencimiento una sola vez.
- `POST /patients/patient-guardians/redeem`: canjea el código temporal desde
  la cuenta del adulto y crea o reactiva el vínculo validado con el dependiente.
- `GET /patients/patients`: lista los pacientes vinculados mediante citas
  vigentes al profesional autenticado. Incluye la última evaluación propia, la
  última consulta completada y una cita válida para registrar atención.
- `GET /patients/emergency-contacts`
- `GET /patients/patient-guardians`
- `GET /patients/family-authorizations`
- `GET /patients/family-authorization-permissions`
- `GET /patients/patient-profile-completion`

## Consentimientos

- `GET /consents`: devuelve los tipos activos y el último estado del paciente
  autenticado.
- `POST /consents/:code/accept`: registra una aceptación versionada junto con
  usuario, fecha, IP y agente del dispositivo.
- `POST /consents/:code/revoke`: retira el consentimiento activo sin eliminar
  su historial.
- `GET /consents/consent-types`
- `GET /consents/patient-consents`

Los servicios de orientación por IA, geolocalización y acceso del paciente a
telemedicina exigen respectivamente `ai_orientation`, `geolocation` y
`telemedicine` en estado `accepted`. Si falta, responden `403` con el código
`CONSENT_REQUIRED` y el campo `consentCode`.

## Profesionales, especialidades y turnos

- `GET /professionals`
- `GET /professionals/specialties`
- `GET /professionals/professionals`: directorio implementado de médicos
  verificados con perfil público, especialidad principal y disponibilidad
  semanal. Requiere `professionals.read`.
- `GET /professionals/professional-specialties`
- `GET /professionals/professional-documents`
- `GET /professionals/me`: devuelve la ficha laboral propia, especialidades y
  documentos con su estado de revisión.
- `PATCH /professionals/me`: actualiza matrícula, biografía, experiencia y
  visibilidad pública sin alterar el estado de validación.
- `POST /professionals/me/documents`: registra una URL de documento como
  pendiente de revisión. El archivo real se incorporará con el módulo de
  almacenamiento.
- `GET /professionals/schedule`: devuelve los horarios semanales activos y
  bloqueos futuros del profesional autenticado.
- `POST /professionals/professional-availability`: agrega un horario semanal
  por día, intervalo y modalidad, rechazando superposiciones.
- `DELETE /professionals/professional-availability/:id`: desactiva un horario
  perteneciente al profesional autenticado.
- `POST /professionals/professional-time-blocks`: bloquea un intervalo sin
  citas activas superpuestas.
- `DELETE /professionals/professional-time-blocks/:id`: retira un bloqueo
  perteneciente al profesional autenticado.
- `GET /professionals/work-shifts`
- `GET /professionals/work-shift-history`

## Perfil clínico e historia clínica

- `GET /clinical-records`
- `GET /clinical-records/profile`: resumen clínico del paciente asociado a la
  sesión, incluyendo últimos valores físicos, cobertura, alergias,
  antecedentes por categoría, medicación y contacto de emergencia.
- `PATCH /clinical-records/profile`: actualiza la ficha del paciente
  autenticado. Requiere `patients.manage`, mantiene la trazabilidad mediante
  baja lógica de los registros clínicos reemplazados y genera auditoría.
- `GET /clinical-records/history`: historial clínico del paciente asociado a
  la sesión, ordenado desde el registro más reciente.
- `GET /clinical-records/trends?days=90` y
  `GET /clinical-records/patients/:patientId/trends?days=90`: series temporales
  de signos vitales, con mínimo, máximo, promedio y último valor. El rango
  admite de 1 a 730 días y todo acceso queda registrado.
- `GET /clinical-records/export?format=jampic|fhir` y
  `GET /clinical-records/patients/:patientId/export?format=jampic|fhir`:
  exportación autorizada y auditada. El formato propietario entrega el expediente
  estructurado; FHIR devuelve un `Bundle` con `Patient`, `Observation`,
  `Encounter`, `Condition`, `MedicationRequest`, `Consent`, `Permission` y
  `AuditEvent`.
- `POST /clinical-records/clinical-notes`: registra una nota SOAP para una cita
  asignada al profesional autenticado. Requiere `clinical_records.manage`;
  valida que paciente, cita y profesional correspondan y limita la escritura a
  atenciones en curso o completadas.
- `POST /clinical-records/consultations/close`: cierra de forma transaccional
  una consulta asignada al profesional, registra SOAP, diagnóstico,
  tratamiento y seguimiento opcional, consolida el expediente, completa la
  cita, conserva el historial de estado y notifica al paciente.
- `GET /clinical-records/clinical-records`
- `GET /clinical-records/clinical-correction-requests`
- `GET /clinical-records/clinical-record-versions`
- `GET /clinical-records/allergies`
- `GET /clinical-records/medical-antecedents`
- `GET /clinical-records/vital-signs`: lista hasta las últimas 100 mediciones
  del paciente autenticado.
- `POST /clinical-records/vital-signs`: registra mediciones aportadas por el
  paciente y exige al menos un valor clínico válido.
- `GET /clinical-records/clinical-documents`: lista estudios, imágenes,
  informes y otras referencias clínicas del paciente autenticado.
- `POST /clinical-records/clinical-documents`: registra un enlace de documento
  externo como pendiente de validación, con tipo, formato y restricción.
- `GET /clinical-records/patients/:patientId/record`: expediente autorizado
  para profesionales con relación clínica vigente; incluye perfil,
  declaraciones, últimas mediciones y documentos no restringidos.
- `PATCH /clinical-records/patients/:patientId/statements/:type/:statementId/validation`:
  valida u observa una alergia o antecedente y registra auditoría.
- `PATCH /clinical-records/patients/:patientId/documents/:documentId/validation`:
  valida u observa un documento visible y registra profesional, fecha y
  auditoría. Los documentos restringidos no se exponen por esta relación.
- `GET /clinical-records/clinical-correction-requests`: devuelve las
  solicitudes propias del paciente o la bandeja completa para administración
  y supervisión clínica.
- `POST /clinical-records/clinical-correction-requests`: solicita corregir un
  registro perteneciente al paciente autenticado y evita duplicados pendientes.
- `PATCH /clinical-records/clinical-correction-requests/:requestId/resolve`:
  acepta o rechaza una solicitud. Al aceptarla guarda la versión anterior,
  incrementa la versión del registro y conserva el motivo de cambio.
  La resolución genera una notificación interna para el paciente.

## Emergencias y operador

- `GET /emergencies`
- `GET /emergencies/events`: solicitudes visibles para la cuenta autenticada.
- `POST /emergencies/events`: crea una solicitud para el paciente derivado del
  JWT. Requiere `emergencies.manage`.
- `PATCH /emergencies/events/:id/cancel`: cancela una solicitud propia mientras
  permanece en validación inicial.
- `PATCH /emergencies/events/:id/assign`: asigna profesional u operador a una
  emergencia activa; requiere rol operativo además del permiso de gestión.
- `PATCH /emergencies/events/:id/status`: registra una transición operativa
  válida, su nota, marcas de llegada o cierre y notifica al paciente.
- `GET /emergencies/emergency-events`
- `GET /emergencies/emergency-status-history`
- `GET /emergencies/emergency-triage-answers`
- `GET /emergencies/emergency-care-records`
- `GET /emergencies/support-call-requests`

## Mapas y ubicación

- `POST /maps/location-preview`: recibe coordenadas válidas de un usuario con
  `emergencies.manage`, obtiene la dirección mediante geocodificación inversa
  y devuelve una imagen de mapa sin exponer la key de Google en Flutter.

## Inteligencia artificial

- `GET /ai`
- `POST /ai/messages`: envía un mensaje de orientación para el paciente
  autenticado, crea o continúa una conversación y registra la respuesta.
  Requiere `ai.use`. Las señales críticas reconocidas por reglas del servidor
  se derivan a emergencias sin delegar esa decisión al proveedor de IA.
- `GET /ai/ai-conversations`: lista conversaciones persistidas propias con
  estado, modelo y último mensaje.
- `GET /ai/ai-conversations/:id/messages`: recupera cronológicamente los
  mensajes de una conversación propia.
- `PATCH /ai/ai-conversations/:id/close`: archiva una conversación activa sin
  eliminar su historial ni evaluaciones de riesgo.
- `GET /ai/ai-risk-assessments`

## Consultas, agenda y telemedicina

- `GET /appointments`
- `GET /appointments/referrals`: devuelve seguimientos, derivaciones y
  calificaciones visibles para la cuenta autenticada.
- `POST /appointments/referrals`: permite al profesional emitir una
  derivación por especialidad, motivo, prioridad y tipo cuando existe relación
  clínica con el paciente.
- `GET /appointments/appointments`: listado real limitado al paciente,
  profesional asignado o rol operativo autorizado. Requiere
  `appointments.read`.
- `POST /appointments/appointments`: crea una cita para el paciente asociado a
  la sesión JWT. Requiere `appointments.manage`. La API valida profesional,
  especialidad, modalidad, horario publicado, bloqueos y superposiciones.
- `PATCH /appointments/appointments/:appointmentId/cancel`: cancela una cita
  futura propia, conserva el motivo y registra el cambio de estado.
- `PATCH /appointments/appointments/:appointmentId/reschedule`: cambia el
  horario de una cita futura propia después de validar disponibilidad y
  superposiciones.
- `GET /appointments/appointment-status-history`
- `GET /appointments/appointment-followups`: devuelve la continuidad de
  atención recomendada para el paciente o profesional autenticado.
- `GET /appointments/telemedicine-rooms`: devuelve las salas reales visibles
  para el paciente, profesional u operador autenticado.
- `POST /appointments/appointments/:appointmentId/telemedicine-room`: crea de
  forma idempotente una sala Google Meet para una cita de telemedicina. Solo el
  profesional asignado, administración u operación pueden crearla.
- `POST /appointments/telemedicine-rooms/:roomId/join`: registra el ingreso de
  un participante autorizado antes de abrir la URL externa.
- `GET /appointments/telemedicine-rooms/:roomId/activity`: devuelve
  participantes, eventos y documentos compartidos de una sala autorizada.
- `POST /appointments/telemedicine-rooms/:roomId/leave`: registra la salida
  del participante.
- `POST /appointments/telemedicine-rooms/:roomId/connection-failure`: aumenta
  el contador de fallos y registra el evento correspondiente.
- `POST /appointments/telemedicine-rooms/:roomId/files`: comparte un documento
  clínico del paciente atendido y registra el evento de la sala.
- `GET /appointments/clinical-notes`
- `GET /appointments/diagnoses`
- `GET /appointments/treatments`
- `GET /appointments/appointment-ratings`: incluye las calificaciones visibles
  de las consultas relacionadas.
- `POST /appointments/appointments/:appointmentId/rating`: permite al paciente
  calificar una consulta propia completada una sola vez y recalcula el promedio
  profesional.

## Integraciones externas

- `GET /integrations/google/status`: informa si Google Meet ya fue autorizado;
  administración y profesionales con acceso a citas pueden consultarlo.
- `GET /integrations/google/authorize`: genera una URL OAuth de un solo uso
  para conectar la cuenta Google administradora.
- `DELETE /integrations/google`: desconecta la cuenta institucional; requiere
  permisos de administración.
- `GET /integrations/google/callback`: callback público validado mediante
  `state`; intercambia el código y guarda los tokens cifrados.

### Contrato del directorio implementado

```json
{
  "items": [
    {
      "id": "uuid-profesional",
      "fullName": "Nombre del profesional",
      "specialtyId": "uuid-especialidad",
      "specialty": "Medicina General",
      "yearsExperience": 5,
      "averageRating": 4.8,
      "ratingCount": 20,
      "availability": [
        {
          "weekday": 1,
          "startTime": "08:00",
          "endTime": "18:00",
          "modality": "in_person"
        }
      ]
    }
  ]
}
```

`weekday` sigue la convención de PostgreSQL: `0` es domingo y `6` es sábado.
Los horarios corresponden a la zona `America/La_Paz`.

### Crear una cita

```http
POST /api/v1/appointments/appointments
Authorization: Bearer <access_token>
Content-Type: application/json
```

```json
{
  "professionalId": "uuid-profesional",
  "specialtyId": "uuid-especialidad",
  "modality": "in_person",
  "startAt": "2026-07-24T14:00:00.000Z",
  "endAt": "2026-07-24T14:30:00.000Z",
  "reason": "Control general"
}
```

Modalidades admitidas: `in_person`, `telemedicine` y `home_visit`. El cliente
no debe enviar `patientId`: la API lo deriva de la sesión para evitar que una
cuenta paciente agende en nombre de otra persona.

## Recetas digitales

- `GET /prescriptions`
- `GET /prescriptions/prescriptions`: recetas e ítems visibles para el paciente,
  profesional emisor o rol clínico autorizado. Requiere
  `prescriptions.read`.
- `POST /prescriptions/prescriptions`: crea un borrador para una atención en
  curso o completada del profesional autenticado. Exige nota clínica previa y
  al menos un medicamento. Requiere `prescriptions.manage`.
- `PATCH /prescriptions/prescriptions/:id/issue`: emite un borrador propio,
  establece el vencimiento, genera en la API una firma de integridad
  HMAC-SHA256, registra auditoría y notifica al paciente. Requiere
  `PRESCRIPTION_SIGNING_SECRET` privado en el entorno de la API.
- `GET /prescriptions/prescription-items`

## Catálogo y tarifario

- `GET /catalog`
- `GET /catalog/service-catalog`: servicios activos combinados con su tarifa
  vigente en monedas o bolivianos. Requiere `catalog.read`.
- `GET /catalog/price-list`
- `POST /catalog/price-list`: crea una nueva tarifa y conserva el historial de
  vigencias. Requiere `catalog.manage`.
- `GET /catalog/management`: devuelve servicios activos e inactivos y el
  historial completo del tarifario. Requiere `catalog.manage`.
- `POST /catalog/service-catalog` y `PATCH /catalog/service-catalog/:id`:
  crean, actualizan o desactivan lógicamente servicios.
- `PATCH /catalog/price-list/:id/validity`: cierra la vigencia de una tarifa.
  Al crear una nueva tarifa se cierra automáticamente la anterior sin
  sobrescribir precios históricos.

## Monedas Doc IA y billeteras

- `GET /coins`
- `GET /coins/overview`: saldo propio, movimientos recientes y paquetes
  activos. La billetera se deriva del JWT. Requiere `coins.read`.
- `GET /coins/coin-packages`
- `GET /coins/coin-wallets`
- `GET /coins/coin-purchases`
- `GET /coins/coin-lots`
- `GET /coins/coin-transactions`
- `GET /coins/coin-transaction-allocations`
- `POST /coins/purchases`: crea la compra y su orden fiat para el paquete
  elegido. La identidad se obtiene del JWT.
- `POST /coins/coin-packages` y `PATCH /coins/coin-packages/:id`: crean o
  actualizan paquetes desde el panel. Requieren `coins.manage`.
- `POST /coins/maintenance/process-expirations`: procesa lotes vencidos,
  genera movimientos y auditoría, crea avisos idempotentes y cierra órdenes
  vencidas. Requiere `coins.manage` y debe programarse una vez al día.

## Pagos fiat, QR, efectivo e incidencias

- `GET /payments/orders`: lista las órdenes propias, su concepto, modalidad de
  cobro, importe, vencimiento y último intento de pago.
- `GET /payments/history`: devuelve las transacciones de las órdenes propias,
  incluidos método, estado, referencia y rechazo cuando corresponda.
- `GET /payments/configuration`: devuelve el QR, titular, banco y disponibilidad
  de efectivo configurados desde `system_settings`.
- `POST /payments/orders/:orderId/payments`: registra un pago QR o efectivo. El
  QR exige comprobante y ambos quedan en `pending_validation`.
- `GET /payments/review-queue` y `PATCH /payments/:paymentId/review`: cola y
  aprobación/rechazo manual. Requieren `payments.manage`. Aprobar una compra de
  monedas acredita billetera, lote y transacción de forma atómica.
- `GET /payments/incidents`, `POST /payments/:paymentId/incidents` y
  `PATCH /payments/incidents/:incidentId/resolve`: gestión de diferencias y
  reclamos de pago.
- `PATCH /payments/incidents/:incidentId/review`: mueve una incidencia abierta
  a revisión. Requiere `payments.manage`.
- `PATCH /payments/incidents/:incidentId/resolve`: admite `reject`, `adjust`,
  `refund_fiat` y `return_coins`. Los dos últimos generan el reembolso o el
  movimiento compensatorio dentro de la misma transacción que resuelve la
  incidencia.
- `GET /payments/refunds`: consulta los reembolsos autorizados por RLS.

Un reembolso total de una compra de monedas revierte también su lote y saldo.
La operación se rechaza si parte de esas monedas ya fue consumida; no se
generan saldos negativos ni reembolsos superiores al pago original.

No existe pasarela automática en esta etapa. El pago se confirma únicamente
después de la revisión humana autorizada.

## Beneficios y descuentos

- `GET /benefits`: lista beneficios activos y vigentes con descuentos,
  límites, disponibilidad personal y aliados participantes.
- `GET /benefits/usages`: devuelve el historial de beneficios aplicados al
  paciente autenticado.
- `POST /benefits` y `PATCH /benefits/:id`: creación, actualización y
  desactivación lógica por administración, con vigencia, límites, condiciones,
  descuentos fiat o monedas y auditoría.
- `POST /benefits/apply`: valida elegibilidad, límites y acumulación y aplica el
  descuento sobre una orden pendiente. Si el aliado exige revisión, genera una
  validación sin modificar todavía el importe.
- `GET /benefits/validations` y `PATCH /benefits/validations/:id`: bandeja y
  decisión del responsable del aliado. La aprobación aplica el descuento de
  forma atómica; el rechazo conserva el antecedente.
- `PATCH /benefits/:benefitId/partners/:partnerId`: configura participación,
  validación y condiciones de liquidación del aliado.
- `PATCH /benefits/usages/:id/reverse`: revierte administrativamente un uso
  mientras la orden permanezca pendiente y restaura su importe.

## Empresas asociadas, planes, sedes y solicitudes

- `GET /partners/health-partners`: empresas asociadas con plan vigente,
  estado de suscripción y número de sedes. Requiere `partners.read`.
- `POST /partners/health-partners` y `PATCH /partners/health-partners/:id`:
  incorporación y actualización lógica del aliado por administración.
- `POST /partners/health-partners/:id/documents` y
  `PATCH /partners/partner-documents/:id/review`: expediente documental y
  revisión administrativa sin eliminación física.
- `PUT /partners/health-partners/:id/users`: asigna o desactiva responsables y
  sincroniza el rol `health_partner` sin afectar otras membresías vigentes.
- `GET /partners/partner-subscription-plans`
- `POST /partners/partner-subscription-plans` y
  `PATCH /partners/partner-subscription-plans/:id`: administran precio,
  periodicidad, características y límites. Requieren `partners.manage`.
- `PUT /partners/partner-subscription-plans/:planId/benefits` y
  `DELETE /partners/partner-subscription-plans/:planId/benefits/:benefitId`:
  administran las asociaciones del plan con beneficios.
- `POST /partners/partner-subscriptions`: crea una contratación y su orden.
- `POST /partners/partner-subscriptions/:id/renew`: crea una nueva suscripción
  y orden conservando el historial de la anterior.
- `PATCH /partners/partner-subscriptions/:id/cancel`: cancelación lógica con
  motivo obligatorio.
- `POST /partners/partner-subscriptions/:id/usage`: registra consumo y bloquea
  operaciones que superen el límite de la característica configurada.
- `POST /partners/maintenance/process-subscriptions`: genera renovaciones
  automáticas próximas a vencer, inicia periodos de gracia y marca vencimientos.
- `GET /partners/partner-plan-benefits`
- `GET /partners/partner-subscriptions`
- `GET /partners/partner-subscription-usage`
- `GET /partners/partner-users`
- `GET /partners/partner-documents`
- `GET /partners/operating-sites`
- `GET /partners/coverage-zones`
- `GET /partners/partner-catalog-items`
- `GET /partners/partner-requests`
- `GET /partners/partner-request-items`
- `POST /partners/partner-requests`: crea una solicitud en borrador con sus
  ítems; `POST /partners/partner-requests/:id/confirm` la envía al aliado.
- `PATCH /partners/partner-requests/:id/respond`: el responsable confirma o
  rechaza disponibilidad y notifica al paciente.
- `GET /partners/diagnostic-orders` y `POST /partners/diagnostic-orders`:
  consulta y emisión profesional autorizada de estudios.
- `POST /partners/diagnostic-orders/:id/result`: el aliado carga el resultado,
  crea un documento clínico pendiente de validación, completa la orden,
  notifica al paciente y registra auditoría clínica.

## Servicios domiciliarios y seguimiento

- `GET /home-services`
- `GET /home-services/home-service-requests`
- `GET /home-services/service-status-history`
- `GET /home-services/realtime-locations`
- `GET /home-services/service-evidence`
- `GET /home-services/home-service-ratings`

## Entregas

- `GET /deliveries`
- `GET /deliveries/deliveries`
- `GET /deliveries/delivery-status-history`
- `GET /deliveries/delivery-evidence`

## Incidentes

- `GET /incidents`: lista los incidentes y reclamos registrados por el usuario.
- `POST /incidents`: registra una solicitud con área, tipo, prioridad y
  descripción; el autor y el paciente se derivan de la sesión.
- `PATCH /incidents/:id/close`: permite al autor cerrar una solicitud propia
  que todavía no está siendo atendida.

## Recursos humanos

- `POST /human-resources/personnel-applications`: crea una postulación propia para
  un rol de personal habilitado.
- `GET /human-resources/personnel-applications`: devuelve postulaciones propias o,
  para RR. HH., la bandeja completa.
- `POST /human-resources/personnel-applications/:applicationId/documents`: adjunta
  un documento a una postulación propia todavía abierta.
- `GET /human-resources/personnel-documents`: devuelve documentos autorizados por
  propiedad o permiso.
- `PATCH /human-resources/personnel-documents/:documentId/review`: aprueba o
  rechaza un documento; el rechazo exige una observación.
- `PATCH /human-resources/personnel-applications/:applicationId/review`: pasa la
  solicitud a revisión, la rechaza con motivo o la aprueba. La aprobación exige
  documentos aprobados y, en una sola transacción, crea o actualiza el profesional,
  concede el rol, abre su expediente laboral, copia los documentos verificados y
  notifica al postulante.
- `GET /human-resources/employment-records`: personal con perfil profesional,
  especialidad, verificación y relación laboral. Requiere
  `human_resources.read`.
- `PATCH /human-resources/employment-records/:recordId`: actualiza, suspende,
  reactiva o cierra lógicamente un expediente laboral, siempre con motivo.
- `PATCH /human-resources/professionals/:professionalId/verification`: aprueba
  o rechaza al profesional, sus documentos y la solicitud relacionada dentro
  de una transacción auditada. Requiere `human_resources.manage`.
- `GET /human-resources/personnel-observations`
- `POST /human-resources/personnel-observations`: registra una observación
  administrativa, confidencial por defecto, sin eliminar antecedentes.
- `GET /human-resources/reports/summary`: totales agrupados de postulaciones,
  documentos, expedientes y observaciones.
- `GET /human-resources/audit-events`: últimas acciones auditadas del módulo.

## Notificaciones

- `GET /notifications`: lista hasta 100 notificaciones propias.
- `PATCH /notifications/:id/read`: marca una notificación propia como leída.
- `POST /notifications/read-all`: marca todas las notificaciones propias como
  leídas.
- `GET /notifications/preferences`: devuelve las preferencias del usuario.
- `PUT /notifications/preferences`: crea o actualiza una preferencia por
  evento y canal.

Las reservas de citas, recetas nuevas, solicitudes y cancelaciones de
emergencia, e incidentes abiertos o cerrados generan notificaciones `in_app`
si la preferencia correspondiente está habilitada.

## Administración y reglas operativas

- `POST /operations/maintenance/process-daily`: mantenimiento consolidado para
  la cuenta técnica. Procesa monedas y suscripciones, vence beneficios y
  recetas, genera recordatorios de consultas, recetas y seguimientos, revoca
  sesiones vencidas, invalida tokens caducados y reintenta notificaciones
  internas y correos mediante Resend. Los canales sin proveedor configurado no
  se marcan como enviados. Requiere `administration.manage`, `coins.manage` y
  `partners.manage` en la cuenta utilizada y registra un resumen de auditoría.

- `GET /administration/system-settings`: lista parámetros JSON administrables
  para usuarios con `administration.read`.
- `PUT /administration/system-settings/:key`: crea o actualiza un parámetro,
  registra al responsable y genera un evento de auditoría. Requiere
  `administration.manage`. Los parámetros clínicos sólo pueden ser confirmados
  por supervisión clínica.
- `GET /administration/roles` y `GET /administration/permissions`: catálogo de
  roles con sus permisos y catálogo general de permisos.
- `POST /administration/roles`, `PATCH /administration/roles/:id` y
  `PUT /administration/roles/:id/permissions`: administración auditada de roles
  y asignaciones. Protege el rol administrador frente a desactivación o pérdida
  de `administration.manage`.
- `GET|POST /administration/operating-sites` y
  `PATCH /administration/operating-sites/:id`: gestión lógica y auditada de
  sedes propias o asociadas.
- `GET|POST /administration/business-rules` y
  `PATCH /administration/business-rules/:id`: reglas JSON con incremento de
  versión, vigencia, historial, motivo y aprobación clínica cuando corresponda.
- `GET /administration/reports/operational-summary`: resumen de usuarios,
  consultas, emergencias, pagos, incidentes, empresas y postulaciones.

## Auditoría

- `GET /audit`
- `GET /audit/audit-events`: devuelve los últimos 100 eventos de auditoría con
  módulo, acción, entidad, actor, rol, motivo y fecha. Requiere `audit.read`.
- `GET /audit/clinical-access-logs`
- `GET /audit/financial-events`: devuelve hasta 500 eventos financieros con
  actor, entidad, valores anteriores y nuevos, referencia, motivo y fecha.
  Requiere `audit.read`.

- `GET /users/overview`: devuelve usuarios, roles y catálogo de permisos para
  administración.
- `PATCH /users/:id/status`: activa, suspende o inactiva una cuenta; impide que
  el administrador suspenda su propia sesión.
- `PATCH /users/:id/roles`: reemplaza de forma transaccional los roles vigentes
  y conserva el historial mediante revocación.
