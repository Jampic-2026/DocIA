ALTER TABLE emergency_events ADD COLUMN IF NOT EXISTS accepted_at TIMESTAMPTZ;
ALTER TABLE emergency_care_records ADD COLUMN IF NOT EXISTS content JSONB NOT NULL DEFAULT '{}'::jsonb;
ALTER TABLE vital_signs ADD COLUMN IF NOT EXISTS related_appointment_id UUID REFERENCES appointments(id);
ALTER TABLE vital_signs ADD COLUMN IF NOT EXISTS related_emergency_id UUID REFERENCES emergency_events(id);
CREATE TABLE IF NOT EXISTS emergency_assignment_decisions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  emergency_id UUID NOT NULL REFERENCES emergency_events(id),
  professional_id UUID NOT NULL REFERENCES professionals(id),
  decision VARCHAR(20) NOT NULL CHECK(decision IN ('accepted','rejected')),
  reason TEXT, created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK(decision<>'rejected' OR COALESCE(length(trim(reason)),0)>=3)
);

CREATE OR REPLACE FUNCTION app_is_emergency_assignee(target_emergency_id UUID)
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER
SET search_path=public,pg_temp AS $docia$
  SELECT EXISTS(SELECT 1 FROM emergency_events event JOIN professionals professional
    ON professional.id=event.assigned_professional_id
    WHERE event.id=target_emergency_id AND professional.user_id=app_current_user_id()
      AND professional.verification_status='approved' AND professional.professional_type IN ('doctor','nurse'));
$docia$;

CREATE OR REPLACE FUNCTION app_can_record_vitals(target_patient_id UUID, target_appointment_id UUID, target_emergency_id UUID)
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER
SET search_path=public,pg_temp AS $docia$
  SELECT app_has_permission('clinical_records.manage') AND
    ((target_appointment_id IS NOT NULL AND target_emergency_id IS NULL AND EXISTS(
      SELECT 1 FROM appointments appointment JOIN professionals professional ON professional.id=appointment.professional_id
      WHERE appointment.id=target_appointment_id AND appointment.patient_id=target_patient_id
        AND appointment.status='in_progress' AND professional.user_id=app_current_user_id() AND professional.verification_status='approved'))
    OR (target_emergency_id IS NOT NULL AND target_appointment_id IS NULL AND EXISTS(
      SELECT 1 FROM emergency_events event WHERE event.id=target_emergency_id AND event.patient_id=target_patient_id
        AND event.status IN ('on_site','in_care') AND event.accepted_at IS NOT NULL AND app_is_emergency_assignee(event.id))));
$docia$;

-- Only a boolean is exposed; clinical access remains scoped to the assigned patient.
CREATE OR REPLACE FUNCTION app_is_person_care_assignee(target_person_id UUID)
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER
SET search_path=public,pg_temp AS $docia$
  SELECT EXISTS(SELECT 1 FROM patients patient JOIN appointments appointment ON appointment.patient_id=patient.id
    JOIN professionals professional ON professional.id=appointment.professional_id
    WHERE patient.person_id=target_person_id AND professional.user_id=app_current_user_id()
      AND professional.verification_status='approved' AND appointment.status NOT IN ('cancelled','no_show'))
  OR EXISTS(SELECT 1 FROM patients patient JOIN emergency_events event ON event.patient_id=patient.id
    WHERE patient.person_id=target_person_id AND app_is_emergency_assignee(event.id)
      AND event.status NOT IN ('closed','cancelled','false_alarm'));
$docia$;

CREATE OR REPLACE FUNCTION app_can_read_patient(target_patient_id UUID)
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER
SET search_path=public,pg_temp AS $docia$
  SELECT EXISTS(SELECT 1 FROM patients patient JOIN persons person ON person.id=patient.person_id
    WHERE patient.id=target_patient_id AND (person.user_id=app_current_user_id() OR app_is_person_care_assignee(person.id)))
  OR EXISTS(SELECT 1 FROM patient_guardians guardian WHERE guardian.patient_id=target_patient_id
    AND guardian.guardian_user_id=app_current_user_id() AND guardian.verification_status='validated'
    AND guardian.revoked_at IS NULL AND guardian.valid_from<=now() AND (guardian.valid_until IS NULL OR guardian.valid_until>now()))
  OR app_has_role('admin') OR app_has_role('clinical_supervisor');
$docia$;

CREATE OR REPLACE FUNCTION app_notify_emergency_update(target_emergency_id UUID, notify_team BOOLEAN DEFAULT FALSE)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $docia$
DECLARE current_event emergency_events;
BEGIN
  SELECT * INTO current_event FROM emergency_events WHERE id=target_emergency_id;
  IF current_event.id IS NULL OR NOT (current_event.requested_by_user_id=app_current_user_id()
    OR app_is_emergency_assignee(target_emergency_id) OR app_has_role('operator') OR app_has_role('admin') OR app_has_role('clinical_supervisor')) THEN
    RAISE EXCEPTION 'Emergencia no autorizada' USING ERRCODE='42501';
  END IF;
  INSERT INTO notifications(user_id,event_code,channel,title,body,related_entity_type,related_entity_id,status)
  SELECT DISTINCT recipient.id,'emergencies','in_app'::notification_channel,'Actualización de emergencia',
    'Se actualizó una solicitud de emergencia. Consulta el módulo para revisar su estado.', 'emergency',current_event.id,'sent'
  FROM users recipient WHERE recipient.status='active' AND (
    recipient.id=current_event.requested_by_user_id
    OR EXISTS(SELECT 1 FROM professionals professional WHERE professional.user_id=recipient.id
      AND professional.id IN (current_event.assigned_professional_id,current_event.assigned_operator_id) AND professional.verification_status='approved')
    OR (notify_team AND EXISTS(
      SELECT 1 FROM roles role WHERE role.is_active AND role.code IN ('operator','clinical_supervisor','admin')
      AND (role.id=recipient.role_id OR EXISTS(SELECT 1 FROM user_roles assignment WHERE assignment.user_id=recipient.id
        AND assignment.role_id=role.id AND assignment.revoked_at IS NULL AND assignment.valid_from<=now()
        AND (assignment.valid_until IS NULL OR assignment.valid_until>now())))))
  );
END;
$docia$;

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
