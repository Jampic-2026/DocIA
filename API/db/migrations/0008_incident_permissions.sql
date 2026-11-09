-- Ajusta permisos de incidentes en bases existentes.
-- Las bases nuevas reciben estos permisos desde los documentos base.

INSERT INTO permissions (code, module, description)
VALUES
('incidents.read', 'incidents', 'Consultar y registrar incidentes propios.'),
('incidents.manage', 'incidents', 'Gestionar y responder incidentes.')
ON CONFLICT (code) DO UPDATE
SET module = EXCLUDED.module,
    description = EXCLUDED.description;

WITH incident_read_roles(role_code) AS (
    VALUES
    ('patient'),
    ('guardian'),
    ('doctor_general'),
    ('doctor_specialist'),
    ('nurse'),
    ('operator'),
    ('clinical_supervisor'),
    ('health_partner'),
    ('delivery_assistant'),
    ('human_resources')
)
INSERT INTO role_permissions (role_id, permission_id)
SELECT role.id, permission.id
FROM incident_read_roles grant_role
JOIN roles role ON role.code = grant_role.role_code
JOIN permissions permission ON permission.code = 'incidents.read'
ON CONFLICT DO NOTHING;

WITH incident_manage_roles(role_code) AS (
    VALUES
    ('operator'),
    ('clinical_supervisor')
)
INSERT INTO role_permissions (role_id, permission_id)
SELECT role.id, permission.id
FROM incident_manage_roles grant_role
JOIN roles role ON role.code = grant_role.role_code
JOIN permissions permission ON permission.code = 'incidents.manage'
ON CONFLICT DO NOTHING;

DELETE FROM role_permissions role_permission
USING roles role, permissions permission
WHERE role_permission.role_id = role.id
  AND role_permission.permission_id = permission.id
  AND permission.code = 'incidents.manage'
  AND role.code NOT IN ('admin', 'operator', 'clinical_supervisor');
