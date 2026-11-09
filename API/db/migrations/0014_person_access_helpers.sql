-- Narrow identity helpers prevent recursive RLS joins (persons -> appointments -> persons).
CREATE OR REPLACE FUNCTION app_is_person_care_assignee(target_person_id UUID)
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public, pg_temp AS $docia$
  SELECT app_current_user_id() IS NOT NULL AND EXISTS (
    SELECT 1 FROM patients patient JOIN appointments appointment ON appointment.patient_id=patient.id
    JOIN professionals professional ON professional.id=appointment.professional_id
    WHERE patient.person_id=target_person_id AND professional.user_id=app_current_user_id()
      AND professional.verification_status='approved' AND appointment.status NOT IN ('cancelled','no_show')
  );
$docia$;

CREATE OR REPLACE FUNCTION app_professional_directory_identity(target_professional_id UUID)
RETURNS TABLE(full_name TEXT) LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public, pg_temp AS $docia$
  SELECT concat_ws(' ',person.first_name,person.last_name,person.second_last_name)
  FROM professionals professional JOIN persons person ON person.id=professional.person_id
  WHERE professional.id=target_professional_id AND professional.verification_status='approved'
    AND professional.public_profile_enabled AND app_current_user_id() IS NOT NULL;
$docia$;

ALTER FUNCTION app_can_read_patient(UUID) SECURITY DEFINER;
ALTER FUNCTION app_can_read_patient(UUID) SET search_path = public, pg_temp;

DROP POLICY IF EXISTS persons_own_account_select ON persons;
CREATE POLICY persons_own_account_select ON persons FOR SELECT USING (
  user_id=app_current_user_id() OR app_has_role('admin') OR app_has_permission('human_resources.manage')
  OR app_has_role('operator') OR app_has_role('clinical_supervisor')
  OR app_is_person_care_assignee(id)
);
