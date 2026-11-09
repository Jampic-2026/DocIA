CREATE OR REPLACE FUNCTION app_appointment_professional_identity(target_appointment_id UUID)
RETURNS TABLE(full_name TEXT) LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $docia$
  SELECT concat_ws(' ',person.first_name,person.last_name,person.second_last_name)
  FROM appointments appointment JOIN professionals professional ON professional.id=appointment.professional_id
  JOIN persons person ON person.id=professional.person_id
  WHERE appointment.id=target_appointment_id AND (professional.user_id=app_current_user_id()
    OR app_can_patient_action(appointment.patient_id,'appointments.manage') OR app_can_read_patient(appointment.patient_id)
    OR app_has_role('operator') OR app_has_role('admin') OR app_has_role('clinical_supervisor'));
$docia$;
