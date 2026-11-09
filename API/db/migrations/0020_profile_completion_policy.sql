CREATE OR REPLACE FUNCTION app_profile_field_present(target_patient_id UUID,field_code TEXT)
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $docia$
SELECT app_can_read_patient(target_patient_id) AND COALESCE((SELECT CASE field_code
 WHEN 'bloodType' THEN NULLIF(trim(patient.blood_type),'') IS NOT NULL
 WHEN 'heightCm' THEN patient.height_cm IS NOT NULL
 WHEN 'weightKg' THEN patient.weight_kg IS NOT NULL
 WHEN 'insuranceProvider' THEN NULLIF(trim(patient.insurance_provider),'') IS NOT NULL
 WHEN 'emergencyContact' THEN EXISTS(SELECT 1 FROM emergency_contacts WHERE patient_id=patient.id AND is_active)
 WHEN 'allergies' THEN EXISTS(SELECT 1 FROM allergies WHERE patient_id=patient.id AND is_active AND validation_status<>'rejected')
 WHEN 'validatedAllergies' THEN EXISTS(SELECT 1 FROM allergies WHERE patient_id=patient.id AND is_active AND validation_status='validated')
 WHEN 'validatedAntecedents' THEN EXISTS(SELECT 1 FROM medical_antecedents WHERE patient_id=patient.id AND is_active AND validation_status='validated')
 WHEN 'professionalVitals' THEN EXISTS(SELECT 1 FROM vital_signs WHERE patient_id=patient.id AND source='professional')
 ELSE EXISTS(SELECT 1 FROM medical_antecedents WHERE patient_id=patient.id AND is_active AND validation_status<>'rejected'
   AND antecedent_type=CASE field_code WHEN 'medicalHistory' THEN 'pathological' WHEN 'familyHistory' THEN 'family'
     WHEN 'surgicalHistory' THEN 'surgical' WHEN 'chronicConditions' THEN 'chronic_condition' WHEN 'currentMedications' THEN 'medication' END)
 END FROM patients patient WHERE patient.id=target_patient_id),FALSE);
$docia$;

CREATE TABLE IF NOT EXISTS profile_completion_policy (
  singleton BOOLEAN PRIMARY KEY DEFAULT TRUE CHECK(singleton),
  policy JSONB NOT NULL DEFAULT '{"rules":[],"rewardEnabled":false}',
  updated_by_user_id UUID REFERENCES users(id), updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
INSERT INTO profile_completion_policy(singleton) VALUES(TRUE) ON CONFLICT DO NOTHING;
CREATE TABLE IF NOT EXISTS profile_reward_grants (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),patient_id UUID NOT NULL REFERENCES patients(id),
  campaign_id VARCHAR(80) NOT NULL,benefit_id UUID NOT NULL REFERENCES benefits(id),
  granted_at TIMESTAMPTZ NOT NULL DEFAULT now(), UNIQUE(patient_id,campaign_id)
);
ALTER TABLE profile_completion_policy ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS completion_policy_read ON profile_completion_policy;
CREATE POLICY completion_policy_read ON profile_completion_policy FOR SELECT USING(app_current_user_id() IS NOT NULL);
DROP POLICY IF EXISTS completion_policy_manage ON profile_completion_policy;
CREATE POLICY completion_policy_manage ON profile_completion_policy FOR ALL USING(app_has_permission('administration.manage')) WITH CHECK(app_has_permission('administration.manage'));
ALTER TABLE profile_reward_grants ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS completion_grant_read ON profile_reward_grants;
CREATE POLICY completion_grant_read ON profile_reward_grants FOR SELECT USING(app_can_read_patient(patient_id));

CREATE OR REPLACE FUNCTION app_grant_profile_reward(target_patient_id UUID, measured_percent NUMERIC)
RETURNS BOOLEAN LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $docia$
DECLARE config JSONB; grant_identifier UUID; calculated_percent NUMERIC; rule_count INT; missing_clinical INT;
BEGIN
  -- Recalculate inside the transaction; never trust the submitted percentage.
  SELECT policy INTO config FROM profile_completion_policy WHERE singleton FOR SHARE;
  SELECT count(*),COALESCE(100.0*count(*) FILTER(WHERE app_profile_field_present(target_patient_id,rule->>'field'))/NULLIF(count(*),0),0),
    count(*) FILTER(WHERE rule->>'actor'='professional' AND NOT app_profile_field_present(target_patient_id,rule->>'field'))
    INTO rule_count,calculated_percent,missing_clinical FROM jsonb_array_elements(config->'rules') rule;
  IF rule_count=0 OR missing_clinical>0 OR NOT COALESCE((config->>'rewardEnabled')::boolean,FALSE) OR NOT app_can_read_patient(target_patient_id)
    OR calculated_percent<(config->>'threshold')::numeric OR config->>'threshold' IS NULL OR config->>'validUntil' IS NULL OR (config->>'validUntil')::timestamptz<=now() THEN RETURN FALSE; END IF;
  IF NOT EXISTS(SELECT 1 FROM benefits WHERE id=(config->>'benefitId')::uuid AND is_active
    AND (valid_from IS NULL OR valid_from<=current_date) AND (valid_until IS NULL OR valid_until>=current_date)) THEN RETURN FALSE; END IF;
  INSERT INTO profile_reward_grants(patient_id,campaign_id,benefit_id)
    VALUES(target_patient_id,config->>'campaignId',(config->>'benefitId')::uuid)
    ON CONFLICT(patient_id,campaign_id) DO NOTHING RETURNING id INTO grant_identifier;
  IF grant_identifier IS NULL THEN RETURN FALSE; END IF;
  INSERT INTO audit_events(actor_user_id,actor_role,patient_id,module,action,entity_type,entity_id)
    VALUES(app_current_user_id(),app_current_role_code(),target_patient_id,'clinical_records','profile_reward_granted','profile_reward',grant_identifier);
  INSERT INTO notifications(user_id,event_code,channel,title,body,related_entity_type,related_entity_id,status)
    SELECT user_id,'benefits','in_app','Beneficio asignado','Tu perfil alcanzó las reglas de la campaña. Consulta tus beneficios.',
      'profile_reward',grant_identifier,'sent' FROM app_patient_alert_recipients(target_patient_id,'clinical_records.read');
  RETURN TRUE;
END;
$docia$;

ALTER TABLE patient_profile_completion ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS completion_metrics_read ON patient_profile_completion;
CREATE POLICY completion_metrics_read ON patient_profile_completion FOR SELECT USING(app_can_read_patient(patient_id));
DROP POLICY IF EXISTS completion_metrics_insert ON patient_profile_completion;
CREATE POLICY completion_metrics_insert ON patient_profile_completion FOR INSERT WITH CHECK(app_can_read_patient(patient_id));
DROP POLICY IF EXISTS completion_metrics_update ON patient_profile_completion;
CREATE POLICY completion_metrics_update ON patient_profile_completion FOR UPDATE USING(app_can_read_patient(patient_id)) WITH CHECK(app_can_read_patient(patient_id));
