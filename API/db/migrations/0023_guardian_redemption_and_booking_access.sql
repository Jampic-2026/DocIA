-- Narrow commands: no disclosure of other patients' bookings or redeemable codes.
CREATE OR REPLACE FUNCTION app_professional_slot_free(target_professional UUID, slot_start TIMESTAMPTZ, slot_end TIMESTAMPTZ, excluded_appointment UUID DEFAULT NULL)
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $docia$
  SELECT app_current_user_id() IS NOT NULL AND slot_start>now() AND slot_end>slot_start
    AND (slot_start AT TIME ZONE 'America/La_Paz')::date=(slot_end AT TIME ZONE 'America/La_Paz')::date
    AND EXISTS(SELECT 1 FROM professionals WHERE id=target_professional AND verification_status='approved' AND public_profile_enabled)
    AND NOT EXISTS(SELECT 1 FROM appointments WHERE professional_id=target_professional AND (excluded_appointment IS NULL OR id<>excluded_appointment) AND status NOT IN('cancelled','no_show') AND start_at<slot_end AND end_at>slot_start)
    AND NOT EXISTS(SELECT 1 FROM professional_time_blocks WHERE professional_id=target_professional AND start_at<slot_end AND end_at>slot_start);
$docia$;

CREATE OR REPLACE FUNCTION app_patient_has_referral(target_patient UUID,target_specialty UUID)
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $docia$
  SELECT app_can_patient_action(target_patient,'appointments.manage') AND EXISTS(
    SELECT 1 FROM referrals WHERE patient_id=target_patient AND specialty_id=target_specialty AND status='active'
      AND valid_from<=current_date AND (valid_until IS NULL OR valid_until>=current_date));
$docia$;

CREATE OR REPLACE FUNCTION app_redeem_guardian_code(code_digest TEXT,relationship_value TEXT)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $docia$
DECLARE selected_code guardian_link_codes; minor_patient patients;
BEGIN
  IF NOT app_has_permission('patients.manage') OR length(trim(relationship_value))<2 OR NOT EXISTS(
    SELECT 1 FROM users account JOIN persons person ON person.user_id=account.id
    WHERE account.id=app_current_user_id() AND account.status='active' AND person.birth_date<=current_date-interval '18 years') THEN
    RAISE EXCEPTION 'El tutor debe ser mayor de edad y tener sus datos completos.' USING ERRCODE='42501';
  END IF;
  SELECT * INTO selected_code FROM guardian_link_codes WHERE code_hash=code_digest AND used_at IS NULL AND expires_at>now() FOR UPDATE;
  SELECT patient.* INTO minor_patient FROM patients patient JOIN persons person ON person.id=patient.person_id
    WHERE patient.id=selected_code.minor_patient_id AND patient.is_minor AND person.birth_date>current_date-interval '18 years'
      AND person.user_id IS DISTINCT FROM app_current_user_id();
  IF minor_patient.id IS NULL THEN RAISE EXCEPTION 'El código no es válido o ya venció.' USING ERRCODE='22023'; END IF;
  INSERT INTO patient_guardians(patient_id,guardian_user_id,relationship,is_legal_guardian,verification_status,can_manage_profile,can_receive_alerts)
    VALUES(minor_patient.id,app_current_user_id(),trim(relationship_value),TRUE,'validated',TRUE,TRUE)
    ON CONFLICT(patient_id,guardian_user_id) DO UPDATE SET relationship=excluded.relationship,is_legal_guardian=TRUE,
      verification_status='validated',can_manage_profile=TRUE,can_receive_alerts=TRUE,valid_from=now(),valid_until=NULL,revoked_at=NULL;
  UPDATE guardian_link_codes SET used_by_user_id=app_current_user_id(),used_at=now() WHERE id=selected_code.id;
  INSERT INTO audit_events(actor_user_id,actor_role,patient_id,module,action,entity_type,entity_id)
    VALUES(app_current_user_id(),app_current_role_code(),minor_patient.id,'patients','guardian_code_redeemed_responsibility_declared','patient',minor_patient.id);
END;
$docia$;

CREATE OR REPLACE FUNCTION app_user_clinically_verified(target_user UUID)
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $docia$
  SELECT EXISTS(SELECT 1 FROM users account JOIN professionals professional ON professional.user_id=account.id
    WHERE account.id=target_user AND account.status='active' AND professional.verification_status='approved'
      AND (account.id=app_current_user_id() OR account.email::text=current_setting('app.login_identifier',TRUE)
        OR account.phone=current_setting('app.login_identifier',TRUE))) ;
$docia$;

DROP POLICY IF EXISTS guardian_link_codes_redeem_select ON guardian_link_codes;
CREATE POLICY guardian_link_codes_redeem_select ON guardian_link_codes FOR SELECT USING(generated_by_user_id=app_current_user_id());
DROP POLICY IF EXISTS guardian_link_codes_redeem_update ON guardian_link_codes;
DROP POLICY IF EXISTS patient_guardians_guardian_insert ON patient_guardians;
DROP POLICY IF EXISTS patient_guardians_guardian_update ON patient_guardians;
