-- ============================================================
-- FUNCIONES Y RPC
-- ============================================================
-- Este archivo se ejecuta después de 01_database.sql.
-- Contiene funciones internas usadas por triggers y futuras RPC de aplicación.

-- RPC previstas para movimientos de monedas:
-- - acreditar compra de paquete: crear lote, movimiento positivo y actualizar billetera.
-- - consumir monedas por servicio: descontar lotes por expiración FIFO, crear asignaciones y movimiento negativo.
-- - reversar/refund: devolver monedas a billetera y auditar relación con payment_order/refund.
-- - expirar lotes vencidos: cerrar saldo restante y registrar movimiento de expiración.
-- Las implementaciones concretas se agregarán aquí cuando se cierre el contrato de aplicación.

CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION validate_minor_guardian_link()
RETURNS TRIGGER AS $$
DECLARE
    minor_birth_date DATE;
    guardian_birth_date DATE;
BEGIN
    SELECT pe.birth_date INTO minor_birth_date
      FROM patients pa JOIN persons pe ON pe.id = pa.person_id
     WHERE pa.id = NEW.patient_id;
    SELECT pe.birth_date INTO guardian_birth_date
      FROM users u JOIN persons pe ON pe.user_id = u.id
     WHERE u.id = NEW.guardian_user_id;
    IF minor_birth_date IS NULL OR minor_birth_date > CURRENT_DATE - INTERVAL '18 years' THEN
        IF guardian_birth_date IS NULL OR guardian_birth_date > CURRENT_DATE - INTERVAL '18 years' THEN
            RAISE EXCEPTION 'El familiar o tutor vinculado a un menor debe ser mayor de edad y tener una cuenta registrada';
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION ensure_minor_has_adult_link()
RETURNS TRIGGER AS $$
DECLARE
    patient_birth_date DATE;
BEGIN
    SELECT pe.birth_date INTO patient_birth_date
      FROM persons pe WHERE pe.id = NEW.person_id;
    IF (NEW.is_minor OR patient_birth_date > CURRENT_DATE - INTERVAL '18 years')
       AND NOT EXISTS (
           SELECT 1 FROM patient_guardians pg
           WHERE pg.patient_id = NEW.id AND pg.revoked_at IS NULL
       ) THEN
        RAISE EXCEPTION 'Todo paciente menor de edad debe vincular un familiar o tutor adulto registrado';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION validate_charge_mode()
RETURNS TRIGGER AS $$
DECLARE
    appt_modality appointment_modality;
BEGIN
    IF NEW.appointment_id IS NOT NULL THEN
        SELECT modality INTO appt_modality FROM appointments WHERE id = NEW.appointment_id;
        IF appt_modality = 'in_person' AND NEW.charge_mode <> 'fiat' THEN
            RAISE EXCEPTION 'Las consultas presenciales deben cobrarse en moneda fiat mediante QR o efectivo';
        ELSIF appt_modality <> 'in_person' AND NEW.charge_mode <> 'coins' THEN
            RAISE EXCEPTION 'Las consultas no presenciales deben cobrarse con monedas Doc IA';
        END IF;
    ELSIF NEW.related_entity_type = 'home_service' AND NEW.charge_mode <> 'fiat' THEN
        RAISE EXCEPTION 'Los servicios presenciales domiciliarios deben cobrarse en moneda fiat';
    ELSIF COALESCE(NEW.related_entity_type, 'service') NOT IN ('coin_package', 'partner_subscription', 'home_service')
          AND NEW.patient_id IS NOT NULL AND NEW.charge_mode <> 'coins' THEN
        RAISE EXCEPTION 'Los servicios no presenciales del usuario deben cobrarse con monedas Doc IA';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION validate_in_person_payment_collector()
RETURNS TRIGGER AS $$
DECLARE
    ptype VARCHAR(60);
    order_charge_mode VARCHAR(20);
BEGIN
    SELECT charge_mode INTO order_charge_mode FROM payment_orders
     WHERE id = NEW.payment_order_id;
    IF order_charge_mode <> 'fiat' THEN
        RAISE EXCEPTION 'Los pagos QR/efectivo solo corresponden a órdenes en moneda fiat';
    END IF;
    IF NEW.collection_context IN ('in_person_appointment', 'home_service') THEN
        IF NEW.method NOT IN ('cash', 'qr') THEN
            RAISE EXCEPTION 'Los servicios presenciales solo pueden abonarse mediante efectivo o QR';
        END IF;
        IF NEW.collected_by_professional_id IS NULL OR NEW.collection_context IS NULL THEN
            RAISE EXCEPTION 'El cobro presencial requiere profesional cobrador y contexto de atención';
        END IF;
        SELECT professional_type INTO ptype FROM professionals
         WHERE id = NEW.collected_by_professional_id;
        IF ptype NOT IN ('doctor', 'nurse') THEN
            RAISE EXCEPTION 'Solo el médico o enfermero de la atención puede registrar un cobro presencial';
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION set_coin_lot_expiration()
RETURNS TRIGGER AS $$
DECLARE
    expiration_interval INTERVAL;
BEGIN
    IF NEW.purchase_id IS NOT NULL THEN
        SELECT cp.coins_expire_after INTO expiration_interval
          FROM coin_purchases cpr
          JOIN coin_packages cp ON cp.id = cpr.package_id
         WHERE cpr.id = NEW.purchase_id;
        NEW.expires_at := NEW.credited_at + COALESCE(expiration_interval, INTERVAL '1 year');
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- HELPERS DE CONTEXTO PARA RLS / POLICIES
-- ============================================================

CREATE OR REPLACE FUNCTION app_current_user_id()
RETURNS UUID AS $jampic$
DECLARE
    value TEXT;
BEGIN
    value := current_setting('app.user_id', true);
    IF value IS NULL OR value = '' THEN
        RETURN NULL;
    END IF;
    RETURN value::UUID;
END;
$jampic$ LANGUAGE plpgsql STABLE;

CREATE OR REPLACE FUNCTION app_current_session_id()
RETURNS UUID AS $jampic$
DECLARE
    value TEXT;
BEGIN
    value := current_setting('app.session_id', true);
    IF value IS NULL OR value = '' THEN
        RETURN NULL;
    END IF;
    RETURN value::UUID;
END;
$jampic$ LANGUAGE plpgsql STABLE;

CREATE OR REPLACE FUNCTION app_current_role_code()
RETURNS TEXT AS $jampic$
BEGIN
    RETURN NULLIF(current_setting('app.role_code', true), '');
END;
$jampic$ LANGUAGE plpgsql STABLE;

CREATE OR REPLACE FUNCTION app_has_role(required_role TEXT)
RETURNS BOOLEAN AS $jampic$
DECLARE
    roles JSONB;
BEGIN
    roles := COALESCE(NULLIF(current_setting('app.roles', true), '')::jsonb, '[]'::jsonb);
    RETURN roles ? required_role;
END;
$jampic$ LANGUAGE plpgsql STABLE;

CREATE OR REPLACE FUNCTION app_has_permission(required_permission TEXT)
RETURNS BOOLEAN AS $jampic$
DECLARE
    permissions JSONB;
BEGIN
    permissions := COALESCE(NULLIF(current_setting('app.permissions', true), '')::jsonb, '[]'::jsonb);
    RETURN permissions ? required_permission;
END;
$jampic$ LANGUAGE plpgsql STABLE;

CREATE OR REPLACE FUNCTION app_login_identifier()
RETURNS TEXT AS $jampic$
BEGIN
    RETURN NULLIF(current_setting('app.login_identifier', true), '');
END;
$jampic$ LANGUAGE plpgsql STABLE;

CREATE OR REPLACE FUNCTION app_is_emergency_assignee(target_emergency_id UUID)
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER
SET search_path=public,pg_temp AS $docia$
  SELECT EXISTS(SELECT 1 FROM emergency_events event JOIN professionals professional
    ON professional.id=event.assigned_professional_id
    WHERE event.id=target_emergency_id AND professional.user_id=app_current_user_id()
      AND professional.verification_status='approved' AND professional.professional_type IN ('doctor','nurse'));
$docia$;

CREATE OR REPLACE FUNCTION app_is_person_care_assignee(target_person_id UUID)
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER
SET search_path=public,pg_temp AS $docia$
  SELECT EXISTS(SELECT 1 FROM patients patient JOIN appointments appointment ON appointment.patient_id=patient.id
    JOIN professionals professional ON professional.id=appointment.professional_id
    WHERE patient.person_id=target_person_id AND professional.user_id=app_current_user_id()
      AND professional.verification_status='approved' AND appointment.status NOT IN ('cancelled','no_show'))
  OR EXISTS(SELECT 1 FROM patients patient JOIN emergency_events event ON event.patient_id=patient.id
    WHERE patient.person_id=target_person_id AND app_is_emergency_assignee(event.id)
      AND event.status NOT IN ('closed','cancelled','false_alarm'));
$docia$;

CREATE OR REPLACE FUNCTION app_can_patient_action(target_patient_id UUID, action_code TEXT)
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $docia$
  SELECT action_code IN ('clinical_records.read','appointments.manage','emergencies.manage','patients.manage') AND (
    EXISTS(SELECT 1 FROM patients patient JOIN persons person ON person.id=patient.person_id
      WHERE patient.id=target_patient_id AND person.user_id=app_current_user_id())
    OR EXISTS(SELECT 1 FROM patient_guardians guardian WHERE guardian.patient_id=target_patient_id
      AND guardian.guardian_user_id=app_current_user_id() AND guardian.verification_status='validated'
      AND guardian.revoked_at IS NULL AND guardian.valid_from<=now() AND (guardian.valid_until IS NULL OR guardian.valid_until>now())
      AND (action_code='clinical_records.read' OR guardian.can_manage_profile))
    OR EXISTS(SELECT 1 FROM family_authorizations family_auth JOIN family_authorization_permissions permission ON permission.authorization_id=family_auth.id
      WHERE family_auth.patient_id=target_patient_id AND family_auth.family_user_id=app_current_user_id()
        AND family_auth.status='active' AND family_auth.revoked_at IS NULL AND family_auth.valid_from<=now()
        AND (family_auth.valid_until IS NULL OR family_auth.valid_until>now()) AND permission.permission_code=action_code)
  );
$docia$;

CREATE OR REPLACE FUNCTION app_can_read_patient(target_patient_id UUID)
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $docia$
  SELECT app_can_patient_action(target_patient_id,'clinical_records.read')
    OR EXISTS(SELECT 1 FROM patients patient WHERE patient.id=target_patient_id AND app_is_person_care_assignee(patient.person_id))
    OR app_has_role('admin') OR app_has_role('clinical_supervisor');
$docia$;



CREATE OR REPLACE FUNCTION app_professional_directory_identity(target_professional_id UUID)
RETURNS TABLE(full_name TEXT) LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = public, pg_temp AS $docia$
  SELECT concat_ws(' ',person.first_name,person.last_name,person.second_last_name)
  FROM professionals professional JOIN persons person ON person.id=professional.person_id
  WHERE professional.id=target_professional_id AND professional.verification_status='approved'
    AND professional.public_profile_enabled AND app_current_user_id() IS NOT NULL;
$docia$;

CREATE OR REPLACE FUNCTION app_emergency_assignee_contact(
    target_emergency_id UUID
)
RETURNS TABLE(team_name TEXT, team_phone VARCHAR)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $jampic$
    SELECT
        NULLIF(
            concat_ws(
                ' ',
                COALESCE(operator_person.first_name, professional_person.first_name),
                COALESCE(operator_person.last_name, professional_person.last_name)
            ),
            ''
        ) AS team_name,
        COALESCE(operator_user.phone, professional_user.phone) AS team_phone
    FROM emergency_events event
    LEFT JOIN professionals assigned_operator
      ON assigned_operator.id = event.assigned_operator_id
    LEFT JOIN persons operator_person
      ON operator_person.id = assigned_operator.person_id
    LEFT JOIN users operator_user
      ON operator_user.id = assigned_operator.user_id
    LEFT JOIN professionals assigned_professional
      ON assigned_professional.id = event.assigned_professional_id
    LEFT JOIN persons professional_person
      ON professional_person.id = assigned_professional.person_id
    LEFT JOIN users professional_user
      ON professional_user.id = assigned_professional.user_id
    WHERE event.id = target_emergency_id
      AND (
          event.requested_by_user_id = app_current_user_id()
          OR app_can_read_patient(event.patient_id)
          OR app_has_role('operator')
      );
$jampic$;

DROP FUNCTION IF EXISTS app_emergency_patient_contact(UUID);

CREATE OR REPLACE FUNCTION app_emergency_patient_contact(
    target_emergency_id UUID
)
RETURNS TABLE(patient_name TEXT, patient_phone VARCHAR)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $jampic$
    SELECT
      concat_ws(' ', person.first_name, person.last_name,
        person.second_last_name) AS patient_name,
      app_user.phone AS patient_phone
    FROM emergency_events event
    JOIN patients patient ON patient.id=event.patient_id
    JOIN persons person ON person.id=patient.person_id
    LEFT JOIN users app_user ON app_user.id=person.user_id
    WHERE event.id=target_emergency_id
      AND (
          event.requested_by_user_id=app_current_user_id()
          OR app_can_read_patient(event.patient_id)
          OR app_can_patient_action(event.patient_id,'emergencies.manage')
          OR app_has_role('operator')
          OR app_has_role('clinical_supervisor')
      );
$jampic$;

CREATE OR REPLACE FUNCTION enqueue_notification_push()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $docia$
BEGIN
    IF NEW.channel = 'in_app'
       AND COALESCE((
           SELECT preference.enabled
           FROM notification_preferences preference
           WHERE preference.user_id = NEW.user_id
             AND preference.channel = 'push'
             AND (
                 preference.event_code = NEW.event_code
                 OR NEW.event_code LIKE preference.event_code || '.%'
             )
           ORDER BY preference.event_code = NEW.event_code DESC
           LIMIT 1
       ), TRUE) THEN
        INSERT INTO notification_push_outbox(notification_id)
        VALUES (NEW.id)
        ON CONFLICT (notification_id) DO NOTHING;
    END IF;
    RETURN NEW;
END;
$docia$;

CREATE OR REPLACE FUNCTION apply_notification_preference()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $docia$
DECLARE
    preference_enabled BOOLEAN;
BEGIN
    SELECT preference.enabled
    INTO preference_enabled
    FROM notification_preferences preference
    WHERE preference.user_id = NEW.user_id
      AND preference.channel = NEW.channel
      AND (
          preference.event_code = NEW.event_code
          OR NEW.event_code LIKE preference.event_code || '.%'
      )
    ORDER BY preference.event_code = NEW.event_code DESC
    LIMIT 1;

    IF preference_enabled IS FALSE THEN
        RETURN NULL;
    END IF;
    RETURN NEW;
END;
$docia$;

-- ============================================================
-- FIN FUNCIONES Y RPC
-- ============================================================




CREATE OR REPLACE FUNCTION app_can_record_vitals(target_patient_id UUID, target_appointment_id UUID, target_emergency_id UUID)
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER
SET search_path=public,pg_temp AS $docia$
  SELECT app_has_permission('clinical_records.manage') AND
    ((target_appointment_id IS NOT NULL AND target_emergency_id IS NULL AND EXISTS(
      SELECT 1 FROM appointments appointment JOIN professionals professional ON professional.id=appointment.professional_id
      WHERE appointment.id=target_appointment_id AND appointment.patient_id=target_patient_id
        AND appointment.status='in_progress' AND professional.user_id=app_current_user_id() AND professional.verification_status='approved'))
    OR (target_emergency_id IS NOT NULL AND target_appointment_id IS NULL AND EXISTS(
      SELECT 1 FROM emergency_events event WHERE event.id=target_emergency_id AND event.patient_id=target_patient_id
        AND event.status IN ('on_site','in_care') AND event.accepted_at IS NOT NULL AND app_is_emergency_assignee(event.id))));
$docia$;

CREATE OR REPLACE FUNCTION app_notify_emergency_update(target_emergency_id UUID, notify_team BOOLEAN DEFAULT FALSE)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $docia$
DECLARE current_event emergency_events;
BEGIN
  SELECT * INTO current_event FROM emergency_events WHERE id=target_emergency_id;
  IF current_event.id IS NULL OR NOT (current_event.requested_by_user_id=app_current_user_id()
    OR app_is_emergency_assignee(target_emergency_id) OR app_has_role('operator') OR app_has_role('admin') OR app_has_role('clinical_supervisor')) THEN
    RAISE EXCEPTION 'Emergencia no autorizada' USING ERRCODE='42501';
  END IF;
  INSERT INTO notifications(user_id,event_code,channel,title,body,related_entity_type,related_entity_id,status)
  SELECT DISTINCT recipient.id,'emergencies','in_app'::notification_channel,'Actualización de emergencia',
    'Se actualizó una solicitud de emergencia. Consulta el módulo para revisar su estado.', 'emergency',current_event.id,'sent'
  FROM users recipient WHERE recipient.status='active' AND (
    recipient.id=current_event.requested_by_user_id
      OR recipient.id IN (SELECT user_id FROM app_patient_alert_recipients(current_event.patient_id,'emergencies.manage'))
    OR EXISTS(SELECT 1 FROM professionals professional WHERE professional.user_id=recipient.id
      AND professional.id IN (current_event.assigned_professional_id,current_event.assigned_operator_id) AND professional.verification_status='approved')
    OR (notify_team AND EXISTS(
      SELECT 1 FROM roles role WHERE role.is_active AND role.code IN ('operator','clinical_supervisor','admin')
      AND (role.id=recipient.role_id OR EXISTS(SELECT 1 FROM user_roles assignment WHERE assignment.user_id=recipient.id
        AND assignment.role_id=role.id AND assignment.revoked_at IS NULL AND assignment.valid_from<=now()
        AND (assignment.valid_until IS NULL OR assignment.valid_until>now())))))
  );
END;
$docia$;

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



CREATE OR REPLACE FUNCTION app_can_read_family_identity(target_person_id UUID)
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $docia$
  SELECT EXISTS(SELECT 1 FROM patients patient WHERE patient.person_id=target_person_id AND (
    app_can_patient_action(patient.id,'clinical_records.read') OR app_can_patient_action(patient.id,'appointments.manage')
    OR app_can_patient_action(patient.id,'emergencies.manage')))
  OR EXISTS(SELECT 1 FROM persons person JOIN family_authorizations family_auth ON family_auth.family_user_id=person.user_id
    WHERE person.id=target_person_id AND family_auth.granted_by_user_id=app_current_user_id()
      AND family_auth.status='active' AND family_auth.revoked_at IS NULL);
$docia$;

CREATE OR REPLACE FUNCTION app_find_family_account(account_email TEXT)
RETURNS TABLE(id UUID) LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $docia$
  SELECT account.id FROM users account WHERE app_current_user_id() IS NOT NULL AND app_has_permission('patients.manage')
    AND account.status='active' AND lower(account.email::text)=lower(account_email);
$docia$;

CREATE OR REPLACE FUNCTION app_create_minor_dependent(first_name_value TEXT,last_name_value TEXT,second_last_name_value TEXT,
  birth_date_value DATE,document_type_value TEXT,document_number_value TEXT,relationship_value TEXT,confirmed BOOLEAN)
RETURNS UUID LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $docia$
DECLARE person_identifier UUID; patient_identifier UUID;
BEGIN
  IF NOT app_has_permission('patients.manage') OR confirmed IS NOT TRUE OR NOT EXISTS(
    SELECT 1 FROM users account JOIN persons person ON person.user_id=account.id WHERE account.id=app_current_user_id()
      AND account.status='active' AND person.birth_date<=current_date-interval '18 years') THEN
    RAISE EXCEPTION 'Completa tu fecha de nacimiento y confirma tu responsabilidad. El tutor debe ser mayor de edad.' USING ERRCODE='42501';
  END IF;
  IF birth_date_value IS NULL OR birth_date_value>current_date OR birth_date_value<=current_date-interval '18 years'
    OR length(trim(first_name_value))<2 OR length(trim(last_name_value))<2 OR length(trim(relationship_value))<2 THEN
    RAISE EXCEPTION 'El dependiente debe ser menor de edad y tener sus datos completos.' USING ERRCODE='22023';
  END IF;
  INSERT INTO persons(first_name,last_name,second_last_name,birth_date,document_type,document_number)
    VALUES(trim(first_name_value),trim(last_name_value),NULLIF(trim(second_last_name_value),''),birth_date_value,NULLIF(trim(document_type_value),''),NULLIF(trim(document_number_value),'')) RETURNING id INTO person_identifier;
  INSERT INTO patients(person_id,is_minor,is_dependent) VALUES(person_identifier,TRUE,TRUE) RETURNING id INTO patient_identifier;
  INSERT INTO patient_guardians(patient_id,guardian_user_id,relationship,is_legal_guardian,verification_status,can_manage_profile,can_receive_alerts)
    VALUES(patient_identifier,app_current_user_id(),trim(relationship_value),TRUE,'validated',TRUE,TRUE);
  INSERT INTO audit_events(actor_user_id,actor_role,patient_id,module,action,entity_type,entity_id)
    VALUES(app_current_user_id(),app_current_role_code(),patient_identifier,'patients','minor_created_guardian_responsibility_declared','patient',patient_identifier);
  RETURN patient_identifier;
END;
$docia$;

CREATE OR REPLACE FUNCTION app_appointment_professional_identity(target_appointment_id UUID)
RETURNS TABLE(full_name TEXT) LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $docia$
  SELECT concat_ws(' ',person.first_name,person.last_name,person.second_last_name)
  FROM appointments appointment JOIN professionals professional ON professional.id=appointment.professional_id
  JOIN persons person ON person.id=professional.person_id
  WHERE appointment.id=target_appointment_id AND (professional.user_id=app_current_user_id()
    OR app_can_patient_action(appointment.patient_id,'appointments.manage') OR app_can_read_patient(appointment.patient_id)
    OR app_has_role('operator') OR app_has_role('admin') OR app_has_role('clinical_supervisor'));
$docia$;

CREATE OR REPLACE FUNCTION app_patient_alert_recipients(target_patient_id UUID, event_permission TEXT)
RETURNS TABLE(user_id UUID) LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $docia$
  SELECT person.user_id FROM patients patient JOIN persons person ON person.id=patient.person_id
    WHERE patient.id=target_patient_id AND person.user_id IS NOT NULL AND (app_can_read_patient(target_patient_id) OR app_can_patient_action(target_patient_id,event_permission))
  UNION
  SELECT guardian.guardian_user_id FROM patient_guardians guardian
    WHERE guardian.patient_id=target_patient_id AND (app_can_read_patient(target_patient_id) OR app_can_patient_action(target_patient_id,event_permission)) AND guardian.verification_status='validated'
      AND guardian.revoked_at IS NULL AND guardian.can_receive_alerts AND guardian.valid_from<=now()
      AND (guardian.valid_until IS NULL OR guardian.valid_until>now())
  UNION
  SELECT family_auth.family_user_id FROM family_authorizations family_auth
    JOIN family_authorization_permissions permission ON permission.authorization_id=family_auth.id
    WHERE family_auth.patient_id=target_patient_id AND (app_can_read_patient(target_patient_id) OR app_can_patient_action(target_patient_id,event_permission)) AND family_auth.status='active'
      AND family_auth.revoked_at IS NULL AND family_auth.valid_from<=now()
      AND (family_auth.valid_until IS NULL OR family_auth.valid_until>now())
      AND permission.permission_code=event_permission;
$docia$;

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

-- Narrow commands: no disclosure of other patients' bookings or redeemable codes.
CREATE OR REPLACE FUNCTION app_professional_slot_free(target_professional UUID, slot_start TIMESTAMPTZ, slot_end TIMESTAMPTZ, excluded_appointment UUID DEFAULT NULL)
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $docia$
  SELECT app_current_user_id() IS NOT NULL AND slot_start>now() AND slot_end>slot_start
    AND (slot_start AT TIME ZONE 'America/La_Paz')::date=(slot_end AT TIME ZONE 'America/La_Paz')::date
    AND EXISTS(SELECT 1 FROM professionals WHERE id=target_professional AND verification_status='approved' AND public_profile_enabled)
    AND NOT EXISTS(SELECT 1 FROM appointments WHERE professional_id=target_professional AND (excluded_appointment IS NULL OR id<>excluded_appointment) AND status NOT IN('cancelled','no_show') AND start_at<slot_end AND end_at>slot_start)
    AND NOT EXISTS(SELECT 1 FROM professional_time_blocks WHERE professional_id=target_professional AND start_at<slot_end AND end_at>slot_start);
$docia$;

CREATE OR REPLACE FUNCTION app_patient_has_referral(target_patient UUID,target_specialty UUID)
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $docia$
  SELECT app_can_patient_action(target_patient,'appointments.manage') AND EXISTS(
    SELECT 1 FROM referrals WHERE patient_id=target_patient AND specialty_id=target_specialty AND status='active'
      AND valid_from<=current_date AND (valid_until IS NULL OR valid_until>=current_date));
$docia$;

CREATE OR REPLACE FUNCTION app_redeem_guardian_code(code_digest TEXT,relationship_value TEXT)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $docia$
DECLARE selected_code guardian_link_codes; minor_patient patients;
BEGIN
  IF NOT app_has_permission('patients.manage') OR length(trim(relationship_value))<2 OR NOT EXISTS(
    SELECT 1 FROM users account JOIN persons person ON person.user_id=account.id
    WHERE account.id=app_current_user_id() AND account.status='active' AND person.birth_date<=current_date-interval '18 years') THEN
    RAISE EXCEPTION 'El tutor debe ser mayor de edad y tener sus datos completos.' USING ERRCODE='42501';
  END IF;
  SELECT * INTO selected_code FROM guardian_link_codes WHERE code_hash=code_digest AND used_at IS NULL AND expires_at>now() FOR UPDATE;
  SELECT patient.* INTO minor_patient FROM patients patient JOIN persons person ON person.id=patient.person_id
    WHERE patient.id=selected_code.minor_patient_id AND patient.is_minor AND person.birth_date>current_date-interval '18 years'
      AND person.user_id IS DISTINCT FROM app_current_user_id();
  IF minor_patient.id IS NULL THEN RAISE EXCEPTION 'El código no es válido o ya venció.' USING ERRCODE='22023'; END IF;
  INSERT INTO patient_guardians(patient_id,guardian_user_id,relationship,is_legal_guardian,verification_status,can_manage_profile,can_receive_alerts)
    VALUES(minor_patient.id,app_current_user_id(),trim(relationship_value),TRUE,'validated',TRUE,TRUE)
    ON CONFLICT(patient_id,guardian_user_id) DO UPDATE SET relationship=excluded.relationship,is_legal_guardian=TRUE,
      verification_status='validated',can_manage_profile=TRUE,can_receive_alerts=TRUE,valid_from=now(),valid_until=NULL,revoked_at=NULL;
  UPDATE guardian_link_codes SET used_by_user_id=app_current_user_id(),used_at=now() WHERE id=selected_code.id;
  INSERT INTO audit_events(actor_user_id,actor_role,patient_id,module,action,entity_type,entity_id)
    VALUES(app_current_user_id(),app_current_role_code(),minor_patient.id,'patients','guardian_code_redeemed_responsibility_declared','patient',minor_patient.id);
END;
$docia$;

CREATE OR REPLACE FUNCTION app_user_clinically_verified(target_user UUID)
RETURNS BOOLEAN LANGUAGE sql STABLE SECURITY DEFINER SET search_path=public,pg_temp AS $docia$
  SELECT EXISTS(SELECT 1 FROM users account JOIN professionals professional ON professional.user_id=account.id
    WHERE account.id=target_user AND account.status='active' AND professional.verification_status='approved'
      AND (account.id=app_current_user_id() OR account.email::text=current_setting('app.login_identifier',TRUE)
        OR account.phone=current_setting('app.login_identifier',TRUE))) ;
$docia$;

CREATE OR REPLACE FUNCTION app_notify_diagnostic_result(target_order UUID)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path=public,pg_temp AS $docia$
DECLARE selected_order diagnostic_orders;
BEGIN
  SELECT diagnostic.* INTO selected_order FROM diagnostic_orders diagnostic
    JOIN partner_users member ON member.partner_id=diagnostic.partner_id
    WHERE diagnostic.id=target_order AND diagnostic.status='completed' AND member.user_id=app_current_user_id() AND member.is_active;
  IF selected_order.id IS NULL THEN RAISE EXCEPTION 'Orden no autorizada' USING ERRCODE='42501'; END IF;
  INSERT INTO notifications(user_id,event_code,channel,title,body,related_entity_type,related_entity_id,status)
    SELECT DISTINCT account.id,'diagnostic.result.available','in_app'::notification_channel,'Resultado disponible',
      'Tienes una actualización. Consulta tu expediente.','diagnostic_order',target_order,'sent'
    FROM users account WHERE account.status='active' AND (
      account.id IN(SELECT person.user_id FROM patients patient JOIN persons person ON person.id=patient.person_id WHERE patient.id=selected_order.patient_id)
      OR account.id IN(SELECT guardian_user_id FROM patient_guardians WHERE patient_id=selected_order.patient_id AND verification_status='validated'
        AND can_receive_alerts AND revoked_at IS NULL AND valid_from<=now() AND (valid_until IS NULL OR valid_until>now()))
      OR account.id IN(SELECT family_user_id FROM family_authorizations family_auth JOIN family_authorization_permissions permission ON permission.authorization_id=family_auth.id
        WHERE family_auth.patient_id=selected_order.patient_id AND family_auth.status='active' AND family_auth.revoked_at IS NULL
          AND family_auth.valid_from<=now() AND (family_auth.valid_until IS NULL OR family_auth.valid_until>now()) AND permission.permission_code='clinical_records.read')
      OR account.id IN(SELECT user_id FROM professionals WHERE id=selected_order.requested_by_professional_id AND verification_status='approved'));
END;
$docia$;
