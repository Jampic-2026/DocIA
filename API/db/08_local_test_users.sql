-- ============================================================
-- USUARIOS LOCALES DE PRUEBA
-- ============================================================
-- Este archivo es solo para desarrollo local.
-- Se aplica con npm run db:apply únicamente si DB_APPLY_LOCAL_SEEDS=true.
-- Password común para todos los usuarios: Jampic123!

WITH test_users(role_code, email, phone, first_name, last_name, document_number) AS (
    VALUES
    ('admin', 'admin@jampic.local', '+59170000001', 'Admin', 'Jampic', 'TEST-ADMIN'),
    ('patient', 'patient@jampic.local', '+59170000002', 'Paciente', 'Prueba', 'TEST-PATIENT'),
    ('guardian', 'guardian@jampic.local', '+59170000003', 'Tutor', 'Prueba', 'TEST-GUARDIAN'),
    ('doctor_general', 'doctor.general@jampic.local', '+59170000004', 'Medico', 'General', 'TEST-DOC-GEN'),
    ('doctor_specialist', 'doctor.specialist@jampic.local', '+59170000005', 'Medico', 'Especialista', 'TEST-DOC-SPEC'),
    ('nurse', 'nurse@jampic.local', '+59170000006', 'Enfermeria', 'Prueba', 'TEST-NURSE'),
    ('operator', 'operator@jampic.local', '+59170000007', 'Operador', 'Clinico', 'TEST-OPERATOR'),
    ('clinical_supervisor', 'clinical.supervisor@jampic.local', '+59170000008', 'Supervisor', 'Clinico', 'TEST-SUPERVISOR'),
    ('health_partner', 'partner@jampic.local', '+59170000009', 'Aliado', 'Salud', 'TEST-PARTNER'),
    ('delivery_assistant', 'delivery@jampic.local', '+59170000010', 'Auxiliar', 'Entrega', 'TEST-DELIVERY'),
    ('human_resources', 'hr@jampic.local', '+59170000011', 'Recursos', 'Humanos', 'TEST-HR')
), inserted_users AS (
    INSERT INTO users (role_id, email, phone, password_hash, status, email_verified_at)
    SELECT r.id, tu.email, tu.phone, crypt('Jampic123!', gen_salt('bf')), 'active', now()
    FROM test_users tu
    JOIN roles r ON r.code = tu.role_code
    ON CONFLICT (email) DO UPDATE
    SET role_id = EXCLUDED.role_id,
        phone = EXCLUDED.phone,
        password_hash = EXCLUDED.password_hash,
        status = 'active',
        email_verified_at = COALESCE(users.email_verified_at, now())
    RETURNING id, email, role_id
), all_test_users AS (
    SELECT u.id, u.email, u.role_id, tu.role_code, tu.first_name, tu.last_name, tu.document_number
    FROM users u
    JOIN test_users tu ON tu.email = u.email
)
INSERT INTO user_roles (user_id, role_id)
SELECT atu.id, atu.role_id
FROM all_test_users atu
ON CONFLICT (user_id, role_id) DO NOTHING;

WITH test_users(role_code, email, first_name, last_name, document_number) AS (
    VALUES
    ('admin', 'admin@jampic.local', 'Admin', 'Jampic', 'TEST-ADMIN'),
    ('patient', 'patient@jampic.local', 'Paciente', 'Prueba', 'TEST-PATIENT'),
    ('guardian', 'guardian@jampic.local', 'Tutor', 'Prueba', 'TEST-GUARDIAN'),
    ('doctor_general', 'doctor.general@jampic.local', 'Medico', 'General', 'TEST-DOC-GEN'),
    ('doctor_specialist', 'doctor.specialist@jampic.local', 'Medico', 'Especialista', 'TEST-DOC-SPEC'),
    ('nurse', 'nurse@jampic.local', 'Enfermeria', 'Prueba', 'TEST-NURSE'),
    ('operator', 'operator@jampic.local', 'Operador', 'Clinico', 'TEST-OPERATOR'),
    ('clinical_supervisor', 'clinical.supervisor@jampic.local', 'Supervisor', 'Clinico', 'TEST-SUPERVISOR'),
    ('health_partner', 'partner@jampic.local', 'Aliado', 'Salud', 'TEST-PARTNER'),
    ('delivery_assistant', 'delivery@jampic.local', 'Auxiliar', 'Entrega', 'TEST-DELIVERY'),
    ('human_resources', 'hr@jampic.local', 'Recursos', 'Humanos', 'TEST-HR')
)
INSERT INTO persons (user_id, first_name, last_name, document_type, document_number, birth_date, nationality)
SELECT u.id, tu.first_name, tu.last_name, 'test', tu.document_number, DATE '1990-01-01', 'Boliviana'
FROM test_users tu
JOIN users u ON u.email = tu.email
ON CONFLICT (user_id) DO UPDATE
SET first_name = EXCLUDED.first_name,
    last_name = EXCLUDED.last_name,
    document_type = EXCLUDED.document_type,
    document_number = EXCLUDED.document_number;

INSERT INTO patients (person_id, blood_type, height_cm, weight_kg, profile_notes)
SELECT p.id, 'O+', 170, 70, 'Paciente local de prueba.'
FROM persons p
JOIN users u ON u.id = p.user_id
WHERE u.email = 'patient@jampic.local'
ON CONFLICT (person_id) DO NOTHING;

INSERT INTO patients (person_id, blood_type, height_cm, weight_kg, profile_notes)
SELECT p.id, 'A+', 165, 62, 'Tutor / apoderado local de prueba.'
FROM persons p
JOIN users u ON u.id = p.user_id
WHERE u.email = 'guardian@jampic.local'
ON CONFLICT (person_id) DO NOTHING;

INSERT INTO patient_consents(
    patient_id, consent_type_id, granted_by_user_id, status
)
SELECT patient.id, type.id, app_user.id, 'accepted'
FROM patients patient
JOIN persons person ON person.id=patient.person_id
JOIN users app_user ON app_user.id=person.user_id
CROSS JOIN consent_types type
WHERE app_user.email IN ('patient@jampic.local', 'guardian@jampic.local')
  AND type.is_required AND type.is_active
  AND NOT EXISTS (
      SELECT 1 FROM patient_consents consent
      WHERE consent.patient_id=patient.id
        AND consent.consent_type_id=type.id
        AND consent.status='accepted'
  );

-- Dependiente menor de prueba para el tutor
WITH guardian_user AS (
    SELECT u.id AS user_id
    FROM users u
    WHERE u.email = 'guardian@jampic.local'
),
child_person AS (
    INSERT INTO persons (first_name, last_name, document_type, document_number, birth_date, nationality)
    SELECT 'Lucas', 'Tutor', 'ci', 'TEST-CHILD-001', DATE '2018-05-15', 'Boliviana'
    WHERE NOT EXISTS (
        SELECT 1 FROM persons WHERE document_number = 'TEST-CHILD-001'
    )
    RETURNING id
),
child_patient AS (
    INSERT INTO patients (person_id, blood_type, height_cm, weight_kg, is_minor, is_dependent, profile_notes)
    SELECT cp.id, 'O+', 125, 26, true, true, 'Hijo dependiente del tutor de prueba.'
    FROM (
        SELECT id FROM child_person
        UNION
        SELECT id FROM persons WHERE document_number = 'TEST-CHILD-001'
    ) cp
    WHERE NOT EXISTS (
        SELECT 1 FROM patients p WHERE p.person_id = cp.id
    )
    RETURNING id
)
INSERT INTO patient_guardians (
    patient_id, guardian_user_id, relationship, is_legal_guardian, verification_status, can_manage_profile, can_receive_alerts
)
SELECT COALESCE(
    (SELECT id FROM child_patient LIMIT 1),
    (SELECT p.id FROM patients p JOIN persons pe ON pe.id = p.person_id WHERE pe.document_number = 'TEST-CHILD-001')
), guardian_user.user_id, 'Hijo', true, 'validated', true, true
FROM guardian_user
ON CONFLICT (patient_id, guardian_user_id) DO NOTHING;

WITH professional_users(email, professional_type, license_number) AS (
    VALUES
    ('doctor.general@jampic.local', 'doctor', 'LOCAL-DG-001'),
    ('doctor.specialist@jampic.local', 'doctor', 'LOCAL-DE-001'),
    ('nurse@jampic.local', 'nurse', 'LOCAL-NUR-001'),
    ('operator@jampic.local', 'operator', 'LOCAL-OP-001'),
    ('clinical.supervisor@jampic.local', 'clinical_supervisor', 'LOCAL-CS-001'),
    ('delivery@jampic.local', 'delivery', 'LOCAL-DEL-001'),
    ('hr@jampic.local', 'admin', 'LOCAL-HR-001')
)
INSERT INTO professionals (user_id, person_id, professional_type, license_number, verification_status, verified_at, public_profile_enabled)
SELECT u.id, p.id, pu.professional_type, pu.license_number, 'approved', now(), true
FROM professional_users pu
JOIN users u ON u.email = pu.email
JOIN persons p ON p.user_id = u.id
ON CONFLICT (user_id) DO UPDATE
SET professional_type = EXCLUDED.professional_type,
    license_number = EXCLUDED.license_number,
    verification_status = 'approved',
    verified_at = COALESCE(professionals.verified_at, now());

INSERT INTO professional_specialties (professional_id, specialty_id, is_primary)
SELECT pr.id, s.id, true
FROM professionals pr
JOIN users u ON u.id = pr.user_id
JOIN specialties s ON s.name = 'Medicina General'
WHERE u.email IN ('doctor.general@jampic.local', 'doctor.specialist@jampic.local')
ON CONFLICT (professional_id, specialty_id) DO NOTHING;

INSERT INTO health_partners (name, partner_type, tax_id, phone, email, address)
SELECT 'Aliado local Jampic', 'clinic', 'LOCAL-PARTNER-001', '+59170000009', 'partner.business@jampic.local', 'Dirección local de prueba'
WHERE NOT EXISTS (
    SELECT 1 FROM health_partners WHERE tax_id = 'LOCAL-PARTNER-001'
);

INSERT INTO partner_users (partner_id, user_id, partner_role)
SELECT hp.id, u.id, 'admin'
FROM health_partners hp
JOIN users u ON u.email = 'partner@jampic.local'
WHERE hp.tax_id = 'LOCAL-PARTNER-001'
ON CONFLICT (partner_id, user_id) DO NOTHING;

INSERT INTO employment_records (professional_id, employee_code, contract_type, hired_at, status)
SELECT pr.id, 'LOCAL-' || upper(split_part(u.email, '@', 1)), 'local_test', CURRENT_DATE, 'active'
FROM professionals pr
JOIN users u ON u.id = pr.user_id
WHERE u.email IN ('nurse@jampic.local', 'operator@jampic.local', 'clinical.supervisor@jampic.local', 'delivery@jampic.local', 'hr@jampic.local')
ON CONFLICT (professional_id) DO NOTHING;

INSERT INTO professional_availability (
    professional_id, weekday, start_time, end_time, modality
)
SELECT
    professional.id,
    day_number,
    '08:00'::time,
    '18:00'::time,
    mode::appointment_modality
FROM professionals professional
JOIN users app_user ON app_user.id = professional.user_id
CROSS JOIN generate_series(1, 6) AS day_number
CROSS JOIN (VALUES ('in_person'), ('telemedicine')) AS modes(mode)
WHERE app_user.email IN (
    'doctor.general@jampic.local',
    'doctor.specialist@jampic.local'
)
AND NOT EXISTS (
    SELECT 1
    FROM professional_availability existing
    WHERE existing.professional_id = professional.id
      AND existing.weekday = day_number
      AND existing.start_time = '08:00'::time
      AND existing.end_time = '18:00'::time
      AND existing.modality = mode::appointment_modality
);

-- ============================================================
-- FIN USUARIOS LOCALES DE PRUEBA
-- ============================================================

