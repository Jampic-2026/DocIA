-- Permisos explícitos y vigentes para solicitar y seguir emergencias de terceros.
DROP POLICY IF EXISTS emergency_events_authorized_select ON emergency_events;
CREATE POLICY emergency_events_authorized_select ON emergency_events FOR SELECT USING(
  app_can_patient_action(patient_id,'emergencies.manage') OR app_is_emergency_assignee(id)
  OR app_has_role('operator') OR app_has_role('admin') OR app_has_role('clinical_supervisor'));
DROP POLICY IF EXISTS emergency_family_select ON emergency_events;
CREATE POLICY emergency_family_select ON emergency_events FOR SELECT
USING(app_can_patient_action(patient_id,'emergencies.manage'));
DROP POLICY IF EXISTS emergency_family_insert ON emergency_events;
CREATE POLICY emergency_family_insert ON emergency_events FOR INSERT
WITH CHECK(requested_by_user_id=app_current_user_id() AND app_can_patient_action(patient_id,'emergencies.manage'));

CREATE OR REPLACE FUNCTION app_patient_alert_recipients(target_patient_id UUID, event_permission TEXT)
RETURNS TABLE(user_id UUID) LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $docia$
  SELECT person.user_id FROM patients patient JOIN persons person ON person.id=patient.person_id
    WHERE patient.id=target_patient_id AND person.user_id IS NOT NULL AND (app_can_read_patient(target_patient_id) OR app_can_patient_action(target_patient_id,event_permission))
  UNION
  SELECT guardian.guardian_user_id FROM patient_guardians guardian
    WHERE guardian.patient_id=target_patient_id AND (app_can_read_patient(target_patient_id) OR app_can_patient_action(target_patient_id,event_permission)) AND guardian.verification_status='validated'
      AND guardian.revoked_at IS NULL AND guardian.can_receive_alerts AND guardian.valid_from<=now()
      AND (guardian.valid_until IS NULL OR guardian.valid_until>now())
  UNION
  SELECT family_auth.family_user_id FROM family_authorizations family_auth
    JOIN family_authorization_permissions permission ON permission.authorization_id=family_auth.id
    WHERE family_auth.patient_id=target_patient_id AND (app_can_read_patient(target_patient_id) OR app_can_patient_action(target_patient_id,event_permission)) AND family_auth.status='active'
      AND family_auth.revoked_at IS NULL AND family_auth.valid_from<=now()
      AND (family_auth.valid_until IS NULL OR family_auth.valid_until>now())
      AND permission.permission_code=event_permission;
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
      OR recipient.id IN (SELECT user_id FROM app_patient_alert_recipients(current_event.patient_id,'emergencies.manage'))
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

CREATE OR REPLACE FUNCTION app_emergency_patient_contact(
    target_emergency_id UUID
)
RETURNS TABLE(patient_name TEXT, patient_phone VARCHAR)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $jampic$
    SELECT
      concat_ws(' ', person.first_name, person.last_name,
        person.second_last_name) AS patient_name,
      app_user.phone AS patient_phone
    FROM emergency_events event
    JOIN patients patient ON patient.id=event.patient_id
    JOIN persons person ON person.id=patient.person_id
    LEFT JOIN users app_user ON app_user.id=person.user_id
    WHERE event.id=target_emergency_id
      AND (
          event.requested_by_user_id=app_current_user_id()
          OR app_can_read_patient(event.patient_id)
          OR app_can_patient_action(event.patient_id,'emergencies.manage')
          OR app_has_role('operator')
          OR app_has_role('clinical_supervisor')
      );
$jampic$;

