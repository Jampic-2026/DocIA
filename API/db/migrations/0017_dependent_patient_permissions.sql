ALTER TABLE family_authorizations ADD COLUMN IF NOT EXISTS valid_from TIMESTAMPTZ NOT NULL DEFAULT now();
ALTER TABLE family_authorizations ADD COLUMN IF NOT EXISTS valid_until TIMESTAMPTZ;

CREATE OR REPLACE FUNCTION app_can_patient_action(target_patient_id UUID, action_code TEXT)
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $docia$
  SELECT action_code IN ('clinical_records.read','appointments.manage','emergencies.manage','patients.manage') AND (
    EXISTS(SELECT 1 FROM patients patient JOIN persons person ON person.id=patient.person_id
      WHERE patient.id=target_patient_id AND person.user_id=app_current_user_id())
    OR EXISTS(SELECT 1 FROM patient_guardians guardian WHERE guardian.patient_id=target_patient_id
      AND guardian.guardian_user_id=app_current_user_id() AND guardian.verification_status='validated'
      AND guardian.revoked_at IS NULL AND guardian.valid_from<=now() AND (guardian.valid_until IS NULL OR guardian.valid_until>now())
      AND (action_code='clinical_records.read' OR guardian.can_manage_profile))
    OR EXISTS(SELECT 1 FROM family_authorizations family_auth JOIN family_authorization_permissions permission ON permission.authorization_id=family_auth.id
      WHERE family_auth.patient_id=target_patient_id AND family_auth.family_user_id=app_current_user_id()
        AND family_auth.status='active' AND family_auth.revoked_at IS NULL AND family_auth.valid_from<=now()
        AND (family_auth.valid_until IS NULL OR family_auth.valid_until>now()) AND permission.permission_code=action_code)
  );
$docia$;

CREATE OR REPLACE FUNCTION app_can_read_patient(target_patient_id UUID)
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $docia$
  SELECT app_can_patient_action(target_patient_id,'clinical_records.read')
    OR EXISTS(SELECT 1 FROM patients patient WHERE patient.id=target_patient_id AND app_is_person_care_assignee(patient.person_id))
    OR app_has_role('admin') OR app_has_role('clinical_supervisor');
$docia$;

CREATE OR REPLACE FUNCTION app_can_read_family_identity(target_person_id UUID)
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $docia$
  SELECT EXISTS(SELECT 1 FROM patients patient WHERE patient.person_id=target_person_id AND (
    app_can_patient_action(patient.id,'clinical_records.read') OR app_can_patient_action(patient.id,'appointments.manage')
    OR app_can_patient_action(patient.id,'emergencies.manage')))
  OR EXISTS(SELECT 1 FROM persons person JOIN family_authorizations family_auth ON family_auth.family_user_id=person.user_id
    WHERE person.id=target_person_id AND family_auth.granted_by_user_id=app_current_user_id()
      AND family_auth.status='active' AND family_auth.revoked_at IS NULL);
$docia$;

CREATE OR REPLACE FUNCTION app_find_family_account(account_email TEXT)
RETURNS TABLE(id UUID) LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $docia$
  SELECT account.id FROM users account WHERE app_current_user_id() IS NOT NULL AND app_has_permission('patients.manage')
    AND account.status='active' AND lower(account.email::text)=lower(account_email);
$docia$;

CREATE OR REPLACE FUNCTION app_create_minor_dependent(first_name_value TEXT,last_name_value TEXT,second_last_name_value TEXT,
  birth_date_value DATE,document_type_value TEXT,document_number_value TEXT,relationship_value TEXT,confirmed BOOLEAN)
RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $docia$
DECLARE person_identifier UUID; patient_identifier UUID;
BEGIN
  IF NOT app_has_permission('patients.manage') OR confirmed IS NOT TRUE OR NOT EXISTS(
    SELECT 1 FROM users account JOIN persons person ON person.user_id=account.id WHERE account.id=app_current_user_id()
      AND account.status='active' AND person.birth_date<=current_date-interval '18 years') THEN
    RAISE EXCEPTION 'Completa tu fecha de nacimiento y confirma tu responsabilidad. El tutor debe ser mayor de edad.' USING ERRCODE='42501';
  END IF;
  IF birth_date_value IS NULL OR birth_date_value>current_date OR birth_date_value<=current_date-interval '18 years'
    OR length(trim(first_name_value))<2 OR length(trim(last_name_value))<2 OR length(trim(relationship_value))<2 THEN
    RAISE EXCEPTION 'El dependiente debe ser menor de edad y tener sus datos completos.' USING ERRCODE='22023';
  END IF;
  INSERT INTO persons(first_name,last_name,second_last_name,birth_date,document_type,document_number)
    VALUES(trim(first_name_value),trim(last_name_value),NULLIF(trim(second_last_name_value),''),birth_date_value,NULLIF(trim(document_type_value),''),NULLIF(trim(document_number_value),'')) RETURNING id INTO person_identifier;
  INSERT INTO patients(person_id,is_minor,is_dependent) VALUES(person_identifier,TRUE,TRUE) RETURNING id INTO patient_identifier;
  INSERT INTO patient_guardians(patient_id,guardian_user_id,relationship,is_legal_guardian,verification_status,can_manage_profile,can_receive_alerts)
    VALUES(patient_identifier,app_current_user_id(),trim(relationship_value),TRUE,'validated',TRUE,TRUE);
  INSERT INTO audit_events(actor_user_id,actor_role,patient_id,module,action,entity_type,entity_id)
    VALUES(app_current_user_id(),app_current_role_code(),patient_identifier,'patients','minor_created_guardian_responsibility_declared','patient',patient_identifier);
  RETURN patient_identifier;
END;
$docia$;

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
