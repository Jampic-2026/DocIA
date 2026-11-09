-- Completa catálogo, tarifario, permisos y datos mínimos en bases existentes.
-- Las bases creadas desde cero ya reciben esto desde los documentos base.

CREATE TABLE IF NOT EXISTS service_catalog (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(80) UNIQUE NOT NULL,
    name VARCHAR(180) NOT NULL,
    category VARCHAR(80) NOT NULL,
    description TEXT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS price_list (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    service_id UUID NOT NULL REFERENCES service_catalog(id),
    charge_mode VARCHAR(20) NOT NULL,
    coin_price BIGINT CHECK (coin_price IS NULL OR coin_price >= 0),
    price NUMERIC(12,2) CHECK (price IS NULL OR price >= 0),
    currency CHAR(3) NOT NULL DEFAULT 'BOB',
    valid_from DATE NOT NULL DEFAULT CURRENT_DATE,
    valid_until DATE,
    created_by_user_id UUID REFERENCES users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CHECK (
        (charge_mode = 'coins' AND coin_price IS NOT NULL AND price IS NULL)
        OR (charge_mode = 'fiat' AND price IS NOT NULL AND coin_price IS NULL)
    )
);

INSERT INTO permissions (code, module, description)
VALUES
('catalog.read', 'catalog', 'Consultar catálogo y tarifario.'),
('catalog.manage', 'catalog', 'Gestionar catálogo y tarifario.'),
('coins.read', 'coins', 'Consultar billetera y movimientos autorizados.'),
('coins.manage', 'coins', 'Gestionar monedas y movimientos autorizados.'),
('payments.read', 'payments', 'Consultar pagos autorizados.'),
('payments.manage', 'payments', 'Gestionar pagos, devoluciones e incidencias.')
ON CONFLICT (code) DO UPDATE
SET module = EXCLUDED.module,
    description = EXCLUDED.description;

WITH grant_matrix(role_code, permission_codes) AS (
    VALUES
    ('patient', ARRAY['catalog.read','coins.read','payments.read']::TEXT[]),
    ('guardian', ARRAY['catalog.read','coins.read','payments.read']::TEXT[]),
    ('doctor_general', ARRAY['catalog.read','payments.read']::TEXT[]),
    ('doctor_specialist', ARRAY['catalog.read','payments.read']::TEXT[]),
    ('nurse', ARRAY['catalog.read','payments.read']::TEXT[]),
    ('health_partner', ARRAY['catalog.read','payments.read']::TEXT[])
),
expanded_grants AS (
    SELECT role_code, unnest(permission_codes) AS permission_code
    FROM grant_matrix
)
INSERT INTO role_permissions (role_id, permission_id)
SELECT role.id, permission.id
FROM expanded_grants grants
JOIN roles role ON role.code = grants.role_code
JOIN permissions permission ON permission.code = grants.permission_code
ON CONFLICT DO NOTHING;

INSERT INTO role_permissions (role_id, permission_id)
SELECT role.id, permission.id
FROM roles role
CROSS JOIN permissions permission
WHERE role.code = 'admin'
  AND permission.code IN (
      'catalog.read','catalog.manage','coins.read','coins.manage',
      'payments.read','payments.manage'
  )
ON CONFLICT DO NOTHING;

ALTER TABLE service_catalog ENABLE ROW LEVEL SECURITY;
ALTER TABLE price_list ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS catalog_active_select ON service_catalog;
CREATE POLICY catalog_active_select ON service_catalog
FOR SELECT USING (
    is_active
    OR app_has_role('admin')
    OR app_has_permission('catalog.manage')
);

DROP POLICY IF EXISTS catalog_manage_insert ON service_catalog;
CREATE POLICY catalog_manage_insert ON service_catalog
FOR INSERT WITH CHECK (
    app_has_role('admin') OR app_has_permission('catalog.manage')
);

DROP POLICY IF EXISTS catalog_manage_update ON service_catalog;
CREATE POLICY catalog_manage_update ON service_catalog
FOR UPDATE USING (
    app_has_role('admin') OR app_has_permission('catalog.manage')
)
WITH CHECK (
    app_has_role('admin') OR app_has_permission('catalog.manage')
);

DROP POLICY IF EXISTS price_current_select ON price_list;
CREATE POLICY price_current_select ON price_list
FOR SELECT USING (
    (
        valid_from <= CURRENT_DATE
        AND (valid_until IS NULL OR valid_until >= CURRENT_DATE)
    )
    OR app_has_role('admin')
    OR app_has_permission('catalog.manage')
);

DROP POLICY IF EXISTS price_list_manage_insert ON price_list;
CREATE POLICY price_list_manage_insert ON price_list
FOR INSERT WITH CHECK (
    app_has_role('admin') OR app_has_permission('catalog.manage')
);

DROP POLICY IF EXISTS price_list_manage_update ON price_list;
CREATE POLICY price_list_manage_update ON price_list
FOR UPDATE USING (
    app_has_role('admin') OR app_has_permission('catalog.manage')
)
WITH CHECK (
    app_has_role('admin') OR app_has_permission('catalog.manage')
);

INSERT INTO service_catalog (code, name, category, description)
VALUES
('consult_general_telemedicine', 'Consulta médica general por telemedicina', 'consultation', 'Consulta virtual con médico general.'),
('consult_specialist_telemedicine', 'Consulta especialista por telemedicina', 'consultation', 'Consulta virtual con especialista autorizado.'),
('emergency_coordination', 'Coordinación de emergencia médica', 'emergency', 'Registro y coordinación de emergencia según cobertura y protocolo.'),
('support_call', 'Llamada de orientación', 'consultation', 'Llamada con operador o personal autorizado.'),
('coin_package_purchase', 'Compra de paquete de monedas', 'coin_package', 'Carga de monedas Doc IA con vigencia de un año.')
ON CONFLICT (code) DO NOTHING;

INSERT INTO system_settings (setting_key, value, description, requires_clinical_approval)
VALUES
('monetization_enabled', 'false'::jsonb, 'Activa los cobros definidos en el tarifario.', FALSE),
('user_charge_unit', '"coins"'::jsonb, 'Unidad de cobro para servicios no presenciales de usuarios.', FALSE),
('coin_expiration_days', '365'::jsonb, 'Vigencia de cada lote de monedas desde su acreditación.', FALSE),
('coins.expiration_notice_days', '30'::jsonb, 'Días de anticipación para avisar el vencimiento de monedas.', FALSE),
('in_person_payment_methods', '["qr", "cash"]'::jsonb, 'Métodos permitidos para servicios presenciales.', FALSE)
ON CONFLICT (setting_key) DO NOTHING;
