-- Backfill family/dependent linking tables for databases created before
-- the current family management module existed in the base schema.

CREATE TABLE IF NOT EXISTS guardian_link_codes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    minor_patient_id UUID NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
    code_hash TEXT NOT NULL UNIQUE,
    generated_by_user_id UUID NOT NULL REFERENCES users(id),
    expires_at TIMESTAMPTZ NOT NULL,
    used_by_user_id UUID REFERENCES users(id),
    used_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS patient_guardians (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id UUID NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
    guardian_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    relationship VARCHAR(80) NOT NULL,
    is_legal_guardian BOOLEAN NOT NULL DEFAULT FALSE,
    verification_status validation_status NOT NULL DEFAULT 'pending_validation',
    can_manage_profile BOOLEAN NOT NULL DEFAULT TRUE,
    can_receive_alerts BOOLEAN NOT NULL DEFAULT TRUE,
    valid_from TIMESTAMPTZ NOT NULL DEFAULT now(),
    valid_until TIMESTAMPTZ,
    revoked_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(patient_id, guardian_user_id)
);

CREATE TABLE IF NOT EXISTS family_authorizations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id UUID NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
    family_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    granted_by_user_id UUID NOT NULL REFERENCES users(id),
    relationship VARCHAR(80),
    status user_status NOT NULL DEFAULT 'active',
    accepted_at TIMESTAMPTZ,
    revoked_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(patient_id, family_user_id)
);

CREATE TABLE IF NOT EXISTS family_authorization_permissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    authorization_id UUID NOT NULL REFERENCES family_authorizations(id) ON DELETE CASCADE,
    permission_code VARCHAR(80) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(authorization_id, permission_code)
);

ALTER TABLE patient_guardians ENABLE ROW LEVEL SECURITY;
ALTER TABLE guardian_link_codes ENABLE ROW LEVEL SECURITY;
ALTER TABLE family_authorizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE family_authorization_permissions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS patient_guardians_authorized_select ON patient_guardians;
CREATE POLICY patient_guardians_authorized_select ON patient_guardians
FOR SELECT USING (
    guardian_user_id = app_current_user_id()
    OR EXISTS (
        SELECT 1
        FROM patients patient
        JOIN persons person ON person.id = patient.person_id
        WHERE patient.id = patient_guardians.patient_id
          AND person.user_id = app_current_user_id()
    )
    OR app_has_role('admin')
    OR app_has_role('clinical_supervisor')
);

DROP POLICY IF EXISTS guardian_link_codes_owner_insert ON guardian_link_codes;
CREATE POLICY guardian_link_codes_owner_insert ON guardian_link_codes
FOR INSERT WITH CHECK (
    generated_by_user_id = app_current_user_id()
    AND EXISTS (
        SELECT 1
        FROM patients patient
        JOIN persons person ON person.id = patient.person_id
        WHERE patient.id = guardian_link_codes.minor_patient_id
          AND person.user_id = app_current_user_id()
    )
);

DROP POLICY IF EXISTS guardian_link_codes_redeem_select ON guardian_link_codes;
CREATE POLICY guardian_link_codes_redeem_select ON guardian_link_codes
FOR SELECT USING (
    generated_by_user_id = app_current_user_id()
    OR (used_at IS NULL AND expires_at > now())
);

DROP POLICY IF EXISTS guardian_link_codes_redeem_update ON guardian_link_codes;
CREATE POLICY guardian_link_codes_redeem_update ON guardian_link_codes
FOR UPDATE USING (used_at IS NULL AND expires_at > now())
WITH CHECK (used_by_user_id = app_current_user_id() AND used_at IS NOT NULL);

DROP POLICY IF EXISTS patient_guardians_guardian_insert ON patient_guardians;
CREATE POLICY patient_guardians_guardian_insert ON patient_guardians
FOR INSERT WITH CHECK (
    guardian_user_id = app_current_user_id()
    AND verification_status = 'validated'
);

DROP POLICY IF EXISTS patient_guardians_guardian_update ON patient_guardians;
CREATE POLICY patient_guardians_guardian_update ON patient_guardians
FOR UPDATE USING (guardian_user_id = app_current_user_id())
WITH CHECK (guardian_user_id = app_current_user_id());

DROP POLICY IF EXISTS family_authorizations_authorized_select ON family_authorizations;
CREATE POLICY family_authorizations_authorized_select ON family_authorizations
FOR SELECT USING (
    family_user_id = app_current_user_id()
    OR granted_by_user_id = app_current_user_id()
    OR app_can_read_patient(patient_id)
);

DROP POLICY IF EXISTS family_authorization_permissions_authorized_select ON family_authorization_permissions;
CREATE POLICY family_authorization_permissions_authorized_select ON family_authorization_permissions
FOR SELECT USING (
    EXISTS (
        SELECT 1
        FROM family_authorizations family_auth
        WHERE family_auth.id = family_authorization_permissions.authorization_id
    )
);

DROP POLICY IF EXISTS family_authorizations_patient_insert ON family_authorizations;
CREATE POLICY family_authorizations_patient_insert ON family_authorizations
FOR INSERT WITH CHECK (
    granted_by_user_id = app_current_user_id()
    AND EXISTS (
        SELECT 1
        FROM patients patient
        JOIN persons person ON person.id = patient.person_id
        WHERE patient.id = family_authorizations.patient_id
          AND person.user_id = app_current_user_id()
    )
);

DROP POLICY IF EXISTS family_authorizations_patient_update ON family_authorizations;
CREATE POLICY family_authorizations_patient_update ON family_authorizations
FOR UPDATE USING (
    EXISTS (
        SELECT 1
        FROM patients patient
        JOIN persons person ON person.id = patient.person_id
        WHERE patient.id = family_authorizations.patient_id
          AND person.user_id = app_current_user_id()
    )
) WITH CHECK (
    granted_by_user_id = app_current_user_id()
);

DROP POLICY IF EXISTS family_permissions_patient_manage ON family_authorization_permissions;
CREATE POLICY family_permissions_patient_manage ON family_authorization_permissions
FOR ALL USING (
    EXISTS (
        SELECT 1
        FROM family_authorizations family_auth
        JOIN patients patient ON patient.id = family_auth.patient_id
        JOIN persons person ON person.id = patient.person_id
        WHERE family_auth.id = family_authorization_permissions.authorization_id
          AND person.user_id = app_current_user_id()
    )
) WITH CHECK (
    EXISTS (
        SELECT 1
        FROM family_authorizations family_auth
        JOIN patients patient ON patient.id = family_auth.patient_id
        JOIN persons person ON person.id = patient.person_id
        WHERE family_auth.id = family_authorization_permissions.authorization_id
          AND person.user_id = app_current_user_id()
    )
);
