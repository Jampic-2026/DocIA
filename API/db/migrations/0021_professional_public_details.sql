ALTER TABLE professionals ADD COLUMN IF NOT EXISTS academic_background TEXT;
ALTER TABLE professionals ADD COLUMN IF NOT EXISTS public_certifications TEXT[] NOT NULL DEFAULT '{}';
ALTER TABLE appointment_ratings ADD COLUMN IF NOT EXISTS public_comment BOOLEAN NOT NULL DEFAULT FALSE;

CREATE OR REPLACE FUNCTION app_professional_public_details(target_professional_id UUID)
RETURNS JSONB LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $docia$
SELECT jsonb_build_object('bio',professional.bio,'academicBackground',professional.academic_background,
  'certifications',professional.public_certifications,'verifiedAt',professional.verified_at,
  'isSpecialist',EXISTS(SELECT 1 FROM roles role WHERE role.code='doctor_specialist' AND role.is_active
    AND (role.id=(SELECT role_id FROM users WHERE id=professional.user_id)
      OR EXISTS(SELECT 1 FROM user_roles assignment WHERE assignment.role_id=role.id AND assignment.user_id=professional.user_id
        AND assignment.revoked_at IS NULL AND assignment.valid_from<=now() AND (assignment.valid_until IS NULL OR assignment.valid_until>now())))),
  'reviews',COALESCE((SELECT jsonb_agg(jsonb_build_object('rating',review.rating,'comment',review.comment,'createdAt',review.created_at) ORDER BY review.created_at DESC)
    FROM (SELECT rating,comment,created_at FROM appointment_ratings WHERE professional_id=professional.id AND public_comment
      AND NULLIF(trim(comment),'') IS NOT NULL ORDER BY created_at DESC LIMIT 50) review),'[]'))
FROM professionals professional WHERE professional.id=target_professional_id AND app_current_user_id() IS NOT NULL
  AND professional.verification_status='approved' AND professional.public_profile_enabled;
$docia$;

CREATE OR REPLACE FUNCTION app_rate_completed_appointment(target_appointment_id UUID,rating_value INT,comment_value TEXT,publish_comment BOOLEAN DEFAULT FALSE)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $docia$
DECLARE selected_appointment appointments;
BEGIN
  SELECT appointment.* INTO selected_appointment FROM appointments appointment
    JOIN patients patient ON patient.id=appointment.patient_id JOIN persons person ON person.id=patient.person_id
    WHERE appointment.id=target_appointment_id AND person.user_id=app_current_user_id() AND appointment.status='completed' FOR UPDATE OF appointment;
  IF selected_appointment.id IS NULL OR rating_value NOT BETWEEN 1 AND 5 OR length(COALESCE(comment_value,''))>1000 THEN
    RAISE EXCEPTION 'La cita o calificación no es válida' USING ERRCODE='22023'; END IF;
  PERFORM 1 FROM professionals WHERE id=selected_appointment.professional_id FOR UPDATE;
  INSERT INTO appointment_ratings(appointment_id,patient_id,professional_id,rating,comment,public_comment)
    VALUES(selected_appointment.id,selected_appointment.patient_id,selected_appointment.professional_id,rating_value,NULLIF(trim(comment_value),''),COALESCE(publish_comment,FALSE));
  UPDATE professionals SET average_rating=summary.average,rating_count=summary.count,updated_at=now()
    FROM (SELECT round(avg(rating)::numeric,2) AS average,count(*) AS count FROM appointment_ratings
      WHERE professional_id=selected_appointment.professional_id) summary WHERE id=selected_appointment.professional_id;
  INSERT INTO audit_events(actor_user_id,actor_role,module,action,entity_type,entity_id)
    VALUES(app_current_user_id(),app_current_role_code(),'appointments','appointment_rated','appointment',target_appointment_id);
END;
$docia$;
