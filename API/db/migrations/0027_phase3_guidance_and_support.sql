CREATE TABLE IF NOT EXISTS ai_risk_policy (
 singleton BOOLEAN PRIMARY KEY DEFAULT true CHECK(singleton),policy JSONB NOT NULL DEFAULT '{"rules":[]}',
 enabled BOOLEAN NOT NULL DEFAULT false,revision INT NOT NULL DEFAULT 1,
 updated_by UUID REFERENCES users(id),reviewed_by UUID REFERENCES users(id),review_reference TEXT,
 CHECK(NOT enabled OR (reviewed_by IS NOT NULL AND review_reference IS NOT NULL))
);
INSERT INTO ai_risk_policy(singleton) VALUES(true) ON CONFLICT DO NOTHING;
CREATE OR REPLACE FUNCTION app_risk_policy_is_active() RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
 SELECT app_current_user_id() IS NOT NULL AND EXISTS(SELECT 1 FROM ai_risk_policy config
 JOIN professionals reviewer ON reviewer.user_id=config.reviewed_by JOIN users account ON account.id=reviewer.user_id
 WHERE config.singleton AND config.enabled AND reviewer.verification_status='approved' AND account.status='active'
 AND EXISTS(SELECT 1 FROM roles r WHERE r.code='clinical_supervisor' AND (r.id=account.role_id
 OR EXISTS(SELECT 1 FROM user_roles ur WHERE ur.user_id=account.id AND ur.role_id=r.id AND ur.revoked_at IS NULL
 AND ur.valid_from<=now() AND (ur.valid_until IS NULL OR ur.valid_until>now())))));
$$;
ALTER TABLE ai_risk_policy ENABLE ROW LEVEL SECURITY;
CREATE OR REPLACE FUNCTION app_verify_risk_revision(target_revision INT) RETURNS BOOLEAN
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
 PERFORM 1 FROM ai_risk_policy WHERE singleton AND revision=target_revision FOR SHARE;
 RETURN FOUND AND app_risk_policy_is_active();
END; $$;
DROP POLICY IF EXISTS risk_policy_read ON ai_risk_policy;
CREATE POLICY risk_policy_read ON ai_risk_policy FOR SELECT USING(app_current_user_id() IS NOT NULL);
DROP POLICY IF EXISTS risk_policy_manage ON ai_risk_policy;
CREATE POLICY risk_policy_manage ON ai_risk_policy FOR UPDATE USING(app_has_permission('ai.manage')) WITH CHECK(app_has_permission('ai.manage'));
ALTER TABLE ai_risk_assessments ADD COLUMN IF NOT EXISTS classification_status TEXT NOT NULL DEFAULT 'preventive_alert';
ALTER TABLE ai_risk_assessments ADD COLUMN IF NOT EXISTS context_used BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE ai_risk_assessments ADD COLUMN IF NOT EXISTS policy_revision INT;
ALTER TABLE ai_risk_assessments ADD COLUMN IF NOT EXISTS questions JSONB NOT NULL DEFAULT '[]';
ALTER TABLE ai_risk_assessments ADD COLUMN IF NOT EXISTS decision_at TIMESTAMPTZ;
ALTER TABLE ai_risk_assessments ADD COLUMN IF NOT EXISTS related_entity_id UUID;
ALTER TABLE support_call_requests ADD COLUMN IF NOT EXISTS meeting_url TEXT;
ALTER TABLE support_call_requests ADD COLUMN IF NOT EXISTS external_meeting_id TEXT;
CREATE TABLE IF NOT EXISTS support_call_history (
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(),call_id UUID NOT NULL REFERENCES support_call_requests(id),
 actor_user_id UUID REFERENCES users(id),action TEXT NOT NULL,notes TEXT,created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS support_call_queue_idx ON support_call_requests(priority,requested_at) WHERE status IN('pending','assigned','in_progress');
CREATE OR REPLACE FUNCTION app_staff_is_available(target_professional_id UUID,service_type TEXT DEFAULT NULL)
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
 SELECT (app_has_permission('human_resources.read') OR app_has_permission('emergencies.manage'))
 AND EXISTS(SELECT 1 FROM professionals p WHERE p.id=target_professional_id AND p.verification_status='approved')
 AND NOT EXISTS(SELECT 1 FROM emergency_events e WHERE e.assigned_professional_id=target_professional_id AND e.status NOT IN('closed','cancelled','false_alarm'))
 AND NOT EXISTS(SELECT 1 FROM home_service_requests h WHERE h.assigned_professional_id=target_professional_id AND h.status::text IN('accepted','assigned','on_route','arrived','in_progress'))
 AND NOT EXISTS(SELECT 1 FROM professional_time_blocks b WHERE b.professional_id=target_professional_id AND b.start_at<=now() AND b.end_at>now())
 AND NOT EXISTS(SELECT 1 FROM appointments a WHERE a.professional_id=target_professional_id AND a.status IN('confirmed','in_progress') AND a.start_at<=now() AND a.end_at>now())
 AND ((service_type IS NULL AND EXISTS(SELECT 1 FROM work_shifts s WHERE s.professional_id=target_professional_id AND s.status='assigned' AND s.start_at<=now() AND s.end_at>now()))
 OR EXISTS(SELECT 1 FROM professional_availability av WHERE av.professional_id=target_professional_id AND av.is_active
 AND av.weekday=extract(dow FROM now() AT TIME ZONE 'America/La_Paz') AND av.start_time<=(now() AT TIME ZONE 'America/La_Paz')::time
 AND av.end_time>(now() AT TIME ZONE 'America/La_Paz')::time AND (service_type IS NULL OR av.modality::text=service_type)));
$$;
CREATE OR REPLACE FUNCTION app_support_available_staff() RETURNS TABLE(id UUID,name TEXT)
LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $$
 SELECT p.id,concat_ws(' ',person.first_name,person.last_name) FROM professionals p
 JOIN persons person ON person.id=p.person_id JOIN users account ON account.id=p.user_id
 WHERE app_has_permission('emergencies.manage') AND (app_has_role('admin') OR app_has_role('operator') OR app_has_role('clinical_supervisor'))
 AND p.verification_status='approved' AND account.status='active' AND p.professional_type IN('doctor','nurse','clinical_supervisor')
 AND app_staff_is_available(p.id)
 AND NOT EXISTS(SELECT 1 FROM support_call_requests c WHERE c.assigned_operator_id=p.id AND c.status IN('assigned','in_progress'))
 AND NOT EXISTS(SELECT 1 FROM appointments a WHERE a.professional_id=p.id AND a.status='in_progress')
 AND NOT EXISTS(SELECT 1 FROM emergency_events e WHERE e.assigned_professional_id=p.id AND e.status NOT IN('closed','cancelled','false_alarm'))
 ORDER BY 2 LIMIT 200;
$$;
CREATE OR REPLACE FUNCTION app_support_assignable(target_professional UUID,target_call UUID) RETURNS BOOLEAN
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
 IF NOT app_has_permission('emergencies.manage') OR NOT (app_has_role('admin') OR app_has_role('operator') OR app_has_role('clinical_supervisor')) THEN RETURN false; END IF;
 PERFORM 1 FROM professionals p JOIN users account ON account.id=p.user_id WHERE p.id=target_professional
 AND p.verification_status='approved' AND account.status='active' AND p.professional_type IN('doctor','nurse','clinical_supervisor') FOR UPDATE OF p;
 IF NOT FOUND THEN RETURN false; END IF;
 IF NOT app_staff_is_available(target_professional) THEN RETURN false; END IF;
 IF EXISTS(SELECT 1 FROM appointments a WHERE a.professional_id=target_professional AND a.status='in_progress')
 OR EXISTS(SELECT 1 FROM emergency_events e WHERE e.assigned_professional_id=target_professional AND e.status NOT IN('closed','cancelled','false_alarm')) THEN RETURN false; END IF;
 RETURN NOT EXISTS(SELECT 1 FROM support_call_requests c WHERE c.assigned_operator_id=target_professional AND c.id<>target_call AND c.status IN('assigned','in_progress'));
END; $$;
ALTER TABLE support_call_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE support_call_history ENABLE ROW LEVEL SECURITY;
CREATE OR REPLACE FUNCTION app_reject_support_call(target_call UUID,rejection_reason TEXT) RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
 IF length(trim(rejection_reason))<3 OR length(rejection_reason)>4000 THEN RAISE EXCEPTION 'Motivo requerido'; END IF;
 PERFORM 1 FROM support_call_requests c JOIN professionals p ON p.id=c.assigned_operator_id
 WHERE c.id=target_call AND c.status='assigned' AND p.user_id=app_current_user_id() AND p.verification_status='approved' FOR UPDATE OF c;
 IF NOT FOUND THEN RAISE EXCEPTION 'Asignacion no disponible'; END IF;
 UPDATE support_call_requests SET status='pending',assigned_operator_id=NULL WHERE id=target_call;
 INSERT INTO support_call_history(call_id,actor_user_id,action,notes) VALUES(target_call,app_current_user_id(),'reject',trim(rejection_reason));
END; $$;
DROP POLICY IF EXISTS support_calls_access ON support_call_requests;
CREATE POLICY support_calls_access ON support_call_requests FOR ALL USING(
 requested_by_user_id=app_current_user_id() OR app_has_role('admin') OR app_has_role('operator') OR app_has_role('clinical_supervisor')
 OR EXISTS(SELECT 1 FROM professionals p WHERE p.id=assigned_operator_id AND p.user_id=app_current_user_id() AND p.verification_status='approved'))
 WITH CHECK(requested_by_user_id=app_current_user_id() OR app_has_role('admin') OR app_has_role('operator') OR app_has_role('clinical_supervisor')
 OR EXISTS(SELECT 1 FROM professionals p WHERE p.id=assigned_operator_id AND p.user_id=app_current_user_id() AND p.verification_status='approved'));
DROP POLICY IF EXISTS support_history_access ON support_call_history;
CREATE POLICY support_history_access ON support_call_history FOR ALL USING(EXISTS(SELECT 1 FROM support_call_requests c WHERE c.id=call_id))
 WITH CHECK(actor_user_id=app_current_user_id() AND EXISTS(SELECT 1 FROM support_call_requests c WHERE c.id=call_id));
CREATE OR REPLACE FUNCTION app_notify_support_transition() RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $$
BEGIN
 INSERT INTO notifications(user_id,event_code,channel,title,body,related_entity_type,related_entity_id,status,sent_at)
 SELECT recipient,'appointments','in_app','Solicitud de orientación actualizada','Consulta el estado de tu solicitud en Orientación humana.',
 'support_call_request',NEW.id,'sent',now() FROM (
 SELECT NEW.requested_by_user_id AS recipient UNION SELECT p.user_id FROM professionals p WHERE p.id=NEW.assigned_operator_id
 UNION SELECT account.id FROM users account JOIN roles r ON r.id=account.role_id WHERE account.status='active' AND r.code IN('operator','clinical_supervisor') AND NEW.status='pending'
 UNION SELECT ur.user_id FROM user_roles ur JOIN roles r ON r.id=ur.role_id JOIN users account ON account.id=ur.user_id
 WHERE account.status='active' AND ur.revoked_at IS NULL AND ur.valid_from<=now() AND (ur.valid_until IS NULL OR ur.valid_until>now())
 AND r.code IN('operator','clinical_supervisor') AND NEW.status='pending'
 ) recipients WHERE recipient IS NOT NULL;
 RETURN NEW;
END; $$;
DROP TRIGGER IF EXISTS notify_support_transition ON support_call_requests;
CREATE TRIGGER notify_support_transition AFTER INSERT OR UPDATE OF status,assigned_operator_id ON support_call_requests FOR EACH ROW EXECUTE FUNCTION app_notify_support_transition();
REVOKE ALL ON FUNCTION app_notify_support_transition() FROM PUBLIC;
