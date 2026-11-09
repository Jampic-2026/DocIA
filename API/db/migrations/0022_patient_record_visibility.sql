ALTER TABLE clinical_records ADD COLUMN IF NOT EXISTS patient_visible BOOLEAN NOT NULL DEFAULT TRUE;
DROP POLICY IF EXISTS clinical_records_authorized_select ON clinical_records;
CREATE POLICY clinical_records_authorized_select ON clinical_records FOR SELECT
USING(app_can_read_patient(patient_id) AND (patient_visible OR app_has_permission('clinical_records.manage')));
