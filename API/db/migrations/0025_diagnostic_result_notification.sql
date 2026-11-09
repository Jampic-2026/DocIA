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
