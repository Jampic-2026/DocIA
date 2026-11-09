-- ============================================================
-- POLICIES / ROW LEVEL SECURITY
-- ============================================================
-- Este archivo se ejecuta después de 03_triggers.sql.
-- Las policies usan los claims seteados por la API en cada transacción:
-- app.user_id, app.session_id, app.role_code, app.roles y app.permissions.
-- Para login se usa app.login_identifier únicamente durante la transacción de autenticación.
--
-- En desarrollo local con rol superuser, PostgreSQL puede bypassar RLS.
-- Para probarlas de forma estricta se debe usar un rol de aplicación sin BYPASSRLS.

-- ============================================================
-- USUARIOS Y SESIONES
-- ============================================================

ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_sessions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS users_select_self_or_admin ON users;
CREATE POLICY users_select_self_or_admin ON users
FOR SELECT
USING (
    id = app_current_user_id()
    OR email::text = app_login_identifier()
    OR phone = app_login_identifier()
    OR app_has_role('admin')
    OR app_has_permission('users.read')
);

DROP POLICY IF EXISTS users_update_self_or_admin ON users;
CREATE POLICY users_update_self_or_admin ON users
FOR UPDATE
USING (
    id = app_current_user_id()
    OR app_has_role('admin')
    OR app_has_permission('users.update')
)
WITH CHECK (
    id = app_current_user_id()
    OR app_has_role('admin')
    OR app_has_permission('users.update')
);

DROP POLICY IF EXISTS users_verified_registration_insert ON users;
CREATE POLICY users_verified_registration_insert ON users
FOR INSERT WITH CHECK (
    email::text = NULLIF(current_setting('app.registration_email', true),'')
    AND EXISTS(
        SELECT 1 FROM registration_email_tokens token
        WHERE token.email=users.email AND token.consumed_at IS NULL
          AND token.expires_at>now()
    )
);

DROP POLICY IF EXISTS user_sessions_self_or_admin ON user_sessions;
CREATE POLICY user_sessions_self_or_admin ON user_sessions
FOR ALL
USING (
    user_id = app_current_user_id()
    OR app_has_role('admin')
    OR app_has_permission('auth.sessions.manage')
)
WITH CHECK (
    user_id = app_current_user_id()
    OR app_has_role('admin')
    OR app_has_permission('auth.sessions.manage')
);

-- ============================================================
-- BILLETERA Y MONEDAS DE USUARIO
-- ============================================================

ALTER TABLE coin_wallets ENABLE ROW LEVEL SECURITY;
ALTER TABLE coin_lots ENABLE ROW LEVEL SECURITY;
ALTER TABLE weekly_free_coin_grants ENABLE ROW LEVEL SECURITY;
ALTER TABLE coin_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE coin_transaction_allocations ENABLE ROW LEVEL SECURITY;
ALTER TABLE coin_purchases ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS coin_wallets_self_or_admin ON coin_wallets;
CREATE POLICY coin_wallets_self_or_admin ON coin_wallets
FOR ALL
USING (
    user_id = app_current_user_id()
    OR app_has_role('admin')
    OR app_has_permission('coins.manage')
    OR app_has_permission('payments.manage')
)
WITH CHECK (
    user_id = app_current_user_id()
    OR app_has_role('admin')
    OR app_has_permission('coins.manage')
    OR app_has_permission('payments.manage')
);

DROP POLICY IF EXISTS coin_lots_self_or_admin ON coin_lots;
CREATE POLICY coin_lots_self_or_admin ON coin_lots
FOR ALL
USING (
    EXISTS (
        SELECT 1 FROM coin_wallets cw
        WHERE cw.id = coin_lots.wallet_id
          AND (
              cw.user_id = app_current_user_id()
              OR app_has_role('admin')
              OR app_has_permission('coins.manage')
              OR app_has_permission('payments.manage')
          )
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1 FROM coin_wallets cw
        WHERE cw.id = coin_lots.wallet_id
          AND (
              cw.user_id = app_current_user_id()
              OR app_has_role('admin')
              OR app_has_permission('coins.manage')
              OR app_has_permission('payments.manage')
          )
    )
);

DROP POLICY IF EXISTS weekly_free_coin_grants_self_or_admin ON weekly_free_coin_grants;
CREATE POLICY weekly_free_coin_grants_self_or_admin ON weekly_free_coin_grants
FOR ALL
USING (
    user_id = app_current_user_id()
    OR app_has_role('admin')
    OR app_has_permission('coins.manage')
)
WITH CHECK (
    user_id = app_current_user_id()
    OR app_has_role('admin')
    OR app_has_permission('coins.manage')
);

DROP POLICY IF EXISTS coin_transactions_self_or_admin ON coin_transactions;
CREATE POLICY coin_transactions_self_or_admin ON coin_transactions
FOR ALL
USING (
    EXISTS (
        SELECT 1 FROM coin_wallets cw
        WHERE cw.id = coin_transactions.wallet_id
          AND (
              cw.user_id = app_current_user_id()
              OR app_has_role('admin')
              OR app_has_permission('coins.manage')
              OR app_has_permission('payments.manage')
          )
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1 FROM coin_wallets cw
        WHERE cw.id = coin_transactions.wallet_id
          AND (
              cw.user_id = app_current_user_id()
              OR app_has_role('admin')
              OR app_has_permission('coins.manage')
              OR app_has_permission('payments.manage')
          )
    )
);

DROP POLICY IF EXISTS coin_transaction_allocations_self_or_admin ON coin_transaction_allocations;
CREATE POLICY coin_transaction_allocations_self_or_admin ON coin_transaction_allocations
FOR ALL
USING (
    EXISTS (
        SELECT 1
        FROM coin_transactions ct
        JOIN coin_wallets cw ON cw.id = ct.wallet_id
        WHERE ct.id = coin_transaction_allocations.transaction_id
          AND (
              cw.user_id = app_current_user_id()
              OR app_has_role('admin')
              OR app_has_permission('coins.manage')
              OR app_has_permission('payments.manage')
          )
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1
        FROM coin_transactions ct
        JOIN coin_wallets cw ON cw.id = ct.wallet_id
        WHERE ct.id = coin_transaction_allocations.transaction_id
          AND (
              cw.user_id = app_current_user_id()
              OR app_has_role('admin')
              OR app_has_permission('coins.manage')
              OR app_has_permission('payments.manage')
          )
    )
);

DROP POLICY IF EXISTS coin_purchases_self_or_admin ON coin_purchases;
CREATE POLICY coin_purchases_self_or_admin ON coin_purchases
FOR ALL
USING (
    user_id = app_current_user_id()
    OR app_has_role('admin')
    OR app_has_permission('coins.manage')
    OR app_has_permission('payments.manage')
)
WITH CHECK (
    user_id = app_current_user_id()
    OR app_has_role('admin')
    OR app_has_permission('coins.manage')
    OR app_has_permission('payments.manage')
);

-- ============================================================
-- CUENTA, PERSONAS Y DIRECCIONES
-- ============================================================

ALTER TABLE persons ENABLE ROW LEVEL SECURITY;
ALTER TABLE addresses ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS persons_own_account_select ON persons;
CREATE POLICY persons_own_account_select ON persons
FOR SELECT USING (
    user_id = app_current_user_id()
    OR app_has_role('admin')
    OR app_has_permission('human_resources.manage')
    OR app_has_role('operator')
    OR app_has_role('clinical_supervisor')
    OR app_is_person_care_assignee(id)
);

DROP POLICY IF EXISTS persons_own_account_update ON persons;
CREATE POLICY persons_own_account_update ON persons
FOR UPDATE
USING (user_id = app_current_user_id() OR app_has_role('admin'))
WITH CHECK (user_id = app_current_user_id() OR app_has_role('admin'));

DROP POLICY IF EXISTS addresses_own_account_select ON addresses;
CREATE POLICY addresses_own_account_select ON addresses
FOR SELECT USING (
    EXISTS (
        SELECT 1
        FROM persons person
        WHERE person.id = addresses.person_id
          AND person.user_id = app_current_user_id()
    )
    OR app_has_role('admin')
    OR app_has_role('operator')
);

DROP POLICY IF EXISTS addresses_own_account_update ON addresses;
CREATE POLICY addresses_own_account_update ON addresses
FOR UPDATE USING (
    EXISTS (
        SELECT 1 FROM persons person
        WHERE person.id = addresses.person_id
          AND person.user_id = app_current_user_id()
    )
    OR app_has_role('admin')
);

DROP POLICY IF EXISTS addresses_own_account_insert ON addresses;
CREATE POLICY addresses_own_account_insert ON addresses
FOR INSERT WITH CHECK (
    EXISTS (
        SELECT 1 FROM persons person
        WHERE person.id = addresses.person_id
          AND person.user_id = app_current_user_id()
    )
    OR app_has_role('admin')
);

-- ============================================================
-- CITAS
-- ============================================================

ALTER TABLE appointments ENABLE ROW LEVEL SECURITY;
ALTER TABLE appointment_status_history ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS appointments_authorized_select ON appointments;
CREATE POLICY appointments_authorized_select ON appointments
FOR SELECT USING (
    EXISTS (
        SELECT 1
        FROM patients patient
        JOIN persons person ON person.id = patient.person_id
        WHERE patient.id = appointments.patient_id
          AND person.user_id = app_current_user_id()
    )
    OR EXISTS (
        SELECT 1
        FROM professionals professional
        WHERE professional.id = appointments.professional_id
          AND professional.user_id = app_current_user_id()
    )
    OR app_has_role('admin')
    OR app_has_role('operator')
    OR app_has_role('clinical_supervisor')
);

DROP POLICY IF EXISTS appointments_authorized_insert ON appointments;
CREATE POLICY appointments_authorized_insert ON appointments
FOR INSERT WITH CHECK (
    (
        created_by_user_id = app_current_user_id()
        AND EXISTS (
            SELECT 1
            FROM patients patient
            JOIN persons person ON person.id = patient.person_id
            WHERE patient.id = appointments.patient_id
              AND person.user_id = app_current_user_id()
        )
    )
    OR app_has_role('admin')
    OR app_has_role('operator')
);

DROP POLICY IF EXISTS appointments_authorized_update ON appointments;
CREATE POLICY appointments_authorized_update ON appointments
FOR UPDATE USING (
    EXISTS (
        SELECT 1 FROM patients patient
        JOIN persons person ON person.id=patient.person_id
        WHERE patient.id=appointments.patient_id
          AND person.user_id=app_current_user_id()
    )
    OR app_has_role('admin')
    OR app_has_role('operator')
)
WITH CHECK (
    EXISTS (
        SELECT 1 FROM patients patient
        JOIN persons person ON person.id=patient.person_id
        WHERE patient.id=appointments.patient_id
          AND person.user_id=app_current_user_id()
    )
    OR app_has_role('admin')
    OR app_has_role('operator')
);

DROP POLICY IF EXISTS appointments_professional_update ON appointments;
CREATE POLICY appointments_professional_update ON appointments
FOR UPDATE USING (
    EXISTS (
        SELECT 1 FROM professionals professional
        WHERE professional.id=appointments.professional_id
          AND professional.user_id=app_current_user_id()
    )
) WITH CHECK (
    EXISTS (
        SELECT 1 FROM professionals professional
        WHERE professional.id=appointments.professional_id
          AND professional.user_id=app_current_user_id()
    )
);

DROP POLICY IF EXISTS appointment_history_authorized_select
ON appointment_status_history;
CREATE POLICY appointment_history_authorized_select
ON appointment_status_history
FOR SELECT USING (
    EXISTS (
        SELECT 1 FROM appointments appointment
        WHERE appointment.id=appointment_status_history.appointment_id
    )
);

DROP POLICY IF EXISTS appointment_history_authorized_insert
ON appointment_status_history;
CREATE POLICY appointment_history_authorized_insert
ON appointment_status_history
FOR INSERT WITH CHECK (
    changed_by_user_id=app_current_user_id()
    AND EXISTS (
        SELECT 1 FROM appointments appointment
        WHERE appointment.id=appointment_status_history.appointment_id
    )
);

-- ============================================================
-- HISTORIA CLÍNICA
-- ============================================================

ALTER TABLE clinical_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE allergies ENABLE ROW LEVEL SECURITY;
ALTER TABLE medical_antecedents ENABLE ROW LEVEL SECURITY;
ALTER TABLE vital_signs ENABLE ROW LEVEL SECURITY;
ALTER TABLE clinical_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE clinical_notes ENABLE ROW LEVEL SECURITY;
ALTER TABLE emergency_contacts ENABLE ROW LEVEL SECURITY;
ALTER TABLE clinical_correction_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE clinical_record_versions ENABLE ROW LEVEL SECURITY;
ALTER TABLE diagnoses ENABLE ROW LEVEL SECURITY;
ALTER TABLE treatments ENABLE ROW LEVEL SECURITY;
ALTER TABLE appointment_followups ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS clinical_records_authorized_select ON clinical_records;
CREATE POLICY clinical_records_authorized_select ON clinical_records
FOR SELECT USING (app_can_read_patient(patient_id));

DROP POLICY IF EXISTS clinical_records_supervision_update ON clinical_records;
CREATE POLICY clinical_records_supervision_update ON clinical_records
FOR UPDATE USING (
    app_has_permission('clinical_records.manage')
    AND app_can_read_patient(patient_id)
    AND (app_has_role('admin') OR app_has_role('clinical_supervisor'))
) WITH CHECK (
    app_has_permission('clinical_records.manage')
    AND app_can_read_patient(patient_id)
    AND (app_has_role('admin') OR app_has_role('clinical_supervisor'))
);

DROP POLICY IF EXISTS clinical_records_professional_insert ON clinical_records;
CREATE POLICY clinical_records_professional_insert ON clinical_records
FOR INSERT WITH CHECK (
    author_user_id=app_current_user_id()
    AND app_has_permission('clinical_records.manage')
    AND app_can_read_patient(patient_id)
);

DROP POLICY IF EXISTS correction_requests_authorized_select
ON clinical_correction_requests;
CREATE POLICY correction_requests_authorized_select
ON clinical_correction_requests
FOR SELECT USING (
    requested_by_user_id=app_current_user_id()
    OR app_has_role('admin')
    OR app_has_role('clinical_supervisor')
);

DROP POLICY IF EXISTS correction_requests_patient_insert
ON clinical_correction_requests;
CREATE POLICY correction_requests_patient_insert
ON clinical_correction_requests
FOR INSERT WITH CHECK (
    requested_by_user_id=app_current_user_id()
    AND EXISTS (
        SELECT 1 FROM patients patient
        JOIN persons person ON person.id=patient.person_id
        WHERE patient.id=clinical_correction_requests.patient_id
          AND person.user_id=app_current_user_id()
    )
);

DROP POLICY IF EXISTS correction_requests_supervision_update
ON clinical_correction_requests;
CREATE POLICY correction_requests_supervision_update
ON clinical_correction_requests
FOR UPDATE USING (
    app_has_permission('clinical_records.manage')
    AND (
        app_has_role('admin') OR app_has_role('clinical_supervisor')
    )
) WITH CHECK (
    app_has_permission('clinical_records.manage')
    AND (
        app_has_role('admin') OR app_has_role('clinical_supervisor')
    )
);

DROP POLICY IF EXISTS clinical_record_versions_authorized_select
ON clinical_record_versions;
CREATE POLICY clinical_record_versions_authorized_select
ON clinical_record_versions
FOR SELECT USING (
    EXISTS (
        SELECT 1 FROM clinical_records record
        WHERE record.id=clinical_record_versions.clinical_record_id
          AND app_can_read_patient(record.patient_id)
    )
);

DROP POLICY IF EXISTS clinical_record_versions_supervision_insert
ON clinical_record_versions;
CREATE POLICY clinical_record_versions_supervision_insert
ON clinical_record_versions
FOR INSERT WITH CHECK (
    changed_by_user_id=app_current_user_id()
    AND app_has_permission('clinical_records.manage')
    AND (
        app_has_role('admin') OR app_has_role('clinical_supervisor')
    )
);

DROP POLICY IF EXISTS allergies_authorized_select ON allergies;
CREATE POLICY allergies_authorized_select ON allergies
FOR SELECT USING (app_can_read_patient(patient_id));

DROP POLICY IF EXISTS allergies_patient_insert ON allergies;
CREATE POLICY allergies_patient_insert ON allergies
FOR INSERT WITH CHECK (
    author_user_id=app_current_user_id()
    AND EXISTS (
        SELECT 1 FROM patients patient
        JOIN persons person ON person.id=patient.person_id
        WHERE patient.id=allergies.patient_id
          AND person.user_id=app_current_user_id()
    )
);

DROP POLICY IF EXISTS allergies_patient_update ON allergies;
CREATE POLICY allergies_patient_update ON allergies
FOR UPDATE USING (
    EXISTS (
        SELECT 1 FROM patients patient
        JOIN persons person ON person.id=patient.person_id
        WHERE patient.id=allergies.patient_id
          AND person.user_id=app_current_user_id()
    )
) WITH CHECK (
    EXISTS (
        SELECT 1 FROM patients patient
        JOIN persons person ON person.id=patient.person_id
        WHERE patient.id=allergies.patient_id
          AND person.user_id=app_current_user_id()
    )
);

DROP POLICY IF EXISTS allergies_professional_validation ON allergies;
CREATE POLICY allergies_professional_validation ON allergies
FOR UPDATE USING (
    app_has_permission('clinical_records.manage')
    AND app_can_read_patient(patient_id)
) WITH CHECK (
    app_has_permission('clinical_records.manage')
    AND app_can_read_patient(patient_id)
);

DROP POLICY IF EXISTS medical_antecedents_authorized_select
ON medical_antecedents;
CREATE POLICY medical_antecedents_authorized_select ON medical_antecedents
FOR SELECT USING (app_can_read_patient(patient_id));

DROP POLICY IF EXISTS medical_antecedents_patient_insert ON medical_antecedents;
CREATE POLICY medical_antecedents_patient_insert ON medical_antecedents
FOR INSERT WITH CHECK (
    author_user_id=app_current_user_id()
    AND EXISTS (
        SELECT 1 FROM patients patient
        JOIN persons person ON person.id=patient.person_id
        WHERE patient.id=medical_antecedents.patient_id
          AND person.user_id=app_current_user_id()
    )
);

DROP POLICY IF EXISTS medical_antecedents_patient_update ON medical_antecedents;
CREATE POLICY medical_antecedents_patient_update ON medical_antecedents
FOR UPDATE USING (
    EXISTS (
        SELECT 1 FROM patients patient
        JOIN persons person ON person.id=patient.person_id
        WHERE patient.id=medical_antecedents.patient_id
          AND person.user_id=app_current_user_id()
    )
) WITH CHECK (
    EXISTS (
        SELECT 1 FROM patients patient
        JOIN persons person ON person.id=patient.person_id
        WHERE patient.id=medical_antecedents.patient_id
          AND person.user_id=app_current_user_id()
    )
);

DROP POLICY IF EXISTS medical_antecedents_professional_validation
ON medical_antecedents;
CREATE POLICY medical_antecedents_professional_validation
ON medical_antecedents
FOR UPDATE USING (
    app_has_permission('clinical_records.manage')
    AND app_can_read_patient(patient_id)
) WITH CHECK (
    app_has_permission('clinical_records.manage')
    AND app_can_read_patient(patient_id)
);

DROP POLICY IF EXISTS emergency_contacts_patient_select ON emergency_contacts;
CREATE POLICY emergency_contacts_patient_select ON emergency_contacts
FOR SELECT USING (app_can_read_patient(patient_id));

DROP POLICY IF EXISTS emergency_contacts_patient_insert ON emergency_contacts;
CREATE POLICY emergency_contacts_patient_insert ON emergency_contacts
FOR INSERT WITH CHECK (
    EXISTS (
        SELECT 1 FROM patients patient
        JOIN persons person ON person.id=patient.person_id
        WHERE patient.id=emergency_contacts.patient_id
          AND person.user_id=app_current_user_id()
    )
);

DROP POLICY IF EXISTS emergency_contacts_patient_update ON emergency_contacts;
CREATE POLICY emergency_contacts_patient_update ON emergency_contacts
FOR UPDATE USING (
    EXISTS (
        SELECT 1 FROM patients patient
        JOIN persons person ON person.id=patient.person_id
        WHERE patient.id=emergency_contacts.patient_id
          AND person.user_id=app_current_user_id()
    )
) WITH CHECK (
    EXISTS (
        SELECT 1 FROM patients patient
        JOIN persons person ON person.id=patient.person_id
        WHERE patient.id=emergency_contacts.patient_id
          AND person.user_id=app_current_user_id()
    )
);

DROP POLICY IF EXISTS vital_signs_authorized_select ON vital_signs;
CREATE POLICY vital_signs_authorized_select ON vital_signs
FOR SELECT USING (app_can_read_patient(patient_id));

DROP POLICY IF EXISTS vital_signs_patient_insert ON vital_signs;
CREATE POLICY vital_signs_patient_insert ON vital_signs
FOR INSERT WITH CHECK (
    recorded_by_user_id=app_current_user_id()
    AND source='patient'
    AND EXISTS (
        SELECT 1 FROM patients patient
        JOIN persons person ON person.id=patient.person_id
        WHERE patient.id=vital_signs.patient_id
          AND person.user_id=app_current_user_id()
    )
);

DROP POLICY IF EXISTS clinical_documents_authorized_select
ON clinical_documents;
CREATE POLICY clinical_documents_authorized_select ON clinical_documents
FOR SELECT USING (
    app_can_read_patient(patient_id)
    AND (
        NOT is_restricted
        OR app_has_role('admin')
        OR app_has_role('clinical_supervisor')
        OR EXISTS (
            SELECT 1 FROM patients patient
            JOIN persons person ON person.id=patient.person_id
            WHERE patient.id=clinical_documents.patient_id
              AND person.user_id=app_current_user_id()
        )
    )
);

DROP POLICY IF EXISTS clinical_documents_patient_insert ON clinical_documents;
CREATE POLICY clinical_documents_patient_insert ON clinical_documents
FOR INSERT WITH CHECK (
    uploaded_by_user_id=app_current_user_id()
    AND source='external'
    AND validation_status='pending_validation'
    AND EXISTS (
        SELECT 1 FROM patients patient
        JOIN persons person ON person.id=patient.person_id
        WHERE patient.id=clinical_documents.patient_id
          AND person.user_id=app_current_user_id()
    )
);

DROP POLICY IF EXISTS clinical_documents_diagnostic_partner_insert ON clinical_documents;
CREATE POLICY clinical_documents_diagnostic_partner_insert ON clinical_documents
FOR INSERT WITH CHECK (
    uploaded_by_user_id=app_current_user_id()
    AND source='external' AND validation_status='pending_validation'
    AND EXISTS (
        SELECT 1 FROM diagnostic_orders diagnostic
        JOIN partner_users partner_user ON partner_user.partner_id=diagnostic.partner_id
        WHERE diagnostic.patient_id=clinical_documents.patient_id
          AND diagnostic.status IN ('requested','in_progress')
          AND partner_user.user_id=app_current_user_id() AND partner_user.is_active
    )
);

DROP POLICY IF EXISTS clinical_documents_professional_validation
ON clinical_documents;
CREATE POLICY clinical_documents_professional_validation
ON clinical_documents
FOR UPDATE USING (
    app_has_permission('clinical_records.manage')
    AND app_can_read_patient(patient_id)
    AND NOT is_restricted
) WITH CHECK (
    app_has_permission('clinical_records.manage')
    AND app_can_read_patient(patient_id)
    AND NOT is_restricted
);

DROP POLICY IF EXISTS clinical_notes_authorized_select ON clinical_notes;
CREATE POLICY clinical_notes_authorized_select ON clinical_notes
FOR SELECT USING (app_can_read_patient(patient_id));

DROP POLICY IF EXISTS clinical_notes_professional_insert ON clinical_notes;
CREATE POLICY clinical_notes_professional_insert ON clinical_notes
FOR INSERT WITH CHECK (
    EXISTS (
        SELECT 1
        FROM appointments appointment
        JOIN professionals professional
          ON professional.id = appointment.professional_id
        WHERE appointment.id = clinical_notes.appointment_id
          AND appointment.patient_id = clinical_notes.patient_id
          AND appointment.professional_id = clinical_notes.professional_id
          AND professional.user_id = app_current_user_id()
          AND appointment.status IN ('in_progress', 'completed')
    )
);

DROP POLICY IF EXISTS clinical_notes_professional_update ON clinical_notes;
CREATE POLICY clinical_notes_professional_update ON clinical_notes
FOR UPDATE USING (
    EXISTS (SELECT 1 FROM professionals professional
      WHERE professional.id=clinical_notes.professional_id
        AND professional.user_id=app_current_user_id())
) WITH CHECK (
    EXISTS (SELECT 1 FROM professionals professional
      WHERE professional.id=clinical_notes.professional_id
        AND professional.user_id=app_current_user_id())
);

DROP POLICY IF EXISTS diagnoses_authorized_select ON diagnoses;
CREATE POLICY diagnoses_authorized_select ON diagnoses
FOR SELECT USING (
    EXISTS (SELECT 1 FROM clinical_notes note
      WHERE note.id=diagnoses.clinical_note_id
        AND app_can_read_patient(note.patient_id))
);
DROP POLICY IF EXISTS diagnoses_professional_insert ON diagnoses;
CREATE POLICY diagnoses_professional_insert ON diagnoses
FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM clinical_notes note
      JOIN professionals professional ON professional.id=note.professional_id
      WHERE note.id=diagnoses.clinical_note_id
        AND professional.user_id=app_current_user_id())
);
DROP POLICY IF EXISTS treatments_authorized_select ON treatments;
CREATE POLICY treatments_authorized_select ON treatments
FOR SELECT USING (
    EXISTS (SELECT 1 FROM clinical_notes note
      WHERE note.id=treatments.clinical_note_id
        AND app_can_read_patient(note.patient_id))
);
DROP POLICY IF EXISTS treatments_professional_insert ON treatments;
CREATE POLICY treatments_professional_insert ON treatments
FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM clinical_notes note
      JOIN professionals professional ON professional.id=note.professional_id
      WHERE note.id=treatments.clinical_note_id
        AND professional.user_id=app_current_user_id())
);
DROP POLICY IF EXISTS appointment_followups_authorized_select ON appointment_followups;
CREATE POLICY appointment_followups_authorized_select ON appointment_followups
FOR SELECT USING (
    EXISTS (SELECT 1 FROM appointments appointment
      WHERE appointment.id=appointment_followups.source_appointment_id)
);
DROP POLICY IF EXISTS appointment_followups_professional_insert ON appointment_followups;
CREATE POLICY appointment_followups_professional_insert ON appointment_followups
FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM professionals professional
      WHERE professional.id=appointment_followups.recommended_by_professional_id
        AND professional.user_id=app_current_user_id())
);

ALTER TABLE referrals ENABLE ROW LEVEL SECURITY;
ALTER TABLE appointment_ratings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS referrals_authorized_select ON referrals;
CREATE POLICY referrals_authorized_select ON referrals
FOR SELECT USING (app_can_read_patient(patient_id) OR EXISTS (
    SELECT 1 FROM professionals professional
    WHERE professional.id=referrals.issued_by_professional_id
      AND professional.user_id=app_current_user_id()
));
DROP POLICY IF EXISTS referrals_professional_insert ON referrals;
CREATE POLICY referrals_professional_insert ON referrals
FOR INSERT WITH CHECK (EXISTS (
    SELECT 1 FROM professionals professional
    WHERE professional.id=referrals.issued_by_professional_id
      AND professional.user_id=app_current_user_id()
));

DROP POLICY IF EXISTS appointment_ratings_authorized_select ON appointment_ratings;
CREATE POLICY appointment_ratings_authorized_select ON appointment_ratings
FOR SELECT USING (app_can_read_patient(patient_id) OR EXISTS (
    SELECT 1 FROM professionals professional
    WHERE professional.id=appointment_ratings.professional_id
      AND professional.user_id=app_current_user_id()
));
DROP POLICY IF EXISTS appointment_ratings_patient_insert ON appointment_ratings;
CREATE POLICY appointment_ratings_patient_insert ON appointment_ratings
FOR INSERT WITH CHECK (EXISTS (
    SELECT 1 FROM patients patient
    JOIN persons person ON person.id=patient.person_id
    WHERE patient.id=appointment_ratings.patient_id
      AND person.user_id=app_current_user_id()
));

DROP POLICY IF EXISTS clinical_records_professional_insert
ON clinical_records;
CREATE POLICY clinical_records_professional_insert ON clinical_records
FOR INSERT WITH CHECK (
    source = 'professional'
    AND author_user_id = app_current_user_id()
    AND related_appointment_id IS NOT NULL
    AND EXISTS (
        SELECT 1
        FROM appointments appointment
        JOIN professionals professional
          ON professional.id = appointment.professional_id
        WHERE appointment.id = clinical_records.related_appointment_id
          AND appointment.patient_id = clinical_records.patient_id
          AND professional.user_id = app_current_user_id()
          AND appointment.status IN ('in_progress', 'completed')
    )
);

DROP POLICY IF EXISTS clinical_records_professional_update
ON clinical_records;
CREATE POLICY clinical_records_professional_update ON clinical_records
FOR UPDATE USING (
    source = 'professional'
    AND author_user_id = app_current_user_id()
    AND related_appointment_id IS NOT NULL
    AND app_has_permission('clinical_records.manage')
    AND EXISTS (
        SELECT 1
        FROM appointments appointment
        JOIN professionals professional
          ON professional.id = appointment.professional_id
        WHERE appointment.id = clinical_records.related_appointment_id
          AND appointment.patient_id = clinical_records.patient_id
          AND professional.user_id = app_current_user_id()
          AND appointment.status IN ('in_progress', 'completed')
    )
) WITH CHECK (
    source = 'professional'
    AND author_user_id = app_current_user_id()
    AND related_appointment_id IS NOT NULL
    AND app_has_permission('clinical_records.manage')
);

-- ============================================================
-- FAMILIARES Y AUTORIZACIONES
-- ============================================================

ALTER TABLE patient_guardians ENABLE ROW LEVEL SECURITY;
ALTER TABLE guardian_link_codes ENABLE ROW LEVEL SECURITY;
ALTER TABLE family_authorizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE family_authorization_permissions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS patient_guardians_authorized_select
ON patient_guardians;
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

DROP POLICY IF EXISTS guardian_link_codes_owner_insert
ON guardian_link_codes;
CREATE POLICY guardian_link_codes_owner_insert ON guardian_link_codes
FOR INSERT WITH CHECK (
    generated_by_user_id = app_current_user_id()
    AND EXISTS (
        SELECT 1 FROM patients patient
        JOIN persons person ON person.id = patient.person_id
        WHERE patient.id = guardian_link_codes.minor_patient_id
          AND person.user_id = app_current_user_id()
    )
);

DROP POLICY IF EXISTS guardian_link_codes_redeem_select
ON guardian_link_codes;
CREATE POLICY guardian_link_codes_redeem_select ON guardian_link_codes
FOR SELECT USING (
    generated_by_user_id = app_current_user_id()
    OR (used_at IS NULL AND expires_at > now())
);

DROP POLICY IF EXISTS guardian_link_codes_redeem_update
ON guardian_link_codes;
CREATE POLICY guardian_link_codes_redeem_update ON guardian_link_codes
FOR UPDATE USING (used_at IS NULL AND expires_at > now())
WITH CHECK (used_by_user_id = app_current_user_id() AND used_at IS NOT NULL);

DROP POLICY IF EXISTS patient_guardians_guardian_insert
ON patient_guardians;
CREATE POLICY patient_guardians_guardian_insert ON patient_guardians
FOR INSERT WITH CHECK (
    guardian_user_id = app_current_user_id()
    AND verification_status = 'validated'
);

DROP POLICY IF EXISTS patient_guardians_guardian_update
ON patient_guardians;
CREATE POLICY patient_guardians_guardian_update ON patient_guardians
FOR UPDATE USING (guardian_user_id = app_current_user_id())
WITH CHECK (guardian_user_id = app_current_user_id());

DROP POLICY IF EXISTS family_authorizations_authorized_select
ON family_authorizations;
CREATE POLICY family_authorizations_authorized_select
ON family_authorizations
FOR SELECT USING (
    family_user_id = app_current_user_id()
    OR granted_by_user_id = app_current_user_id()
    OR app_can_read_patient(patient_id)
);

DROP POLICY IF EXISTS family_authorization_permissions_authorized_select
ON family_authorization_permissions;
CREATE POLICY family_authorization_permissions_authorized_select
ON family_authorization_permissions
FOR SELECT USING (
    EXISTS (
        SELECT 1
        FROM family_authorizations family_auth
        WHERE family_auth.id =
          family_authorization_permissions.authorization_id
    )
);

DROP POLICY IF EXISTS family_authorizations_patient_insert
ON family_authorizations;
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

DROP POLICY IF EXISTS family_authorizations_patient_update
ON family_authorizations;
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

DROP POLICY IF EXISTS family_permissions_patient_manage
ON family_authorization_permissions;
CREATE POLICY family_permissions_patient_manage
ON family_authorization_permissions
FOR ALL USING (
    EXISTS (
        SELECT 1
        FROM family_authorizations family_auth
        JOIN patients patient ON patient.id = family_auth.patient_id
        JOIN persons person ON person.id = patient.person_id
        WHERE family_auth.id =
          family_authorization_permissions.authorization_id
          AND person.user_id = app_current_user_id()
    )
) WITH CHECK (
    EXISTS (
        SELECT 1
        FROM family_authorizations family_auth
        JOIN patients patient ON patient.id = family_auth.patient_id
        JOIN persons person ON person.id = patient.person_id
        WHERE family_auth.id =
          family_authorization_permissions.authorization_id
          AND person.user_id = app_current_user_id()
    )
);

-- ============================================================
-- DISPONIBILIDAD PROFESIONAL
-- ============================================================

ALTER TABLE professional_documents ENABLE ROW LEVEL SECURITY;

ALTER TABLE professional_document_requirements ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS requirements_read ON professional_document_requirements;
CREATE POLICY requirements_read ON professional_document_requirements
FOR SELECT USING (app_current_user_id() IS NOT NULL);
DROP POLICY IF EXISTS requirements_manage ON professional_document_requirements;
CREATE POLICY requirements_manage ON professional_document_requirements
FOR ALL USING (app_has_permission('human_resources.manage'))
WITH CHECK (app_has_permission('human_resources.manage'));

ALTER TABLE professional_specialties ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS professional_specialties_read ON professional_specialties;
CREATE POLICY professional_specialties_read ON professional_specialties
FOR SELECT USING (app_current_user_id() IS NOT NULL);
DROP POLICY IF EXISTS professional_specialties_review ON professional_specialties;
CREATE POLICY professional_specialties_review ON professional_specialties
FOR ALL USING (app_has_permission('human_resources.manage'))
WITH CHECK (app_has_permission('human_resources.manage'));

DROP POLICY IF EXISTS professionals_authenticated_select ON professionals;
CREATE POLICY professionals_authenticated_select ON professionals
FOR SELECT USING (app_current_user_id() IS NOT NULL);
DROP POLICY IF EXISTS professionals_owner_update ON professionals;
CREATE POLICY professionals_owner_update ON professionals
FOR UPDATE USING (user_id=app_current_user_id() OR app_has_role('admin')
  OR app_has_permission('human_resources.manage'))
WITH CHECK (user_id=app_current_user_id() OR app_has_role('admin')
  OR app_has_permission('human_resources.manage'));
DROP POLICY IF EXISTS professionals_rating_summary_update ON professionals;
CREATE POLICY professionals_rating_summary_update ON professionals
FOR UPDATE USING (
  EXISTS (
    SELECT 1
    FROM appointment_ratings rating
    WHERE rating.professional_id=professionals.id
      AND app_can_read_patient(rating.patient_id)
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1
    FROM appointment_ratings rating
    WHERE rating.professional_id=professionals.id
      AND app_can_read_patient(rating.patient_id)
  )
);
DROP POLICY IF EXISTS professionals_hr_insert ON professionals;
CREATE POLICY professionals_hr_insert ON professionals
FOR INSERT WITH CHECK (app_has_permission('human_resources.manage'));

DROP POLICY IF EXISTS professional_documents_authorized_select ON professional_documents;
CREATE POLICY professional_documents_authorized_select ON professional_documents
FOR SELECT USING (EXISTS (SELECT 1 FROM professionals professional
  WHERE professional.id=professional_documents.professional_id
    AND (professional.user_id=app_current_user_id()
      OR app_has_role('admin') OR app_has_role('clinical_supervisor')
      OR app_has_permission('human_resources.read'))));
DROP POLICY IF EXISTS professional_documents_owner_insert ON professional_documents;
CREATE POLICY professional_documents_owner_insert ON professional_documents
FOR INSERT WITH CHECK (status='pending' AND EXISTS (SELECT 1 FROM professionals professional
  WHERE professional.id=professional_documents.professional_id
    AND professional.user_id=app_current_user_id()));
DROP POLICY IF EXISTS professional_documents_reviewer_update ON professional_documents;
CREATE POLICY professional_documents_reviewer_update ON professional_documents
FOR UPDATE USING (app_has_role('admin') OR app_has_role('clinical_supervisor')
  OR app_has_permission('human_resources.manage'))
WITH CHECK (app_has_role('admin') OR app_has_role('clinical_supervisor')
  OR app_has_permission('human_resources.manage'));
DROP POLICY IF EXISTS professional_documents_hr_insert ON professional_documents;
CREATE POLICY professional_documents_hr_insert ON professional_documents
FOR INSERT WITH CHECK (app_has_permission('human_resources.manage'));

ALTER TABLE professional_availability ENABLE ROW LEVEL SECURITY;
ALTER TABLE professional_time_blocks ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS professional_availability_authorized_select ON professional_availability;
CREATE POLICY professional_availability_authorized_select ON professional_availability
FOR SELECT USING (
    is_active OR EXISTS (SELECT 1 FROM professionals professional
      WHERE professional.id=professional_availability.professional_id
        AND professional.user_id=app_current_user_id())
);
DROP POLICY IF EXISTS professional_availability_owner_insert ON professional_availability;
CREATE POLICY professional_availability_owner_insert ON professional_availability
FOR INSERT WITH CHECK (EXISTS (SELECT 1 FROM professionals professional
  WHERE professional.id=professional_availability.professional_id
    AND professional.user_id=app_current_user_id()));
DROP POLICY IF EXISTS professional_availability_owner_update ON professional_availability;
CREATE POLICY professional_availability_owner_update ON professional_availability
FOR UPDATE USING (EXISTS (SELECT 1 FROM professionals professional
  WHERE professional.id=professional_availability.professional_id
    AND professional.user_id=app_current_user_id()))
WITH CHECK (EXISTS (SELECT 1 FROM professionals professional
  WHERE professional.id=professional_availability.professional_id
    AND professional.user_id=app_current_user_id()));

DROP POLICY IF EXISTS professional_time_blocks_owner_select ON professional_time_blocks;
CREATE POLICY professional_time_blocks_owner_select ON professional_time_blocks
FOR SELECT USING (EXISTS (SELECT 1 FROM professionals professional
  WHERE professional.id=professional_time_blocks.professional_id
    AND professional.user_id=app_current_user_id()));
DROP POLICY IF EXISTS professional_time_blocks_owner_insert ON professional_time_blocks;
CREATE POLICY professional_time_blocks_owner_insert ON professional_time_blocks
FOR INSERT WITH CHECK (EXISTS (SELECT 1 FROM professionals professional
  WHERE professional.id=professional_time_blocks.professional_id
    AND professional.user_id=app_current_user_id()));
DROP POLICY IF EXISTS professional_time_blocks_owner_delete ON professional_time_blocks;
CREATE POLICY professional_time_blocks_owner_delete ON professional_time_blocks
FOR DELETE USING (EXISTS (SELECT 1 FROM professionals professional
  WHERE professional.id=professional_time_blocks.professional_id
    AND professional.user_id=app_current_user_id()));

-- ============================================================
-- RECETAS
-- ============================================================

ALTER TABLE prescriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE prescription_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS prescriptions_authorized_select ON prescriptions;
CREATE POLICY prescriptions_authorized_select ON prescriptions
FOR SELECT USING (
    app_can_read_patient(patient_id)
    OR EXISTS (
        SELECT 1
        FROM professionals professional
        WHERE professional.id = prescriptions.professional_id
          AND professional.user_id = app_current_user_id()
    )
);

DROP POLICY IF EXISTS prescription_items_authorized_select
ON prescription_items;
CREATE POLICY prescription_items_authorized_select ON prescription_items
FOR SELECT USING (
    EXISTS (
        SELECT 1
        FROM prescriptions prescription
        WHERE prescription.id = prescription_items.prescription_id
    )
);

DROP POLICY IF EXISTS prescriptions_professional_insert ON prescriptions;
CREATE POLICY prescriptions_professional_insert ON prescriptions
FOR INSERT WITH CHECK (
    status = 'draft'
    AND EXISTS (
        SELECT 1
        FROM appointments appointment
        JOIN professionals professional
          ON professional.id = appointment.professional_id
        WHERE appointment.id = prescriptions.appointment_id
          AND appointment.patient_id = prescriptions.patient_id
          AND appointment.professional_id = prescriptions.professional_id
          AND professional.user_id = app_current_user_id()
          AND appointment.status IN ('in_progress', 'completed')
    )
);

DROP POLICY IF EXISTS prescriptions_professional_update ON prescriptions;
CREATE POLICY prescriptions_professional_update ON prescriptions
FOR UPDATE USING (
    status = 'draft'
    AND EXISTS (
        SELECT 1 FROM professionals professional
        WHERE professional.id = prescriptions.professional_id
          AND professional.user_id = app_current_user_id()
    )
) WITH CHECK (
    status IN ('draft', 'issued', 'cancelled')
    AND EXISTS (
        SELECT 1 FROM professionals professional
        WHERE professional.id = prescriptions.professional_id
          AND professional.user_id = app_current_user_id()
    )
);

DROP POLICY IF EXISTS prescription_items_professional_insert
ON prescription_items;
DROP POLICY IF EXISTS prescriptions_operations_expire ON prescriptions;
CREATE POLICY prescriptions_operations_expire ON prescriptions
FOR UPDATE USING (app_has_permission('administration.manage'))
WITH CHECK (
    app_has_permission('administration.manage')
    AND status='expired'
);

CREATE POLICY prescription_items_professional_insert ON prescription_items
FOR INSERT WITH CHECK (
    EXISTS (
        SELECT 1
        FROM prescriptions prescription
        JOIN professionals professional
          ON professional.id = prescription.professional_id
        WHERE prescription.id = prescription_items.prescription_id
          AND prescription.status = 'draft'
          AND professional.user_id = app_current_user_id()
    )
);

-- ============================================================
-- EMERGENCIAS
-- ============================================================

ALTER TABLE emergency_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE emergency_status_history ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS emergency_events_authorized_select
ON emergency_events;
CREATE POLICY emergency_events_authorized_select ON emergency_events
FOR SELECT USING (
    requested_by_user_id = app_current_user_id()
    OR app_can_read_patient(patient_id)
    OR app_has_role('operator')
);

DROP POLICY IF EXISTS emergency_events_patient_insert ON emergency_events;
CREATE POLICY emergency_events_patient_insert ON emergency_events
FOR INSERT WITH CHECK (
    requested_by_user_id = app_current_user_id()
    AND EXISTS (
        SELECT 1
        FROM patients patient
        JOIN persons person ON person.id = patient.person_id
        WHERE patient.id = emergency_events.patient_id
          AND person.user_id = app_current_user_id()
    )
);

DROP POLICY IF EXISTS emergency_events_patient_update ON emergency_events;
CREATE POLICY emergency_events_patient_update ON emergency_events
FOR UPDATE USING (
    requested_by_user_id = app_current_user_id()
    OR app_has_role('admin')
    OR app_has_role('operator')
    OR app_has_role('clinical_supervisor')
) WITH CHECK (
    requested_by_user_id = app_current_user_id()
    OR app_has_role('admin')
    OR app_has_role('operator')
    OR app_has_role('clinical_supervisor')
);

DROP POLICY IF EXISTS emergency_history_select ON emergency_status_history;
CREATE POLICY emergency_history_select ON emergency_status_history
FOR SELECT USING (
    EXISTS (
        SELECT 1
        FROM emergency_events event
        WHERE event.id = emergency_status_history.emergency_id
    )
);

DROP POLICY IF EXISTS emergency_history_insert ON emergency_status_history;
CREATE POLICY emergency_history_insert ON emergency_status_history
FOR INSERT WITH CHECK (
    changed_by_user_id = app_current_user_id()
);

-- ============================================================
-- RR. HH., EMPRESAS, CATÁLOGO Y PAQUETES
-- ============================================================

ALTER TABLE personnel_applications ENABLE ROW LEVEL SECURITY;
ALTER TABLE personnel_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE employment_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE personnel_observations ENABLE ROW LEVEL SECURITY;
ALTER TABLE health_partners ENABLE ROW LEVEL SECURITY;
ALTER TABLE partner_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE partner_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE partner_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE partner_request_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE diagnostic_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE partner_subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE partner_subscription_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE partner_plan_benefits ENABLE ROW LEVEL SECURITY;
ALTER TABLE partner_subscription_usage ENABLE ROW LEVEL SECURITY;
ALTER TABLE operating_sites ENABLE ROW LEVEL SECURITY;
ALTER TABLE service_catalog ENABLE ROW LEVEL SECURITY;
ALTER TABLE price_list ENABLE ROW LEVEL SECURITY;
ALTER TABLE coin_packages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS personnel_applications_authorized_select ON personnel_applications;
CREATE POLICY personnel_applications_authorized_select ON personnel_applications
FOR SELECT USING (applicant_user_id=app_current_user_id()
    OR app_has_permission('human_resources.read'));
DROP POLICY IF EXISTS personnel_applications_applicant_insert ON personnel_applications;
CREATE POLICY personnel_applications_applicant_insert ON personnel_applications
FOR INSERT WITH CHECK (applicant_user_id=app_current_user_id() AND status='pending');
DROP POLICY IF EXISTS personnel_applications_hr_update ON personnel_applications;
CREATE POLICY personnel_applications_hr_update ON personnel_applications
FOR UPDATE USING (app_has_permission('human_resources.manage'))
WITH CHECK (app_has_permission('human_resources.manage'));

DROP POLICY IF EXISTS personnel_documents_authorized_select ON personnel_documents;
CREATE POLICY personnel_documents_authorized_select ON personnel_documents
FOR SELECT USING (app_has_permission('human_resources.read') OR EXISTS (
    SELECT 1 FROM personnel_applications application
    WHERE application.id=personnel_documents.application_id
      AND application.applicant_user_id=app_current_user_id()
) OR EXISTS (
    SELECT 1 FROM professionals professional
    WHERE professional.id=personnel_documents.professional_id
      AND professional.user_id=app_current_user_id()
));
DROP POLICY IF EXISTS personnel_documents_applicant_insert ON personnel_documents;
CREATE POLICY personnel_documents_applicant_insert ON personnel_documents
FOR INSERT WITH CHECK (status='pending' AND EXISTS (
    SELECT 1 FROM personnel_applications application
    WHERE application.id=personnel_documents.application_id
      AND application.applicant_user_id=app_current_user_id()
      AND application.status IN ('pending','under_review')
));
DROP POLICY IF EXISTS personnel_documents_hr_update ON personnel_documents;
CREATE POLICY personnel_documents_hr_update ON personnel_documents
FOR UPDATE USING (app_has_permission('human_resources.manage'))
WITH CHECK (app_has_permission('human_resources.manage'));

DROP POLICY IF EXISTS employment_hr_select ON employment_records;
CREATE POLICY employment_hr_select ON employment_records
FOR SELECT USING (
    app_has_role('admin')
    OR app_has_role('human_resources')
    OR app_has_permission('human_resources.read')
);
DROP POLICY IF EXISTS employment_hr_manage ON employment_records;
CREATE POLICY employment_hr_manage ON employment_records
FOR ALL USING (app_has_permission('human_resources.manage'))
WITH CHECK (app_has_permission('human_resources.manage'));
DROP POLICY IF EXISTS employment_owner_select ON employment_records;
CREATE POLICY employment_owner_select ON employment_records
FOR SELECT USING (EXISTS (
    SELECT 1 FROM professionals professional
    WHERE professional.id=employment_records.professional_id
      AND professional.user_id=app_current_user_id()
));

DROP POLICY IF EXISTS personnel_observations_hr_manage ON personnel_observations;
CREATE POLICY personnel_observations_hr_manage ON personnel_observations
FOR ALL USING (app_has_permission('human_resources.manage'))
WITH CHECK (app_has_permission('human_resources.manage')
    AND registered_by_user_id=app_current_user_id());
DROP POLICY IF EXISTS personnel_observations_owner_select ON personnel_observations;
CREATE POLICY personnel_observations_owner_select ON personnel_observations
FOR SELECT USING (NOT is_confidential AND EXISTS (
    SELECT 1 FROM professionals professional
    WHERE professional.id=personnel_observations.professional_id
      AND professional.user_id=app_current_user_id()
));

DROP POLICY IF EXISTS partners_authorized_select ON health_partners;
CREATE POLICY partners_authorized_select ON health_partners
FOR SELECT USING (
    app_has_role('admin')
    OR app_has_role('partner')
    OR is_active
);
DROP POLICY IF EXISTS partners_admin_insert ON health_partners;
CREATE POLICY partners_admin_insert ON health_partners
FOR INSERT WITH CHECK (app_has_role('admin'));
DROP POLICY IF EXISTS partners_admin_update ON health_partners;
CREATE POLICY partners_admin_update ON health_partners
FOR UPDATE USING (app_has_role('admin')) WITH CHECK (app_has_role('admin'));

DROP POLICY IF EXISTS partner_users_authorized_select ON partner_users;
CREATE POLICY partner_users_authorized_select ON partner_users
FOR SELECT USING (user_id=app_current_user_id() OR app_has_role('admin'));
DROP POLICY IF EXISTS partner_users_admin_manage ON partner_users;
CREATE POLICY partner_users_admin_manage ON partner_users
FOR ALL USING (app_has_role('admin')) WITH CHECK (app_has_role('admin'));

DROP POLICY IF EXISTS partner_documents_authorized_select ON partner_documents;
CREATE POLICY partner_documents_authorized_select ON partner_documents
FOR SELECT USING (app_has_role('admin') OR EXISTS(SELECT 1 FROM partner_users partner_user WHERE partner_user.partner_id=partner_documents.partner_id AND partner_user.user_id=app_current_user_id() AND partner_user.is_active));
DROP POLICY IF EXISTS partner_documents_authorized_insert ON partner_documents;
CREATE POLICY partner_documents_authorized_insert ON partner_documents
FOR INSERT WITH CHECK (app_has_role('admin') OR EXISTS(SELECT 1 FROM partner_users partner_user WHERE partner_user.partner_id=partner_documents.partner_id AND partner_user.user_id=app_current_user_id() AND partner_user.is_active));
DROP POLICY IF EXISTS partner_documents_admin_update ON partner_documents;
CREATE POLICY partner_documents_admin_update ON partner_documents
FOR UPDATE USING (app_has_role('admin')) WITH CHECK (app_has_role('admin'));

DROP POLICY IF EXISTS partner_requests_authorized_select ON partner_requests;
CREATE POLICY partner_requests_authorized_select ON partner_requests
FOR SELECT USING (requested_by_user_id=app_current_user_id() OR app_can_read_patient(patient_id) OR EXISTS(SELECT 1 FROM partner_users partner_user WHERE partner_user.partner_id=partner_requests.partner_id AND partner_user.user_id=app_current_user_id() AND partner_user.is_active));
DROP POLICY IF EXISTS partner_requests_patient_insert ON partner_requests;
CREATE POLICY partner_requests_patient_insert ON partner_requests
FOR INSERT WITH CHECK (requested_by_user_id=app_current_user_id() AND app_can_read_patient(patient_id));
DROP POLICY IF EXISTS partner_requests_authorized_update ON partner_requests;
CREATE POLICY partner_requests_authorized_update ON partner_requests
FOR UPDATE USING (requested_by_user_id=app_current_user_id() OR EXISTS(SELECT 1 FROM partner_users partner_user WHERE partner_user.partner_id=partner_requests.partner_id AND partner_user.user_id=app_current_user_id() AND partner_user.is_active))
WITH CHECK (requested_by_user_id=app_current_user_id() OR EXISTS(SELECT 1 FROM partner_users partner_user WHERE partner_user.partner_id=partner_requests.partner_id AND partner_user.user_id=app_current_user_id() AND partner_user.is_active));

DROP POLICY IF EXISTS partner_request_items_authorized_select ON partner_request_items;
CREATE POLICY partner_request_items_authorized_select ON partner_request_items
FOR SELECT USING (EXISTS(SELECT 1 FROM partner_requests request WHERE request.id=partner_request_items.request_id));
DROP POLICY IF EXISTS partner_request_items_patient_insert ON partner_request_items;
CREATE POLICY partner_request_items_patient_insert ON partner_request_items
FOR INSERT WITH CHECK (EXISTS(SELECT 1 FROM partner_requests request WHERE request.id=partner_request_items.request_id AND request.requested_by_user_id=app_current_user_id() AND request.status='draft'));
DROP POLICY IF EXISTS partner_request_items_partner_update ON partner_request_items;
CREATE POLICY partner_request_items_partner_update ON partner_request_items
FOR UPDATE USING (EXISTS(SELECT 1 FROM partner_requests request JOIN partner_users partner_user ON partner_user.partner_id=request.partner_id WHERE request.id=partner_request_items.request_id AND partner_user.user_id=app_current_user_id() AND partner_user.is_active))
WITH CHECK (EXISTS(SELECT 1 FROM partner_requests request JOIN partner_users partner_user ON partner_user.partner_id=request.partner_id WHERE request.id=partner_request_items.request_id AND partner_user.user_id=app_current_user_id() AND partner_user.is_active));

DROP POLICY IF EXISTS diagnostic_orders_authorized_select ON diagnostic_orders;
CREATE POLICY diagnostic_orders_authorized_select ON diagnostic_orders
FOR SELECT USING (app_can_read_patient(patient_id) OR EXISTS(SELECT 1 FROM professionals professional WHERE professional.id=diagnostic_orders.requested_by_professional_id AND professional.user_id=app_current_user_id()) OR EXISTS(SELECT 1 FROM partner_users partner_user WHERE partner_user.partner_id=diagnostic_orders.partner_id AND partner_user.user_id=app_current_user_id() AND partner_user.is_active));
DROP POLICY IF EXISTS diagnostic_orders_professional_insert ON diagnostic_orders;
CREATE POLICY diagnostic_orders_professional_insert ON diagnostic_orders
FOR INSERT WITH CHECK (app_can_read_patient(patient_id) AND EXISTS(SELECT 1 FROM professionals professional WHERE professional.id=diagnostic_orders.requested_by_professional_id AND professional.user_id=app_current_user_id()));
DROP POLICY IF EXISTS diagnostic_orders_partner_update ON diagnostic_orders;
CREATE POLICY diagnostic_orders_partner_update ON diagnostic_orders
FOR UPDATE USING (EXISTS(SELECT 1 FROM partner_users partner_user WHERE partner_user.partner_id=diagnostic_orders.partner_id AND partner_user.user_id=app_current_user_id() AND partner_user.is_active))
WITH CHECK (EXISTS(SELECT 1 FROM partner_users partner_user WHERE partner_user.partner_id=diagnostic_orders.partner_id AND partner_user.user_id=app_current_user_id() AND partner_user.is_active));

DROP POLICY IF EXISTS partner_subscriptions_authorized_select
ON partner_subscriptions;
CREATE POLICY partner_subscriptions_authorized_select
ON partner_subscriptions
FOR SELECT USING (
    app_has_role('admin')
    OR EXISTS (
        SELECT 1
        FROM partner_users partner_user
        WHERE partner_user.partner_id = partner_subscriptions.partner_id
          AND partner_user.user_id = app_current_user_id()
          AND partner_user.is_active
    )
);

DROP POLICY IF EXISTS partner_subscriptions_manage_insert ON partner_subscriptions;
CREATE POLICY partner_subscriptions_manage_insert ON partner_subscriptions
FOR INSERT WITH CHECK (
    app_has_role('admin') OR app_has_permission('partners.manage')
);

DROP POLICY IF EXISTS partner_subscriptions_manage_update ON partner_subscriptions;
CREATE POLICY partner_subscriptions_manage_update ON partner_subscriptions
FOR UPDATE USING (
    app_has_role('admin') OR app_has_permission('partners.manage')
    OR EXISTS (
        SELECT 1 FROM payment_orders payment_order
        WHERE payment_order.id=partner_subscriptions.payment_order_id
          AND payment_order.user_id=app_current_user_id()
    )
)
WITH CHECK (
    app_has_role('admin') OR app_has_permission('partners.manage')
    OR EXISTS (
        SELECT 1 FROM payment_orders payment_order
        WHERE payment_order.id=partner_subscriptions.payment_order_id
          AND payment_order.user_id=app_current_user_id()
    )
);

DROP POLICY IF EXISTS partner_plans_select ON partner_subscription_plans;
CREATE POLICY partner_plans_select ON partner_subscription_plans
FOR SELECT USING (is_active OR app_has_role('admin') OR app_has_permission('partners.manage'));

DROP POLICY IF EXISTS partner_plans_manage_insert ON partner_subscription_plans;
CREATE POLICY partner_plans_manage_insert ON partner_subscription_plans
FOR INSERT WITH CHECK (
    app_has_role('admin') OR app_has_permission('partners.manage')
);

DROP POLICY IF EXISTS partner_plans_manage_update ON partner_subscription_plans;
CREATE POLICY partner_plans_manage_update ON partner_subscription_plans
FOR UPDATE USING (
    app_has_role('admin') OR app_has_permission('partners.manage')
)
WITH CHECK (
    app_has_role('admin') OR app_has_permission('partners.manage')
);

DROP POLICY IF EXISTS partner_plan_benefits_select ON partner_plan_benefits;
CREATE POLICY partner_plan_benefits_select ON partner_plan_benefits
FOR SELECT USING (true);
DROP POLICY IF EXISTS partner_plan_benefits_manage ON partner_plan_benefits;
CREATE POLICY partner_plan_benefits_manage ON partner_plan_benefits
FOR ALL USING (app_has_role('admin') OR app_has_permission('partners.manage'))
WITH CHECK (app_has_role('admin') OR app_has_permission('partners.manage'));

DROP POLICY IF EXISTS partner_subscription_usage_authorized ON partner_subscription_usage;
CREATE POLICY partner_subscription_usage_authorized ON partner_subscription_usage
FOR ALL USING (
    app_has_role('admin') OR app_has_permission('partners.manage')
    OR EXISTS(
        SELECT 1 FROM partner_subscriptions subscription
        JOIN partner_users partner_user ON partner_user.partner_id=subscription.partner_id
        WHERE subscription.id=partner_subscription_usage.subscription_id
          AND partner_user.user_id=app_current_user_id() AND partner_user.is_active
    )
)
WITH CHECK (
    app_has_role('admin') OR app_has_permission('partners.manage')
    OR EXISTS(
        SELECT 1 FROM partner_subscriptions subscription
        JOIN partner_users partner_user ON partner_user.partner_id=subscription.partner_id
        WHERE subscription.id=partner_subscription_usage.subscription_id
          AND partner_user.user_id=app_current_user_id() AND partner_user.is_active
    )
);

DROP POLICY IF EXISTS operating_sites_select ON operating_sites;
CREATE POLICY operating_sites_select ON operating_sites
FOR SELECT USING (is_active OR app_has_role('admin')
    OR app_has_permission('administration.read'));
DROP POLICY IF EXISTS operating_sites_admin_insert ON operating_sites;
CREATE POLICY operating_sites_admin_insert ON operating_sites
FOR INSERT WITH CHECK (app_has_permission('administration.manage'));
DROP POLICY IF EXISTS operating_sites_admin_update ON operating_sites;
CREATE POLICY operating_sites_admin_update ON operating_sites
FOR UPDATE USING (app_has_permission('administration.manage'))
WITH CHECK (app_has_permission('administration.manage'));

DROP POLICY IF EXISTS catalog_active_select ON service_catalog;
CREATE POLICY catalog_active_select ON service_catalog
FOR SELECT USING (is_active OR app_has_role('admin') OR app_has_permission('catalog.manage'));

DROP POLICY IF EXISTS catalog_manage_insert ON service_catalog;
CREATE POLICY catalog_manage_insert ON service_catalog
FOR INSERT WITH CHECK (app_has_role('admin') OR app_has_permission('catalog.manage'));
DROP POLICY IF EXISTS catalog_manage_update ON service_catalog;
CREATE POLICY catalog_manage_update ON service_catalog
FOR UPDATE USING (app_has_role('admin') OR app_has_permission('catalog.manage'))
WITH CHECK (app_has_role('admin') OR app_has_permission('catalog.manage'));

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
FOR UPDATE USING (app_has_role('admin') OR app_has_permission('catalog.manage'))
WITH CHECK (app_has_role('admin') OR app_has_permission('catalog.manage'));

DROP POLICY IF EXISTS coin_packages_active_select ON coin_packages;
CREATE POLICY coin_packages_active_select ON coin_packages
FOR SELECT USING (
    (
        is_active
        AND valid_from <= now()
        AND (valid_until IS NULL OR valid_until > now())
    )
    OR app_has_role('admin')
    OR app_has_permission('coins.manage')
);

DROP POLICY IF EXISTS coin_packages_manage_insert ON coin_packages;
CREATE POLICY coin_packages_manage_insert ON coin_packages
FOR INSERT WITH CHECK (
    app_has_role('admin') OR app_has_permission('coins.manage')
);

DROP POLICY IF EXISTS coin_packages_manage_update ON coin_packages;
CREATE POLICY coin_packages_manage_update ON coin_packages
FOR UPDATE USING (
    app_has_role('admin') OR app_has_permission('coins.manage')
)
WITH CHECK (
    app_has_role('admin') OR app_has_permission('coins.manage')
);

-- ============================================================
-- AUDITORÍA
-- ============================================================

ALTER TABLE audit_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE clinical_access_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS audit_events_authorized_select ON audit_events;
CREATE POLICY audit_events_authorized_select ON audit_events
FOR SELECT USING (
    app_has_permission('audit.read')
    OR (module='human_resources' AND app_has_permission('human_resources.read'))
);

DROP POLICY IF EXISTS clinical_access_logs_authorized_select
ON clinical_access_logs;
CREATE POLICY clinical_access_logs_authorized_select
ON clinical_access_logs
FOR SELECT USING (app_has_permission('audit.read'));

DROP POLICY IF EXISTS clinical_access_logs_actor_insert ON clinical_access_logs;
CREATE POLICY clinical_access_logs_actor_insert ON clinical_access_logs
FOR INSERT WITH CHECK (
    actor_user_id=app_current_user_id()
    AND app_can_read_patient(patient_id)
);

DROP POLICY IF EXISTS audit_events_authorized_insert ON audit_events;
CREATE POLICY audit_events_authorized_insert ON audit_events
FOR INSERT WITH CHECK (
    actor_user_id = app_current_user_id()
);

-- ============================================================
-- IA CONVERSACIONAL
-- ============================================================

ALTER TABLE ai_conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_risk_assessments ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_voice_sessions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS ai_conversations_patient_manage ON ai_conversations;
CREATE POLICY ai_conversations_patient_manage ON ai_conversations
FOR ALL USING (
    created_by_user_id = app_current_user_id()
) WITH CHECK (
    created_by_user_id = app_current_user_id()
    AND EXISTS (
        SELECT 1
        FROM patients patient
        JOIN persons person ON person.id = patient.person_id
        WHERE patient.id = ai_conversations.patient_id
          AND person.user_id = app_current_user_id()
    )
);

DROP POLICY IF EXISTS ai_messages_patient_manage ON ai_messages;
CREATE POLICY ai_messages_patient_manage ON ai_messages
FOR ALL USING (
    EXISTS (
        SELECT 1
        FROM ai_conversations conversation
        WHERE conversation.id = ai_messages.conversation_id
          AND conversation.created_by_user_id = app_current_user_id()
    )
) WITH CHECK (
    EXISTS (
        SELECT 1
        FROM ai_conversations conversation
        WHERE conversation.id = ai_messages.conversation_id
          AND conversation.created_by_user_id = app_current_user_id()
    )
);

DROP POLICY IF EXISTS ai_risk_patient_manage ON ai_risk_assessments;
CREATE POLICY ai_risk_patient_manage ON ai_risk_assessments
FOR ALL USING (
    EXISTS (
        SELECT 1
        FROM ai_conversations conversation
        WHERE conversation.id = ai_risk_assessments.conversation_id
          AND conversation.created_by_user_id = app_current_user_id()
    )
) WITH CHECK (
    EXISTS (
        SELECT 1
        FROM ai_conversations conversation
        WHERE conversation.id = ai_risk_assessments.conversation_id
          AND conversation.created_by_user_id = app_current_user_id()
    )
);

DROP POLICY IF EXISTS ai_voice_sessions_patient_manage ON ai_voice_sessions;
CREATE POLICY ai_voice_sessions_patient_manage ON ai_voice_sessions
FOR ALL USING (
    user_id = app_current_user_id()
) WITH CHECK (
    user_id = app_current_user_id()
);

-- ============================================================
-- TELEMEDICINA
-- ============================================================

ALTER TABLE telemedicine_rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE telemedicine_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE telemedicine_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE telemedicine_shared_files ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS telemedicine_rooms_authorized_select
ON telemedicine_rooms;
CREATE POLICY telemedicine_rooms_authorized_select ON telemedicine_rooms
FOR SELECT USING (
    EXISTS (
        SELECT 1
        FROM appointments appointment
        JOIN patients patient ON patient.id = appointment.patient_id
        JOIN persons patient_person
          ON patient_person.id = patient.person_id
        JOIN professionals professional
          ON professional.id = appointment.professional_id
        WHERE appointment.id = telemedicine_rooms.appointment_id
          AND (
              patient_person.user_id = app_current_user_id()
              OR professional.user_id = app_current_user_id()
              OR app_has_role('admin')
              OR app_has_role('operator')
          )
    )
);

DROP POLICY IF EXISTS telemedicine_rooms_staff_insert
ON telemedicine_rooms;
CREATE POLICY telemedicine_rooms_staff_insert ON telemedicine_rooms
FOR INSERT WITH CHECK (
    EXISTS (
        SELECT 1
        FROM appointments appointment
        JOIN professionals professional
          ON professional.id = appointment.professional_id
        WHERE appointment.id = telemedicine_rooms.appointment_id
          AND (
              professional.user_id = app_current_user_id()
              OR app_has_role('admin')
              OR app_has_role('operator')
          )
    )
);

DROP POLICY IF EXISTS telemedicine_participants_authorized
ON telemedicine_participants;
CREATE POLICY telemedicine_participants_authorized
ON telemedicine_participants
FOR ALL USING (
    user_id = app_current_user_id()
    OR app_has_role('admin')
    OR app_has_role('operator')
) WITH CHECK (
    user_id = app_current_user_id()
    OR app_has_role('admin')
    OR app_has_role('operator')
    OR EXISTS (
        SELECT 1
        FROM telemedicine_rooms room
        JOIN appointments appointment
          ON appointment.id = room.appointment_id
        JOIN professionals professional
          ON professional.id = appointment.professional_id
        WHERE room.id = telemedicine_participants.room_id
          AND professional.user_id = app_current_user_id()
    )
);

DROP POLICY IF EXISTS telemedicine_events_participant_insert
ON telemedicine_events;
CREATE POLICY telemedicine_events_participant_insert ON telemedicine_events
FOR INSERT WITH CHECK (
    user_id = app_current_user_id()
    AND EXISTS (
        SELECT 1
        FROM telemedicine_participants participant
        WHERE participant.room_id = telemedicine_events.room_id
          AND participant.user_id = app_current_user_id()
    )
);

DROP POLICY IF EXISTS telemedicine_participants_room_select ON telemedicine_participants;
CREATE POLICY telemedicine_participants_room_select ON telemedicine_participants
FOR SELECT USING (EXISTS (
    SELECT 1 FROM telemedicine_rooms room
    JOIN appointments appointment ON appointment.id=room.appointment_id
    JOIN patients patient ON patient.id=appointment.patient_id
    JOIN persons patient_person ON patient_person.id=patient.person_id
    JOIN professionals professional ON professional.id=appointment.professional_id
    WHERE room.id=telemedicine_participants.room_id
      AND (patient_person.user_id=app_current_user_id()
        OR professional.user_id=app_current_user_id())
));

DROP POLICY IF EXISTS telemedicine_events_room_select ON telemedicine_events;
CREATE POLICY telemedicine_events_room_select ON telemedicine_events
FOR SELECT USING (EXISTS (
    SELECT 1 FROM telemedicine_rooms room
    JOIN appointments appointment ON appointment.id=room.appointment_id
    JOIN patients patient ON patient.id=appointment.patient_id
    JOIN persons patient_person ON patient_person.id=patient.person_id
    JOIN professionals professional ON professional.id=appointment.professional_id
    WHERE room.id=telemedicine_events.room_id
      AND (patient_person.user_id=app_current_user_id()
        OR professional.user_id=app_current_user_id())
));

DROP POLICY IF EXISTS telemedicine_shared_files_room_select ON telemedicine_shared_files;
CREATE POLICY telemedicine_shared_files_room_select ON telemedicine_shared_files
FOR SELECT USING (EXISTS (
    SELECT 1 FROM telemedicine_rooms room
    JOIN appointments appointment ON appointment.id=room.appointment_id
    WHERE room.id=telemedicine_shared_files.room_id
      AND app_can_read_patient(appointment.patient_id)
));
DROP POLICY IF EXISTS telemedicine_shared_files_participant_insert ON telemedicine_shared_files;
CREATE POLICY telemedicine_shared_files_participant_insert ON telemedicine_shared_files
FOR INSERT WITH CHECK (shared_by_user_id=app_current_user_id() AND EXISTS (
    SELECT 1 FROM telemedicine_participants participant
    WHERE participant.room_id=telemedicine_shared_files.room_id
      AND participant.user_id=app_current_user_id()
));

-- ============================================================
-- CONSENTIMIENTOS
-- ============================================================

ALTER TABLE consent_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE patient_consents ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS consent_types_active_select ON consent_types;
CREATE POLICY consent_types_active_select ON consent_types
FOR SELECT USING (is_active OR app_has_role('admin'));

DROP POLICY IF EXISTS patient_consents_authorized_select
ON patient_consents;
CREATE POLICY patient_consents_authorized_select ON patient_consents
FOR SELECT USING (
    app_can_read_patient(patient_id)
    OR granted_by_user_id = app_current_user_id()
    OR app_has_role('admin')
);

DROP POLICY IF EXISTS patient_consents_patient_insert ON patient_consents;
CREATE POLICY patient_consents_patient_insert ON patient_consents
FOR INSERT WITH CHECK (
    granted_by_user_id = app_current_user_id()
    AND EXISTS (
        SELECT 1
        FROM patients patient
        JOIN persons person ON person.id = patient.person_id
        WHERE patient.id = patient_consents.patient_id
          AND person.user_id = app_current_user_id()
    )
);

DROP POLICY IF EXISTS patient_consents_patient_update ON patient_consents;
CREATE POLICY patient_consents_patient_update ON patient_consents
FOR UPDATE USING (
    granted_by_user_id = app_current_user_id()
) WITH CHECK (
    granted_by_user_id = app_current_user_id()
);

-- ============================================================
-- CONFIGURACIÓN ADMINISTRATIVA
-- ============================================================

ALTER TABLE system_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE business_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE business_rule_history ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS system_settings_admin_select ON system_settings;
CREATE POLICY system_settings_admin_select ON system_settings
FOR SELECT USING (app_has_permission('administration.read'));
DROP POLICY IF EXISTS system_settings_payment_public_select ON system_settings;
CREATE POLICY system_settings_payment_public_select ON system_settings
FOR SELECT USING (
    setting_key IN (
        'payments.qr_image_url',
        'payments.qr_account_name',
        'payments.qr_bank_name',
        'payments.cash_enabled',
        'coins.expiration_notice_days',
        'partners.grace_period_days'
    )
);
DROP POLICY IF EXISTS system_settings_admin_insert ON system_settings;
CREATE POLICY system_settings_admin_insert ON system_settings
FOR INSERT WITH CHECK (app_has_permission('administration.manage'));
DROP POLICY IF EXISTS system_settings_admin_update ON system_settings;
CREATE POLICY system_settings_admin_update ON system_settings
FOR UPDATE USING (app_has_permission('administration.manage'))
WITH CHECK (app_has_permission('administration.manage'));

DROP POLICY IF EXISTS business_rules_admin_select ON business_rules;
CREATE POLICY business_rules_admin_select ON business_rules
FOR SELECT USING (app_has_permission('administration.read'));
DROP POLICY IF EXISTS business_rules_admin_insert ON business_rules;
CREATE POLICY business_rules_admin_insert ON business_rules
FOR INSERT WITH CHECK (
    app_has_permission('administration.manage')
    AND created_by_user_id=app_current_user_id()
);
DROP POLICY IF EXISTS business_rules_admin_update ON business_rules;
CREATE POLICY business_rules_admin_update ON business_rules
FOR UPDATE USING (app_has_permission('administration.manage'))
WITH CHECK (app_has_permission('administration.manage'));
DROP POLICY IF EXISTS business_rule_history_admin_select ON business_rule_history;
CREATE POLICY business_rule_history_admin_select ON business_rule_history
FOR SELECT USING (app_has_permission('administration.read'));
DROP POLICY IF EXISTS business_rule_history_admin_insert ON business_rule_history;
CREATE POLICY business_rule_history_admin_insert ON business_rule_history
FOR INSERT WITH CHECK (
    app_has_permission('administration.manage')
    AND changed_by_user_id=app_current_user_id()
);

-- ============================================================
-- NOTIFICACIONES E INCIDENTES
-- ============================================================

ALTER TABLE notification_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE push_device_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE incidents ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS notification_preferences_own_select
ON notification_preferences;
CREATE POLICY notification_preferences_own_select
ON notification_preferences
FOR SELECT USING (
    user_id = app_current_user_id()
    OR app_has_role('admin')
);

DROP POLICY IF EXISTS notification_preferences_own_insert
ON notification_preferences;
CREATE POLICY notification_preferences_own_insert
ON notification_preferences
FOR INSERT WITH CHECK (user_id = app_current_user_id());

DROP POLICY IF EXISTS notification_preferences_own_update
ON notification_preferences;
CREATE POLICY notification_preferences_own_update
ON notification_preferences
FOR UPDATE USING (
    user_id = app_current_user_id()
) WITH CHECK (
    user_id = app_current_user_id()
);

DROP POLICY IF EXISTS notifications_own_select ON notifications;
CREATE POLICY notifications_own_select ON notifications
FOR SELECT USING (
    user_id = app_current_user_id()
    OR app_has_role('admin')
);

DROP POLICY IF EXISTS notifications_own_update ON notifications;
CREATE POLICY notifications_own_update ON notifications
FOR UPDATE USING (
    user_id = app_current_user_id()
) WITH CHECK (
    user_id = app_current_user_id()
);

DROP POLICY IF EXISTS notifications_operations_update ON notifications;
CREATE POLICY notifications_operations_update ON notifications
FOR UPDATE USING (app_has_permission('administration.manage'))
WITH CHECK (app_has_permission('administration.manage'));

DROP POLICY IF EXISTS notifications_authorized_insert ON notifications;
CREATE POLICY notifications_authorized_insert ON notifications
FOR INSERT WITH CHECK (
    user_id = app_current_user_id()
    OR app_has_permission('notifications.manage')
    OR app_has_permission('coins.manage')
    OR app_has_permission('partners.manage')
);

DROP POLICY IF EXISTS push_device_tokens_own_select ON push_device_tokens;
CREATE POLICY push_device_tokens_own_select
ON push_device_tokens
FOR SELECT USING (
    user_id = app_current_user_id()
    OR app_has_permission('notifications.manage')
);

DROP POLICY IF EXISTS push_device_tokens_own_insert ON push_device_tokens;
CREATE POLICY push_device_tokens_own_insert
ON push_device_tokens
FOR INSERT WITH CHECK (user_id = app_current_user_id());

DROP POLICY IF EXISTS push_device_tokens_own_update ON push_device_tokens;
CREATE POLICY push_device_tokens_own_update
ON push_device_tokens
FOR UPDATE USING (
    user_id = app_current_user_id()
) WITH CHECK (
    user_id = app_current_user_id()
);

DROP POLICY IF EXISTS incidents_authorized_select ON incidents;
CREATE POLICY incidents_authorized_select ON incidents
FOR SELECT USING (
    reported_by_user_id = app_current_user_id()
    OR app_has_role('admin')
    OR app_has_role('operator')
    OR app_has_role('clinical_supervisor')
);

DROP POLICY IF EXISTS incidents_own_insert ON incidents;
CREATE POLICY incidents_own_insert ON incidents
FOR INSERT WITH CHECK (
    reported_by_user_id = app_current_user_id()
);

DROP POLICY IF EXISTS incidents_own_update ON incidents;
CREATE POLICY incidents_own_update ON incidents
FOR UPDATE USING (
    reported_by_user_id = app_current_user_id()
    OR app_has_role('admin')
    OR app_has_role('operator')
    OR app_has_role('clinical_supervisor')
);

-- ============================================================
-- BENEFICIOS Y PAGOS
-- ============================================================

ALTER TABLE benefits ENABLE ROW LEVEL SECURITY;
ALTER TABLE benefit_usages ENABLE ROW LEVEL SECURITY;
ALTER TABLE partner_benefits ENABLE ROW LEVEL SECURITY;
ALTER TABLE benefit_validations ENABLE ROW LEVEL SECURITY;
ALTER TABLE payment_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE payment_incidents ENABLE ROW LEVEL SECURITY;
ALTER TABLE refunds ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS benefits_active_select ON benefits;
CREATE POLICY benefits_active_select ON benefits
FOR SELECT USING (is_active OR app_has_role('admin')
    OR app_has_permission('administration.manage'));

DROP POLICY IF EXISTS benefits_operations_expire ON benefits;
CREATE POLICY benefits_operations_expire ON benefits
FOR UPDATE USING (app_has_permission('administration.manage'))
WITH CHECK (app_has_permission('administration.manage'));

DROP POLICY IF EXISTS benefits_manage_insert ON benefits;
CREATE POLICY benefits_manage_insert ON benefits
FOR INSERT WITH CHECK (app_has_permission('benefits.manage'));
DROP POLICY IF EXISTS benefits_manage_update ON benefits;
CREATE POLICY benefits_manage_update ON benefits
FOR UPDATE USING (app_has_permission('benefits.manage'))
WITH CHECK (app_has_permission('benefits.manage'));

DROP POLICY IF EXISTS benefit_usages_own_select ON benefit_usages;
CREATE POLICY benefit_usages_own_select ON benefit_usages
FOR SELECT USING (
    app_can_read_patient(patient_id)
    OR app_has_role('admin')
    OR app_has_role('health_partner')
);
DROP POLICY IF EXISTS benefit_usages_apply_insert ON benefit_usages;
CREATE POLICY benefit_usages_apply_insert ON benefit_usages
FOR INSERT WITH CHECK (app_can_read_patient(patient_id));
DROP POLICY IF EXISTS benefit_usages_validation_update ON benefit_usages;
CREATE POLICY benefit_usages_validation_update ON benefit_usages
FOR UPDATE USING (app_has_permission('benefits.manage'))
WITH CHECK (app_has_permission('benefits.manage'));

DROP POLICY IF EXISTS partner_benefits_active_select ON partner_benefits;
CREATE POLICY partner_benefits_active_select ON partner_benefits
FOR SELECT USING (is_active OR app_has_role('admin'));
DROP POLICY IF EXISTS partner_benefits_admin_insert ON partner_benefits;
CREATE POLICY partner_benefits_admin_insert ON partner_benefits
FOR INSERT WITH CHECK (app_has_role('admin'));
DROP POLICY IF EXISTS partner_benefits_admin_update ON partner_benefits;
CREATE POLICY partner_benefits_admin_update ON partner_benefits
FOR UPDATE USING (app_has_role('admin')) WITH CHECK (app_has_role('admin'));

DROP POLICY IF EXISTS benefit_validations_partner_select ON benefit_validations;
CREATE POLICY benefit_validations_partner_select ON benefit_validations
FOR SELECT USING (app_has_role('admin') OR EXISTS (
    SELECT 1 FROM partner_users partner_user
    WHERE partner_user.partner_id=benefit_validations.partner_id
      AND partner_user.user_id=app_current_user_id() AND partner_user.is_active
));
DROP POLICY IF EXISTS benefit_validations_apply_insert ON benefit_validations;
CREATE POLICY benefit_validations_apply_insert ON benefit_validations
FOR INSERT WITH CHECK (EXISTS (
    SELECT 1 FROM benefit_usages usage
    WHERE usage.id=benefit_validations.benefit_usage_id
      AND app_can_read_patient(usage.patient_id)
));
DROP POLICY IF EXISTS benefit_validations_partner_update ON benefit_validations;
CREATE POLICY benefit_validations_partner_update ON benefit_validations
FOR UPDATE USING (EXISTS (
    SELECT 1 FROM partner_users partner_user
    WHERE partner_user.partner_id=benefit_validations.partner_id
      AND partner_user.user_id=app_current_user_id() AND partner_user.is_active
)) WITH CHECK (EXISTS (
    SELECT 1 FROM partner_users partner_user
    WHERE partner_user.partner_id=benefit_validations.partner_id
      AND partner_user.user_id=app_current_user_id() AND partner_user.is_active
));

DROP POLICY IF EXISTS payment_orders_own_select ON payment_orders;
CREATE POLICY payment_orders_own_select ON payment_orders
FOR SELECT USING (
    user_id = app_current_user_id()
    OR app_has_role('admin')
    OR app_has_role('health_partner')
    OR app_has_permission('payments.manage')
    OR (
        app_has_permission('partners.manage')
        AND related_entity_type='partner_subscription'
    )
);

DROP POLICY IF EXISTS payment_orders_own_insert ON payment_orders;
CREATE POLICY payment_orders_own_insert ON payment_orders
FOR INSERT WITH CHECK (
    user_id = app_current_user_id()
    OR app_has_role('admin')
    OR app_has_permission('payments.manage')
    OR (
        app_has_permission('partners.manage')
        AND related_entity_type='partner_subscription'
    )
);

DROP POLICY IF EXISTS payment_orders_authorized_update ON payment_orders;
CREATE POLICY payment_orders_authorized_update ON payment_orders
FOR UPDATE USING (
    user_id = app_current_user_id()
    OR app_has_role('admin')
    OR app_has_permission('payments.manage')
    OR (
        app_has_permission('partners.manage')
        AND related_entity_type='partner_subscription'
    )
    OR EXISTS (
        SELECT 1 FROM benefit_usages usage
        JOIN benefit_validations validation ON validation.benefit_usage_id=usage.id
        JOIN partner_users partner_user ON partner_user.partner_id=validation.partner_id
        WHERE usage.payment_order_id=payment_orders.id
          AND validation.status='pending'
          AND partner_user.user_id=app_current_user_id() AND partner_user.is_active
    )
)
WITH CHECK (
    user_id = app_current_user_id()
    OR app_has_role('admin')
    OR app_has_permission('payments.manage')
    OR (
        app_has_permission('partners.manage')
        AND related_entity_type='partner_subscription'
    )
    OR EXISTS (
        SELECT 1 FROM benefit_usages usage
        JOIN benefit_validations validation ON validation.benefit_usage_id=usage.id
        JOIN partner_users partner_user ON partner_user.partner_id=validation.partner_id
        WHERE usage.payment_order_id=payment_orders.id
          AND validation.status='pending'
          AND partner_user.user_id=app_current_user_id() AND partner_user.is_active
    )
);

DROP POLICY IF EXISTS payments_own_select ON payments;
CREATE POLICY payments_own_select ON payments
FOR SELECT USING (
    EXISTS (
        SELECT 1
        FROM payment_orders payment_order
        WHERE payment_order.id = payments.payment_order_id
          AND (
              payment_order.user_id = app_current_user_id()
              OR app_has_role('admin')
              OR app_has_role('health_partner')
              OR app_has_permission('payments.manage')
          )
    )
);

DROP POLICY IF EXISTS payments_own_insert ON payments;
CREATE POLICY payments_own_insert ON payments
FOR INSERT WITH CHECK (
    EXISTS (
        SELECT 1 FROM payment_orders payment_order
        WHERE payment_order.id = payments.payment_order_id
          AND (
              payment_order.user_id = app_current_user_id()
              OR app_has_role('admin')
              OR app_has_permission('payments.manage')
          )
    )
);

DROP POLICY IF EXISTS payments_manage_update ON payments;
CREATE POLICY payments_manage_update ON payments
FOR UPDATE USING (
    app_has_role('admin') OR app_has_permission('payments.manage')
)
WITH CHECK (
    app_has_role('admin') OR app_has_permission('payments.manage')
);

DROP POLICY IF EXISTS payments_owner_confirmation_update ON payments;
CREATE POLICY payments_owner_confirmation_update ON payments
FOR UPDATE USING (
    EXISTS (
        SELECT 1 FROM payment_orders payment_order
        WHERE payment_order.id=payments.payment_order_id
          AND payment_order.user_id=app_current_user_id()
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1 FROM payment_orders payment_order
        WHERE payment_order.id=payments.payment_order_id
          AND payment_order.user_id=app_current_user_id()
    )
);

DROP POLICY IF EXISTS payment_incidents_authorized_select
ON payment_incidents;
CREATE POLICY payment_incidents_authorized_select ON payment_incidents
FOR SELECT USING (
    reported_by_user_id = app_current_user_id()
    OR app_has_role('admin')
    OR app_has_role('health_partner')
    OR app_has_permission('payments.manage')
);

DROP POLICY IF EXISTS payment_incidents_authorized_insert ON payment_incidents;
CREATE POLICY payment_incidents_authorized_insert ON payment_incidents
FOR INSERT WITH CHECK (
    reported_by_user_id = app_current_user_id()
    OR app_has_role('admin')
    OR app_has_permission('payments.manage')
);

DROP POLICY IF EXISTS payment_incidents_manage_update ON payment_incidents;
CREATE POLICY payment_incidents_manage_update ON payment_incidents
FOR UPDATE USING (
    app_has_role('admin') OR app_has_permission('payments.manage')
)
WITH CHECK (
    app_has_role('admin') OR app_has_permission('payments.manage')
);

DROP POLICY IF EXISTS refunds_authorized_select ON refunds;
CREATE POLICY refunds_authorized_select ON refunds
FOR SELECT USING (
    requested_by_user_id = app_current_user_id()
    OR app_has_role('admin')
    OR app_has_role('health_partner')
    OR app_has_permission('payments.manage')
);

DROP POLICY IF EXISTS refunds_manage_insert ON refunds;
CREATE POLICY refunds_manage_insert ON refunds
FOR INSERT WITH CHECK (
    app_has_role('admin') OR app_has_permission('payments.manage')
);

DROP POLICY IF EXISTS refunds_manage_update ON refunds;
CREATE POLICY refunds_manage_update ON refunds
FOR UPDATE USING (
    app_has_role('admin') OR app_has_permission('payments.manage')
)
WITH CHECK (
    app_has_role('admin') OR app_has_permission('payments.manage')
);

-- ============================================================
-- SECRETOS DE INTEGRACIONES EXTERNAS
-- ============================================================

-- ============================================================
-- SERVICIOS DOMICILIARIOS
-- ============================================================

ALTER TABLE home_service_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE service_status_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE realtime_locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE service_evidence ENABLE ROW LEVEL SECURITY;
ALTER TABLE home_service_ratings ENABLE ROW LEVEL SECURITY;
ALTER TABLE deliveries ENABLE ROW LEVEL SECURITY;
ALTER TABLE delivery_status_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE delivery_evidence ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS home_services_authorized_select ON home_service_requests;
CREATE POLICY home_services_authorized_select ON home_service_requests
FOR SELECT USING (
    requested_by_user_id = app_current_user_id()
    OR app_can_read_patient(patient_id)
    OR assigned_professional_id = (
        SELECT professional.id FROM professionals professional
        WHERE professional.user_id = app_current_user_id()
    )
    OR app_has_permission('home_services.manage')
);

DROP POLICY IF EXISTS home_services_own_insert ON home_service_requests;
CREATE POLICY home_services_own_insert ON home_service_requests
FOR INSERT WITH CHECK (
    requested_by_user_id = app_current_user_id()
    AND app_can_read_patient(patient_id)
);

DROP POLICY IF EXISTS home_services_authorized_update ON home_service_requests;
CREATE POLICY home_services_authorized_update ON home_service_requests
FOR UPDATE USING (
    requested_by_user_id = app_current_user_id()
    OR assigned_professional_id = (
        SELECT professional.id FROM professionals professional
        WHERE professional.user_id = app_current_user_id()
    )
    OR app_has_permission('home_services.manage')
);

DROP POLICY IF EXISTS service_history_authorized_select ON service_status_history;
CREATE POLICY service_history_authorized_select ON service_status_history
FOR SELECT USING (
    EXISTS (SELECT 1 FROM home_service_requests request
            WHERE request.id = service_status_history.home_service_id)
);

DROP POLICY IF EXISTS service_history_authorized_insert ON service_status_history;
CREATE POLICY service_history_authorized_insert ON service_status_history
FOR INSERT WITH CHECK (
    changed_by_user_id = app_current_user_id()
    AND EXISTS (SELECT 1 FROM home_service_requests request
                WHERE request.id = service_status_history.home_service_id)
);

DROP POLICY IF EXISTS service_locations_authorized_select ON realtime_locations;
CREATE POLICY service_locations_authorized_select ON realtime_locations
FOR SELECT USING (
    home_service_id IS NOT NULL
    AND EXISTS (SELECT 1 FROM home_service_requests request
                WHERE request.id = realtime_locations.home_service_id)
);

DROP POLICY IF EXISTS service_locations_professional_insert ON realtime_locations;
CREATE POLICY service_locations_professional_insert ON realtime_locations
FOR INSERT WITH CHECK (
    professional_id = (SELECT professional.id FROM professionals professional
                       WHERE professional.user_id = app_current_user_id())
    AND home_service_id IS NOT NULL
    AND EXISTS (SELECT 1 FROM home_service_requests request
                WHERE request.id = realtime_locations.home_service_id)
);

DROP POLICY IF EXISTS service_evidence_authorized_select ON service_evidence;
CREATE POLICY service_evidence_authorized_select ON service_evidence
FOR SELECT USING (
    EXISTS (SELECT 1 FROM home_service_requests request
            WHERE request.id = service_evidence.home_service_id)
);

DROP POLICY IF EXISTS service_evidence_authorized_insert ON service_evidence;
CREATE POLICY service_evidence_authorized_insert ON service_evidence
FOR INSERT WITH CHECK (
    uploaded_by_user_id = app_current_user_id()
    AND EXISTS (SELECT 1 FROM home_service_requests request
                WHERE request.id = service_evidence.home_service_id)
);

DROP POLICY IF EXISTS home_service_ratings_authorized_select ON home_service_ratings;
CREATE POLICY home_service_ratings_authorized_select ON home_service_ratings
FOR SELECT USING (
    app_can_read_patient(patient_id)
    OR professional_id = (SELECT professional.id FROM professionals professional
                          WHERE professional.user_id = app_current_user_id())
    OR app_has_permission('home_services.manage')
);

DROP POLICY IF EXISTS home_service_ratings_own_insert ON home_service_ratings;
CREATE POLICY home_service_ratings_own_insert ON home_service_ratings
FOR INSERT WITH CHECK (app_can_read_patient(patient_id));

DROP POLICY IF EXISTS deliveries_authorized_select ON deliveries;
CREATE POLICY deliveries_authorized_select ON deliveries FOR SELECT USING (
 recipient_user_id=app_current_user_id()
 OR assigned_professional_id=(SELECT id FROM professionals WHERE user_id=app_current_user_id())
 OR EXISTS(SELECT 1 FROM partner_requests request WHERE request.id=deliveries.partner_request_id AND request.requested_by_user_id=app_current_user_id())
 OR app_has_permission('deliveries.manage')
);
DROP POLICY IF EXISTS deliveries_authorized_insert ON deliveries;
CREATE POLICY deliveries_authorized_insert ON deliveries FOR INSERT WITH CHECK (
 recipient_user_id=app_current_user_id() OR app_has_permission('deliveries.manage')
);
DROP POLICY IF EXISTS deliveries_authorized_update ON deliveries;
CREATE POLICY deliveries_authorized_update ON deliveries FOR UPDATE USING (
 assigned_professional_id=(SELECT id FROM professionals WHERE user_id=app_current_user_id()) OR app_has_permission('deliveries.manage')
);
DROP POLICY IF EXISTS delivery_history_authorized_select ON delivery_status_history;
CREATE POLICY delivery_history_authorized_select ON delivery_status_history FOR SELECT USING (EXISTS(SELECT 1 FROM deliveries delivery WHERE delivery.id=delivery_status_history.delivery_id));
DROP POLICY IF EXISTS delivery_history_authorized_insert ON delivery_status_history;
CREATE POLICY delivery_history_authorized_insert ON delivery_status_history FOR INSERT WITH CHECK (changed_by_user_id=app_current_user_id() AND EXISTS(SELECT 1 FROM deliveries delivery WHERE delivery.id=delivery_status_history.delivery_id));
DROP POLICY IF EXISTS delivery_evidence_authorized_select ON delivery_evidence;
CREATE POLICY delivery_evidence_authorized_select ON delivery_evidence FOR SELECT USING (EXISTS(SELECT 1 FROM deliveries delivery WHERE delivery.id=delivery_evidence.delivery_id));
DROP POLICY IF EXISTS delivery_evidence_authorized_insert ON delivery_evidence;
CREATE POLICY delivery_evidence_authorized_insert ON delivery_evidence FOR INSERT WITH CHECK (uploaded_by_user_id=app_current_user_id() AND EXISTS(SELECT 1 FROM deliveries delivery WHERE delivery.id=delivery_evidence.delivery_id));

REVOKE ALL ON oauth_authorization_states FROM PUBLIC;
REVOKE ALL ON external_oauth_credentials FROM PUBLIC;
REVOKE ALL ON password_reset_tokens FROM PUBLIC;

-- ============================================================
-- FIN POLICIES / ROW LEVEL SECURITY
-- ============================================================

-- Atención contextual de emergencias y signos profesionales.
DROP POLICY IF EXISTS emergency_assignee_select ON emergency_events;
CREATE POLICY emergency_assignee_select ON emergency_events FOR SELECT USING(app_is_emergency_assignee(id));
DROP POLICY IF EXISTS emergency_assignee_update ON emergency_events;
CREATE POLICY emergency_assignee_update ON emergency_events FOR UPDATE USING(app_is_emergency_assignee(id))
WITH CHECK(app_is_emergency_assignee(id) OR (assigned_professional_id IS NULL AND status='validating'));
ALTER TABLE emergency_care_records ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS emergency_care_read ON emergency_care_records;
CREATE POLICY emergency_care_read ON emergency_care_records FOR SELECT USING(EXISTS(SELECT 1 FROM emergency_events event WHERE event.id=emergency_id));
DROP POLICY IF EXISTS emergency_care_write ON emergency_care_records;
CREATE POLICY emergency_care_write ON emergency_care_records FOR INSERT WITH CHECK(
  app_has_permission('clinical_records.manage') AND app_is_emergency_assignee(emergency_id)
  AND professional_id=(SELECT id FROM professionals WHERE user_id=app_current_user_id()));
ALTER TABLE emergency_triage_answers ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS emergency_triage_read ON emergency_triage_answers;
CREATE POLICY emergency_triage_read ON emergency_triage_answers FOR SELECT USING(EXISTS(SELECT 1 FROM emergency_events event WHERE event.id=emergency_id));
DROP POLICY IF EXISTS emergency_triage_write ON emergency_triage_answers;
CREATE POLICY emergency_triage_write ON emergency_triage_answers FOR INSERT WITH CHECK(app_is_emergency_assignee(emergency_id) AND app_has_permission('clinical_records.manage'));
ALTER TABLE emergency_assignment_decisions ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS emergency_decision_read ON emergency_assignment_decisions;
CREATE POLICY emergency_decision_read ON emergency_assignment_decisions FOR SELECT USING(EXISTS(SELECT 1 FROM emergency_events event WHERE event.id=emergency_id));
DROP POLICY IF EXISTS emergency_decision_write ON emergency_assignment_decisions;
CREATE POLICY emergency_decision_write ON emergency_assignment_decisions FOR INSERT WITH CHECK(app_is_emergency_assignee(emergency_id)
  AND professional_id=(SELECT id FROM professionals WHERE user_id=app_current_user_id()));
DROP POLICY IF EXISTS vital_signs_professional_insert ON vital_signs;
CREATE POLICY vital_signs_professional_insert ON vital_signs FOR INSERT WITH CHECK(source='professional'
  AND recorded_by_user_id=app_current_user_id() AND app_can_record_vitals(patient_id,related_appointment_id,related_emergency_id));

DROP POLICY IF EXISTS clinical_records_emergency_insert ON clinical_records;
CREATE POLICY clinical_records_emergency_insert ON clinical_records FOR INSERT WITH CHECK(source='professional'
  AND author_user_id=app_current_user_id() AND app_has_permission('clinical_records.manage')
  AND related_appointment_id IS NULL AND related_emergency_id IS NOT NULL AND EXISTS(
    SELECT 1 FROM emergency_events event WHERE event.id=clinical_records.related_emergency_id AND event.patient_id=clinical_records.patient_id
      AND event.accepted_at IS NOT NULL AND event.status IN ('on_site','in_care','referred')
      AND app_is_emergency_assignee(event.id)));

ALTER TABLE work_shifts ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS shifts_read ON work_shifts;
CREATE POLICY shifts_read ON work_shifts FOR SELECT USING(app_has_permission('human_resources.read')
  OR professional_id=(SELECT id FROM professionals WHERE user_id=app_current_user_id()));
DROP POLICY IF EXISTS shifts_manage ON work_shifts;
CREATE POLICY shifts_manage ON work_shifts FOR ALL USING(app_has_permission('human_resources.manage'))
WITH CHECK(app_has_permission('human_resources.manage'));
ALTER TABLE work_shift_history ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS shift_history_read ON work_shift_history;
CREATE POLICY shift_history_read ON work_shift_history FOR SELECT USING(EXISTS(SELECT 1 FROM work_shifts shift WHERE shift.id=shift_id));
DROP POLICY IF EXISTS shift_history_write ON work_shift_history;
CREATE POLICY shift_history_write ON work_shift_history FOR INSERT WITH CHECK(app_has_permission('human_resources.manage') AND changed_by_user_id=app_current_user_id());

DROP POLICY IF EXISTS persons_family_identity_select ON persons;
CREATE POLICY persons_family_identity_select ON persons FOR SELECT USING(app_can_read_family_identity(id));
DROP POLICY IF EXISTS appointments_family_select ON appointments;
CREATE POLICY appointments_family_select ON appointments FOR SELECT USING(app_can_patient_action(patient_id,'appointments.manage'));
DROP POLICY IF EXISTS appointments_family_insert ON appointments;
CREATE POLICY appointments_family_insert ON appointments FOR INSERT WITH CHECK(created_by_user_id=app_current_user_id() AND app_can_patient_action(patient_id,'appointments.manage'));
DROP POLICY IF EXISTS appointments_family_update ON appointments;
CREATE POLICY appointments_family_update ON appointments FOR UPDATE USING(app_can_patient_action(patient_id,'appointments.manage'))
WITH CHECK(app_can_patient_action(patient_id,'appointments.manage'));

DROP POLICY IF EXISTS allergies_guardian_insert ON allergies;
CREATE POLICY allergies_guardian_insert ON allergies FOR INSERT WITH CHECK(author_user_id=app_current_user_id()
  AND validation_status='self_declared' AND app_can_patient_action(patient_id,'patients.manage'));
DROP POLICY IF EXISTS allergies_guardian_update ON allergies;
CREATE POLICY allergies_guardian_update ON allergies FOR UPDATE USING(author_user_id=app_current_user_id()
  AND validation_status IN ('self_declared','pending_validation') AND app_can_patient_action(patient_id,'patients.manage'))
WITH CHECK(author_user_id=app_current_user_id() AND validation_status IN ('self_declared','pending_validation') AND app_can_patient_action(patient_id,'patients.manage'));
DROP POLICY IF EXISTS antecedents_guardian_insert ON medical_antecedents;
CREATE POLICY antecedents_guardian_insert ON medical_antecedents FOR INSERT WITH CHECK(author_user_id=app_current_user_id()
  AND validation_status='self_declared' AND app_can_patient_action(patient_id,'patients.manage'));
DROP POLICY IF EXISTS antecedents_guardian_update ON medical_antecedents;
CREATE POLICY antecedents_guardian_update ON medical_antecedents FOR UPDATE USING(author_user_id=app_current_user_id()
  AND validation_status IN ('self_declared','pending_validation') AND app_can_patient_action(patient_id,'patients.manage'))
WITH CHECK(author_user_id=app_current_user_id() AND validation_status IN ('self_declared','pending_validation') AND app_can_patient_action(patient_id,'patients.manage'));
ALTER TABLE emergency_contacts ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS contacts_patient_read ON emergency_contacts;
CREATE POLICY contacts_patient_read ON emergency_contacts FOR SELECT USING(app_can_read_patient(patient_id));
DROP POLICY IF EXISTS contacts_patient_manage ON emergency_contacts;
CREATE POLICY contacts_patient_manage ON emergency_contacts FOR ALL USING(app_can_patient_action(patient_id,'patients.manage'))
WITH CHECK(app_can_patient_action(patient_id,'patients.manage'));

-- Permisos explícitos y vigentes para solicitar y seguir emergencias de terceros.
DROP POLICY IF EXISTS emergency_family_select ON emergency_events;
CREATE POLICY emergency_family_select ON emergency_events FOR SELECT
USING(app_can_patient_action(patient_id,'emergencies.manage'));
DROP POLICY IF EXISTS emergency_family_insert ON emergency_events;
CREATE POLICY emergency_family_insert ON emergency_events FOR INSERT
WITH CHECK(requested_by_user_id=app_current_user_id() AND app_can_patient_action(patient_id,'emergencies.manage'));


ALTER TABLE profile_completion_policy ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS completion_policy_read ON profile_completion_policy;
CREATE POLICY completion_policy_read ON profile_completion_policy FOR SELECT USING(app_current_user_id() IS NOT NULL);
DROP POLICY IF EXISTS completion_policy_manage ON profile_completion_policy;
CREATE POLICY completion_policy_manage ON profile_completion_policy FOR ALL USING(app_has_permission('administration.manage')) WITH CHECK(app_has_permission('administration.manage'));
ALTER TABLE profile_reward_grants ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS completion_grant_read ON profile_reward_grants;
CREATE POLICY completion_grant_read ON profile_reward_grants FOR SELECT USING(app_can_read_patient(patient_id));


ALTER TABLE patient_profile_completion ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS completion_metrics_read ON patient_profile_completion;
CREATE POLICY completion_metrics_read ON patient_profile_completion FOR SELECT USING(app_can_read_patient(patient_id));
DROP POLICY IF EXISTS completion_metrics_insert ON patient_profile_completion;
CREATE POLICY completion_metrics_insert ON patient_profile_completion FOR INSERT WITH CHECK(app_can_read_patient(patient_id));
DROP POLICY IF EXISTS completion_metrics_update ON patient_profile_completion;
CREATE POLICY completion_metrics_update ON patient_profile_completion FOR UPDATE USING(app_can_read_patient(patient_id)) WITH CHECK(app_can_read_patient(patient_id));

DROP POLICY IF EXISTS emergency_events_authorized_select ON emergency_events;
CREATE POLICY emergency_events_authorized_select ON emergency_events FOR SELECT USING(
  app_can_patient_action(patient_id,'emergencies.manage') OR app_is_emergency_assignee(id)
  OR app_has_role('operator') OR app_has_role('admin') OR app_has_role('clinical_supervisor'));

DROP POLICY IF EXISTS guardian_link_codes_redeem_select ON guardian_link_codes;
CREATE POLICY guardian_link_codes_redeem_select ON guardian_link_codes FOR SELECT USING(generated_by_user_id=app_current_user_id());
DROP POLICY IF EXISTS guardian_link_codes_redeem_update ON guardian_link_codes;
DROP POLICY IF EXISTS patient_guardians_guardian_insert ON patient_guardians;
DROP POLICY IF EXISTS patient_guardians_guardian_update ON patient_guardians;

DROP POLICY IF EXISTS clinical_records_authorized_select ON clinical_records;
CREATE POLICY clinical_records_authorized_select ON clinical_records FOR SELECT
USING(app_can_read_patient(patient_id) AND (patient_visible OR app_has_permission('clinical_records.manage')));
