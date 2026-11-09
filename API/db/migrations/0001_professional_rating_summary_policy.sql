-- Permite que un paciente que acaba de calificar una cita actualice
-- el resumen denormalizado de puntaje del profesional.
DROP POLICY IF EXISTS professionals_rating_summary_update ON professionals;

CREATE POLICY professionals_rating_summary_update ON professionals
FOR UPDATE USING (
  EXISTS (
    SELECT 1
    FROM appointment_ratings rating
    WHERE rating.professional_id = professionals.id
      AND app_can_read_patient(rating.patient_id)
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1
    FROM appointment_ratings rating
    WHERE rating.professional_id = professionals.id
      AND app_can_read_patient(rating.patient_id)
  )
);
