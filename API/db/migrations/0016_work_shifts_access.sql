ALTER TABLE work_shifts ADD COLUMN IF NOT EXISTS area_text VARCHAR(160);

CREATE OR REPLACE FUNCTION app_staff_is_available(target_professional_id UUID, service_type TEXT DEFAULT NULL)
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $docia$
  SELECT app_has_permission('human_resources.read') AND EXISTS(SELECT 1 FROM professionals professional
    WHERE professional.id=target_professional_id AND professional.verification_status='approved')
  AND NOT EXISTS(SELECT 1 FROM emergency_events event WHERE event.assigned_professional_id=target_professional_id AND event.status NOT IN ('closed','cancelled','false_alarm'))
  AND NOT EXISTS(SELECT 1 FROM home_service_requests request WHERE request.assigned_professional_id=target_professional_id AND request.status::text IN ('accepted','assigned','on_route','arrived','in_progress'))
  AND NOT EXISTS(SELECT 1 FROM professional_time_blocks block WHERE block.professional_id=target_professional_id AND block.start_at<=now() AND block.end_at>now())
  AND NOT EXISTS(SELECT 1 FROM appointments appointment WHERE appointment.professional_id=target_professional_id AND appointment.status IN ('confirmed','in_progress') AND appointment.start_at<=now() AND appointment.end_at>now())
  AND ((service_type IS NULL AND EXISTS(SELECT 1 FROM work_shifts shift WHERE shift.professional_id=target_professional_id
      AND shift.status='assigned' AND shift.start_at<=now() AND shift.end_at>now()))
    OR EXISTS(SELECT 1 FROM professional_availability availability WHERE availability.professional_id=target_professional_id AND availability.is_active
      AND availability.weekday=extract(dow FROM now() AT TIME ZONE 'America/La_Paz') AND availability.start_time<=(now() AT TIME ZONE 'America/La_Paz')::time
      AND availability.end_time>(now() AT TIME ZONE 'America/La_Paz')::time AND (service_type IS NULL OR availability.modality::text=service_type)));
$docia$;
ALTER TABLE work_shifts ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS shifts_read ON work_shifts;
CREATE POLICY shifts_read ON work_shifts FOR SELECT USING(app_has_permission('human_resources.read')
  OR professional_id=(SELECT id FROM professionals WHERE user_id=app_current_user_id()));
DROP POLICY IF EXISTS shifts_manage ON work_shifts;
CREATE POLICY shifts_manage ON work_shifts FOR ALL USING(app_has_permission('human_resources.manage'))
WITH CHECK(app_has_permission('human_resources.manage'));
ALTER TABLE work_shift_history ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS shift_history_read ON work_shift_history;
CREATE POLICY shift_history_read ON work_shift_history FOR SELECT USING(EXISTS(SELECT 1 FROM work_shifts shift WHERE shift.id=shift_id));
DROP POLICY IF EXISTS shift_history_write ON work_shift_history;
CREATE POLICY shift_history_write ON work_shift_history FOR INSERT WITH CHECK(app_has_permission('human_resources.manage') AND changed_by_user_id=app_current_user_id());
