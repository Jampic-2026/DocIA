-- ============================================================
-- SEED INICIAL
-- ============================================================

INSERT INTO roles (code, name, description, is_system)
VALUES
('admin', 'Administrador de plataforma', 'Gestiona usuarios, configuración, catálogos, permisos y reportes no clínicos.', TRUE),
('patient', 'Paciente', 'Solicita orientación, consultas, emergencias y consulta su información.', TRUE),
('guardian', 'Tutor / Apoderado / Cuidador', 'Administra perfiles dependientes y permisos autorizados.', TRUE),
('doctor_general', 'Médico general', 'Realiza primer contacto, diagnóstico, tratamiento, receta, seguimiento y derivación.', TRUE),
('doctor_specialist', 'Médico especialista', 'Atiende consultas especializadas permitidas o derivadas.', TRUE),
('nurse', 'Profesional de enfermería', 'Registra signos vitales, valoración de enfermería y procedimientos permitidos.', TRUE),
('operator', 'Operador clínico / coordinador', 'Atiende llamadas, coordina emergencias y soporte humano.', TRUE),
('clinical_supervisor', 'Supervisor clínico', 'Revisa protocolos, calidad clínica e incidentes.', TRUE),
('health_partner', 'Proveedor de salud aliado', 'Laboratorio, imagenología, clínica, farmacia, ambulancia u otro aliado.', TRUE),
('delivery_assistant', 'Auxiliar de entrega', 'Gestiona retiro, traslado y entrega de productos e insumos.', TRUE),
('human_resources', 'Recursos Humanos', 'Valida incorporaciones, expedientes, turnos y personal.', TRUE)
ON CONFLICT (code) DO NOTHING;

INSERT INTO permissions (code, module, description)
VALUES
('users.read', 'users', 'Consultar usuarios y datos de seguridad autorizados.'),
('users.update', 'users', 'Actualizar usuarios autorizados.'),
('auth.sessions.manage', 'auth', 'Consultar y revocar sesiones de usuario.'),
('people.read', 'people', 'Consultar datos personales autorizados.'),
('patients.read', 'patients', 'Consultar pacientes autorizados.'),
('patients.manage', 'patients', 'Gestionar pacientes, tutores y familiares autorizados.'),
('consents.read', 'consents', 'Consultar consentimientos autorizados.'),
('consents.manage', 'consents', 'Registrar o revocar consentimientos autorizados.'),
('professionals.read', 'professionals', 'Consultar profesionales, especialidades y disponibilidad.'),
('professionals.manage', 'professionals', 'Gestionar profesionales, disponibilidad y turnos.'),
('clinical_records.read', 'clinical_records', 'Consultar información clínica autorizada.'),
('clinical_records.manage', 'clinical_records', 'Registrar o corregir información clínica autorizada.'),
('emergencies.read', 'emergencies', 'Consultar emergencias autorizadas.'),
('emergencies.manage', 'emergencies', 'Registrar, coordinar y actualizar emergencias.'),
('ai.use', 'ai', 'Utilizar orientación y asistencia mediante inteligencia artificial.'),
('ai.manage', 'ai', 'Supervisar conversaciones y evaluaciones de riesgo de IA.'),
('appointments.read', 'appointments', 'Consultar citas y telemedicina autorizadas.'),
('appointments.manage', 'appointments', 'Crear y gestionar citas y telemedicina autorizadas.'),
('prescriptions.read', 'prescriptions', 'Consultar recetas autorizadas.'),
('prescriptions.manage', 'prescriptions', 'Emitir y gestionar recetas autorizadas.'),
('catalog.read', 'catalog', 'Consultar catálogo y tarifario.'),
('catalog.manage', 'catalog', 'Gestionar catálogo y tarifario.'),
('coins.read', 'coins', 'Consultar billetera y movimientos autorizados.'),
('coins.manage', 'coins', 'Gestionar monedas y movimientos autorizados.'),
('payments.read', 'payments', 'Consultar pagos autorizados.'),
('payments.manage', 'payments', 'Gestionar pagos, devoluciones e incidencias.'),
('benefits.read', 'benefits', 'Consultar beneficios autorizados.'),
('benefits.manage', 'benefits', 'Gestionar beneficios y validaciones.'),
('partners.read', 'partners', 'Consultar empresas asociadas autorizadas.'),
('partners.manage', 'partners', 'Gestionar empresas asociadas, planes y solicitudes.'),
('home_services.read', 'home_services', 'Consultar servicios domiciliarios autorizados.'),
('home_services.manage', 'home_services', 'Gestionar servicios domiciliarios autorizados.'),
('deliveries.read', 'deliveries', 'Consultar entregas autorizadas.'),
('deliveries.manage', 'deliveries', 'Gestionar entregas autorizadas.'),
('incidents.read', 'incidents', 'Consultar incidentes autorizados.'),
('incidents.manage', 'incidents', 'Registrar y gestionar incidentes.'),
('human_resources.read', 'human_resources', 'Consultar información autorizada de recursos humanos.'),
('human_resources.manage', 'human_resources', 'Gestionar postulaciones, expedientes y personal.'),
('notifications.read', 'notifications', 'Consultar notificaciones propias o autorizadas.'),
('notifications.manage', 'notifications', 'Gestionar preferencias y envío de notificaciones.'),
('administration.read', 'administration', 'Consultar configuración y reglas operativas.'),
('administration.manage', 'administration', 'Gestionar configuración y reglas operativas.'),
('audit.read', 'audit', 'Consultar auditoría y accesos clínicos autorizados.')
ON CONFLICT (code) DO UPDATE
SET module = EXCLUDED.module,
    description = EXCLUDED.description;

-- El administrador recibe el catálogo completo.
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r
CROSS JOIN permissions p
WHERE r.code = 'admin'
ON CONFLICT DO NOTHING;

-- Asignaciones base por rol. Las policies RLS siguen limitando las filas.
WITH role_permission_values(role_code, permission_code) AS (
    VALUES
    ('patient', 'people.read'),
    ('patient', 'patients.read'),
    ('patient', 'patients.manage'),
    ('patient', 'consents.read'),
    ('patient', 'consents.manage'),
    ('patient', 'professionals.read'),
    ('patient', 'clinical_records.read'),
    ('patient', 'emergencies.read'),
    ('patient', 'emergencies.manage'),
    ('patient', 'ai.use'),
    ('patient', 'appointments.read'),
    ('patient', 'appointments.manage'),
    ('patient', 'prescriptions.read'),
    ('patient', 'catalog.read'),
    ('patient', 'coins.read'),
    ('patient', 'payments.read'),
    ('patient', 'benefits.read'),
    ('patient', 'home_services.read'),
    ('patient', 'home_services.manage'),
    ('patient', 'notifications.read'),
    ('patient', 'notifications.manage'),
    ('patient', 'incidents.read'),

    ('guardian', 'people.read'),
    ('guardian', 'patients.read'),
    ('guardian', 'patients.manage'),
    ('guardian', 'consents.read'),
    ('guardian', 'consents.manage'),
    ('guardian', 'professionals.read'),
    ('guardian', 'clinical_records.read'),
    ('guardian', 'emergencies.read'),
    ('guardian', 'emergencies.manage'),
    ('guardian', 'ai.use'),
    ('guardian', 'appointments.read'),
    ('guardian', 'appointments.manage'),
    ('guardian', 'prescriptions.read'),
    ('guardian', 'catalog.read'),
    ('guardian', 'coins.read'),
    ('guardian', 'payments.read'),
    ('guardian', 'benefits.read'),
    ('guardian', 'home_services.read'),
    ('guardian', 'home_services.manage'),
    ('guardian', 'notifications.read'),
    ('guardian', 'notifications.manage'),
    ('guardian', 'incidents.read'),

    ('doctor_general', 'people.read'),
    ('doctor_general', 'patients.read'),
    ('doctor_general', 'consents.read'),
    ('doctor_general', 'professionals.read'),
    ('doctor_general', 'clinical_records.read'),
    ('doctor_general', 'clinical_records.manage'),
    ('doctor_general', 'emergencies.read'),
    ('doctor_general', 'emergencies.manage'),
    ('doctor_general', 'appointments.read'),
    ('doctor_general', 'appointments.manage'),
    ('doctor_general', 'prescriptions.read'),
    ('doctor_general', 'prescriptions.manage'),
    ('doctor_general', 'catalog.read'),
    ('doctor_general', 'payments.read'),
    ('doctor_general', 'home_services.read'),
    ('doctor_general', 'home_services.manage'),
    ('doctor_general', 'notifications.read'),
    ('doctor_general', 'notifications.manage'),
    ('doctor_general', 'incidents.read'),

    ('doctor_specialist', 'people.read'),
    ('doctor_specialist', 'patients.read'),
    ('doctor_specialist', 'consents.read'),
    ('doctor_specialist', 'professionals.read'),
    ('doctor_specialist', 'clinical_records.read'),
    ('doctor_specialist', 'clinical_records.manage'),
    ('doctor_specialist', 'emergencies.read'),
    ('doctor_specialist', 'appointments.read'),
    ('doctor_specialist', 'appointments.manage'),
    ('doctor_specialist', 'prescriptions.read'),
    ('doctor_specialist', 'prescriptions.manage'),
    ('doctor_specialist', 'catalog.read'),
    ('doctor_specialist', 'payments.read'),
    ('doctor_specialist', 'notifications.read'),
    ('doctor_specialist', 'notifications.manage'),
    ('doctor_specialist', 'incidents.read'),

    ('nurse', 'people.read'),
    ('nurse', 'patients.read'),
    ('nurse', 'consents.read'),
    ('nurse', 'professionals.read'),
    ('nurse', 'clinical_records.read'),
    ('nurse', 'clinical_records.manage'),
    ('nurse', 'emergencies.read'),
    ('nurse', 'emergencies.manage'),
    ('nurse', 'appointments.read'),
    ('nurse', 'appointments.manage'),
    ('nurse', 'catalog.read'),
    ('nurse', 'payments.read'),
    ('nurse', 'home_services.read'),
    ('nurse', 'home_services.manage'),
    ('nurse', 'notifications.read'),
    ('nurse', 'notifications.manage'),
    ('nurse', 'incidents.read'),

    ('operator', 'patients.read'),
    ('operator', 'clinical_records.read'),
    ('operator', 'emergencies.read'),
    ('operator', 'emergencies.manage'),
    ('operator', 'appointments.read'),
    ('operator', 'home_services.read'),
    ('operator', 'home_services.manage'),
    ('operator', 'incidents.read'),
    ('operator', 'incidents.manage'),
    ('operator', 'notifications.read'),
    ('operator', 'notifications.manage'),

    ('clinical_supervisor', 'patients.read'),
    ('clinical_supervisor', 'professionals.read'),
    ('clinical_supervisor', 'clinical_records.read'),
    ('clinical_supervisor', 'clinical_records.manage'),
    ('clinical_supervisor', 'emergencies.read'),
    ('clinical_supervisor', 'emergencies.manage'),
    ('clinical_supervisor', 'ai.manage'),
    ('clinical_supervisor', 'appointments.read'),
    ('clinical_supervisor', 'incidents.read'),
    ('clinical_supervisor', 'incidents.manage'),
    ('clinical_supervisor', 'audit.read'),

    ('health_partner', 'catalog.read'),
    ('health_partner', 'prescriptions.read'),
    ('health_partner', 'partners.read'),
    ('health_partner', 'partners.manage'),
    ('health_partner', 'deliveries.read'),
    ('health_partner', 'payments.read'),
    ('health_partner', 'benefits.read'),
    ('health_partner', 'benefits.manage'),
    ('health_partner', 'notifications.read'),
    ('health_partner', 'notifications.manage'),
    ('health_partner', 'incidents.read'),

    ('delivery_assistant', 'partners.read'),
    ('delivery_assistant', 'deliveries.read'),
    ('delivery_assistant', 'deliveries.manage'),
    ('delivery_assistant', 'incidents.read'),
    ('delivery_assistant', 'notifications.read'),
    ('delivery_assistant', 'notifications.manage'),

    ('human_resources', 'people.read'),
    ('human_resources', 'professionals.read'),
    ('human_resources', 'professionals.manage'),
    ('human_resources', 'human_resources.read'),
    ('human_resources', 'human_resources.manage'),
    ('human_resources', 'notifications.read'),
    ('human_resources', 'notifications.manage'),
    ('human_resources', 'incidents.read')
)
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM role_permission_values values_to_assign
JOIN roles r ON r.code = values_to_assign.role_code
JOIN permissions p ON p.code = values_to_assign.permission_code
ON CONFLICT DO NOTHING;

INSERT INTO consent_types (code, name, description, version, is_required)
VALUES
('terms', 'Términos y condiciones', 'Aceptación de condiciones generales de uso.', '1.0', TRUE),
('privacy', 'Política de privacidad', 'Tratamiento de datos personales y clínicos.', '1.0', TRUE),
('telemedicine', 'Consentimiento de telemedicina', 'Aceptación para atención por videollamada.', '1.0', FALSE),
('ai_orientation', 'Consentimiento de orientación con IA', 'Uso de asistente digital para orientación y clasificación de riesgo.', '1.0', FALSE),
('geolocation', 'Consentimiento de geolocalización', 'Uso de ubicación para emergencias y servicios domiciliarios.', '1.0', FALSE),
('family_profile', 'Consentimiento de perfil familiar/dependiente', 'Administración de perfiles vinculados por tutor o familiar autorizado.', '1.0', FALSE),
('iot_vitals', 'Consentimiento de signos vitales IoT', 'Captura y uso de mediciones desde dispositivos.', '1.0', FALSE)
ON CONFLICT (code) DO NOTHING;

-- Normaliza cuentas creadas antes de que términos y privacidad fueran
-- obligatorios. Las cuentas nuevas los aceptan dentro de la transacción de
-- registro y no pueden completarse sin esa aceptación.
INSERT INTO patient_consents(
    patient_id, consent_type_id, granted_by_user_id, status
)
SELECT patient.id, type.id, person.user_id, 'accepted'
FROM patients patient
JOIN persons person ON person.id=patient.person_id
CROSS JOIN consent_types type
WHERE person.user_id IS NOT NULL
  AND type.is_required AND type.is_active
  AND NOT EXISTS (
      SELECT 1 FROM patient_consents consent
      WHERE consent.patient_id=patient.id
        AND consent.consent_type_id=type.id
        AND consent.status='accepted'
  );

INSERT INTO specialties (name, description)
VALUES
('Medicina General', 'Atención médica general y primer contacto.'),
('Medicina Familiar', 'Atención integral y seguimiento familiar.'),
('Pediatría', 'Atención médica de niños y adolescentes.'),
('Cardiología', 'Atención de enfermedades cardiovasculares.'),
('Ginecología y Obstetricia', 'Atención ginecológica y obstétrica.'),
('Dermatología', 'Atención de enfermedades de la piel.'),
('Endocrinología', 'Atención de trastornos endocrinos y metabólicos.'),
('Gastroenterología', 'Atención del sistema digestivo.'),
('Neurología', 'Atención del sistema nervioso.'),
('Neumología', 'Atención del sistema respiratorio.'),
('Reumatología', 'Atención de enfermedades reumatológicas.'),
('Psiquiatría', 'Atención médica de salud mental.'),
('Psicología', 'Orientación y atención psicológica.'),
('Traumatología y Ortopedia', 'Atención de lesiones y enfermedades musculoesqueléticas.'),
('Urología', 'Atención del sistema urinario y reproductor masculino.'),
('Otorrinolaringología', 'Atención de oído, nariz y garganta.'),
('Oftalmología', 'Atención de salud visual.'),
('Nutrición', 'Evaluación y seguimiento nutricional.'),
('Fisioterapia y Rehabilitación', 'Rehabilitación física y funcional.')
ON CONFLICT (name) DO NOTHING;

-- Los montos, cantidades y bonificaciones de paquetes de monedas se definirán
-- desde administración cuando el modelo comercial sea aprobado.
-- Los nombres, precios, límites y beneficios de planes empresariales también
-- permanecen configurables y no se fijan como datos iniciales.

-- El lanzamiento puede mantenerse gratuito. Cuando monetization_enabled pase a true,
-- todo servicio no presencial cobrable usa monedas; los servicios presenciales usan QR o efectivo.
INSERT INTO system_settings (setting_key, value, description, requires_clinical_approval)
VALUES
('monetization_enabled', 'false'::jsonb, 'Activa los cobros definidos en el tarifario.', FALSE),
('user_charge_unit', '"coins"'::jsonb, 'Unidad de cobro para servicios no presenciales de usuarios.', FALSE),
('coin_expiration_days', '365'::jsonb, 'Vigencia de cada lote de monedas desde su acreditación.', FALSE),
('coins.expiration_notice_days', '30'::jsonb, 'Días de anticipación para avisar el vencimiento de monedas.', FALSE),
('in_person_payment_methods', '["qr", "cash"]'::jsonb, 'Métodos permitidos para servicios presenciales.', FALSE),
('user_subscriptions_enabled', 'false'::jsonb, 'Los usuarios no utilizan planes ni suscripciones.', FALSE),
('partner_subscriptions_enabled', 'true'::jsonb, 'Los planes se aplican exclusivamente a empresas asociadas.', FALSE),
('partners.grace_period_days', '7'::jsonb, 'Duración del periodo de gracia para suscripciones empresariales.', FALSE),
('emergency_available_to_all', 'true'::jsonb, 'El botón de emergencia no depende del plan.', TRUE),
('direct_specialist_access_enabled', 'true'::jsonb, 'Permite elección directa con aviso informativo.', TRUE),
('minor_guardian_link_required', 'true'::jsonb, 'Exige vínculo con adulto registrado para menores.', TRUE)
ON CONFLICT (setting_key) DO NOTHING;

INSERT INTO service_catalog (code, name, category, description)
VALUES
('consult_general_telemedicine', 'Consulta médica general por telemedicina', 'consultation', 'Consulta virtual con médico general.'),
('consult_specialist_telemedicine', 'Consulta especialista por telemedicina', 'consultation', 'Consulta virtual con especialista autorizado.'),
('emergency_coordination', 'Coordinación de emergencia médica', 'emergency', 'Registro y coordinación de emergencia según cobertura y protocolo.'),
('support_call', 'Llamada de orientación', 'consultation', 'Llamada con operador o personal autorizado.'),
('coin_package_purchase', 'Compra de paquete de monedas', 'coin_package', 'Carga de monedas Doc IA con vigencia de un año.')
ON CONFLICT (code) DO NOTHING;

-- ============================================================
-- FIN
-- ============================================================
