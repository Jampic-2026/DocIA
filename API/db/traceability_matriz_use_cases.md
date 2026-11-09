# Matriz de trazabilidad: casos de uso y tablas de Doc IA

**Versión:** 2.0  
**Fecha:** 17 de julio de 2026

## Criterios transversales

- La auditoría se aplica de forma selectiva a eventos de seguridad, modificaciones clínicas, accesos a información clínica sensible, autorizaciones, emergencias, transacciones financieras, verificación profesional, recursos humanos, cambios administrativos críticos y seguimiento operativo.
- Las consultas ordinarias de catálogos, directorios, agenda propia, planes o beneficios no generan auditoría específica. Los logs técnicos y de observabilidad se gestionan por separado.
- No se elimina físicamente información clínica, financiera, laboral ni de auditoría.
- El lanzamiento puede mantenerse gratuito mediante `monetization_enabled = false`. Cuando se activen los cobros, los servicios no presenciales se pagarán con monedas Doc IA; las atenciones presenciales se abonarán mediante QR o efectivo al profesional responsable.
- Los usuarios no tienen suscripciones. Compran paquetes de monedas cuyos lotes vencen un año después de su acreditación. Los planes se reservan exclusivamente para empresas asociadas.
- Todo menor puede tener cuenta propia, pero debe vincular un familiar o tutor adulto registrado.
- El acceso directo a especialistas está permitido y se conserva la aceptación del aviso informativo.
- Los datos autodeclarados o externos permanecen diferenciados hasta validación médica.

## CU-01 — Registrar Paciente

- **Módulo:** Autenticación
- **Tablas principales:** `registration_email_tokens`, `users`, `user_roles`.
- **Tablas relacionadas:** `persons`, `patients`, `addresses`, `patient_consents`, `audit_events`.
- **Operaciones por tabla:** lectura, inserción o actualización según el flujo; sin eliminación física.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.
- **Auditoría:** Sí. Registrar actor, fecha, acción, resultado, IP o dispositivo y valores modificados cuando corresponda.

## CU-02 — Iniciar Sesión

- **Módulo:** Autenticación
- **Tablas principales:** `users`, `user_roles`, `user_sessions`.
- **Tablas relacionadas:** `audit_events`.
- **Operaciones por tabla:** lectura, inserción o actualización según el flujo; sin eliminación física.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.
- **Auditoría:** Sí. Registrar actor, fecha, acción, resultado, IP o dispositivo y valores modificados cuando corresponda.

## CU-03 — Recuperar Contraseña

- **Módulo:** Autenticación
- **Tablas principales:** `users`, `password_reset_tokens`, `audit_events`.
- **Tablas relacionadas:** ninguna adicional.
- **Operaciones por tabla:** lectura, inserción o actualización según el flujo; sin eliminación física.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.
- **Auditoría:** Sí. Registrar actor, fecha, acción, resultado, IP o dispositivo y valores modificados cuando corresponda.

## CU-04 — Cerrar Sesión

- **Módulo:** Autenticación
- **Tablas principales:** `users`, `user_sessions`.
- **Tablas relacionadas:** ninguna adicional.
- **Operaciones por tabla:** lectura, inserción o actualización según el flujo; sin eliminación física.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.

## CU-05 — Configurar MFA

- **Módulo:** Autenticación
- **Tablas principales:** `users`, `user_sessions`, `audit_events`.
- **Tablas relacionadas:** ninguna adicional.
- **Operaciones por tabla:** lectura, inserción o actualización según el flujo; sin eliminación física.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.
- **Auditoría:** Sí. Registrar actor, fecha, acción, resultado, IP o dispositivo y valores modificados cuando corresponda.

## CU-06 — Gestionar Perfil de Usuario

- **Módulo:** Autenticación
- **Tablas principales:** `users`, `user_sessions`, `audit_events`.
- **Tablas relacionadas:** ninguna adicional.
- **Operaciones por tabla:** lectura, inserción o actualización según el flujo; sin eliminación física.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.
- **Auditoría:** Sí. Registrar actor, fecha, acción, resultado, IP o dispositivo y valores modificados cuando corresponda.

## CU-07 — Consultar Perfil Clínico

- **Módulo:** Perfil clínico
- **Tablas principales:** `patients`, `persons`, `clinical_records`.
- **Tablas relacionadas:** `medical_antecedents`, `allergies`, `vital_signs`, `audit_events`.
- **Operaciones por tabla:** lectura y registro de auditoría.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.
- **Auditoría:** Sí. Registrar acceso o modificación clínica, paciente, profesional, fecha, propósito y versiones anterior y nueva cuando corresponda.

## CU-08 — Actualizar Datos Personales del Paciente

- **Módulo:** Perfil clínico
- **Tablas principales:** `persons`, `addresses`, `users`.
- **Tablas relacionadas:** `audit_events`.
- **Operaciones por tabla:** lectura, inserción o actualización según el flujo; sin eliminación física.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.
- **Auditoría:** Sí. Registrar actor, fecha, acción, resultado, IP o dispositivo y valores modificados cuando corresponda.

## CU-09 — Gestionar Antecedentes Patológicos

- **Módulo:** Perfil clínico
- **Tablas principales:** `patients`, `clinical_records`, `medical_antecedents`.
- **Tablas relacionadas:** `allergies`, `clinical_documents`, `audit_events`.
- **Operaciones por tabla:** lectura, inserción o actualización según el flujo; sin eliminación física.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.
- **Auditoría:** Sí. Registrar acceso o modificación clínica, paciente, profesional, fecha, propósito y versiones anterior y nueva cuando corresponda.

## CU-10 — Gestionar Antecedentes Familiares

- **Módulo:** Perfil clínico
- **Tablas principales:** `patients`, `clinical_records`, `medical_antecedents`.
- **Tablas relacionadas:** `allergies`, `clinical_documents`, `audit_events`.
- **Operaciones por tabla:** lectura, inserción o actualización según el flujo; sin eliminación física.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.
- **Auditoría:** Sí. Registrar acceso o modificación clínica, paciente, profesional, fecha, propósito y versiones anterior y nueva cuando corresponda.

## CU-11 — Gestionar Antecedentes Quirúrgicos

- **Módulo:** Perfil clínico
- **Tablas principales:** `patients`, `clinical_records`, `medical_antecedents`.
- **Tablas relacionadas:** `allergies`, `clinical_documents`, `audit_events`.
- **Operaciones por tabla:** lectura, inserción o actualización según el flujo; sin eliminación física.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.
- **Auditoría:** Sí. Registrar acceso o modificación clínica, paciente, profesional, fecha, propósito y versiones anterior y nueva cuando corresponda.

## CU-12 — Gestionar Alergias

- **Módulo:** Perfil clínico
- **Tablas principales:** `patients`, `clinical_records`, `medical_antecedents`.
- **Tablas relacionadas:** `allergies`, `clinical_documents`, `audit_events`.
- **Operaciones por tabla:** lectura, inserción o actualización según el flujo; sin eliminación física.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.
- **Auditoría:** Sí. Registrar acceso o modificación clínica, paciente, profesional, fecha, propósito y versiones anterior y nueva cuando corresponda.

## CU-13 — Gestionar Contactos de Emergencia

- **Módulo:** Perfil clínico
- **Tablas principales:** `emergency_contacts`, `patients`, `audit_events`.
- **Tablas relacionadas:** ninguna adicional.
- **Operaciones por tabla:** lectura, inserción o actualización según el flujo; sin eliminación física.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.
- **Auditoría:** Sí. Registrar acceso o modificación clínica, paciente, profesional, fecha, propósito y versiones anterior y nueva cuando corresponda.

## CU-14 — Consultar Historial Clínico

- **Módulo:** Perfil clínico
- **Tablas principales:** `clinical_records`, `clinical_notes`, `diagnoses`.
- **Tablas relacionadas:** `treatments`, `prescriptions`, `clinical_documents`, `clinical_access_logs`, `audit_events`.
- **Operaciones por tabla:** lectura y registro de auditoría.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.
- **Auditoría:** Sí. Registrar acceso o modificación clínica, paciente, profesional, fecha, propósito y versiones anterior y nueva cuando corresponda.

## CU-15 — Descargar Historial Clínico

- **Módulo:** Perfil clínico
- **Tablas principales:** `clinical_records`, `clinical_access_logs`, `audit_events`.
- **Tablas relacionadas:** ninguna adicional.
- **Operaciones por tabla:** lectura, inserción o actualización según el flujo; sin eliminación física.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.
- **Auditoría:** Sí. Registrar acceso o modificación clínica, paciente, profesional, fecha, propósito y versiones anterior y nueva cuando corresponda.

## CU-16 — Consultar Porcentaje de Perfil Clínico

- **Módulo:** Perfil clínico
- **Tablas principales:** `patient_profile_completion`, `patients`.
- **Tablas relacionadas:** ninguna adicional.
- **Operaciones por tabla:** lectura.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.

## CU-17 — Sugerir Datos Pendientes del Perfil

- **Módulo:** Perfil clínico
- **Tablas principales:** `patient_profile_completion`, `notifications`.
- **Tablas relacionadas:** ninguna adicional.
- **Operaciones por tabla:** lectura, inserción o actualización según el flujo; sin eliminación física.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.

## CU-18 — Otorgar Beneficio por Perfil Completo

- **Módulo:** Perfil clínico
- **Tablas principales:** `patient_profile_completion`, `benefits`, `benefit_usages`.
- **Tablas relacionadas:** ninguna adicional.
- **Operaciones por tabla:** lectura, inserción o actualización según el flujo; sin eliminación física.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.

## CU-19 — Autorizar Familiar

- **Módulo:** Familiares y tutores
- **Tablas principales:** `family_authorizations`, `family_authorization_permissions`, `users`.
- **Tablas relacionadas:** `audit_events`.
- **Operaciones por tabla:** lectura, inserción o actualización según el flujo; sin eliminación física.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.
- **Auditoría:** Sí. Registrar actor, fecha, acción, resultado, IP o dispositivo y valores modificados cuando corresponda.

## CU-20 — Revocar Acceso Familiar

- **Módulo:** Familiares y tutores
- **Tablas principales:** `family_authorizations`, `audit_events`.
- **Tablas relacionadas:** ninguna adicional.
- **Operaciones por tabla:** lectura, inserción o actualización según el flujo; sin eliminación física.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.
- **Auditoría:** Sí. Registrar actor, fecha, acción, resultado, IP o dispositivo y valores modificados cuando corresponda.

## CU-21 — Gestionar Permisos de Familiar

- **Módulo:** Familiares y tutores
- **Tablas principales:** `family_authorizations`, `family_authorization_permissions`, `audit_events`.
- **Tablas relacionadas:** ninguna adicional.
- **Operaciones por tabla:** lectura, inserción o actualización según el flujo; sin eliminación física.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.
- **Auditoría:** Sí. Registrar actor, fecha, acción, resultado, IP o dispositivo y valores modificados cuando corresponda.

## CU-22 — Registrar Perfil de Menor de Edad

- **Módulo:** Familiares y tutores
- **Tablas principales:** `users`, `persons`, `patients`.
- **Tablas relacionadas:** `guardian_link_codes`, `patient_guardians`, `audit_events`.
- **Operaciones por tabla:** lectura, inserción o actualización según el flujo; sin eliminación física.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.
- **Auditoría:** Sí. Registrar actor, fecha, acción, resultado, IP o dispositivo y valores modificados cuando corresponda.

## CU-23 — Consultar Estado del Paciente

- **Módulo:** Familiares y tutores
- **Tablas principales:** `patients`, `patient_guardians`, `family_authorizations`.
- **Tablas relacionadas:** `family_authorization_permissions`, `audit_events`.
- **Operaciones por tabla:** lectura y registro de auditoría.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.
- **Auditoría:** Sí. Registrar acceso o modificación clínica, paciente, profesional, fecha, propósito y versiones anterior y nueva cuando corresponda.

## CU-24 — Consultar Historial Autorizado

- **Módulo:** Familiares y tutores
- **Tablas principales:** `patients`, `patient_guardians`, `family_authorizations`.
- **Tablas relacionadas:** `family_authorization_permissions`, `audit_events`.
- **Operaciones por tabla:** lectura y registro de auditoría.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.
- **Auditoría:** Sí. Registrar acceso o modificación clínica, paciente, profesional, fecha, propósito y versiones anterior y nueva cuando corresponda.

## CU-25 — Recibir Alertas de Emergencia

- **Módulo:** Familiares y tutores
- **Tablas principales:** `family_authorizations`, `emergency_events`, `notifications`.
- **Tablas relacionadas:** ninguna adicional.
- **Operaciones por tabla:** lectura.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.

## CU-26 — Consultar Consultas Programadas

- **Módulo:** Familiares y tutores
- **Tablas principales:** `family_authorizations`, `appointments`.
- **Tablas relacionadas:** ninguna adicional.
- **Operaciones por tabla:** lectura.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.

## CU-27 — Solicitar Auxilio

- **Módulo:** Emergencias
- **Tablas principales:** `emergency_events`, `emergency_status_history`, `addresses`.
- **Tablas relacionadas:** `patient_consents`, `audit_events`.
- **Operaciones por tabla:** lectura, inserción o actualización según el flujo; sin eliminación física.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.
- **Auditoría:** Sí. Registrar responsable, caso afectado, transición de estado, fecha, ubicación cuando corresponda, motivo y resultado.

## CU-28 — Consultar Estado de Emergencia

- **Módulo:** Emergencias
- **Tablas principales:** `emergency_events`, `emergency_status_history`, `emergency_care_records`.
- **Tablas relacionadas:** `realtime_locations`.
- **Operaciones por tabla:** lectura.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.

## CU-29 — Cancelar Emergencia

- **Módulo:** Emergencias
- **Tablas principales:** `emergency_events`, `emergency_status_history`, `emergency_care_records`.
- **Tablas relacionadas:** `realtime_locations`, `audit_events`.
- **Operaciones por tabla:** lectura, inserción o actualización según el flujo; sin eliminación física.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.
- **Auditoría:** Sí. Registrar responsable, caso afectado, transición de estado, fecha, ubicación cuando corresponda, motivo y resultado.

## CU-30 — Consultar Historial de Emergencias

- **Módulo:** Emergencias
- **Tablas principales:** `emergency_events`, `emergency_status_history`, `emergency_care_records`.
- **Tablas relacionadas:** `realtime_locations`.
- **Operaciones por tabla:** lectura.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.

## CU-31 — Consultar Emergencias Activas

- **Módulo:** Emergencias
- **Tablas principales:** `emergency_events`, `emergency_status_history`, `emergency_care_records`.
- **Tablas relacionadas:** `realtime_locations`.
- **Operaciones por tabla:** lectura.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.

## CU-32 — Aceptar Emergencia

- **Módulo:** Emergencias
- **Tablas principales:** `emergency_events`, `emergency_status_history`, `emergency_care_records`.
- **Tablas relacionadas:** `realtime_locations`, `audit_events`.
- **Operaciones por tabla:** lectura, inserción o actualización según el flujo; sin eliminación física.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.
- **Auditoría:** Sí. Registrar responsable, caso afectado, transición de estado, fecha, ubicación cuando corresponda, motivo y resultado.

## CU-33 — Rechazar Emergencia

- **Módulo:** Emergencias
- **Tablas principales:** `emergency_events`, `emergency_status_history`, `emergency_care_records`.
- **Tablas relacionadas:** `realtime_locations`, `audit_events`.
- **Operaciones por tabla:** lectura, inserción o actualización según el flujo; sin eliminación física.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.
- **Auditoría:** Sí. Registrar responsable, caso afectado, transición de estado, fecha, ubicación cuando corresponda, motivo y resultado.

## CU-34 — Atender Emergencia

- **Módulo:** Emergencias
- **Tablas principales:** `emergency_events`, `emergency_status_history`, `emergency_care_records`.
- **Tablas relacionadas:** `realtime_locations`, `audit_events`.
- **Operaciones por tabla:** lectura, inserción o actualización según el flujo; sin eliminación física.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.
- **Auditoría:** Sí. Registrar responsable, caso afectado, transición de estado, fecha, ubicación cuando corresponda, motivo y resultado.

## CU-35 — Registrar Signos Vitales

- **Módulo:** Emergencias
- **Tablas principales:** `vital_signs`, `emergency_events`, `audit_events`.
- **Tablas relacionadas:** ninguna adicional.
- **Operaciones por tabla:** lectura, inserción o actualización según el flujo; sin eliminación física.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.
- **Auditoría:** Sí. Registrar responsable, caso afectado, transición de estado, fecha, ubicación cuando corresponda, motivo y resultado.

## CU-36 — Registrar Síntomas

- **Módulo:** Emergencias
- **Tablas principales:** `emergency_events`, `emergency_status_history`, `emergency_care_records`.
- **Tablas relacionadas:** `realtime_locations`, `audit_events`.
- **Operaciones por tabla:** lectura, inserción o actualización según el flujo; sin eliminación física.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.
- **Auditoría:** Sí. Registrar responsable, caso afectado, transición de estado, fecha, ubicación cuando corresponda, motivo y resultado.

## CU-37 — Registrar Valoración Preliminar

- **Módulo:** Emergencias
- **Tablas principales:** `emergency_events`, `emergency_status_history`, `emergency_care_records`.
- **Tablas relacionadas:** `realtime_locations`, `audit_events`.
- **Operaciones por tabla:** lectura, inserción o actualización según el flujo; sin eliminación física.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.
- **Auditoría:** Sí. Registrar responsable, caso afectado, transición de estado, fecha, ubicación cuando corresponda, motivo y resultado.

## CU-38 — Derivar Paciente a Especialista

- **Módulo:** Emergencias
- **Tablas principales:** `referrals`, `emergency_events`, `emergency_care_records`.
- **Tablas relacionadas:** `audit_events`.
- **Operaciones por tabla:** lectura, inserción o actualización según el flujo; sin eliminación física.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.
- **Auditoría:** Sí. Registrar responsable, caso afectado, transición de estado, fecha, ubicación cuando corresponda, motivo y resultado.

## CU-39 — Cerrar Emergencia

- **Módulo:** Emergencias
- **Tablas principales:** `emergency_events`, `emergency_status_history`, `emergency_care_records`.
- **Tablas relacionadas:** `realtime_locations`, `audit_events`.
- **Operaciones por tabla:** lectura, inserción o actualización según el flujo; sin eliminación física.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.
- **Auditoría:** Sí. Registrar responsable, caso afectado, transición de estado, fecha, ubicación cuando corresponda, motivo y resultado.

## CU-40 — Solicitar Apoyo por Llamada

- **Módulo:** Emergencias
- **Tablas principales:** `support_call_requests`, `emergency_events`.
- **Tablas relacionadas:** ninguna adicional.
- **Operaciones por tabla:** lectura, inserción o actualización según el flujo; sin eliminación física.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.

## CU-41 — Consultar Asistente IA

- **Módulo:** IA y orientación
- **Tablas principales:** `ai_conversations`, `ai_messages`, `patient_consents`.
- **Tablas relacionadas:** ninguna adicional.
- **Operaciones por tabla:** lectura.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.

## CU-42 — Consultar Historial IA

- **Módulo:** IA y orientación
- **Tablas principales:** `ai_conversations`, `ai_messages`, `ai_risk_assessments`.
- **Tablas relacionadas:** `support_call_requests`, `audit_events`.
- **Operaciones por tabla:** lectura y registro de auditoría.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.
- **Auditoría:** Sí. Registrar acceso o modificación clínica, paciente, profesional, fecha, propósito y versiones anterior y nueva cuando corresponda.

## CU-43 — Detectar Riesgo Clínico

- **Módulo:** IA y orientación
- **Tablas principales:** `ai_risk_assessments`, `ai_conversations`, `clinical_records`.
- **Tablas relacionadas:** `audit_events`.
- **Operaciones por tabla:** lectura, inserción o actualización según el flujo; sin eliminación física.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.
- **Auditoría:** Sí. Registrar acceso o modificación clínica, paciente, profesional, fecha, propósito y versiones anterior y nueva cuando corresponda.

## CU-44 — Escalar Caso a Emergencia

- **Módulo:** IA y orientación
- **Tablas principales:** `ai_risk_assessments`, `emergency_events`, `notifications`.
- **Tablas relacionadas:** `audit_events`.
- **Operaciones por tabla:** lectura, inserción o actualización según el flujo; sin eliminación física.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.
- **Auditoría:** Sí. Registrar responsable, caso afectado, transición de estado, fecha, ubicación cuando corresponda, motivo y resultado.

## CU-45 — Recomendar Consulta Médica

- **Módulo:** IA y orientación
- **Tablas principales:** `ai_risk_assessments`, `appointments`, `notifications`.
- **Tablas relacionadas:** ninguna adicional.
- **Operaciones por tabla:** lectura, inserción o actualización según el flujo; sin eliminación física.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.

## CU-46 — Solicitar Llamada de Orientación

- **Módulo:** IA y orientación
- **Tablas principales:** `ai_conversations`, `ai_messages`, `ai_risk_assessments`.
- **Tablas relacionadas:** `support_call_requests`.
- **Operaciones por tabla:** lectura, inserción o actualización según el flujo; sin eliminación física.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.

## CU-47 — Buscar Médico Disponible

- **Módulo:** Directorio médico
- **Tablas principales:** `professionals`, `professional_specialties`, `specialties`.
- **Tablas relacionadas:** `professional_availability`.
- **Operaciones por tabla:** lectura.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.

## CU-48 — Ver Perfil de Especialista

- **Módulo:** Directorio médico
- **Tablas principales:** `professionals`, `professional_specialties`, `specialties`.
- **Tablas relacionadas:** `professional_availability`.
- **Operaciones por tabla:** lectura.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.

## CU-49 — Agendar Consulta

- **Módulo:** Consultas
- **Tablas principales:** `appointments`, `professional_availability`, `specialties`.
- **Tablas relacionadas:** `professional_time_blocks`, `referrals`, `payment_orders`, `coin_wallets`, `coin_transactions`, `audit_events`.
- **Operaciones por tabla:** lectura, inserción o actualización según el flujo; sin eliminación física.
- **Relaciones necesarias:** la consulta enlaza paciente, profesional, especialidad y horario. Si es no presencial y cobrable, la orden se paga con monedas; si es presencial, el cobro QR o efectivo se registra durante la atención.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.

## CU-50 — Reprogramar Consulta

- **Módulo:** Consultas
- **Tablas principales:** `appointments`, `appointment_status_history`, `clinical_notes`.
- **Tablas relacionadas:** `referrals`.
- **Operaciones por tabla:** lectura, inserción o actualización según el flujo; sin eliminación física.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.

## CU-51 — Cancelar Consulta

- **Módulo:** Consultas
- **Tablas principales:** `appointments`, `appointment_status_history`, `clinical_notes`.
- **Tablas relacionadas:** `referrals`.
- **Operaciones por tabla:** lectura, inserción o actualización según el flujo; sin eliminación física.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.

## CU-52 — Consultar Mis Consultas

- **Módulo:** Consultas
- **Tablas principales:** `appointments`, `appointment_status_history`, `clinical_notes`.
- **Tablas relacionadas:** `referrals`.
- **Operaciones por tabla:** lectura.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.

## CU-53 — Calificar Médico

- **Módulo:** Consultas
- **Tablas principales:** `appointment_ratings`, `appointments`.
- **Tablas relacionadas:** ninguna adicional.
- **Operaciones por tabla:** lectura, inserción o actualización según el flujo; sin eliminación física.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.

## CU-54 — Consultar Agenda

- **Módulo:** Consultas
- **Tablas principales:** `appointments`, `appointment_status_history`, `clinical_notes`.
- **Tablas relacionadas:** `referrals`.
- **Operaciones por tabla:** lectura.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.

## CU-55 — Gestionar Disponibilidad

- **Módulo:** Consultas
- **Tablas principales:** `professional_availability`, `professionals`.
- **Tablas relacionadas:** ninguna adicional.
- **Operaciones por tabla:** lectura, inserción o actualización según el flujo; sin eliminación física.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.

## CU-56 — Bloquear Horario

- **Módulo:** Consultas
- **Tablas principales:** `professional_time_blocks`, `professionals`.
- **Tablas relacionadas:** ninguna adicional.
- **Operaciones por tabla:** lectura, inserción o actualización según el flujo; sin eliminación física.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.

## CU-57 — Atender Consulta

- **Módulo:** Consultas
- **Tablas principales:** `appointments`, `appointment_status_history`, `clinical_notes`.
- **Tablas relacionadas:** `referrals`, `audit_events`.
- **Operaciones por tabla:** lectura, inserción o actualización según el flujo; sin eliminación física.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.
- **Auditoría:** Sí. Registrar acceso o modificación clínica, paciente, profesional, fecha, propósito y versiones anterior y nueva cuando corresponda.

## CU-58 — Registrar Nota Clínica

- **Módulo:** Consultas
- **Tablas principales:** `clinical_notes`, `clinical_record_versions`, `audit_events`.
- **Tablas relacionadas:** ninguna adicional.
- **Operaciones por tabla:** lectura, inserción o actualización según el flujo; sin eliminación física.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.
- **Auditoría:** Sí. Registrar acceso o modificación clínica, paciente, profesional, fecha, propósito y versiones anterior y nueva cuando corresponda.

## CU-59 — Registrar Diagnóstico

- **Módulo:** Consultas
- **Tablas principales:** `diagnoses`, `clinical_notes`, `audit_events`.
- **Tablas relacionadas:** ninguna adicional.
- **Operaciones por tabla:** lectura, inserción o actualización según el flujo; sin eliminación física.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.
- **Auditoría:** Sí. Registrar acceso o modificación clínica, paciente, profesional, fecha, propósito y versiones anterior y nueva cuando corresponda.

## CU-60 — Registrar Tratamiento

- **Módulo:** Consultas
- **Tablas principales:** `treatments`, `clinical_notes`, `audit_events`.
- **Tablas relacionadas:** ninguna adicional.
- **Operaciones por tabla:** lectura, inserción o actualización según el flujo; sin eliminación física.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.
- **Auditoría:** Sí. Registrar acceso o modificación clínica, paciente, profesional, fecha, propósito y versiones anterior y nueva cuando corresponda.

## CU-61 — Adjuntar Documentos Clínicos

- **Módulo:** Consultas
- **Tablas principales:** `clinical_documents`, `clinical_notes`, `audit_events`.
- **Tablas relacionadas:** ninguna adicional.
- **Operaciones por tabla:** lectura, inserción o actualización según el flujo; sin eliminación física.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.
- **Auditoría:** Sí. Registrar acceso o modificación clínica, paciente, profesional, fecha, propósito y versiones anterior y nueva cuando corresponda.

## CU-62 — Programar Seguimiento

- **Módulo:** Consultas
- **Tablas principales:** `appointment_followups`, `appointments`, `audit_events`.
- **Tablas relacionadas:** ninguna adicional.
- **Operaciones por tabla:** lectura, inserción o actualización según el flujo; sin eliminación física.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.
- **Auditoría:** Sí. Registrar acceso o modificación clínica, paciente, profesional, fecha, propósito y versiones anterior y nueva cuando corresponda.

## CU-63 — Consultar Historial del Paciente

- **Módulo:** Consultas
- **Tablas principales:** `clinical_records`, `clinical_notes`, `diagnoses`.
- **Tablas relacionadas:** `treatments`, `clinical_documents`, `clinical_access_logs`, `audit_events`.
- **Operaciones por tabla:** lectura y registro de auditoría.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.
- **Auditoría:** Sí. Registrar acceso o modificación clínica, paciente, profesional, fecha, propósito y versiones anterior y nueva cuando corresponda.

## CU-64 — Derivar Paciente a Especialista

- **Módulo:** Consultas
- **Tablas principales:** `referrals`, `appointments`, `audit_events`.
- **Tablas relacionadas:** ninguna adicional.
- **Operaciones por tabla:** lectura, inserción o actualización según el flujo; sin eliminación física.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.
- **Auditoría:** Sí. Registrar acceso o modificación clínica, paciente, profesional, fecha, propósito y versiones anterior y nueva cuando corresponda.

## CU-65 — Generar Sala de Telemedicina

- **Módulo:** Telemedicina
- **Tablas principales:** `telemedicine_rooms`, `appointments`.
- **Tablas relacionadas:** ninguna adicional.
- **Operaciones por tabla:** lectura, inserción o actualización según el flujo; sin eliminación física.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.

## CU-66 — Iniciar Videollamada

- **Módulo:** Telemedicina
- **Tablas principales:** `telemedicine_rooms`, `telemedicine_participants`, `telemedicine_events`.
- **Tablas relacionadas:** ninguna adicional.
- **Operaciones por tabla:** lectura, inserción o actualización según el flujo; sin eliminación física.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.

## CU-67 — Unirse a Videollamada

- **Módulo:** Telemedicina
- **Tablas principales:** `telemedicine_rooms`, `telemedicine_participants`, `telemedicine_events`.
- **Tablas relacionadas:** ninguna adicional.
- **Operaciones por tabla:** lectura, inserción o actualización según el flujo; sin eliminación física.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.

## CU-68 — Finalizar Videollamada

- **Módulo:** Telemedicina
- **Tablas principales:** `telemedicine_rooms`, `telemedicine_participants`, `telemedicine_events`.
- **Tablas relacionadas:** ninguna adicional.
- **Operaciones por tabla:** lectura, inserción o actualización según el flujo; sin eliminación física.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.

## CU-69 — Compartir Archivos Durante Telemedicina

- **Módulo:** Telemedicina
- **Tablas principales:** `telemedicine_shared_files`, `clinical_documents`, `telemedicine_events`.
- **Tablas relacionadas:** `audit_events`.
- **Operaciones por tabla:** lectura, inserción o actualización según el flujo; sin eliminación física.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.
- **Auditoría:** Sí. Registrar acceso o modificación clínica, paciente, profesional, fecha, propósito y versiones anterior y nueva cuando corresponda.

## CU-70 — Registrar Médico

- **Módulo:** Médicos y verificación
- **Tablas principales:** `registration_email_tokens`, `users`, `persons`.
- **Tablas relacionadas:** `professionals`, `personnel_applications`, `audit_events`.
- **Operaciones por tabla:** lectura, inserción o actualización según el flujo; sin eliminación física.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.
- **Auditoría:** Sí. Registrar actor, fecha, acción, resultado, IP o dispositivo y valores modificados cuando corresponda.

## CU-71 — Gestionar Perfil Profesional

- **Módulo:** Médicos y verificación
- **Tablas principales:** `professionals`, `professional_documents`, `professional_specialties`.
- **Tablas relacionadas:** `personnel_applications`, `audit_events`.
- **Operaciones por tabla:** lectura, inserción o actualización según el flujo; sin eliminación física.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.
- **Auditoría:** Sí. Registrar actor, fecha, acción, resultado, IP o dispositivo y valores modificados cuando corresponda.

## CU-72 — Subir Documentación Profesional

- **Módulo:** Médicos y verificación
- **Tablas principales:** `professional_documents`, `professionals`, `audit_events`.
- **Tablas relacionadas:** ninguna adicional.
- **Operaciones por tabla:** lectura, inserción o actualización según el flujo; sin eliminación física.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.
- **Auditoría:** Sí. Registrar actor, fecha, acción, resultado, IP o dispositivo y valores modificados cuando corresponda.

## CU-73 — Consultar Estado de Verificación

- **Módulo:** Médicos y verificación
- **Tablas principales:** `professionals`, `professional_documents`, `professional_specialties`.
- **Tablas relacionadas:** `personnel_applications`, `audit_events`.
- **Operaciones por tabla:** lectura y registro de auditoría.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.
- **Auditoría:** Sí. Registrar actor, fecha, acción, resultado, IP o dispositivo y valores modificados cuando corresponda.

## CU-74 — Revisar Documentación Médica

- **Módulo:** Médicos y verificación
- **Tablas principales:** `professional_documents`, `personnel_applications`, `audit_events`.
- **Tablas relacionadas:** ninguna adicional.
- **Operaciones por tabla:** lectura, inserción o actualización según el flujo; sin eliminación física.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.
- **Auditoría:** Sí. Registrar actor, fecha, acción, resultado, IP o dispositivo y valores modificados cuando corresponda.

## CU-75 — Aprobar Médico

- **Módulo:** Médicos y verificación
- **Tablas principales:** `professionals`, `professional_documents`, `user_roles`.
- **Tablas relacionadas:** `audit_events`.
- **Operaciones por tabla:** lectura, inserción o actualización según el flujo; sin eliminación física.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.
- **Auditoría:** Sí. Registrar actor, fecha, acción, resultado, IP o dispositivo y valores modificados cuando corresponda.

## CU-76 — Rechazar Médico

- **Módulo:** Médicos y verificación
- **Tablas principales:** `professionals`, `professional_documents`, `professional_specialties`.
- **Tablas relacionadas:** `personnel_applications`, `audit_events`.
- **Operaciones por tabla:** lectura, inserción o actualización según el flujo; sin eliminación física.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.
- **Auditoría:** Sí. Registrar actor, fecha, acción, resultado, IP o dispositivo y valores modificados cuando corresponda.

## CU-77 — Actualizar Especialidad Médica

- **Módulo:** Médicos y verificación
- **Tablas principales:** `professionals`, `professional_documents`, `professional_specialties`.
- **Tablas relacionadas:** `personnel_applications`, `audit_events`.
- **Operaciones por tabla:** lectura, inserción o actualización según el flujo; sin eliminación física.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.
- **Auditoría:** Sí. Registrar actor, fecha, acción, resultado, IP o dispositivo y valores modificados cuando corresponda.

## CU-78 — Consultar Turno Actual

- **Módulo:** Turnos
- **Tablas principales:** `work_shifts`, `professionals`.
- **Tablas relacionadas:** ninguna adicional.
- **Operaciones por tabla:** lectura.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.

## CU-79 — Consultar Historial de Turnos

- **Módulo:** Turnos
- **Tablas principales:** `work_shifts`, `work_shift_history`, `professionals`.
- **Tablas relacionadas:** ninguna adicional.
- **Operaciones por tabla:** lectura.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.

## CU-80 — Asignar Turno

- **Módulo:** Turnos
- **Tablas principales:** `work_shifts`, `work_shift_history`, `professionals`.
- **Tablas relacionadas:** ninguna adicional.
- **Operaciones por tabla:** lectura, inserción o actualización según el flujo; sin eliminación física.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.

## CU-81 — Modificar Turnos

- **Módulo:** Turnos
- **Tablas principales:** `work_shifts`, `work_shift_history`, `professionals`.
- **Tablas relacionadas:** ninguna adicional.
- **Operaciones por tabla:** lectura, inserción o actualización según el flujo; sin eliminación física.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.

## CU-82 — Consultar Personal Disponible

- **Módulo:** Turnos
- **Tablas principales:** `professionals`, `work_shifts`, `professional_availability`.
- **Tablas relacionadas:** ninguna adicional.
- **Operaciones por tabla:** lectura.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.

## CU-83 — Solicitar Servicio Domiciliario

- **Módulo:** Servicios domiciliarios
- **Tablas principales:** `home_service_requests`, `service_catalog`, `addresses`.
- **Tablas relacionadas:** `coverage_zones`, `payment_orders`, `payments`.
- **Operaciones por tabla:** lectura, inserción o actualización según el flujo; sin eliminación física.
- **Relaciones necesarias:** la solicitud vincula paciente, servicio, domicilio y cobertura. Al ser presencial, cualquier cobro se registra en fiat mediante QR o efectivo por el profesional responsable.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.

## CU-84 — Seleccionar Tipo de Servicio Domiciliario

- **Módulo:** Servicios domiciliarios
- **Tablas principales:** `home_service_requests`, `service_status_history`, `realtime_locations`.
- **Tablas relacionadas:** `service_evidence`.
- **Operaciones por tabla:** lectura, inserción o actualización según el flujo; sin eliminación física.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.

## CU-85 — Asignar Profesional a Servicio

- **Módulo:** Servicios domiciliarios
- **Tablas principales:** `home_service_requests`, `professionals`, `work_shifts`.
- **Tablas relacionadas:** ninguna adicional.
- **Operaciones por tabla:** lectura, inserción o actualización según el flujo; sin eliminación física.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.

## CU-86 — Aceptar Servicio Domiciliario

- **Módulo:** Servicios domiciliarios
- **Tablas principales:** `home_service_requests`, `service_status_history`, `realtime_locations`.
- **Tablas relacionadas:** `service_evidence`.
- **Operaciones por tabla:** lectura, inserción o actualización según el flujo; sin eliminación física.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.

## CU-87 — Rechazar Servicio Domiciliario

- **Módulo:** Servicios domiciliarios
- **Tablas principales:** `home_service_requests`, `service_status_history`, `realtime_locations`.
- **Tablas relacionadas:** `service_evidence`.
- **Operaciones por tabla:** lectura, inserción o actualización según el flujo; sin eliminación física.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.

## CU-88 — Iniciar Desplazamiento al Domicilio

- **Módulo:** Servicios domiciliarios
- **Tablas principales:** `home_service_requests`, `service_status_history`, `realtime_locations`.
- **Tablas relacionadas:** `service_evidence`.
- **Operaciones por tabla:** lectura, inserción o actualización según el flujo; sin eliminación física.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.

## CU-89 — Compartir Ubicación en Tiempo Real

- **Módulo:** Servicios domiciliarios
- **Tablas principales:** `home_service_requests`, `service_status_history`, `realtime_locations`.
- **Tablas relacionadas:** `service_evidence`.
- **Operaciones por tabla:** lectura, inserción o actualización según el flujo; sin eliminación física.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.

## CU-90 — Consultar Ubicación del Profesional

- **Módulo:** Servicios domiciliarios
- **Tablas principales:** `home_service_requests`, `service_status_history`, `realtime_locations`.
- **Tablas relacionadas:** `service_evidence`.
- **Operaciones por tabla:** lectura.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.

## CU-91 — Actualizar Ubicación en Tiempo Real

- **Módulo:** Servicios domiciliarios
- **Tablas principales:** `home_service_requests`, `service_status_history`, `realtime_locations`.
- **Tablas relacionadas:** `service_evidence`.
- **Operaciones por tabla:** lectura, inserción o actualización según el flujo; sin eliminación física.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.

## CU-92 — Registrar Llegada al Domicilio

- **Módulo:** Servicios domiciliarios
- **Tablas principales:** `home_service_requests`, `service_status_history`, `realtime_locations`.
- **Tablas relacionadas:** `service_evidence`.
- **Operaciones por tabla:** lectura, inserción o actualización según el flujo; sin eliminación física.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.

## CU-93 — Finalizar Servicio Domiciliario

- **Módulo:** Servicios domiciliarios
- **Tablas principales:** `home_service_requests`, `service_status_history`, `realtime_locations`.
- **Tablas relacionadas:** `service_evidence`.
- **Operaciones por tabla:** lectura, inserción o actualización según el flujo; sin eliminación física.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.

## CU-94 — Registrar Evidencia del Servicio

- **Módulo:** Servicios domiciliarios
- **Tablas principales:** `service_evidence`, `home_service_requests`.
- **Tablas relacionadas:** ninguna adicional.
- **Operaciones por tabla:** lectura, inserción o actualización según el flujo; sin eliminación física.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.

## CU-95 — Calificar Servicio Domiciliario

- **Módulo:** Servicios domiciliarios
- **Tablas principales:** `home_service_ratings`, `home_service_requests`.
- **Tablas relacionadas:** ninguna adicional.
- **Operaciones por tabla:** lectura, inserción o actualización según el flujo; sin eliminación física.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.

## CU-96 — Registrar Atención Domiciliaria

- **Módulo:** Servicios domiciliarios
- **Tablas principales:** `home_service_requests`, `clinical_records`, `vital_signs`.
- **Tablas relacionadas:** `clinical_notes`, `audit_events`.
- **Operaciones por tabla:** lectura, inserción o actualización según el flujo; sin eliminación física.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.
- **Auditoría:** Sí. Registrar acceso o modificación clínica, paciente, profesional, fecha, propósito y versiones anterior y nueva cuando corresponda.

## CU-97 — Generar Receta Médica

- **Módulo:** Recetas y negocios
- **Tablas principales:** `prescriptions`, `prescription_items`, `clinical_notes`.
- **Tablas relacionadas:** `audit_events`.
- **Operaciones por tabla:** lectura, inserción o actualización según el flujo; sin eliminación física.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.
- **Auditoría:** Sí. Registrar acceso o modificación clínica, paciente, profesional, fecha, propósito y versiones anterior y nueva cuando corresponda.

## CU-98 — Firmar Receta

- **Módulo:** Recetas y negocios
- **Tablas principales:** `prescriptions`, `audit_events`.
- **Tablas relacionadas:** ninguna adicional.
- **Operaciones por tabla:** lectura, inserción o actualización según el flujo; sin eliminación física.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.
- **Auditoría:** Sí. Registrar acceso o modificación clínica, paciente, profesional, fecha, propósito y versiones anterior y nueva cuando corresponda.

## CU-99 — Consultar Receta

- **Módulo:** Recetas y negocios
- **Tablas principales:** `prescriptions`, `prescription_items`, `audit_events`.
- **Tablas relacionadas:** ninguna adicional.
- **Operaciones por tabla:** lectura y registro de auditoría.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.
- **Auditoría:** Sí. Registrar acceso o modificación clínica, paciente, profesional, fecha, propósito y versiones anterior y nueva cuando corresponda.

## CU-100 — Solicitar Compra de Medicamentos

- **Módulo:** Recetas y negocios
- **Tablas principales:** `partner_requests`, `partner_request_items`, `prescriptions`.
- **Tablas relacionadas:** `payment_orders`, `coin_wallets`, `coin_transactions`, `audit_events`.
- **Operaciones por tabla:** lectura, inserción o actualización según el flujo; sin eliminación física.
- **Relaciones necesarias:** la solicitud se vincula con receta, productos y usuario; si genera cobro al usuario dentro de la plataforma, se paga con monedas.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.

## CU-101 — Seleccionar Negocio Asociado

- **Módulo:** Recetas y negocios
- **Tablas principales:** `prescriptions`, `prescription_items`, `partner_requests`.
- **Tablas relacionadas:** `partner_request_items`, `health_partners`.
- **Operaciones por tabla:** lectura, inserción o actualización según el flujo; sin eliminación física.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.

## CU-102 — Confirmar Solicitud

- **Módulo:** Recetas y negocios
- **Tablas principales:** `partner_requests`, `partner_request_items`, `payment_orders`.
- **Tablas relacionadas:** `coin_wallets`, `coin_transactions`, `audit_events`.
- **Operaciones por tabla:** lectura, inserción o actualización según el flujo; sin eliminación física.
- **Relaciones necesarias:** la confirmación fija los ítems, cantidades y precio en monedas, y vincula la orden con la billetera del usuario.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.

## CU-103 — Consultar Estado de Solicitud

- **Módulo:** Recetas y negocios
- **Tablas principales:** `prescriptions`, `prescription_items`, `partner_requests`.
- **Tablas relacionadas:** `partner_request_items`, `health_partners`.
- **Operaciones por tabla:** lectura.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.

## CU-104 — Registrar Negocio Asociado de Salud

- **Módulo:** Recetas y negocios
- **Tablas principales:** `health_partners`, `partner_documents`, `partner_users`.
- **Tablas relacionadas:** ninguna adicional.
- **Operaciones por tabla:** lectura, inserción o actualización según el flujo; sin eliminación física.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.

## CU-105 — Gestionar Catálogo de Productos o Servicios

- **Módulo:** Recetas y negocios
- **Tablas principales:** `partner_catalog_items`, `health_partners`.
- **Tablas relacionadas:** ninguna adicional.
- **Operaciones por tabla:** lectura, inserción o actualización según el flujo; sin eliminación física.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.

## CU-106 — Recibir Solicitud

- **Módulo:** Recetas y negocios
- **Tablas principales:** `prescriptions`, `prescription_items`, `partner_requests`.
- **Tablas relacionadas:** `partner_request_items`, `health_partners`.
- **Operaciones por tabla:** lectura.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.

## CU-107 — Confirmar Disponibilidad o Atención

- **Módulo:** Recetas y negocios
- **Tablas principales:** `prescriptions`, `prescription_items`, `partner_requests`.
- **Tablas relacionadas:** `partner_request_items`, `health_partners`.
- **Operaciones por tabla:** lectura, inserción o actualización según el flujo; sin eliminación física.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.

## CU-108 — Rechazar Solicitud

- **Módulo:** Recetas y negocios
- **Tablas principales:** `prescriptions`, `prescription_items`, `partner_requests`.
- **Tablas relacionadas:** `partner_request_items`, `health_partners`.
- **Operaciones por tabla:** lectura, inserción o actualización según el flujo; sin eliminación física.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.

## CU-109 — Consultar Entregas Disponibles

- **Módulo:** Entregas
- **Tablas principales:** `deliveries`, `partner_requests`, `coverage_zones`.
- **Tablas relacionadas:** ninguna adicional.
- **Operaciones por tabla:** lectura.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.

## CU-110 — Aceptar Entrega

- **Módulo:** Entregas
- **Tablas principales:** `deliveries`, `delivery_status_history`, `delivery_evidence`.
- **Tablas relacionadas:** ninguna adicional.
- **Operaciones por tabla:** lectura, inserción o actualización según el flujo; sin eliminación física.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.

## CU-111 — Retirar Productos o Insumos

- **Módulo:** Entregas
- **Tablas principales:** `deliveries`, `delivery_status_history`, `delivery_evidence`.
- **Tablas relacionadas:** ninguna adicional.
- **Operaciones por tabla:** lectura, inserción o actualización según el flujo; sin eliminación física.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.

## CU-112 — Entregar Productos o Insumos

- **Módulo:** Entregas
- **Tablas principales:** `deliveries`, `delivery_status_history`, `delivery_evidence`.
- **Tablas relacionadas:** ninguna adicional.
- **Operaciones por tabla:** lectura, inserción o actualización según el flujo; sin eliminación física.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.

## CU-113 — Registrar Evidencia de Entrega

- **Módulo:** Entregas
- **Tablas principales:** `delivery_evidence`, `deliveries`.
- **Tablas relacionadas:** ninguna adicional.
- **Operaciones por tabla:** lectura, inserción o actualización según el flujo; sin eliminación física.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.

## CU-114 — Consultar Paquetes de Monedas

- **Módulo:** Monedas y pagos
- **Tablas principales:** `coin_packages`, `price_list`, `system_settings`.
- **Tablas relacionadas:** ninguna adicional.
- **Operaciones por tabla:** lectura.
- **Relaciones necesarias:** `coin_packages` define cantidad, bonificación, precio y vigencia; solo se muestran paquetes activos dentro de sus fechas de validez.
- **Estados involucrados:** activo, inactivo, próximo a iniciar o vencido.

## CU-115 — Comprar Paquete de Monedas

- **Módulo:** Monedas y pagos
- **Tablas principales:** `coin_packages`, `payment_orders`, `payments`.
- **Tablas relacionadas:** `coin_purchases`, `coin_wallets`, `coin_lots`, `coin_transactions`, `audit_events`.
- **Operaciones por tabla:** lectura e inserción de la orden y compra; actualización del pago; acreditación transaccional del lote y saldo.
- **Relaciones necesarias:** la compra pertenece al usuario y paquete; enlaza una orden y un pago; al aprobarse crea un lote en la billetera y su movimiento de crédito.
- **Estados involucrados:** pendiente de pago, pendiente de validación, pagada, acreditada, rechazada o cancelada.
- **Auditoría:** Sí. Registrar actor, importe o configuración afectada, estado anterior y nuevo, fecha, referencia y motivo.

## CU-116 — Consultar Saldo y Movimientos de Monedas

- **Módulo:** Monedas y pagos
- **Tablas principales:** `coin_wallets`, `coin_lots`, `coin_transactions`.
- **Tablas relacionadas:** `coin_transaction_allocations`.
- **Operaciones por tabla:** lectura del saldo, lotes disponibles y movimientos.
- **Relaciones necesarias:** la billetera pertenece a un usuario; los movimientos afectan la billetera y se distribuyen entre lotes por orden de vencimiento.
- **Estados involucrados:** saldo disponible, reservado, consumido o vencido.

## CU-117 — Consultar Vigencia de Monedas

- **Módulo:** Monedas y pagos
- **Tablas principales:** `coin_lots`, `coin_wallets`, `notifications`.
- **Tablas relacionadas:** ninguna adicional.
- **Operaciones por tabla:** lectura de lotes y fechas de expiración; inserción de avisos de próximo vencimiento cuando corresponda.
- **Relaciones necesarias:** cada lote pertenece a una billetera y, cuando proviene de compra, a `coin_purchases`.
- **Estados involucrados:** vigente, próximo a vencer, agotado o vencido.

## CU-118 — Generar Orden de Cobro

- **Módulo:** Monedas y pagos
- **Tablas principales:** `payment_orders`, `price_list`, `coin_wallets`.
- **Tablas relacionadas:** `coin_transactions`, `system_settings`, `audit_events`.
- **Operaciones por tabla:** lectura del tarifario y configuración; inserción de la orden en monedas o fiat según modalidad.
- **Relaciones necesarias:** la orden enlaza usuario, servicio y atención. Las no presenciales usan monedas; las presenciales, compras de monedas y planes de empresas usan fiat.
- **Estados involucrados:** pendiente, aceptada, pagada, cancelada, expirada o reembolsada.
- **Auditoría:** Sí. Registrar actor, importe o configuración afectada, estado anterior y nuevo, fecha, referencia y motivo.

## CU-119 — Aceptar Cobro

- **Módulo:** Monedas y pagos
- **Tablas principales:** `payment_orders`, `coin_wallets`, `coin_transactions`.
- **Tablas relacionadas:** `coin_lots`, `coin_transaction_allocations`, `audit_events`.
- **Operaciones por tabla:** lectura y actualización de la orden; reserva o débito transaccional de monedas.
- **Relaciones necesarias:** la orden aceptada se vincula con la billetera y consume primero los lotes con vencimiento más cercano.
- **Estados involucrados:** pendiente, aceptada, saldo insuficiente, pagada con monedas o cancelada.
- **Auditoría:** Sí. Registrar actor, importe o configuración afectada, estado anterior y nuevo, fecha, referencia y motivo.

## CU-120 — Subir Comprobante QR

- **Módulo:** Monedas y pagos
- **Tablas principales:** `payments`, `payment_orders`, `coin_purchases`.
- **Tablas relacionadas:** `partner_subscriptions`, `audit_events`.
- **Operaciones por tabla:** inserción del comprobante y actualización del pago a pendiente de validación.
- **Relaciones necesarias:** el comprobante corresponde a una orden fiat por compra de monedas, atención presencial o plan de empresa asociada.
- **Estados involucrados:** pendiente de validación, aprobado o rechazado.
- **Auditoría:** Sí. Registrar actor, importe o configuración afectada, estado anterior y nuevo, fecha, referencia y motivo.

## CU-121 — Registrar Cobro Presencial

- **Módulo:** Monedas y pagos
- **Tablas principales:** `payments`, `professionals`, `appointments`.
- **Tablas relacionadas:** `home_service_requests`, `payment_orders`, `audit_events`.
- **Operaciones por tabla:** inserción del pago QR o efectivo durante la atención y actualización de la orden.
- **Relaciones necesarias:** el pago se vincula con la consulta o servicio presencial y con el médico o enfermero que asistió y realizó el cobro.
- **Estados involucrados:** registrado, pendiente de confirmación, confirmado, observado o rechazado.
- **Auditoría:** Sí. Registrar actor, importe o configuración afectada, estado anterior y nuevo, fecha, referencia y motivo.

## CU-122 — Confirmar Cobro Presencial

- **Módulo:** Monedas y pagos
- **Tablas principales:** `payments`, `payment_orders`, `appointments`.
- **Tablas relacionadas:** `home_service_requests`, `audit_events`.
- **Operaciones por tabla:** lectura y actualización del pago presencial y su orden.
- **Relaciones necesarias:** el usuario confirma el cobro registrado por el profesional responsable de la atención.
- **Estados involucrados:** pendiente de confirmación, confirmado o reportado con diferencia.
- **Auditoría:** Sí. Registrar actor, importe o configuración afectada, estado anterior y nuevo, fecha, referencia y motivo.

## CU-123 — Reportar Diferencia de Cobro

- **Módulo:** Monedas y pagos
- **Tablas principales:** `payment_incidents`, `payments`, `payment_orders`.
- **Tablas relacionadas:** `audit_events`.
- **Operaciones por tabla:** inserción de la incidencia y actualización del pago a observado.
- **Relaciones necesarias:** la incidencia pertenece al pago presencial o QR y al usuario que reporta la diferencia.
- **Estados involucrados:** abierta, en revisión, resuelta o rechazada.
- **Auditoría:** Sí. Registrar actor, importe o configuración afectada, estado anterior y nuevo, fecha, referencia y motivo.

## CU-124 — Aprobar Pago

- **Módulo:** Monedas y pagos
- **Tablas principales:** `payments`, `payment_orders`, `coin_purchases`.
- **Tablas relacionadas:** `coin_wallets`, `coin_lots`, `coin_transactions`, `partner_subscriptions`, `audit_events`.
- **Operaciones por tabla:** actualización transaccional del pago; acreditación de monedas o activación del plan empresarial cuando corresponda.
- **Relaciones necesarias:** un pago aprobado puede acreditar un lote de monedas, confirmar una atención presencial o activar una suscripción empresarial.
- **Estados involucrados:** aprobado, pagado y, según el concepto, acreditado o activo.
- **Auditoría:** Sí. Registrar actor, importe o configuración afectada, estado anterior y nuevo, fecha, referencia y motivo.

## CU-125 — Rechazar Pago

- **Módulo:** Monedas y pagos
- **Tablas principales:** `payments`, `payment_orders`, `coin_purchases`.
- **Tablas relacionadas:** `partner_subscriptions`, `audit_events`.
- **Operaciones por tabla:** actualización del pago, orden y entidad asociada; registro obligatorio del motivo.
- **Relaciones necesarias:** el rechazo se propaga a la compra de monedas o suscripción empresarial vinculada, sin acreditar saldo ni activar el plan.
- **Estados involucrados:** rechazado, pendiente de corrección o cancelado.
- **Auditoría:** Sí. Registrar actor, importe o configuración afectada, estado anterior y nuevo, fecha, referencia y motivo.

## CU-126 — Resolver Incidencia de Pago

- **Módulo:** Monedas y pagos
- **Tablas principales:** `payment_incidents`, `refunds`, `coin_transactions`.
- **Tablas relacionadas:** `payments`, `coin_wallets`, `audit_events`.
- **Operaciones por tabla:** lectura y actualización de la incidencia; inserción de reembolso fiat o devolución de monedas.
- **Relaciones necesarias:** la resolución enlaza el pago original y, si corresponde, la billetera y el movimiento compensatorio.
- **Estados involucrados:** abierta, en revisión, resuelta mediante ajuste, reembolso o devolución de monedas, o rechazada.
- **Auditoría:** Sí. Registrar actor, importe o configuración afectada, estado anterior y nuevo, fecha, referencia y motivo.

## CU-127 — Revisar Solicitud de Incorporación

- **Módulo:** Recursos Humanos
- **Tablas principales:** `personnel_applications`, `personnel_documents`, `professional_documents`.
- **Tablas relacionadas:** `audit_events`.
- **Operaciones por tabla:** lectura, inserción o actualización según el flujo; sin eliminación física.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.
- **Auditoría:** Sí. Registrar responsable, expediente afectado, valores anteriores y nuevos, fecha y motivo.

## CU-128 — Aprobar Incorporación de Personal

- **Módulo:** Recursos Humanos
- **Tablas principales:** `personnel_applications`, `employment_records`, `user_roles`.
- **Tablas relacionadas:** `audit_events`.
- **Operaciones por tabla:** lectura, inserción o actualización según el flujo; sin eliminación física.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.
- **Auditoría:** Sí. Registrar responsable, expediente afectado, valores anteriores y nuevos, fecha y motivo.

## CU-129 — Rechazar Incorporación de Personal

- **Módulo:** Recursos Humanos
- **Tablas principales:** `personnel_applications`, `personnel_documents`, `employment_records`.
- **Tablas relacionadas:** `personnel_observations`, `audit_events`.
- **Operaciones por tabla:** lectura, inserción o actualización según el flujo; sin eliminación física.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.
- **Auditoría:** Sí. Registrar responsable, expediente afectado, valores anteriores y nuevos, fecha y motivo.

## CU-130 — Gestionar Expedientes Laborales

- **Módulo:** Recursos Humanos
- **Tablas principales:** `employment_records`, `personnel_documents`, `professional_documents`.
- **Tablas relacionadas:** `audit_events`.
- **Operaciones por tabla:** lectura, inserción o actualización según el flujo; sin eliminación física.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.
- **Auditoría:** Sí. Registrar responsable, expediente afectado, valores anteriores y nuevos, fecha y motivo.

## CU-131 — Registrar Observaciones Administrativas

- **Módulo:** Recursos Humanos
- **Tablas principales:** `personnel_applications`, `personnel_documents`, `employment_records`.
- **Tablas relacionadas:** `personnel_observations`, `audit_events`.
- **Operaciones por tabla:** lectura, inserción o actualización según el flujo; sin eliminación física.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.
- **Auditoría:** Sí. Registrar responsable, expediente afectado, valores anteriores y nuevos, fecha y motivo.

## CU-132 — Consultar Reportes de Personal

- **Módulo:** Recursos Humanos
- **Tablas principales:** `personnel_applications`, `personnel_documents`, `employment_records`.
- **Tablas relacionadas:** `personnel_observations`.
- **Operaciones por tabla:** lectura.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.

## CU-133 — Gestionar Usuarios

- **Módulo:** Administración
- **Tablas principales:** `users`, `persons`, `user_roles`.
- **Tablas relacionadas:** `audit_events`.
- **Operaciones por tabla:** lectura, inserción o actualización según el flujo; sin eliminación física.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.
- **Auditoría:** Sí. Registrar actor, fecha, acción, resultado, IP o dispositivo y valores modificados cuando corresponda.

## CU-134 — Suspender Usuario

- **Módulo:** Administración
- **Tablas principales:** `users`, `roles`, `permissions`.
- **Tablas relacionadas:** `operating_sites`, `system_settings`, `business_rules`, `audit_events`.
- **Operaciones por tabla:** lectura, inserción o actualización según el flujo; sin eliminación física.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.
- **Auditoría:** Sí. Registrar actor, fecha, acción, resultado, IP o dispositivo y valores modificados cuando corresponda.

## CU-135 — Reactivar Usuario

- **Módulo:** Administración
- **Tablas principales:** `users`, `roles`, `permissions`.
- **Tablas relacionadas:** `operating_sites`, `system_settings`, `business_rules`, `audit_events`.
- **Operaciones por tabla:** lectura, inserción o actualización según el flujo; sin eliminación física.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.
- **Auditoría:** Sí. Registrar actor, fecha, acción, resultado, IP o dispositivo y valores modificados cuando corresponda.

## CU-136 — Gestionar Roles

- **Módulo:** Administración
- **Tablas principales:** `roles`, `user_roles`, `audit_events`.
- **Tablas relacionadas:** ninguna adicional.
- **Operaciones por tabla:** lectura, inserción o actualización según el flujo; sin eliminación física.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.
- **Auditoría:** Sí. Registrar actor, fecha, acción, resultado, IP o dispositivo y valores modificados cuando corresponda.

## CU-137 — Gestionar Permisos

- **Módulo:** Administración
- **Tablas principales:** `permissions`, `role_permissions`, `audit_events`.
- **Tablas relacionadas:** ninguna adicional.
- **Operaciones por tabla:** lectura, inserción o actualización según el flujo; sin eliminación física.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.
- **Auditoría:** Sí. Registrar actor, fecha, acción, resultado, IP o dispositivo y valores modificados cuando corresponda.

## CU-138 — Gestionar Sedes

- **Módulo:** Administración
- **Tablas principales:** `operating_sites`, `coverage_zones`, `audit_events`.
- **Tablas relacionadas:** ninguna adicional.
- **Operaciones por tabla:** lectura, inserción o actualización según el flujo; sin eliminación física.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.
- **Auditoría:** Sí. Registrar actor, entidad afectada, acción, fecha, valores anteriores y nuevos y motivo.

## CU-139 — Gestionar Tarifario

- **Módulo:** Administración
- **Tablas principales:** `service_catalog`, `price_list`, `system_settings`.
- **Tablas relacionadas:** `coin_packages`, `partner_subscription_plans`, `audit_events`.
- **Operaciones por tabla:** lectura, inserción o actualización según el flujo; sin eliminación física.
- **Relaciones necesarias:** el tarifario define precios en monedas para servicios no presenciales y en BOB para atenciones presenciales, paquetes de monedas y planes empresariales.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.
- **Auditoría:** Sí. Registrar actor, importe o configuración afectada, estado anterior y nuevo, fecha, referencia y motivo.

## CU-140 — Gestionar Planes de Empresas Asociadas

- **Módulo:** Administración
- **Tablas principales:** `partner_subscription_plans`, `partner_plan_benefits`, `system_settings`.
- **Tablas relacionadas:** `partner_subscriptions`, `partner_subscription_usage`, `audit_events`.
- **Operaciones por tabla:** lectura, inserción, actualización y desactivación lógica de planes exclusivos para empresas asociadas.
- **Relaciones necesarias:** cada suscripción empresarial vincula una empresa con un plan; los beneficios y consumos dependen de ese plan.
- **Estados involucrados:** borrador, activo, inactivo, vigente, en gracia, vencido o cancelado.
- **Auditoría:** Sí. Registrar actor, importe o configuración afectada, estado anterior y nuevo, fecha, referencia y motivo.

## CU-141 — Gestionar Negocios Asociados de Salud

- **Módulo:** Administración
- **Tablas principales:** `health_partners`, `partner_documents`, `partner_users`.
- **Tablas relacionadas:** `partner_subscription_plans`, `partner_subscriptions`, `audit_events`.
- **Operaciones por tabla:** lectura, inserción o actualización según el flujo; sin eliminación física.
- **Relaciones necesarias:** la empresa asociada enlaza usuarios responsables, documentos, sedes y, cuando corresponda, un plan empresarial vigente.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.
- **Auditoría:** Sí. Registrar actor, importe o configuración afectada, estado anterior y nuevo, fecha, referencia y motivo.

## CU-142 — Consultar Reportes Operativos

- **Módulo:** Administración
- **Tablas principales:** `users`, `roles`, `permissions`.
- **Tablas relacionadas:** `operating_sites`, `system_settings`, `business_rules`.
- **Operaciones por tabla:** lectura.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.

## CU-143 — Registrar Evento de Auditoría

- **Módulo:** Auditoría
- **Tablas principales:** `audit_events`.
- **Tablas relacionadas:** ninguna adicional.
- **Operaciones por tabla:** lectura, inserción o actualización según el flujo; sin eliminación física.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.
- **Auditoría:** Sí. Registrar actor, entidad afectada, acción, fecha, valores anteriores y nuevos y motivo.

## CU-144 — Consultar Auditoría

- **Módulo:** Auditoría
- **Tablas principales:** `audit_events`, `clinical_access_logs`, `clinical_record_versions`.
- **Tablas relacionadas:** ninguna adicional.
- **Operaciones por tabla:** lectura y registro de auditoría.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.
- **Auditoría:** Sí. Registrar actor, entidad afectada, acción, fecha, valores anteriores y nuevos y motivo.

## CU-145 — Auditar Accesos a Historial Clínico

- **Módulo:** Auditoría
- **Tablas principales:** `clinical_access_logs`, `audit_events`.
- **Tablas relacionadas:** ninguna adicional.
- **Operaciones por tabla:** lectura, inserción o actualización según el flujo; sin eliminación física.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.
- **Auditoría:** Sí. Registrar acceso o modificación clínica, paciente, profesional, fecha, propósito y versiones anterior y nueva cuando corresponda.

## CU-146 — Auditar Cambios de Información Clínica

- **Módulo:** Auditoría
- **Tablas principales:** `clinical_record_versions`, `audit_events`.
- **Tablas relacionadas:** ninguna adicional.
- **Operaciones por tabla:** lectura, inserción o actualización según el flujo; sin eliminación física.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.
- **Auditoría:** Sí. Registrar acceso o modificación clínica, paciente, profesional, fecha, propósito y versiones anterior y nueva cuando corresponda.

## CU-147 — Auditar Pagos y Monedas

- **Módulo:** Auditoría
- **Tablas principales:** `payments`, `payment_orders`, `coin_transactions`.
- **Tablas relacionadas:** `coin_purchases`, `partner_subscriptions`, `refunds`, `audit_events`.
- **Operaciones por tabla:** lectura y registro de eventos financieros inmutables.
- **Relaciones necesarias:** la auditoría enlaza pago u operación de monedas con usuario, empresa, orden, servicio y responsable.
- **Estados involucrados:** estado financiero anterior y nuevo, incluida acreditación, consumo, expiración, devolución o rechazo.
- **Auditoría:** Sí. Registrar actor, importe o configuración afectada, estado anterior y nuevo, fecha, referencia y motivo.

## CU-148 — Auditar Entregas de Productos e Insumos de Salud

- **Módulo:** Auditoría
- **Tablas principales:** `deliveries`, `delivery_status_history`, `delivery_evidence`.
- **Tablas relacionadas:** `audit_events`.
- **Operaciones por tabla:** lectura, inserción o actualización según el flujo; sin eliminación física.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.
- **Auditoría:** Sí. Registrar actor, entidad afectada, acción, fecha, valores anteriores y nuevos y motivo.

## CU-149 — Auditar Gestión de Personal

- **Módulo:** Auditoría
- **Tablas principales:** `personnel_applications`, `employment_records`, `personnel_observations`.
- **Tablas relacionadas:** `audit_events`.
- **Operaciones por tabla:** lectura, inserción o actualización según el flujo; sin eliminación física.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.
- **Auditoría:** Sí. Registrar responsable, expediente afectado, valores anteriores y nuevos, fecha y motivo.

## CU-150 — Auditar Seguimiento en Tiempo Real

- **Módulo:** Auditoría
- **Tablas principales:** `realtime_locations`, `audit_events`.
- **Tablas relacionadas:** ninguna adicional.
- **Operaciones por tabla:** lectura, inserción o actualización según el flujo; sin eliminación física.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.
- **Auditoría:** Sí. Registrar responsable, caso afectado, transición de estado, fecha, ubicación cuando corresponda, motivo y resultado.

## CU-151 — Consultar Beneficios Disponibles

- **Módulo:** Beneficios
- **Tablas principales:** `benefits`, `partner_plan_benefits`, `partner_benefits`.
- **Tablas relacionadas:** ninguna adicional.
- **Operaciones por tabla:** lectura.
- **Relaciones necesarias:** los beneficios pueden ser generales, aplicables a cobros en monedas o asociados a planes y convenios de empresas.
- **Estados involucrados:** activo, inactivo, próximo, vigente o vencido.

## CU-152 — Aplicar Beneficio o Descuento

- **Módulo:** Beneficios
- **Tablas principales:** `benefit_usages`, `benefits`, `payment_orders`.
- **Tablas relacionadas:** `audit_events`.
- **Operaciones por tabla:** lectura, inserción o actualización según el flujo; sin eliminación física.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.
- **Auditoría:** Sí. Registrar actor, importe o configuración afectada, estado anterior y nuevo, fecha, referencia y motivo.

## CU-153 — Validar Beneficio por Negocio Asociado

- **Módulo:** Beneficios
- **Tablas principales:** `benefit_validations`, `partner_benefits`, `benefit_usages`.
- **Tablas relacionadas:** `audit_events`.
- **Operaciones por tabla:** lectura, inserción o actualización según el flujo; sin eliminación física.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.
- **Auditoría:** Sí. Registrar actor, importe o configuración afectada, estado anterior y nuevo, fecha, referencia y motivo.

## CU-154 — Gestionar Beneficios y Descuentos

- **Módulo:** Beneficios
- **Tablas principales:** `benefits`, `partner_plan_benefits`, `partner_benefits`.
- **Tablas relacionadas:** `benefit_usages`, `audit_events`.
- **Operaciones por tabla:** lectura, inserción, actualización y desactivación lógica.
- **Relaciones necesarias:** el beneficio puede descontar monedas o fiat y asociarse a una empresa o a su plan.
- **Estados involucrados:** borrador, activo, suspendido, agotado o vencido.
- **Auditoría:** Sí. Registrar actor, importe o configuración afectada, estado anterior y nuevo, fecha, referencia y motivo.

## CU-155 — Consultar Historial de Beneficios Utilizados

- **Módulo:** Beneficios
- **Tablas principales:** `benefits`, `benefit_usages`, `partner_plan_benefits`.
- **Tablas relacionadas:** `partner_benefits`.
- **Operaciones por tabla:** lectura.
- **Relaciones necesarias:** cada uso enlaza beneficio, paciente y orden; registra descuento en monedas o fiat.
- **Estados involucrados:** aplicado, validado, rechazado o revertido.

## CU-156 — Cambiar Contraseña

- **Módulo:** Complementarias
- **Tablas principales:** `users`, `password_reset_tokens`, `user_sessions`.
- **Tablas relacionadas:** `audit_events`.
- **Operaciones por tabla:** lectura, inserción o actualización según el flujo; sin eliminación física.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.
- **Auditoría:** Sí. Registrar actor, fecha, acción, resultado, IP o dispositivo y valores modificados cuando corresponda.

## CU-157 — Verificar Teléfono y Correo Electrónico

- **Módulo:** Complementarias
- **Tablas principales:** `registration_email_tokens`, `users`, `audit_events`.
- **Tablas relacionadas:** ninguna adicional.
- **Operaciones por tabla:** lectura y registro de auditoría.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.
- **Auditoría:** Sí. Registrar actor, fecha, acción, resultado, IP o dispositivo y valores modificados cuando corresponda.

## CU-158 — Solicitar Estudio Diagnóstico

- **Módulo:** Complementarias
- **Tablas principales:** `diagnostic_orders`, `clinical_notes`, `health_partners`.
- **Tablas relacionadas:** `audit_events`.
- **Operaciones por tabla:** lectura, inserción o actualización según el flujo; sin eliminación física.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.
- **Auditoría:** Sí. Registrar acceso o modificación clínica, paciente, profesional, fecha, propósito y versiones anterior y nueva cuando corresponda.

## CU-159 — Cargar Resultado de Estudio Diagnóstico

- **Módulo:** Complementarias
- **Tablas principales:** `diagnostic_orders`, `clinical_documents`, `audit_events`.
- **Tablas relacionadas:** ninguna adicional.
- **Operaciones por tabla:** lectura, inserción o actualización según el flujo; sin eliminación física.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.
- **Auditoría:** Sí. Registrar acceso o modificación clínica, paciente, profesional, fecha, propósito y versiones anterior y nueva cuando corresponda.

## CU-160 — Consultar Gráficos y Tendencias Clínicas

- **Módulo:** Complementarias
- **Tablas principales:** `vital_signs`, `clinical_records`, `audit_events`.
- **Tablas relacionadas:** ninguna adicional.
- **Operaciones por tabla:** lectura y registro de auditoría.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.
- **Auditoría:** Sí. Registrar acceso o modificación clínica, paciente, profesional, fecha, propósito y versiones anterior y nueva cuando corresponda.

## CU-161 — Gestionar Preferencias de Notificación

- **Módulo:** Complementarias
- **Tablas principales:** `notification_preferences`, `notifications`.
- **Tablas relacionadas:** ninguna adicional.
- **Operaciones por tabla:** lectura, inserción o actualización según el flujo; sin eliminación física.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.

## CU-162 — Solicitar Corrección de Información

- **Módulo:** Complementarias
- **Tablas principales:** `clinical_correction_requests`, `clinical_record_versions`, `audit_events`.
- **Tablas relacionadas:** ninguna adicional.
- **Operaciones por tabla:** lectura, inserción o actualización según el flujo; sin eliminación física.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.
- **Auditoría:** Sí. Registrar acceso o modificación clínica, paciente, profesional, fecha, propósito y versiones anterior y nueva cuando corresponda.

## CU-163 — Reportar Incidente Clínico o Técnico

- **Módulo:** Complementarias
- **Tablas principales:** `incidents`, `notifications`, `audit_events`.
- **Tablas relacionadas:** ninguna adicional.
- **Operaciones por tabla:** lectura, inserción o actualización según el flujo; sin eliminación física.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.
- **Auditoría:** Sí. Registrar acceso o modificación clínica, paciente, profesional, fecha, propósito y versiones anterior y nueva cuando corresponda.

## CU-164 — Registrar Información Clínica Autodeclarada

- **Módulo:** Complementarias
- **Tablas principales:** `clinical_records`, `medical_antecedents`, `allergies`.
- **Tablas relacionadas:** `clinical_documents`, `audit_events`.
- **Operaciones por tabla:** lectura, inserción o actualización según el flujo; sin eliminación física.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.
- **Auditoría:** Sí. Registrar acceso o modificación clínica, paciente, profesional, fecha, propósito y versiones anterior y nueva cuando corresponda.

## CU-165 — Validar Información Clínica Autodeclarada

- **Módulo:** Complementarias
- **Tablas principales:** `clinical_records`, `clinical_record_versions`, `medical_antecedents`.
- **Tablas relacionadas:** `allergies`, `audit_events`.
- **Operaciones por tabla:** lectura, inserción o actualización según el flujo; sin eliminación física.
- **Relaciones necesarias:** claves foráneas hacia usuario, paciente, profesional y entidad de origen según corresponda.
- **Estados involucrados:** estados propios del módulo e historial de transición cuando exista cambio de ciclo de vida.
- **Auditoría:** Sí. Registrar acceso o modificación clínica, paciente, profesional, fecha, propósito y versiones anterior y nueva cuando corresponda.

## Notas para la API

1. La existencia de tablas no sustituye las autorizaciones por rol, relación con el paciente y propósito.
2. Los archivos, campos sensibles y secretos MFA requieren cifrado y gestión de claves fuera del SQL.
3. La API debe leer parámetros desde `system_settings` y `business_rules`; no debe hardcodearlos.
4. HL7 FHIR se implementará mediante mapeos de Patient, Observation, Encounter, Condition, MedicationRequest, Consent, Permission y AuditEvent.
