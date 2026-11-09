-- Ensure existing databases have the permissions needed for patients to manage
-- family/dependent links and generate guardian QR/link codes.

INSERT INTO permissions (code, module, description)
VALUES
('patients.read', 'patients', 'Consultar pacientes autorizados.'),
('patients.manage', 'patients', 'Gestionar pacientes, tutores y familiares autorizados.')
ON CONFLICT (code) DO UPDATE
SET module = EXCLUDED.module,
    description = EXCLUDED.description;

INSERT INTO role_permissions (role_id, permission_id)
SELECT role.id, permission.id
FROM roles role
JOIN permissions permission ON permission.code IN ('patients.read', 'patients.manage')
WHERE role.code IN ('patient', 'guardian')
ON CONFLICT DO NOTHING;
