-- Bounded staff roster for authorized support-call coordinators.
-- No patient details, personnel documents or contact information are returned.
CREATE OR REPLACE FUNCTION app_support_staff_status()
RETURNS TABLE(id UUID,name TEXT,available BOOLEAN,reasons TEXT[])
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
 WITH roster AS (
 SELECT p.id,concat_ws(' ',person.first_name,person.last_name) AS name,
 array_remove(ARRAY[
   CASE WHEN p.verification_status IS DISTINCT FROM 'approved' THEN 'Profesional pendiente de habilitación' END,
   CASE WHEN account.status IS DISTINCT FROM 'active' THEN 'Cuenta inactiva' END,
   CASE WHEN NOT (
     EXISTS(SELECT 1 FROM work_shifts s WHERE s.professional_id=p.id AND s.status='assigned' AND s.start_at<=now() AND s.end_at>now())
     OR EXISTS(SELECT 1 FROM professional_availability av WHERE av.professional_id=p.id AND av.is_active
       AND av.weekday=extract(dow FROM now() AT TIME ZONE 'America/La_Paz')
       AND av.start_time<=(now() AT TIME ZONE 'America/La_Paz')::time
       AND av.end_time>(now() AT TIME ZONE 'America/La_Paz')::time)
   ) THEN 'Fuera de horario laboral: sin turno o disponibilidad vigente' END,
   CASE WHEN EXISTS(SELECT 1 FROM professional_time_blocks b WHERE b.professional_id=p.id AND b.start_at<=now() AND b.end_at>now()) THEN 'Bloqueo horario vigente' END,
   CASE WHEN EXISTS(SELECT 1 FROM support_call_requests c WHERE c.assigned_operator_id=p.id AND c.status IN('assigned','in_progress')) THEN 'Otra llamada asignada o en atención' END,
   CASE WHEN EXISTS(SELECT 1 FROM emergency_events e WHERE e.assigned_professional_id=p.id AND e.status NOT IN('closed','cancelled','false_alarm')) THEN 'Atención de emergencia activa' END,
   CASE WHEN EXISTS(SELECT 1 FROM home_service_requests h WHERE h.assigned_professional_id=p.id AND h.status::text IN('accepted','assigned','on_route','arrived','in_progress')) THEN 'Atención domiciliaria activa' END,
   CASE WHEN EXISTS(SELECT 1 FROM appointments a WHERE a.professional_id=p.id AND (
     a.status='in_progress' OR (a.status='confirmed' AND a.start_at<=now() AND a.end_at>now()))) THEN 'Consulta en curso o cita en horario vigente' END
 ],NULL) AS reasons
 FROM professionals p JOIN persons person ON person.id=p.person_id JOIN users account ON account.id=p.user_id
 WHERE app_has_permission('emergencies.manage')
   AND (app_has_role('admin') OR app_has_role('operator') OR app_has_role('clinical_supervisor'))
   AND p.professional_type IN('doctor','nurse','clinical_supervisor')
 )
 SELECT roster.id,roster.name,cardinality(roster.reasons)=0,roster.reasons
 FROM roster ORDER BY cardinality(roster.reasons)=0 DESC,roster.name,roster.id;
$$;
