-- ============================================================
-- TRIGGERS
-- ============================================================
-- Este archivo se ejecuta después de 02_functions.sql.
-- Agrupa validaciones automáticas y mantenimiento de updated_at.

DROP TRIGGER IF EXISTS trg_validate_minor_guardian ON patient_guardians;
CREATE TRIGGER trg_validate_minor_guardian
BEFORE INSERT OR UPDATE ON patient_guardians
FOR EACH ROW EXECUTE FUNCTION validate_minor_guardian_link();

DROP TRIGGER IF EXISTS trg_minor_requires_guardian ON patients;
CREATE CONSTRAINT TRIGGER trg_minor_requires_guardian
AFTER INSERT OR UPDATE OF is_minor, person_id ON patients
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW EXECUTE FUNCTION ensure_minor_has_adult_link();

DROP TRIGGER IF EXISTS trg_validate_charge_mode ON payment_orders;
CREATE TRIGGER trg_validate_charge_mode
BEFORE INSERT OR UPDATE ON payment_orders
FOR EACH ROW EXECUTE FUNCTION validate_charge_mode();

DROP TRIGGER IF EXISTS trg_validate_in_person_payment ON payments;
CREATE TRIGGER trg_validate_in_person_payment
BEFORE INSERT OR UPDATE ON payments
FOR EACH ROW EXECUTE FUNCTION validate_in_person_payment_collector();

DROP TRIGGER IF EXISTS trg_set_coin_lot_expiration ON coin_lots;
CREATE TRIGGER trg_set_coin_lot_expiration
BEFORE INSERT OR UPDATE OF purchase_id, credited_at ON coin_lots
FOR EACH ROW EXECUTE FUNCTION set_coin_lot_expiration();

DROP TRIGGER IF EXISTS trg_roles_updated_at ON roles;
CREATE TRIGGER trg_roles_updated_at BEFORE UPDATE ON roles
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_users_updated_at ON users;
CREATE TRIGGER trg_users_updated_at BEFORE UPDATE ON users
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_persons_updated_at ON persons;
CREATE TRIGGER trg_persons_updated_at BEFORE UPDATE ON persons
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_addresses_updated_at ON addresses;
CREATE TRIGGER trg_addresses_updated_at BEFORE UPDATE ON addresses
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_patients_updated_at ON patients;
CREATE TRIGGER trg_patients_updated_at BEFORE UPDATE ON patients
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_professionals_updated_at ON professionals;
CREATE TRIGGER trg_professionals_updated_at BEFORE UPDATE ON professionals
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_appointments_updated_at ON appointments;
CREATE TRIGGER trg_appointments_updated_at BEFORE UPDATE ON appointments
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_emergency_events_updated_at ON emergency_events;
CREATE TRIGGER trg_emergency_events_updated_at BEFORE UPDATE ON emergency_events
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_clinical_notes_updated_at ON clinical_notes;
CREATE TRIGGER trg_clinical_notes_updated_at BEFORE UPDATE ON clinical_notes
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_prescriptions_updated_at ON prescriptions;
CREATE TRIGGER trg_prescriptions_updated_at BEFORE UPDATE ON prescriptions
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_payment_orders_updated_at ON payment_orders;
CREATE TRIGGER trg_payment_orders_updated_at BEFORE UPDATE ON payment_orders
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

DROP TRIGGER IF EXISTS trg_enqueue_notification_push ON notifications;
CREATE TRIGGER trg_enqueue_notification_push
AFTER INSERT ON notifications
FOR EACH ROW EXECUTE FUNCTION enqueue_notification_push();

DROP TRIGGER IF EXISTS trg_apply_notification_preference ON notifications;
CREATE TRIGGER trg_apply_notification_preference
BEFORE INSERT ON notifications
FOR EACH ROW EXECUTE FUNCTION apply_notification_preference();

-- ============================================================
-- FIN TRIGGERS
-- ============================================================
