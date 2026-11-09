-- Automatic room provisioning, transactional notifications, explicit conference closure.
ALTER TABLE telemedicine_rooms ADD COLUMN IF NOT EXISTS duration_seconds INT NOT NULL DEFAULT 0 CHECK(duration_seconds>=0);
CREATE OR REPLACE FUNCTION app_telemedicine_professional_identity(target_room UUID) RETURNS TEXT
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
 SELECT concat_ws(' ',person.first_name,person.last_name) FROM telemedicine_rooms room
 JOIN appointments a ON a.id=room.appointment_id JOIN professionals p ON p.id=a.professional_id JOIN persons person ON person.id=p.person_id
 JOIN patients patient ON patient.id=a.patient_id JOIN persons owner ON owner.id=patient.person_id
 WHERE room.id=target_room AND (owner.user_id=app_current_user_id() OR p.user_id=app_current_user_id() OR app_has_role('admin') OR app_has_role('operator'));
$$;
CREATE TABLE IF NOT EXISTS telemedicine_room_jobs (
 appointment_id UUID PRIMARY KEY REFERENCES appointments(id) ON DELETE CASCADE,
 requested_by_user_id UUID REFERENCES users(id),attempts INT NOT NULL DEFAULT 0,
 available_at TIMESTAMPTZ NOT NULL DEFAULT now(),processed_at TIMESTAMPTZ,
 last_error_code TEXT,last_notified_at TIMESTAMPTZ
);
ALTER TABLE telemedicine_room_jobs ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS room_jobs_system ON telemedicine_room_jobs;
CREATE POLICY room_jobs_system ON telemedicine_room_jobs FOR ALL USING(app_has_role('admin')) WITH CHECK(app_has_role('admin'));
CREATE OR REPLACE FUNCTION app_queue_telemedicine_room() RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
 IF NEW.status IN('cancelled','completed','no_show') THEN
  UPDATE telemedicine_room_jobs SET processed_at=now() WHERE appointment_id=NEW.id;
 END IF;
 IF NEW.modality='telemedicine' AND NEW.status IN('scheduled','confirmed') THEN
  INSERT INTO telemedicine_room_jobs(appointment_id,requested_by_user_id)
  VALUES(NEW.id,app_current_user_id()) ON CONFLICT DO NOTHING;
 END IF;
 RETURN NEW;
END; $$;
DROP TRIGGER IF EXISTS queue_telemedicine_room ON appointments;
CREATE TRIGGER queue_telemedicine_room AFTER INSERT OR UPDATE OF status ON appointments
FOR EACH ROW EXECUTE FUNCTION app_queue_telemedicine_room();
CREATE OR REPLACE FUNCTION app_prepare_room_participants() RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
 INSERT INTO telemedicine_participants(room_id,user_id)
 SELECT NEW.id,person.user_id FROM appointments appointment JOIN patients patient ON patient.id=appointment.patient_id
 JOIN persons person ON person.id=patient.person_id WHERE appointment.id=NEW.appointment_id AND person.user_id IS NOT NULL
 UNION SELECT NEW.id,professional.user_id FROM appointments appointment JOIN professionals professional ON professional.id=appointment.professional_id
 WHERE appointment.id=NEW.appointment_id AND professional.user_id IS NOT NULL ON CONFLICT DO NOTHING;
 INSERT INTO notifications(user_id,event_code,channel,title,body,related_entity_type,related_entity_id,status,sent_at)
 SELECT user_id,'appointments','in_app','Sala de teleconsulta preparada','La sala está disponible en Telemedicina.',
 'telemedicine_room',NEW.id,'sent',now() FROM telemedicine_participants WHERE room_id=NEW.id;
 RETURN NEW;
END; $$;
DROP TRIGGER IF EXISTS prepare_room_participants ON telemedicine_rooms;
CREATE TRIGGER prepare_room_participants AFTER INSERT ON telemedicine_rooms FOR EACH ROW EXECUTE FUNCTION app_prepare_room_participants();
DROP POLICY IF EXISTS telemedicine_rooms_staff_insert ON telemedicine_rooms;
CREATE POLICY telemedicine_rooms_staff_insert ON telemedicine_rooms FOR INSERT WITH CHECK(EXISTS(
 SELECT 1 FROM appointments a JOIN professionals p ON p.id=a.professional_id WHERE a.id=appointment_id
 AND a.modality='telemedicine' AND a.status NOT IN('cancelled','completed','no_show')
 AND (p.user_id=app_current_user_id() OR app_can_patient_action(a.patient_id,'appointments.manage') OR app_has_role('admin') OR app_has_role('operator'))));
DROP POLICY IF EXISTS telemedicine_rooms_participant_update ON telemedicine_rooms;
CREATE POLICY telemedicine_rooms_participant_update ON telemedicine_rooms FOR UPDATE USING(EXISTS(
 SELECT 1 FROM appointments a JOIN professionals p ON p.id=a.professional_id WHERE a.id=appointment_id
 AND (p.user_id=app_current_user_id() OR app_can_patient_action(a.patient_id,'appointments.manage') OR app_has_role('admin') OR app_has_role('operator'))));
-- Trigger installs both participants; consumers must not manufacture participants.
REVOKE ALL ON FUNCTION app_queue_telemedicine_room() FROM PUBLIC;
REVOKE ALL ON FUNCTION app_prepare_room_participants() FROM PUBLIC;
INSERT INTO telemedicine_room_jobs(appointment_id,requested_by_user_id)
SELECT appointment.id,COALESCE(appointment.created_by_user_id,professional.user_id) FROM appointments appointment
JOIN professionals professional ON professional.id=appointment.professional_id
WHERE appointment.modality='telemedicine' AND appointment.status IN('scheduled','confirmed','rescheduled','in_progress')
AND (appointment.end_at>now() OR appointment.status='in_progress')
AND NOT EXISTS(SELECT 1 FROM telemedicine_rooms room WHERE room.appointment_id=appointment.id)
ON CONFLICT DO NOTHING;
CREATE OR REPLACE FUNCTION app_report_room_job_failure(target_appointment UUID) RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
 IF NOT app_has_role('admin') THEN RAISE EXCEPTION 'Operacion interna no autorizada'; END IF;
 UPDATE telemedicine_room_jobs SET last_error_code='MEET_PROVISIONING_FAILED',last_notified_at=now()
 WHERE appointment_id=target_appointment AND (last_notified_at IS NULL OR last_notified_at<now()-interval '1 hour');
 IF NOT FOUND THEN RETURN; END IF;
 INSERT INTO audit_events(actor_user_id,actor_role,module,action,entity_type,entity_id)
 VALUES(app_current_user_id(),COALESCE(app_current_role_code(),'system'),'telemedicine','room_provisioning_failed','appointment',target_appointment);
 INSERT INTO notifications(user_id,event_code,channel,title,body,related_entity_type,related_entity_id,status,sent_at)
 SELECT account.id,'appointments','in_app','Revisar integración de telemedicina','No se pudo preparar una sala; el sistema reintentará. Revisa la conexión institucional.',
 'appointment',target_appointment,'sent',now() FROM users account WHERE account.status='active' AND EXISTS(SELECT 1 FROM roles r WHERE r.code='admin'
 AND (account.role_id=r.id OR EXISTS(SELECT 1 FROM user_roles ur WHERE ur.user_id=account.id AND ur.role_id=r.id AND ur.revoked_at IS NULL
 AND ur.valid_from<=now() AND (ur.valid_until IS NULL OR ur.valid_until>now()))));
END; $$;
