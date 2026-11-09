-- Bounded display identity for an authorized prescription reader, including former clinicians.
-- No access is granted to professional documents, contacts or private personnel records.
CREATE OR REPLACE FUNCTION app_prescription_author_identity(target_prescription UUID) RETURNS TEXT
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
 SELECT concat_ws(' ',person.first_name,person.last_name,person.second_last_name)
 FROM prescriptions prescription JOIN professionals professional ON professional.id=prescription.professional_id
 JOIN persons person ON person.id=professional.person_id
 WHERE prescription.id=target_prescription AND (
  (prescription.status<>'draft' AND app_can_read_patient(prescription.patient_id))
  OR professional.user_id=app_current_user_id() OR app_has_role('admin') OR app_has_role('clinical_supervisor'));
$$;
