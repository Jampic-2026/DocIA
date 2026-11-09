-- ============================================================
-- CATÁLOGO DE PERMISOS Y ASIGNACIONES BASE POR ROL
-- ============================================================
-- Este archivo actualiza bases ya creadas. Las policies RLS siguen siendo
-- responsables de limitar las filas visibles dentro de cada permiso.

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

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM roles r
CROSS JOIN permissions p
WHERE r.code = 'admin'
ON CONFLICT DO NOTHING;

WITH grant_matrix(role_code, permission_codes) AS (
    VALUES
    (
        'patient',
        ARRAY[
            'people.read', 'patients.read', 'patients.manage',
            'consents.read', 'consents.manage', 'professionals.read',
            'clinical_records.read', 'emergencies.read', 'emergencies.manage',
            'ai.use', 'appointments.read', 'appointments.manage',
            'prescriptions.read', 'catalog.read', 'coins.read', 'payments.read',
            'benefits.read', 'home_services.read', 'home_services.manage',
            'notifications.read', 'notifications.manage', 'incidents.read'
        ]::TEXT[]
    ),
    (
        'guardian',
        ARRAY[
            'people.read', 'patients.read', 'patients.manage',
            'consents.read', 'consents.manage', 'professionals.read',
            'clinical_records.read', 'emergencies.read', 'emergencies.manage',
            'ai.use', 'appointments.read', 'appointments.manage',
            'prescriptions.read', 'catalog.read', 'coins.read', 'payments.read',
            'benefits.read', 'home_services.read', 'home_services.manage',
            'notifications.read', 'notifications.manage', 'incidents.read'
        ]::TEXT[]
    ),
    (
        'doctor_general',
        ARRAY[
            'people.read', 'patients.read', 'consents.read',
            'professionals.read', 'clinical_records.read',
            'clinical_records.manage', 'emergencies.read',
            'emergencies.manage', 'appointments.read', 'appointments.manage',
            'prescriptions.read', 'prescriptions.manage', 'catalog.read',
            'payments.read', 'home_services.read', 'home_services.manage',
            'notifications.read', 'notifications.manage', 'incidents.read'
        ]::TEXT[]
    ),
    (
        'doctor_specialist',
        ARRAY[
            'people.read', 'patients.read', 'consents.read',
            'professionals.read', 'clinical_records.read',
            'clinical_records.manage', 'emergencies.read',
            'appointments.read', 'appointments.manage', 'prescriptions.read',
            'prescriptions.manage', 'catalog.read', 'payments.read',
            'notifications.read', 'notifications.manage', 'incidents.read'
        ]::TEXT[]
    ),
    (
        'nurse',
        ARRAY[
            'people.read', 'patients.read', 'consents.read',
            'professionals.read', 'clinical_records.read',
            'clinical_records.manage', 'emergencies.read',
            'emergencies.manage', 'appointments.read', 'appointments.manage',
            'catalog.read', 'payments.read', 'home_services.read',
            'home_services.manage', 'notifications.read',
            'notifications.manage', 'incidents.read'
        ]::TEXT[]
    ),
    (
        'operator',
        ARRAY[
            'patients.read', 'clinical_records.read', 'emergencies.read',
            'emergencies.manage', 'appointments.read', 'home_services.read',
            'home_services.manage', 'incidents.read', 'incidents.manage',
            'notifications.read', 'notifications.manage'
        ]::TEXT[]
    ),
    (
        'clinical_supervisor',
        ARRAY[
            'patients.read', 'professionals.read', 'clinical_records.read',
            'clinical_records.manage', 'emergencies.read',
            'emergencies.manage', 'ai.manage', 'appointments.read',
            'incidents.read', 'incidents.manage', 'audit.read'
        ]::TEXT[]
    ),
    (
        'health_partner',
        ARRAY[
            'catalog.read', 'prescriptions.read', 'partners.read',
            'partners.manage', 'deliveries.read', 'payments.read',
            'benefits.read', 'benefits.manage', 'notifications.read',
            'notifications.manage', 'incidents.read'
        ]::TEXT[]
    ),
    (
        'delivery_assistant',
        ARRAY[
            'partners.read', 'deliveries.read', 'deliveries.manage',
            'incidents.read', 'notifications.read',
            'notifications.manage'
        ]::TEXT[]
    ),
    (
        'human_resources',
        ARRAY[
            'people.read', 'professionals.read', 'professionals.manage',
            'human_resources.read', 'human_resources.manage',
            'notifications.read', 'notifications.manage', 'incidents.read'
        ]::TEXT[]
    )
),
expanded_grants AS (
    SELECT role_code, unnest(permission_codes) AS permission_code
    FROM grant_matrix
)
INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM expanded_grants grants
JOIN roles r ON r.code = grants.role_code
JOIN permissions p ON p.code = grants.permission_code
ON CONFLICT DO NOTHING;
