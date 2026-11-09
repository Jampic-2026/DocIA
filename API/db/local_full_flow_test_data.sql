-- ============================================================
-- DATOS LOCALES PARA PRUEBA DEL FLUJO INTEGRAL DE JAMPIC
-- ============================================================
-- Solo desarrollo local. No se ejecuta desde npm run db:apply porque este
-- archivo no está numerado. Requiere haber aplicado 01..08 incluyendo el 08.
-- Es idempotente: utiliza identificadores reservados y actualiza sus semillas.

BEGIN;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM users WHERE email='patient@jampic.local')
       OR NOT EXISTS (SELECT 1 FROM users WHERE email='admin@jampic.local')
       OR NOT EXISTS (SELECT 1 FROM users WHERE email='doctor.general@jampic.local') THEN
        RAISE EXCEPTION 'Primero aplique 01..08 con DB_APPLY_LOCAL_SEEDS=true para cargar 08_local_test_users.sql';
    END IF;
END $$;

-- Perfil, dirección, contacto, tutor y consentimiento.
INSERT INTO addresses(id,person_id,municipality,zone,address_line,reference,latitude,longitude,is_current)
SELECT 'f1000000-0000-4000-8000-000000000001',person.id,'La Paz','Sopocachi',
       'Calle de prueba 123','Cerca de la plaza de prueba',-16.5100000,-68.1300000,true
FROM persons person JOIN users app_user ON app_user.id=person.user_id
WHERE app_user.email='patient@jampic.local'
ON CONFLICT(id) DO UPDATE SET address_line=EXCLUDED.address_line,is_current=true;

INSERT INTO emergency_contacts(id,patient_id,full_name,relationship,phone,email,is_primary,is_active)
SELECT 'f1000000-0000-4000-8000-000000000002',patient.id,'Tutor Prueba','Familiar',
       '+59170000003','guardian@jampic.local',true,true
FROM patients patient JOIN persons person ON person.id=patient.person_id
JOIN users app_user ON app_user.id=person.user_id WHERE app_user.email='patient@jampic.local'
ON CONFLICT(id) DO UPDATE SET phone=EXCLUDED.phone,is_active=true;

INSERT INTO patient_guardians(id,patient_id,guardian_user_id,relationship,is_legal_guardian,
                              verification_status,can_manage_profile,can_receive_alerts)
SELECT 'f1000000-0000-4000-8000-000000000003',patient.id,guardian.id,'Familiar',true,
       'validated',true,true
FROM patients patient JOIN persons person ON person.id=patient.person_id
JOIN users patient_user ON patient_user.id=person.user_id
JOIN users guardian ON guardian.email='guardian@jampic.local'
WHERE patient_user.email='patient@jampic.local'
ON CONFLICT(patient_id,guardian_user_id) DO UPDATE
SET verification_status='validated',revoked_at=NULL;

INSERT INTO patient_consents(id,patient_id,consent_type_id,granted_by_user_id,status,accepted_at,user_agent)
SELECT 'f1000000-0000-4000-8000-000000000004',patient.id,consent.id,patient_user.id,
       'accepted',now(),'Jampic local full-flow seed'
FROM patients patient JOIN persons person ON person.id=patient.person_id
JOIN users patient_user ON patient_user.id=person.user_id
CROSS JOIN LATERAL (SELECT id FROM consent_types WHERE is_active ORDER BY is_required DESC,code LIMIT 1) consent
WHERE patient_user.email='patient@jampic.local'
ON CONFLICT(id) DO UPDATE SET status='accepted',revoked_at=NULL,accepted_at=now();

-- Consulta completa, historia clínica y receta.
INSERT INTO appointments(id,patient_id,professional_id,specialty_id,modality,status,start_at,end_at,
                         reason,payment_required,created_by_user_id)
SELECT 'f2000000-0000-4000-8000-000000000001',patient.id,professional.id,specialty.id,
       'in_person','completed',now()-interval '2 days',now()-interval '2 days'+interval '30 minutes',
       'Control general integral de prueba',true,patient_user.id
FROM patients patient JOIN persons person ON person.id=patient.person_id
JOIN users patient_user ON patient_user.id=person.user_id
JOIN users doctor_user ON doctor_user.email='doctor.general@jampic.local'
JOIN professionals professional ON professional.user_id=doctor_user.id
JOIN professional_specialties professional_specialty ON professional_specialty.professional_id=professional.id
JOIN specialties specialty ON specialty.id=professional_specialty.specialty_id
WHERE patient_user.email='patient@jampic.local'
ON CONFLICT(id) DO UPDATE SET status='completed',updated_at=now();

INSERT INTO clinical_notes(id,appointment_id,patient_id,professional_id,anamnesis,findings,assessment,plan,closed_at)
SELECT 'f2000000-0000-4000-8000-000000000002',appointment.id,appointment.patient_id,
       appointment.professional_id,'Paciente refiere control preventivo.',
       'Signos vitales estables.','Paciente clínicamente estable.',
       'Control anual y hábitos saludables.',now()-interval '2 days'
FROM appointments appointment WHERE appointment.id='f2000000-0000-4000-8000-000000000001'
ON CONFLICT(id) DO UPDATE SET assessment=EXCLUDED.assessment,closed_at=EXCLUDED.closed_at;

INSERT INTO vital_signs(id,patient_id,recorded_by_user_id,source,systolic_pressure,diastolic_pressure,
                        heart_rate,temperature_c,oxygen_saturation,weight_kg,height_cm,notes,recorded_at)
SELECT 'f2000000-0000-4000-8000-000000000003',appointment.patient_id,doctor.id,'professional',
       118,76,72,36.5,97,70,170,'Control integral de prueba',appointment.start_at
FROM appointments appointment JOIN professionals professional ON professional.id=appointment.professional_id
JOIN users doctor ON doctor.id=professional.user_id
WHERE appointment.id='f2000000-0000-4000-8000-000000000001'
ON CONFLICT(id) DO UPDATE SET heart_rate=EXCLUDED.heart_rate,recorded_at=EXCLUDED.recorded_at;

INSERT INTO clinical_records(id,patient_id,record_type,title,content,source,validation_status,
                             author_user_id,author_role,related_appointment_id,recorded_at)
SELECT 'f2000000-0000-4000-8000-000000000004',appointment.patient_id,'note','Control preventivo',
       '{"summary":"Paciente estable","origin":"local_full_flow_test_data"}'::jsonb,
       'professional','validated',doctor.id,'doctor_general',appointment.id,appointment.start_at
FROM appointments appointment JOIN professionals professional ON professional.id=appointment.professional_id
JOIN users doctor ON doctor.id=professional.user_id
WHERE appointment.id='f2000000-0000-4000-8000-000000000001'
ON CONFLICT(id) DO UPDATE SET content=EXCLUDED.content,version=clinical_records.version+1;

INSERT INTO prescriptions(id,patient_id,professional_id,appointment_id,clinical_note_id,status,
                          issued_at,expires_at,digital_signature_hash)
SELECT 'f2000000-0000-4000-8000-000000000005',note.patient_id,note.professional_id,
       note.appointment_id,note.id,'issued',now()-interval '2 days',now()+interval '28 days',
       encode(digest('JAMPIC-LOCAL-PRESCRIPTION','sha256'),'hex')
FROM clinical_notes note WHERE note.id='f2000000-0000-4000-8000-000000000002'
ON CONFLICT(id) DO UPDATE SET status='issued',expires_at=EXCLUDED.expires_at;

INSERT INTO prescription_items(id,prescription_id,medication_name,dose,frequency,duration,instructions)
VALUES('f2000000-0000-4000-8000-000000000006','f2000000-0000-4000-8000-000000000005',
       'Paracetamol','500 mg','Cada 8 horas','3 días','Tomar después de comer si existe dolor.')
ON CONFLICT(id) DO UPDATE SET instructions=EXCLUDED.instructions;

-- Catálogo, tarifario, billetera, orden y pago manual aprobado.
INSERT INTO service_catalog(id,code,name,category,description,is_active)
VALUES('f3000000-0000-4000-8000-000000000001','LOCAL_FULL_FLOW_CONSULT',
       'Consulta integral local','consultation','Servicio utilizado por el flujo local completo.',true)
ON CONFLICT(code) DO UPDATE SET name=EXCLUDED.name,is_active=true;

INSERT INTO price_list(id,service_id,charge_mode,price)
SELECT 'f3000000-0000-4000-8000-000000000002',id,'fiat',120.00
FROM service_catalog WHERE code='LOCAL_FULL_FLOW_CONSULT'
ON CONFLICT(id) DO UPDATE SET price=EXCLUDED.price;

INSERT INTO coin_wallets(id,user_id,available_balance,reserved_balance,lifetime_credited,lifetime_spent)
SELECT 'f3000000-0000-4000-8000-000000000003',id,500,0,500,0
FROM users WHERE email='patient@jampic.local'
ON CONFLICT(user_id) DO UPDATE
SET available_balance=GREATEST(coin_wallets.available_balance,500),
    lifetime_credited=GREATEST(coin_wallets.lifetime_credited,500),updated_at=now();

INSERT INTO payment_orders(id,user_id,patient_id,service_id,appointment_id,concept,charge_mode,amount,currency,status,due_at,accepted_at)
SELECT 'f3000000-0000-4000-8000-000000000004',patient_user.id,appointment.patient_id,service.id,
       appointment.id,'Consulta integral local','fiat',120.00,'BOB','paid',now()+interval '1 day',now()
FROM appointments appointment JOIN patients patient ON patient.id=appointment.patient_id
JOIN persons person ON person.id=patient.person_id JOIN users patient_user ON patient_user.id=person.user_id
JOIN service_catalog service ON service.code='LOCAL_FULL_FLOW_CONSULT'
WHERE appointment.id='f2000000-0000-4000-8000-000000000001'
ON CONFLICT(id) DO UPDATE SET status='paid',amount=120.00,accepted_at=now();

INSERT INTO payments(id,payment_order_id,method,amount,status,receipt_url,transaction_reference,
                     paid_at,validated_by_user_id,validated_at,collected_by_professional_id,collection_context)
SELECT 'f3000000-0000-4000-8000-000000000005',payment_order.id,'qr',120.00,'paid',
       'https://example.com/local/receipt.pdf','LOCAL-FULL-FLOW-QR',now(),admin.id,now(),
       appointment.professional_id,'in_person_appointment'
FROM payment_orders payment_order
JOIN appointments appointment ON appointment.id=payment_order.appointment_id
CROSS JOIN (SELECT id FROM users WHERE email='admin@jampic.local') admin
WHERE payment_order.id='f3000000-0000-4000-8000-000000000004'
ON CONFLICT(id) DO UPDATE SET status='paid',validated_at=now();

-- Beneficio aplicado y validado por empresa asociada.
INSERT INTO benefits(id,code,name,description,discount_percent,benefit_type,max_uses_per_user,
                     max_total_uses,is_stackable,funded_by,valid_from,valid_until,conditions,is_active)
VALUES('f4000000-0000-4000-8000-000000000001','LOCAL_FULL_FLOW_10',
       'Beneficio integral local','Diez por ciento para pruebas funcionales.',10,'promotion',5,100,false,
       'platform',current_date-1,current_date+30,'{"minimumAmount":50}'::jsonb,true)
ON CONFLICT(code) DO UPDATE SET valid_until=EXCLUDED.valid_until,is_active=true;

INSERT INTO partner_benefits(partner_id,benefit_id,validation_required,settlement_terms,is_active)
SELECT partner.id,benefit.id,true,'{"settlement":"manual_test"}'::jsonb,true
FROM health_partners partner CROSS JOIN benefits benefit
WHERE partner.tax_id='LOCAL-PARTNER-001' AND benefit.code='LOCAL_FULL_FLOW_10'
ON CONFLICT(partner_id,benefit_id) DO UPDATE SET is_active=true;

INSERT INTO benefit_usages(id,benefit_id,patient_id,payment_order_id,discount_applied,status,used_at)
SELECT 'f4000000-0000-4000-8000-000000000002',benefit.id,payment_order.patient_id,
       payment_order.id,12.00,'validated',now()
FROM benefits benefit CROSS JOIN payment_orders payment_order
WHERE benefit.code='LOCAL_FULL_FLOW_10' AND payment_order.id='f3000000-0000-4000-8000-000000000004'
ON CONFLICT(id) DO UPDATE SET status='validated',discount_applied=12.00;

INSERT INTO benefit_validations(id,benefit_usage_id,partner_id,validated_by_user_id,status,reason,validated_at)
SELECT 'f4000000-0000-4000-8000-000000000003',usage.id,partner.id,partner_user.id,
       'approved','Validación local satisfactoria.',now()
FROM benefit_usages usage CROSS JOIN health_partners partner
CROSS JOIN (SELECT id FROM users WHERE email='partner@jampic.local') partner_user
WHERE usage.id='f4000000-0000-4000-8000-000000000002' AND partner.tax_id='LOCAL-PARTNER-001'
ON CONFLICT(id) DO UPDATE SET status='approved',validated_at=now();

-- Catálogo empresarial, solicitud de receta y estudio diagnóstico.
INSERT INTO partner_catalog_items(id,partner_id,service_id,item_type,sku,name,description,price,
                                  stock_quantity,requires_prescription,is_active)
SELECT 'f5000000-0000-4000-8000-000000000001',partner.id,service.id,'medication',
       'LOCAL-PARACETAMOL','Paracetamol 500 mg','Producto local de prueba.',18.00,100,true,true
FROM health_partners partner CROSS JOIN service_catalog service
WHERE partner.tax_id='LOCAL-PARTNER-001' AND service.code='LOCAL_FULL_FLOW_CONSULT'
ON CONFLICT(partner_id,sku) DO UPDATE SET stock_quantity=100,is_active=true;

INSERT INTO partner_requests(id,patient_id,requested_by_user_id,partner_id,prescription_id,status,
                             notes,confirmed_at,partner_response_at)
SELECT 'f5000000-0000-4000-8000-000000000002',prescription.patient_id,patient_user.id,
       partner.id,prescription.id,'accepted','Solicitud integral local.',now(),now()
FROM prescriptions prescription JOIN patients patient ON patient.id=prescription.patient_id
JOIN persons person ON person.id=patient.person_id JOIN users patient_user ON patient_user.id=person.user_id
CROSS JOIN (SELECT id FROM health_partners WHERE tax_id='LOCAL-PARTNER-001') partner
WHERE prescription.id='f2000000-0000-4000-8000-000000000005'
ON CONFLICT(id) DO UPDATE SET status='accepted',partner_response_at=now();

INSERT INTO partner_request_items(id,request_id,catalog_item_id,prescription_item_id,description,
                                  quantity,unit_price,availability_status)
SELECT 'f5000000-0000-4000-8000-000000000003',request.id,catalog.id,prescription_item.id,
       'Paracetamol 500 mg',1,catalog.price,'available'
FROM partner_requests request CROSS JOIN partner_catalog_items catalog
CROSS JOIN prescription_items prescription_item
WHERE request.id='f5000000-0000-4000-8000-000000000002'
  AND catalog.id='f5000000-0000-4000-8000-000000000001'
  AND prescription_item.id='f2000000-0000-4000-8000-000000000006'
ON CONFLICT(id) DO UPDATE SET availability_status='available',unit_price=EXCLUDED.unit_price;

INSERT INTO clinical_documents(id,patient_id,uploaded_by_user_id,related_appointment_id,document_type,
                               file_url,file_name,mime_type,source,validation_status,validated_by_professional_id,validated_at)
SELECT 'f5000000-0000-4000-8000-000000000004',appointment.patient_id,partner_user.id,appointment.id,
       'laboratory_result','https://example.com/local/laboratory-result.pdf','resultado-laboratorio.pdf',
       'application/pdf','external','validated',appointment.professional_id,now()
FROM appointments appointment CROSS JOIN (SELECT id FROM users WHERE email='partner@jampic.local') partner_user
WHERE appointment.id='f2000000-0000-4000-8000-000000000001'
ON CONFLICT(id) DO UPDATE SET validation_status='validated',validated_at=now();

INSERT INTO diagnostic_orders(id,patient_id,requested_by_professional_id,partner_id,appointment_id,
                              order_type,description,status,result_document_id,completed_at)
SELECT 'f5000000-0000-4000-8000-000000000005',appointment.patient_id,appointment.professional_id,
       partner.id,appointment.id,'lab','Hemograma completo de prueba','completed',
       'f5000000-0000-4000-8000-000000000004',now()
FROM appointments appointment CROSS JOIN (SELECT id FROM health_partners WHERE tax_id='LOCAL-PARTNER-001') partner
WHERE appointment.id='f2000000-0000-4000-8000-000000000001'
ON CONFLICT(id) DO UPDATE SET status='completed',completed_at=now();

-- Incidente, recursos humanos y notificación de cierre.
INSERT INTO incidents(id,reported_by_user_id,patient_id,module,incident_type,severity,description,status,resolution,
                      resolved_by_user_id,resolved_at)
SELECT 'f6000000-0000-4000-8000-000000000001',patient_user.id,patient.id,'payments',
       'test_incident','green','Incidente controlado del flujo integral local.','resolved',
       'Verificado manualmente en ambiente local.',admin.id,now()
FROM patients patient JOIN persons person ON person.id=patient.person_id
JOIN users patient_user ON patient_user.id=person.user_id
CROSS JOIN (SELECT id FROM users WHERE email='admin@jampic.local') admin
WHERE patient_user.email='patient@jampic.local'
ON CONFLICT(id) DO UPDATE SET status='resolved',resolved_at=now();

INSERT INTO personnel_applications(id,applicant_user_id,requested_role_code,status,submitted_at,
                                   reviewed_by_user_id,reviewed_at)
SELECT 'f6000000-0000-4000-8000-000000000002',nurse.id,'nurse','approved',
       now()-interval '30 days',hr.id,now()-interval '29 days'
FROM users nurse CROSS JOIN users hr
WHERE nurse.email='nurse@jampic.local' AND hr.email='hr@jampic.local'
ON CONFLICT(id) DO UPDATE SET status='approved',reviewed_at=EXCLUDED.reviewed_at;

INSERT INTO personnel_observations(id,professional_id,registered_by_user_id,observation_type,
                                   description,action_taken,is_confidential)
SELECT 'f6000000-0000-4000-8000-000000000003',professional.id,hr.id,'recognition',
       'Registro positivo generado por la prueba integral.','Sin acción adicional.',true
FROM professionals professional JOIN users nurse ON nurse.id=professional.user_id
CROSS JOIN (SELECT id FROM users WHERE email='hr@jampic.local') hr
WHERE nurse.email='nurse@jampic.local'
ON CONFLICT(id) DO UPDATE SET description=EXCLUDED.description;

INSERT INTO notification_preferences(user_id,event_code,channel,enabled)
SELECT id,'full_flow_test','in_app',true FROM users WHERE email='patient@jampic.local'
ON CONFLICT(user_id,event_code,channel) DO UPDATE SET enabled=true,updated_at=now();

INSERT INTO notifications(id,user_id,event_code,channel,title,body,related_entity_type,related_entity_id,
                          status,sent_at)
SELECT 'f6000000-0000-4000-8000-000000000004',id,'full_flow_test','in_app',
       'Flujo integral disponible','Los datos locales del flujo integral fueron cargados correctamente.',
       'appointment','f2000000-0000-4000-8000-000000000001','sent',now()
FROM users WHERE email='patient@jampic.local'
ON CONFLICT(id) DO UPDATE SET body=EXCLUDED.body,status='sent',sent_at=now(),read_at=NULL;

COMMIT;

-- Resumen esperado: una fila con los contadores principales del escenario.
SELECT
    (SELECT count(*) FROM appointments WHERE id='f2000000-0000-4000-8000-000000000001') AS appointments,
    (SELECT count(*) FROM prescriptions WHERE id='f2000000-0000-4000-8000-000000000005') AS prescriptions,
    (SELECT count(*) FROM payments WHERE id='f3000000-0000-4000-8000-000000000005') AS payments,
    (SELECT count(*) FROM benefit_usages WHERE id='f4000000-0000-4000-8000-000000000002') AS benefits,
    (SELECT count(*) FROM partner_requests WHERE id='f5000000-0000-4000-8000-000000000002') AS partner_requests,
    (SELECT count(*) FROM diagnostic_orders WHERE id='f5000000-0000-4000-8000-000000000005') AS diagnostics,
    (SELECT count(*) FROM incidents WHERE id='f6000000-0000-4000-8000-000000000001') AS incidents,
    (SELECT count(*) FROM notifications WHERE id='f6000000-0000-4000-8000-000000000004') AS notifications;
