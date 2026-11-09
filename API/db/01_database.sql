
-- ============================================================
-- JAMPIC Base de datos PostgreSQL local
-- Versión corregida e integral 2.0
-- Basado en los 165 casos de uso, el diseño general y las definiciones
-- funcionales y operativas de Jampic (julio de 2026).
-- ============================================================

-- Crear base manualmente si aún no existe:
-- CREATE DATABASE jampic_local;
-- \c jampic_local;

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS citext;

-- ============================================================
-- LIMPIEZA OPCIONAL PARA DESARROLLO LOCAL
-- CUIDADO: borra todo el esquema público.
-- ============================================================
-- DROP SCHEMA public CASCADE;
-- CREATE SCHEMA public;

-- ============================================================
-- ENUMS
-- ============================================================

DO $$ BEGIN
    CREATE TYPE user_status AS ENUM ('active', 'pending_verification', 'suspended', 'inactive', 'deleted');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TYPE sex_biological AS ENUM ('female', 'male', 'intersex', 'unknown', 'not_specified');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TYPE validation_status AS ENUM ('self_declared', 'pending_validation', 'validated', 'corrected', 'rejected', 'inactive');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TYPE appointment_status AS ENUM ('scheduled', 'confirmed', 'rescheduled', 'cancelled', 'in_progress', 'completed', 'no_show');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TYPE appointment_modality AS ENUM ('telemedicine', 'home_visit', 'in_person');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TYPE emergency_status AS ENUM ('received', 'confirming', 'validating', 'assigned', 'on_route', 'on_site', 'in_care', 'referred', 'closed', 'cancelled', 'false_alarm');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TYPE risk_level AS ENUM ('green', 'yellow', 'red', 'undetermined');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TYPE payment_status AS ENUM ('pending', 'accepted', 'pending_validation', 'paid', 'failed', 'rejected', 'cancelled', 'expired', 'refunded', 'partially_refunded');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TYPE payment_method AS ENUM ('qr', 'cash', 'card', 'bank_transfer', 'other');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TYPE consent_status AS ENUM ('accepted', 'revoked', 'expired');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TYPE professional_verification_status AS ENUM ('pending', 'under_review', 'approved', 'rejected', 'expired');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TYPE prescription_status AS ENUM ('draft', 'issued', 'cancelled', 'expired');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TYPE generic_request_status AS ENUM ('draft', 'pending', 'assigned', 'accepted', 'rejected', 'in_progress', 'completed', 'cancelled', 'failed');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TYPE delivery_status AS ENUM ('available', 'assigned', 'accepted', 'picked_up', 'on_route', 'delivered', 'failed', 'returned', 'cancelled');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TYPE notification_channel AS ENUM ('email', 'push', 'sms', 'instant_message', 'in_app');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ============================================================
-- ============================================================
-- SEGURIDAD, USUARIOS, ROLES Y PERMISOS
-- ============================================================

CREATE TABLE IF NOT EXISTS roles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(60) UNIQUE NOT NULL,
    name VARCHAR(120) NOT NULL,
    description TEXT,
    is_system BOOLEAN NOT NULL DEFAULT FALSE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS permissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(120) UNIQUE NOT NULL,
    module VARCHAR(80) NOT NULL,
    description TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS role_permissions (
    role_id UUID NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
    permission_id UUID NOT NULL REFERENCES permissions(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (role_id, permission_id)
);

CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    role_id UUID REFERENCES roles(id), -- rol principal; los roles adicionales viven en user_roles
    email CITEXT UNIQUE NOT NULL,
    phone VARCHAR(40) UNIQUE,
    password_hash TEXT NOT NULL,
    status user_status NOT NULL DEFAULT 'active',
    mfa_enabled BOOLEAN NOT NULL DEFAULT FALSE,
    mfa_secret_encrypted TEXT,
    email_verified_at TIMESTAMPTZ,
    phone_verified_at TIMESTAMPTZ,
    last_login_at TIMESTAMPTZ,
    suspension_reason TEXT,
    suspended_at TIMESTAMPTZ,
    reactivated_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT users_verified_before_active_chk CHECK (status <> 'active' OR email_verified_at IS NOT NULL)
);

-- El registro comienza aquí: primero se valida el email con un token de un solo uso.
-- La API solo crea users/persons/patients después de consumir un token vigente.
CREATE TABLE IF NOT EXISTS registration_email_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email CITEXT NOT NULL,
    token_hash TEXT NOT NULL UNIQUE,
    requested_ip INET,
    user_agent TEXT,
    expires_at TIMESTAMPTZ NOT NULL,
    verified_at TIMESTAMPTZ,
    consumed_at TIMESTAMPTZ,
    created_user_id UUID UNIQUE REFERENCES users(id) ON DELETE SET NULL,
    attempt_count SMALLINT NOT NULL DEFAULT 0 CHECK (attempt_count >= 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT registration_token_dates_chk CHECK (expires_at > created_at)
);

CREATE TABLE IF NOT EXISTS user_roles (
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role_id UUID NOT NULL REFERENCES roles(id),
    granted_by_user_id UUID REFERENCES users(id),
    valid_from TIMESTAMPTZ NOT NULL DEFAULT now(),
    valid_until TIMESTAMPTZ,
    revoked_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, role_id)
);

CREATE TABLE IF NOT EXISTS password_reset_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash TEXT NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    used_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS user_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    refresh_token_hash TEXT NOT NULL,
    user_agent TEXT,
    ip_address INET,
    expires_at TIMESTAMPTZ NOT NULL,
    revoked_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================
-- PERSONAS, PACIENTES Y DEPENDIENTES
-- ============================================================

CREATE TABLE IF NOT EXISTS persons (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID UNIQUE REFERENCES users(id) ON DELETE SET NULL,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    second_last_name VARCHAR(100),
    document_type VARCHAR(30),
    document_number VARCHAR(60),
    birth_date DATE,
    nationality VARCHAR(100),
    sex sex_biological DEFAULT 'not_specified',
    marital_status VARCHAR(50),
    profession VARCHAR(120),
    photo_url TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (document_type, document_number)
);

CREATE TABLE IF NOT EXISTS addresses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    person_id UUID REFERENCES persons(id) ON DELETE CASCADE,
    municipality VARCHAR(120),
    zone VARCHAR(120),
    address_line TEXT,
    reference TEXT,
    latitude NUMERIC(10, 7),
    longitude NUMERIC(10, 7),
    is_current BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS patients (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    person_id UUID UNIQUE NOT NULL REFERENCES persons(id) ON DELETE CASCADE,
    insurance_provider VARCHAR(160),
    insurance_number VARCHAR(80),
    blood_type VARCHAR(10),
    height_cm NUMERIC(5,2),
    weight_kg NUMERIC(5,2),
    profile_notes TEXT,
    is_minor BOOLEAN NOT NULL DEFAULT FALSE,
    is_dependent BOOLEAN NOT NULL DEFAULT FALSE,
    clinical_profile_created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS guardian_link_codes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    minor_patient_id UUID NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
    code_hash TEXT NOT NULL UNIQUE,
    generated_by_user_id UUID NOT NULL REFERENCES users(id),
    expires_at TIMESTAMPTZ NOT NULL,
    used_by_user_id UUID REFERENCES users(id),
    used_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS emergency_contacts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id UUID NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
    full_name VARCHAR(180) NOT NULL,
    relationship VARCHAR(80),
    phone VARCHAR(40) NOT NULL,
    email CITEXT,
    is_primary BOOLEAN NOT NULL DEFAULT FALSE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS patient_guardians (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id UUID NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
    guardian_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    relationship VARCHAR(80) NOT NULL,
    is_legal_guardian BOOLEAN NOT NULL DEFAULT FALSE,
    verification_status validation_status NOT NULL DEFAULT 'pending_validation',
    can_manage_profile BOOLEAN NOT NULL DEFAULT TRUE,
    can_receive_alerts BOOLEAN NOT NULL DEFAULT TRUE,
    valid_from TIMESTAMPTZ NOT NULL DEFAULT now(),
    valid_until TIMESTAMPTZ,
    revoked_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(patient_id, guardian_user_id)
);

-- Los límites de gestión familiar se resuelven por reglas de negocio y permisos vigentes.
-- Todo menor puede crear su propia cuenta, pero debe vincular al menos un adulto registrado.
CREATE TABLE IF NOT EXISTS family_authorizations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id UUID NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
    family_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    granted_by_user_id UUID NOT NULL REFERENCES users(id),
    relationship VARCHAR(80),
    status user_status NOT NULL DEFAULT 'active',
    accepted_at TIMESTAMPTZ,
    revoked_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(patient_id, family_user_id)
);

CREATE TABLE IF NOT EXISTS family_authorization_permissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    authorization_id UUID NOT NULL REFERENCES family_authorizations(id) ON DELETE CASCADE,
    permission_code VARCHAR(80) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(authorization_id, permission_code)
);

CREATE TABLE IF NOT EXISTS patient_profile_completion (
    patient_id UUID PRIMARY KEY REFERENCES patients(id) ON DELETE CASCADE,
    completion_percent NUMERIC(5,2) NOT NULL DEFAULT 0 CHECK (completion_percent BETWEEN 0 AND 100),
    missing_fields JSONB NOT NULL DEFAULT '[]'::jsonb,
    calculated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================
-- CONSENTIMIENTOS
-- ============================================================

CREATE TABLE IF NOT EXISTS consent_types (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(80) UNIQUE NOT NULL,
    name VARCHAR(160) NOT NULL,
    description TEXT,
    version VARCHAR(30) NOT NULL DEFAULT '1.0',
    is_required BOOLEAN NOT NULL DEFAULT FALSE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS patient_consents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id UUID NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
    consent_type_id UUID NOT NULL REFERENCES consent_types(id),
    granted_by_user_id UUID NOT NULL REFERENCES users(id),
    status consent_status NOT NULL DEFAULT 'accepted',
    accepted_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    revoked_at TIMESTAMPTZ,
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================
-- PROFESIONALES, ESPECIALIDADES, DISPONIBILIDAD
-- ============================================================

CREATE TABLE IF NOT EXISTS specialties (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(160) UNIQUE NOT NULL,
    description TEXT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS professionals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID UNIQUE NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    person_id UUID UNIQUE NOT NULL REFERENCES persons(id) ON DELETE CASCADE,
    professional_type VARCHAR(60) NOT NULL, -- doctor, nurse, operator, admin, delivery, clinical_supervisor
    license_number VARCHAR(100),
    bio TEXT,
    years_experience INT CHECK (years_experience IS NULL OR years_experience >= 0),
    verification_status professional_verification_status NOT NULL DEFAULT 'pending',
    verified_at TIMESTAMPTZ,
    verified_by_user_id UUID REFERENCES users(id),
    public_profile_enabled BOOLEAN NOT NULL DEFAULT FALSE,
    pending_specialty_id UUID REFERENCES specialties(id),
    average_rating NUMERIC(3,2) DEFAULT 0,
    rating_count INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS professional_specialties (
    professional_id UUID NOT NULL REFERENCES professionals(id) ON DELETE CASCADE,
    specialty_id UUID NOT NULL REFERENCES specialties(id),
    requires_referral BOOLEAN NOT NULL DEFAULT FALSE,
    is_primary BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (professional_id, specialty_id)
);

CREATE TABLE IF NOT EXISTS professional_documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    professional_id UUID NOT NULL REFERENCES professionals(id) ON DELETE CASCADE,
    document_type VARCHAR(80) NOT NULL,
    file_url TEXT NOT NULL,
    status professional_verification_status NOT NULL DEFAULT 'pending',
    reviewed_by_user_id UUID REFERENCES users(id),
    reviewed_at TIMESTAMPTZ,
    observation TEXT,
    valid_until DATE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS professional_document_requirements (
    role_code VARCHAR(60) PRIMARY KEY REFERENCES roles(code),
    document_types JSONB NOT NULL CHECK (jsonb_typeof(document_types)='array' AND jsonb_array_length(document_types)>0),
    updated_by_user_id UUID NOT NULL REFERENCES users(id),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS professional_availability (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    professional_id UUID NOT NULL REFERENCES professionals(id) ON DELETE CASCADE,
    weekday SMALLINT CHECK (weekday BETWEEN 0 AND 6),
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    modality appointment_modality NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT availability_time_chk CHECK (end_time > start_time)
);

CREATE TABLE IF NOT EXISTS professional_time_blocks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    professional_id UUID NOT NULL REFERENCES professionals(id) ON DELETE CASCADE,
    start_at TIMESTAMPTZ NOT NULL,
    end_at TIMESTAMPTZ NOT NULL,
    reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT time_blocks_chk CHECK (end_at > start_at)
);

CREATE TABLE IF NOT EXISTS work_shifts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    professional_id UUID NOT NULL REFERENCES professionals(id) ON DELETE CASCADE,
    assigned_by_user_id UUID NOT NULL REFERENCES users(id),
    start_at TIMESTAMPTZ NOT NULL,
    end_at TIMESTAMPTZ NOT NULL,
    status VARCHAR(40) NOT NULL DEFAULT 'assigned',
    location_text TEXT,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CHECK (end_at > start_at)
);

CREATE TABLE IF NOT EXISTS work_shift_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    shift_id UUID NOT NULL REFERENCES work_shifts(id) ON DELETE CASCADE,
    changed_by_user_id UUID NOT NULL REFERENCES users(id),
    old_values JSONB,
    new_values JSONB NOT NULL,
    reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================
-- HISTORIA CLÍNICA PROGRESIVA Y DATOS CLÍNICOS
-- ============================================================

CREATE TABLE IF NOT EXISTS clinical_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id UUID NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
    record_type VARCHAR(80) NOT NULL, -- antecedent, allergy, vital_sign, note, diagnosis, treatment, prescription, emergency, document
    title VARCHAR(180),
    content JSONB NOT NULL DEFAULT '{}'::jsonb,
    source VARCHAR(80) NOT NULL DEFAULT 'professional', -- self_declared, professional, device, ai, imported
    validation_status validation_status NOT NULL DEFAULT 'validated',
    author_user_id UUID REFERENCES users(id),
    author_role VARCHAR(80),
    related_appointment_id UUID,
    related_emergency_id UUID,
    version INT NOT NULL DEFAULT 1,
    previous_record_id UUID REFERENCES clinical_records(id),
    change_reason TEXT,
    editable_until TIMESTAMPTZ NOT NULL DEFAULT (now() + INTERVAL '12 hours'),
    recorded_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS clinical_correction_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id UUID NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
    requested_by_user_id UUID NOT NULL REFERENCES users(id),
    entity_type VARCHAR(120) NOT NULL,
    entity_id UUID NOT NULL,
    requested_change TEXT NOT NULL,
    reason TEXT NOT NULL,
    status VARCHAR(40) NOT NULL DEFAULT 'pending',
    resolved_by_user_id UUID REFERENCES users(id),
    resolution TEXT,
    resolved_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS clinical_record_versions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    clinical_record_id UUID NOT NULL REFERENCES clinical_records(id) ON DELETE CASCADE,
    version_number INT NOT NULL CHECK (version_number > 0),
    snapshot JSONB NOT NULL,
    changed_by_user_id UUID REFERENCES users(id),
    change_reason TEXT NOT NULL,
    changed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (clinical_record_id, version_number)
);

CREATE TABLE IF NOT EXISTS allergies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id UUID NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
    substance VARCHAR(180) NOT NULL,
    reaction TEXT,
    severity risk_level DEFAULT 'undetermined',
    validation_status validation_status NOT NULL DEFAULT 'validated',
    author_user_id UUID REFERENCES users(id),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS medical_antecedents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id UUID NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
    antecedent_type VARCHAR(60) NOT NULL, -- pathological, family, surgical, medication, chronic_condition
    description TEXT NOT NULL,
    relation VARCHAR(80),
    start_date DATE,
    validation_status validation_status NOT NULL DEFAULT 'validated',
    author_user_id UUID REFERENCES users(id),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS vital_signs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id UUID NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
    recorded_by_user_id UUID REFERENCES users(id),
    source VARCHAR(80) NOT NULL DEFAULT 'professional', -- professional, patient, iot_device
    systolic_pressure INT,
    diastolic_pressure INT,
    heart_rate INT,
    temperature_c NUMERIC(4,2),
    oxygen_saturation NUMERIC(5,2),
    respiratory_rate INT,
    glucose_mg_dl NUMERIC(6,2),
    weight_kg NUMERIC(5,2),
    height_cm NUMERIC(5,2),
    signal_quality VARCHAR(60),
    notes TEXT,
    recorded_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS clinical_documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id UUID NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
    uploaded_by_user_id UUID REFERENCES users(id),
    related_appointment_id UUID,
    related_emergency_id UUID,
    document_type VARCHAR(80) NOT NULL,
    file_url TEXT NOT NULL,
    file_name TEXT,
    mime_type VARCHAR(120),
    is_restricted BOOLEAN NOT NULL DEFAULT FALSE,
    source VARCHAR(40) NOT NULL DEFAULT 'internal', -- internal, external
    validation_status validation_status NOT NULL DEFAULT 'pending_validation',
    validated_by_professional_id UUID REFERENCES professionals(id),
    validated_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================
-- EMERGENCIAS Y OPERADOR
-- ============================================================

CREATE TABLE IF NOT EXISTS emergency_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id UUID NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
    requested_by_user_id UUID NOT NULL REFERENCES users(id),
    status emergency_status NOT NULL DEFAULT 'received',
    risk_level risk_level NOT NULL DEFAULT 'undetermined',
    risk_source VARCHAR(40) NOT NULL DEFAULT 'unassessed', -- ai_pretriage, professional, external
    risk_assessed_by_user_id UUID REFERENCES users(id),
    risk_assessed_at TIMESTAMPTZ,
    description TEXT,
    latitude NUMERIC(10,7),
    longitude NUMERIC(10,7),
    manual_address TEXT,
    reference TEXT,
    coverage_available BOOLEAN,
    assigned_professional_id UUID REFERENCES professionals(id),
    assigned_operator_id UUID REFERENCES professionals(id),
    cancellation_reason TEXT,
    false_alarm_reason TEXT,
    opened_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    assigned_at TIMESTAMPTZ,
    arrived_at TIMESTAMPTZ,
    closed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS emergency_status_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    emergency_id UUID NOT NULL REFERENCES emergency_events(id) ON DELETE CASCADE,
    old_status emergency_status,
    new_status emergency_status NOT NULL,
    changed_by_user_id UUID REFERENCES users(id),
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS emergency_triage_answers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    emergency_id UUID NOT NULL REFERENCES emergency_events(id) ON DELETE CASCADE,
    question_code VARCHAR(80) NOT NULL,
    question_text TEXT NOT NULL,
    answer TEXT,
    risk_weight INT DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS emergency_care_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    emergency_id UUID NOT NULL REFERENCES emergency_events(id) ON DELETE CASCADE,
    professional_id UUID NOT NULL REFERENCES professionals(id),
    care_type VARCHAR(80) NOT NULL, -- nursing_assessment, medical_assessment, intervention, referral, closure
    notes TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS support_call_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id UUID REFERENCES patients(id) ON DELETE SET NULL,
    requested_by_user_id UUID NOT NULL REFERENCES users(id),
    assigned_operator_id UUID REFERENCES professionals(id),
    priority risk_level NOT NULL DEFAULT 'green',
    reason TEXT,
    status VARCHAR(40) NOT NULL DEFAULT 'pending',
    result_notes TEXT,
    direction VARCHAR(20) NOT NULL DEFAULT 'outbound',
    duration_seconds INT CHECK (duration_seconds IS NULL OR duration_seconds >= 0),
    escalation_type VARCHAR(60),
    escalation_reference_id UUID,
    requested_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    started_at TIMESTAMPTZ,
    ended_at TIMESTAMPTZ,
    cancelled_at TIMESTAMPTZ
);

-- ============================================================
-- IA: SESIONES, MENSAJES Y RIESGO
-- ============================================================

CREATE TABLE IF NOT EXISTS ai_conversations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id UUID NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
    created_by_user_id UUID NOT NULL REFERENCES users(id),
    title VARCHAR(180),
    model_name VARCHAR(120),
    prompt_version VARCHAR(60),
    status VARCHAR(40) NOT NULL DEFAULT 'active',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    closed_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS ai_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID NOT NULL REFERENCES ai_conversations(id) ON DELETE CASCADE,
    sender VARCHAR(20) NOT NULL, -- user, assistant, system
    message TEXT NOT NULL,
    safety_flags JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS ai_risk_assessments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID NOT NULL REFERENCES ai_conversations(id) ON DELETE CASCADE,
    patient_id UUID NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
    risk_level risk_level NOT NULL DEFAULT 'undetermined',
    reasons JSONB NOT NULL DEFAULT '[]'::jsonb,
    recommended_action VARCHAR(120), -- emergency, appointment, call_operator, self_care_info
    user_decision VARCHAR(120),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS ai_voice_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    patient_id UUID NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
    topic VARCHAR(120),
    meeting_url TEXT,
    external_meeting_id VARCHAR(160),
    started_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    ended_at TIMESTAMPTZ,
    max_billable_minutes INTEGER CHECK (max_billable_minutes IS NULL OR max_billable_minutes BETWEEN 1 AND 15),
    billed_minutes INTEGER CHECK (billed_minutes IS NULL OR billed_minutes BETWEEN 1 AND 15),
    coin_transaction_id UUID,
    status VARCHAR(30) NOT NULL DEFAULT 'active',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================
-- CONSULTAS, TELEMEDICINA Y ATENCIÓN CLÍNICA
-- ============================================================

CREATE TABLE IF NOT EXISTS referrals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id UUID NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
    issued_by_professional_id UUID NOT NULL REFERENCES professionals(id),
    specialty_id UUID NOT NULL REFERENCES specialties(id),
    reason TEXT NOT NULL,
    priority risk_level NOT NULL DEFAULT 'yellow',
    referral_type VARCHAR(40) NOT NULL DEFAULT 'ordinary', -- urgent, preferred, ordinary, chronic_followup
    status VARCHAR(40) NOT NULL DEFAULT 'active',
    valid_from DATE NOT NULL DEFAULT CURRENT_DATE,
    valid_until DATE,
    used_at TIMESTAMPTZ,
    closed_at TIMESTAMPTZ,
    closed_reason TEXT,
    counter_referral_notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS appointments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id UUID NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
    professional_id UUID NOT NULL REFERENCES professionals(id),
    specialty_id UUID REFERENCES specialties(id),
    referral_id UUID REFERENCES referrals(id),
    direct_specialist_access BOOLEAN NOT NULL DEFAULT FALSE,
    general_practitioner_recommendation_shown_at TIMESTAMPTZ,
    patient_direct_access_acknowledged_at TIMESTAMPTZ,
    modality appointment_modality NOT NULL,
    status appointment_status NOT NULL DEFAULT 'scheduled',
    start_at TIMESTAMPTZ NOT NULL,
    end_at TIMESTAMPTZ NOT NULL,
    reason TEXT,
    cancellation_reason TEXT,
    cancellation_policy_snapshot JSONB NOT NULL DEFAULT '{}'::jsonb,
    payment_required BOOLEAN NOT NULL DEFAULT FALSE,
    rescheduled_from_id UUID REFERENCES appointments(id),
    created_by_user_id UUID REFERENCES users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT appointments_time_chk CHECK (end_at > start_at)
);

CREATE TABLE IF NOT EXISTS appointment_status_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    appointment_id UUID NOT NULL REFERENCES appointments(id) ON DELETE CASCADE,
    old_status appointment_status,
    new_status appointment_status NOT NULL,
    changed_by_user_id UUID REFERENCES users(id),
    reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS appointment_followups (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    source_appointment_id UUID NOT NULL REFERENCES appointments(id) ON DELETE CASCADE,
    followup_appointment_id UUID REFERENCES appointments(id) ON DELETE SET NULL,
    recommended_by_professional_id UUID NOT NULL REFERENCES professionals(id),
    recommended_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    due_at TIMESTAMPTZ,
    instructions TEXT,
    status VARCHAR(40) NOT NULL DEFAULT 'pending'
);

CREATE TABLE IF NOT EXISTS telemedicine_rooms (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    appointment_id UUID UNIQUE NOT NULL REFERENCES appointments(id) ON DELETE CASCADE,
    provider VARCHAR(80) NOT NULL DEFAULT 'google_meet',
    meeting_url TEXT NOT NULL,
    external_meeting_id TEXT,
    status VARCHAR(40) NOT NULL DEFAULT 'created',
    started_at TIMESTAMPTZ,
    ended_at TIMESTAMPTZ,
    recording_enabled BOOLEAN NOT NULL DEFAULT FALSE,
    recording_url TEXT,
    recording_retention_until TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS telemedicine_participants (
    room_id UUID NOT NULL REFERENCES telemedicine_rooms(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    consent_id UUID REFERENCES patient_consents(id),
    joined_at TIMESTAMPTZ,
    left_at TIMESTAMPTZ,
    connection_failures INT NOT NULL DEFAULT 0,
    PRIMARY KEY (room_id, user_id)
);

CREATE TABLE IF NOT EXISTS telemedicine_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    room_id UUID NOT NULL REFERENCES telemedicine_rooms(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id),
    event_type VARCHAR(60) NOT NULL, -- join, leave, retry, connection_failure, switch_to_call, file_shared
    details JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS telemedicine_shared_files (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    room_id UUID NOT NULL REFERENCES telemedicine_rooms(id) ON DELETE CASCADE,
    clinical_document_id UUID NOT NULL REFERENCES clinical_documents(id) ON DELETE CASCADE,
    shared_by_user_id UUID NOT NULL REFERENCES users(id),
    shared_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS clinical_notes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    appointment_id UUID REFERENCES appointments(id) ON DELETE CASCADE,
    emergency_id UUID REFERENCES emergency_events(id) ON DELETE SET NULL,
    patient_id UUID NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
    professional_id UUID NOT NULL REFERENCES professionals(id),
    anamnesis TEXT,
    findings TEXT,
    assessment TEXT,
    plan TEXT,
    internal_notes TEXT,
    closed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS diagnoses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    clinical_note_id UUID NOT NULL REFERENCES clinical_notes(id) ON DELETE CASCADE,
    diagnosis_code VARCHAR(40),
    diagnosis_text TEXT NOT NULL,
    diagnosis_type VARCHAR(40) NOT NULL DEFAULT 'presumptive', -- presumptive, definitive, differential
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS treatments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    clinical_note_id UUID NOT NULL REFERENCES clinical_notes(id) ON DELETE CASCADE,
    description TEXT NOT NULL,
    instructions TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS appointment_ratings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    appointment_id UUID UNIQUE NOT NULL REFERENCES appointments(id) ON DELETE CASCADE,
    patient_id UUID NOT NULL REFERENCES patients(id),
    professional_id UUID NOT NULL REFERENCES professionals(id),
    rating SMALLINT NOT NULL CHECK (rating BETWEEN 1 AND 5),
    comment TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================
-- RECETAS DIGITALES
-- ============================================================

CREATE TABLE IF NOT EXISTS prescriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id UUID NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
    professional_id UUID NOT NULL REFERENCES professionals(id),
    appointment_id UUID REFERENCES appointments(id) ON DELETE SET NULL,
    clinical_note_id UUID REFERENCES clinical_notes(id) ON DELETE SET NULL,
    status prescription_status NOT NULL DEFAULT 'draft',
    issued_at TIMESTAMPTZ,
    expires_at TIMESTAMPTZ,
    digital_signature_hash TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS prescription_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    prescription_id UUID NOT NULL REFERENCES prescriptions(id) ON DELETE CASCADE,
    medication_name VARCHAR(180) NOT NULL,
    dose VARCHAR(100),
    frequency VARCHAR(120),
    duration VARCHAR(120),
    instructions TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================
-- CATÁLOGO, MONEDAS, PAGOS PRESENCIALES Y BENEFICIOS
-- ============================================================

CREATE TABLE IF NOT EXISTS service_catalog (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(80) UNIQUE NOT NULL,
    name VARCHAR(180) NOT NULL,
    category VARCHAR(80) NOT NULL, -- consultation, emergency, home_service, delivery, partner_service, coin_package
    description TEXT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS price_list (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    service_id UUID NOT NULL REFERENCES service_catalog(id),
    charge_mode VARCHAR(20) NOT NULL, -- coins para servicios no presenciales, fiat para presenciales
    coin_price BIGINT CHECK (coin_price IS NULL OR coin_price >= 0),
    price NUMERIC(12,2) CHECK (price IS NULL OR price >= 0),
    currency CHAR(3) NOT NULL DEFAULT 'BOB',
    valid_from DATE NOT NULL DEFAULT CURRENT_DATE,
    valid_until DATE,
    created_by_user_id UUID REFERENCES users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CHECK (
        (charge_mode = 'coins' AND coin_price IS NOT NULL AND price IS NULL)
        OR (charge_mode = 'fiat' AND price IS NOT NULL AND coin_price IS NULL)
    )
);

CREATE TABLE IF NOT EXISTS coin_packages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(80) UNIQUE NOT NULL,
    name VARCHAR(160) NOT NULL,
    description TEXT,
    coin_amount BIGINT NOT NULL CHECK (coin_amount > 0),
    bonus_coin_amount BIGINT NOT NULL DEFAULT 0 CHECK (bonus_coin_amount >= 0),
    price NUMERIC(12,2) NOT NULL CHECK (price > 0),
    currency CHAR(3) NOT NULL DEFAULT 'BOB',
    qr_image_url TEXT,
    coins_expire_after INTERVAL NOT NULL DEFAULT INTERVAL '1 year',
    valid_from TIMESTAMPTZ NOT NULL DEFAULT now(),
    valid_until TIMESTAMPTZ,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS coin_wallets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID UNIQUE NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    available_balance BIGINT NOT NULL DEFAULT 0 CHECK (available_balance >= 0),
    reserved_balance BIGINT NOT NULL DEFAULT 0 CHECK (reserved_balance >= 0),
    lifetime_credited BIGINT NOT NULL DEFAULT 0 CHECK (lifetime_credited >= 0),
    lifetime_spent BIGINT NOT NULL DEFAULT 0 CHECK (lifetime_spent >= 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CHECK (available_balance >= reserved_balance)
);

CREATE TABLE IF NOT EXISTS payment_orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id),
    patient_id UUID REFERENCES patients(id),
    service_id UUID REFERENCES service_catalog(id),
    appointment_id UUID REFERENCES appointments(id),
    emergency_id UUID REFERENCES emergency_events(id),
    related_entity_type VARCHAR(80), -- home_service, coin_package, partner_subscription, delivery, other
    related_entity_id UUID,
    concept TEXT NOT NULL,
    charge_mode VARCHAR(20) NOT NULL, -- coins, fiat
    coin_amount BIGINT CHECK (coin_amount IS NULL OR coin_amount > 0),
    amount NUMERIC(12,2) CHECK (amount IS NULL OR amount > 0),
    currency CHAR(3) NOT NULL DEFAULT 'BOB',
    status payment_status NOT NULL DEFAULT 'pending',
    due_at TIMESTAMPTZ,
    accepted_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT payment_order_charge_chk CHECK (
        (charge_mode = 'coins' AND coin_amount IS NOT NULL AND amount IS NULL)
        OR (charge_mode = 'fiat' AND amount IS NOT NULL AND coin_amount IS NULL)
    )
);

CREATE TABLE IF NOT EXISTS payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    payment_order_id UUID NOT NULL REFERENCES payment_orders(id) ON DELETE CASCADE,
    method payment_method NOT NULL,
    amount NUMERIC(12,2) NOT NULL CHECK (amount >= 0),
    status payment_status NOT NULL DEFAULT 'pending_validation',
    receipt_url TEXT,
    transaction_reference VARCHAR(160),
    stripe_payment_intent_id VARCHAR(120) UNIQUE,
    stripe_checkout_session_id VARCHAR(120) UNIQUE,
    paid_at TIMESTAMPTZ,
    validated_by_user_id UUID REFERENCES users(id),
    validated_at TIMESTAMPTZ,
    rejection_reason TEXT,
    collected_by_professional_id UUID REFERENCES professionals(id),
    collection_context VARCHAR(40), -- in_person_appointment, home_service, coin_package
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS coin_purchases (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id),
    package_id UUID NOT NULL REFERENCES coin_packages(id),
    payment_order_id UUID UNIQUE NOT NULL REFERENCES payment_orders(id),
    payment_id UUID UNIQUE REFERENCES payments(id),
    purchased_coin_amount BIGINT NOT NULL CHECK (purchased_coin_amount > 0),
    bonus_coin_amount BIGINT NOT NULL DEFAULT 0 CHECK (bonus_coin_amount >= 0),
    status VARCHAR(40) NOT NULL DEFAULT 'pending_payment',
    purchased_at TIMESTAMPTZ,
    credited_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS coin_lots (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    wallet_id UUID NOT NULL REFERENCES coin_wallets(id) ON DELETE CASCADE,
    purchase_id UUID REFERENCES coin_purchases(id),
    original_amount BIGINT NOT NULL CHECK (original_amount > 0),
    remaining_amount BIGINT NOT NULL CHECK (remaining_amount >= 0),
    credited_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at TIMESTAMPTZ NOT NULL,
    expired_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CHECK (remaining_amount <= original_amount),
    CHECK (expires_at > credited_at)
);

CREATE TABLE IF NOT EXISTS weekly_free_coin_grants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    wallet_id UUID NOT NULL REFERENCES coin_wallets(id) ON DELETE CASCADE,
    coin_lot_id UUID UNIQUE NOT NULL REFERENCES coin_lots(id) ON DELETE CASCADE,
    week_start DATE NOT NULL,
    coin_amount BIGINT NOT NULL DEFAULT 15 CHECK (coin_amount > 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE(user_id, week_start)
);

CREATE TABLE IF NOT EXISTS coin_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    wallet_id UUID NOT NULL REFERENCES coin_wallets(id) ON DELETE CASCADE,
    transaction_type VARCHAR(40) NOT NULL, -- purchase, bonus, charge, refund, reservation, release, expiration, adjustment
    coin_amount BIGINT NOT NULL CHECK (coin_amount <> 0),
    balance_after BIGINT NOT NULL CHECK (balance_after >= 0),
    payment_order_id UUID REFERENCES payment_orders(id),
    service_id UUID REFERENCES service_catalog(id),
    appointment_id UUID REFERENCES appointments(id),
    emergency_id UUID REFERENCES emergency_events(id),
    related_entity_type VARCHAR(80),
    related_entity_id UUID,
    performed_by_user_id UUID REFERENCES users(id),
    reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS coin_transaction_allocations (
    transaction_id UUID NOT NULL REFERENCES coin_transactions(id) ON DELETE CASCADE,
    coin_lot_id UUID NOT NULL REFERENCES coin_lots(id),
    coin_amount BIGINT NOT NULL CHECK (coin_amount > 0),
    PRIMARY KEY (transaction_id, coin_lot_id)
);

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'ai_voice_sessions_coin_transaction_fk'
    ) THEN
        ALTER TABLE ai_voice_sessions
            ADD CONSTRAINT ai_voice_sessions_coin_transaction_fk
            FOREIGN KEY (coin_transaction_id) REFERENCES coin_transactions(id);
    END IF;
END $$;

CREATE TABLE IF NOT EXISTS payment_incidents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    payment_id UUID NOT NULL REFERENCES payments(id) ON DELETE CASCADE,
    reported_by_user_id UUID NOT NULL REFERENCES users(id),
    incident_type VARCHAR(60) NOT NULL, -- amount_difference, duplicate, failed, other
    reported_amount NUMERIC(12,2),
    expected_amount NUMERIC(12,2),
    description TEXT NOT NULL,
    status VARCHAR(40) NOT NULL DEFAULT 'open',
    resolved_by_user_id UUID REFERENCES users(id),
    resolution TEXT,
    resolved_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS refunds (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    payment_id UUID NOT NULL REFERENCES payments(id),
    requested_by_user_id UUID REFERENCES users(id),
    approved_by_user_id UUID REFERENCES users(id),
    amount NUMERIC(12,2) NOT NULL CHECK (amount > 0),
    reason TEXT NOT NULL,
    status VARCHAR(40) NOT NULL DEFAULT 'pending',
    requested_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    processed_at TIMESTAMPTZ
);

CREATE TABLE IF NOT EXISTS benefits (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(80) UNIQUE NOT NULL,
    name VARCHAR(180) NOT NULL,
    description TEXT,
    discount_percent NUMERIC(5,2),
    discount_amount NUMERIC(12,2),
    discount_coin_amount BIGINT,
    benefit_type VARCHAR(40) NOT NULL DEFAULT 'promotion',
    max_uses_per_user INT,
    max_total_uses INT,
    is_stackable BOOLEAN NOT NULL DEFAULT FALSE,
    funded_by VARCHAR(40) NOT NULL DEFAULT 'platform',
    valid_from DATE,
    valid_until DATE,
    conditions JSONB NOT NULL DEFAULT '{}'::jsonb,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS benefit_usages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    benefit_id UUID NOT NULL REFERENCES benefits(id),
    patient_id UUID NOT NULL REFERENCES patients(id),
    payment_order_id UUID REFERENCES payment_orders(id),
    discount_applied NUMERIC(12,2) NOT NULL DEFAULT 0,
    coin_discount_applied BIGINT NOT NULL DEFAULT 0,
    status VARCHAR(40) NOT NULL DEFAULT 'applied',
    used_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================
-- PROVEEDORES ALIADOS / LABORATORIOS / IMAGENOLOGÍA / FARMACIAS
-- Modelo genérico. Farmacia y entregas profundas pueden ir a fase 2.
-- ============================================================

CREATE TABLE IF NOT EXISTS health_partners (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(180) NOT NULL,
    partner_type VARCHAR(80) NOT NULL, -- laboratory, imaging, clinic, hospital, pharmacy, ambulance, other
    tax_id VARCHAR(80),
    phone VARCHAR(40),
    email CITEXT,
    address TEXT,
    latitude NUMERIC(10,7),
    longitude NUMERIC(10,7),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Los planes pertenecen exclusivamente a empresas asociadas.
CREATE TABLE IF NOT EXISTS partner_subscription_plans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(80) UNIQUE NOT NULL,
    name VARCHAR(160) NOT NULL,
    description TEXT,
    billing_period VARCHAR(20) NOT NULL DEFAULT 'monthly',
    price NUMERIC(12,2) NOT NULL CHECK (price >= 0),
    currency CHAR(3) NOT NULL DEFAULT 'BOB',
    features JSONB NOT NULL DEFAULT '{}'::jsonb,
    limits JSONB NOT NULL DEFAULT '{}'::jsonb,
    discount_percent NUMERIC(5,2) NOT NULL DEFAULT 0 CHECK (discount_percent BETWEEN 0 AND 100),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS partner_plan_benefits (
    plan_id UUID NOT NULL REFERENCES partner_subscription_plans(id) ON DELETE CASCADE,
    benefit_id UUID NOT NULL REFERENCES benefits(id) ON DELETE CASCADE,
    usage_limit NUMERIC(12,2),
    period VARCHAR(30),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (plan_id, benefit_id)
);

CREATE TABLE IF NOT EXISTS partner_subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    partner_id UUID NOT NULL REFERENCES health_partners(id) ON DELETE CASCADE,
    plan_id UUID NOT NULL REFERENCES partner_subscription_plans(id),
    payment_order_id UUID REFERENCES payment_orders(id),
    status VARCHAR(40) NOT NULL DEFAULT 'pending_payment',
    starts_at TIMESTAMPTZ,
    ends_at TIMESTAMPTZ,
    auto_renew BOOLEAN NOT NULL DEFAULT FALSE,
    cancelled_at TIMESTAMPTZ,
    cancellation_reason TEXT,
    grace_period_ends_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS partner_subscription_usage (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    subscription_id UUID NOT NULL REFERENCES partner_subscriptions(id) ON DELETE CASCADE,
    feature_code VARCHAR(80) NOT NULL,
    period_start DATE NOT NULL,
    period_end DATE NOT NULL,
    used_quantity NUMERIC(12,2) NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (subscription_id, feature_code, period_start)
);

CREATE TABLE IF NOT EXISTS partner_users (
    partner_id UUID NOT NULL REFERENCES health_partners(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    partner_role VARCHAR(60) NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    PRIMARY KEY (partner_id, user_id)
);

CREATE TABLE IF NOT EXISTS partner_documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    partner_id UUID NOT NULL REFERENCES health_partners(id) ON DELETE CASCADE,
    document_type VARCHAR(80) NOT NULL,
    document_number VARCHAR(120),
    file_url TEXT NOT NULL,
    valid_until DATE,
    status professional_verification_status NOT NULL DEFAULT 'pending',
    reviewed_by_user_id UUID REFERENCES users(id),
    reviewed_at TIMESTAMPTZ,
    observation TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS operating_sites (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    partner_id UUID REFERENCES health_partners(id) ON DELETE CASCADE,
    code VARCHAR(80) UNIQUE NOT NULL,
    name VARCHAR(180) NOT NULL,
    site_type VARCHAR(60) NOT NULL,
    address TEXT,
    latitude NUMERIC(10,7),
    longitude NUMERIC(10,7),
    phone VARCHAR(40),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS coverage_zones (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    site_id UUID REFERENCES operating_sites(id) ON DELETE CASCADE,
    partner_id UUID REFERENCES health_partners(id) ON DELETE CASCADE,
    name VARCHAR(180) NOT NULL,
    municipality VARCHAR(120),
    polygon_geojson JSONB,
    service_radius_km NUMERIC(8,2),
    regular_hours JSONB NOT NULL DEFAULT '{}'::jsonb,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS partner_catalog_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    partner_id UUID NOT NULL REFERENCES health_partners(id) ON DELETE CASCADE,
    service_id UUID REFERENCES service_catalog(id),
    item_type VARCHAR(40) NOT NULL, -- product, medication, supply, service
    sku VARCHAR(100),
    name VARCHAR(180) NOT NULL,
    description TEXT,
    price NUMERIC(12,2) NOT NULL CHECK (price >= 0),
    stock_quantity NUMERIC(12,2),
    requires_prescription BOOLEAN NOT NULL DEFAULT FALSE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (partner_id, sku)
);

CREATE TABLE IF NOT EXISTS partner_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id UUID NOT NULL REFERENCES patients(id),
    requested_by_user_id UUID NOT NULL REFERENCES users(id),
    partner_id UUID REFERENCES health_partners(id),
    prescription_id UUID REFERENCES prescriptions(id),
    status generic_request_status NOT NULL DEFAULT 'draft',
    notes TEXT,
    confirmed_at TIMESTAMPTZ,
    partner_response_at TIMESTAMPTZ,
    rejection_reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS partner_request_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    request_id UUID NOT NULL REFERENCES partner_requests(id) ON DELETE CASCADE,
    catalog_item_id UUID REFERENCES partner_catalog_items(id),
    prescription_item_id UUID REFERENCES prescription_items(id),
    description TEXT NOT NULL,
    quantity NUMERIC(12,2) NOT NULL DEFAULT 1 CHECK (quantity > 0),
    unit_price NUMERIC(12,2) CHECK (unit_price >= 0),
    availability_status VARCHAR(40) NOT NULL DEFAULT 'pending'
);

CREATE TABLE IF NOT EXISTS partner_benefits (
    partner_id UUID NOT NULL REFERENCES health_partners(id) ON DELETE CASCADE,
    benefit_id UUID NOT NULL REFERENCES benefits(id) ON DELETE CASCADE,
    validation_required BOOLEAN NOT NULL DEFAULT TRUE,
    settlement_terms JSONB NOT NULL DEFAULT '{}'::jsonb,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    PRIMARY KEY (partner_id, benefit_id)
);

CREATE TABLE IF NOT EXISTS benefit_validations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    benefit_usage_id UUID NOT NULL REFERENCES benefit_usages(id) ON DELETE CASCADE,
    partner_id UUID NOT NULL REFERENCES health_partners(id),
    validated_by_user_id UUID REFERENCES users(id),
    status VARCHAR(40) NOT NULL DEFAULT 'pending',
    reason TEXT,
    validated_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS home_service_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id UUID NOT NULL REFERENCES patients(id),
    requested_by_user_id UUID NOT NULL REFERENCES users(id),
    service_id UUID NOT NULL REFERENCES service_catalog(id),
    address_id UUID NOT NULL REFERENCES addresses(id),
    coverage_zone_id UUID REFERENCES coverage_zones(id),
    assigned_professional_id UUID REFERENCES professionals(id),
    assigned_partner_id UUID REFERENCES health_partners(id),
    status generic_request_status NOT NULL DEFAULT 'pending',
    requested_for TIMESTAMPTZ,
    accepted_at TIMESTAMPTZ,
    rejected_at TIMESTAMPTZ,
    rejection_reason TEXT,
    on_route_at TIMESTAMPTZ,
    arrived_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    clinical_notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS service_status_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    home_service_id UUID NOT NULL REFERENCES home_service_requests(id) ON DELETE CASCADE,
    old_status generic_request_status,
    new_status generic_request_status NOT NULL,
    changed_by_user_id UUID REFERENCES users(id),
    reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS realtime_locations (
    id BIGSERIAL PRIMARY KEY,
    professional_id UUID NOT NULL REFERENCES professionals(id),
    home_service_id UUID REFERENCES home_service_requests(id) ON DELETE CASCADE,
    emergency_id UUID REFERENCES emergency_events(id) ON DELETE CASCADE,
    latitude NUMERIC(10,7) NOT NULL,
    longitude NUMERIC(10,7) NOT NULL,
    accuracy_m NUMERIC(10,2),
    recorded_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CHECK (home_service_id IS NOT NULL OR emergency_id IS NOT NULL)
);

CREATE TABLE IF NOT EXISTS service_evidence (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    home_service_id UUID NOT NULL REFERENCES home_service_requests(id) ON DELETE CASCADE,
    uploaded_by_user_id UUID NOT NULL REFERENCES users(id),
    evidence_type VARCHAR(60) NOT NULL,
    file_url TEXT NOT NULL,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS home_service_ratings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    home_service_id UUID UNIQUE NOT NULL REFERENCES home_service_requests(id) ON DELETE CASCADE,
    patient_id UUID NOT NULL REFERENCES patients(id),
    professional_id UUID REFERENCES professionals(id),
    rating SMALLINT NOT NULL CHECK (rating BETWEEN 1 AND 5),
    comment TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS deliveries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    partner_request_id UUID NOT NULL REFERENCES partner_requests(id),
    assigned_professional_id UUID REFERENCES professionals(id),
    delivery_address_id UUID NOT NULL REFERENCES addresses(id),
    recipient_user_id UUID REFERENCES users(id),
    status delivery_status NOT NULL DEFAULT 'available',
    delivery_fee NUMERIC(12,2) NOT NULL DEFAULT 0 CHECK (delivery_fee >= 0),
    accepted_at TIMESTAMPTZ,
    picked_up_at TIMESTAMPTZ,
    delivered_at TIMESTAMPTZ,
    failed_at TIMESTAMPTZ,
    failure_reason TEXT,
    retry_count SMALLINT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS delivery_status_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    delivery_id UUID NOT NULL REFERENCES deliveries(id) ON DELETE CASCADE,
    old_status delivery_status,
    new_status delivery_status NOT NULL,
    changed_by_user_id UUID REFERENCES users(id),
    reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS delivery_evidence (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    delivery_id UUID NOT NULL REFERENCES deliveries(id) ON DELETE CASCADE,
    uploaded_by_user_id UUID NOT NULL REFERENCES users(id),
    evidence_type VARCHAR(60) NOT NULL,
    file_url TEXT NOT NULL,
    recipient_document_verified BOOLEAN NOT NULL DEFAULT FALSE,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS diagnostic_orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    patient_id UUID NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
    requested_by_professional_id UUID NOT NULL REFERENCES professionals(id),
    partner_id UUID REFERENCES health_partners(id),
    appointment_id UUID REFERENCES appointments(id),
    order_type VARCHAR(80) NOT NULL, -- lab, imaging, other
    description TEXT NOT NULL,
    status VARCHAR(40) NOT NULL DEFAULT 'requested',
    result_document_id UUID REFERENCES clinical_documents(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    completed_at TIMESTAMPTZ
);

-- ============================================================
-- INCIDENTES
-- ============================================================

CREATE TABLE IF NOT EXISTS incidents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reported_by_user_id UUID REFERENCES users(id),
    patient_id UUID REFERENCES patients(id),
    module VARCHAR(80) NOT NULL,
    incident_type VARCHAR(80) NOT NULL,
    severity risk_level NOT NULL DEFAULT 'yellow',
    description TEXT NOT NULL,
    status VARCHAR(40) NOT NULL DEFAULT 'open',
    resolution TEXT,
    resolved_by_user_id UUID REFERENCES users(id),
    resolved_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================
-- RECURSOS HUMANOS
-- ============================================================

CREATE TABLE IF NOT EXISTS personnel_applications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    applicant_user_id UUID NOT NULL REFERENCES users(id),
    requested_role_code VARCHAR(60) NOT NULL,
    license_number VARCHAR(100),
    requested_specialty VARCHAR(160),
    status VARCHAR(40) NOT NULL DEFAULT 'pending',
    submitted_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    reviewed_by_user_id UUID REFERENCES users(id),
    reviewed_at TIMESTAMPTZ,
    rejection_reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS personnel_documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    application_id UUID REFERENCES personnel_applications(id) ON DELETE CASCADE,
    professional_id UUID REFERENCES professionals(id) ON DELETE CASCADE,
    document_type VARCHAR(80) NOT NULL,
    file_url TEXT NOT NULL,
    valid_until DATE,
    status VARCHAR(40) NOT NULL DEFAULT 'pending',
    reviewed_by_user_id UUID REFERENCES users(id),
    reviewed_at TIMESTAMPTZ,
    observation TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CHECK (application_id IS NOT NULL OR professional_id IS NOT NULL)
);

CREATE TABLE IF NOT EXISTS employment_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    professional_id UUID UNIQUE NOT NULL REFERENCES professionals(id),
    employee_code VARCHAR(80) UNIQUE,
    contract_type VARCHAR(60),
    hired_at DATE,
    ended_at DATE,
    status VARCHAR(40) NOT NULL DEFAULT 'active',
    metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS personnel_observations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    professional_id UUID NOT NULL REFERENCES professionals(id),
    registered_by_user_id UUID NOT NULL REFERENCES users(id),
    observation_type VARCHAR(60) NOT NULL,
    description TEXT NOT NULL,
    action_taken TEXT,
    is_confidential BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================
-- NOTIFICACIONES Y CONFIGURACIÓN OPERATIVA
-- ============================================================

CREATE TABLE IF NOT EXISTS notification_preferences (
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    event_code VARCHAR(100) NOT NULL,
    channel notification_channel NOT NULL,
    enabled BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, event_code, channel)
);

CREATE TABLE IF NOT EXISTS notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    event_code VARCHAR(100) NOT NULL,
    channel notification_channel NOT NULL,
    title TEXT NOT NULL,
    body TEXT NOT NULL,
    related_entity_type VARCHAR(80),
    related_entity_id UUID,
    status VARCHAR(40) NOT NULL DEFAULT 'pending',
    sent_at TIMESTAMPTZ,
    read_at TIMESTAMPTZ,
    failure_reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS notification_push_outbox (
    notification_id UUID PRIMARY KEY REFERENCES notifications(id) ON DELETE CASCADE,
    attempts INT NOT NULL DEFAULT 0,
    available_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    processed_at TIMESTAMPTZ,
    last_error TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_notification_push_outbox_pending
ON notification_push_outbox(available_at, created_at)
WHERE processed_at IS NULL;

CREATE TABLE IF NOT EXISTS push_device_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token TEXT UNIQUE NOT NULL,
    platform VARCHAR(20) NOT NULL DEFAULT 'unknown',
    device_id VARCHAR(160),
    app_version VARCHAR(40),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    last_seen_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS system_settings (
    setting_key VARCHAR(120) PRIMARY KEY,
    value JSONB NOT NULL,
    description TEXT,
    requires_clinical_approval BOOLEAN NOT NULL DEFAULT FALSE,
    updated_by_user_id UUID REFERENCES users(id),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS business_rules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(120) UNIQUE NOT NULL,
    domain VARCHAR(80) NOT NULL,
    name VARCHAR(180) NOT NULL,
    configuration JSONB NOT NULL,
    version INT NOT NULL DEFAULT 1,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    requires_clinical_approval BOOLEAN NOT NULL DEFAULT FALSE,
    approved_by_professional_id UUID REFERENCES professionals(id),
    approved_at TIMESTAMPTZ,
    valid_from TIMESTAMPTZ NOT NULL DEFAULT now(),
    valid_until TIMESTAMPTZ,
    created_by_user_id UUID NOT NULL REFERENCES users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS business_rule_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_rule_id UUID NOT NULL REFERENCES business_rules(id) ON DELETE CASCADE,
    changed_by_user_id UUID NOT NULL REFERENCES users(id),
    old_configuration JSONB,
    new_configuration JSONB NOT NULL,
    reason TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================
-- AUDITORÍA TRANSVERSAL
-- ============================================================

CREATE TABLE IF NOT EXISTS audit_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    actor_user_id UUID REFERENCES users(id),
    actor_role VARCHAR(80),
    patient_id UUID REFERENCES patients(id),
    module VARCHAR(80) NOT NULL,
    action VARCHAR(120) NOT NULL,
    entity_type VARCHAR(120),
    entity_id UUID,
    old_values JSONB,
    new_values JSONB,
    reason TEXT,
    ip_address INET,
    user_agent TEXT,
    location JSONB,
    fhir_audit_event JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS clinical_access_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    actor_user_id UUID REFERENCES users(id),
    actor_role VARCHAR(80),
    patient_id UUID NOT NULL REFERENCES patients(id) ON DELETE CASCADE,
    section VARCHAR(120) NOT NULL,
    purpose TEXT,
    access_granted BOOLEAN NOT NULL DEFAULT TRUE,
    denial_reason TEXT,
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================
-- CREDENCIALES OAUTH DE INTEGRACIONES EXTERNAS
-- ============================================================

CREATE TABLE IF NOT EXISTS oauth_authorization_states (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    provider VARCHAR(40) NOT NULL,
    state_hash VARCHAR(64) UNIQUE NOT NULL,
    created_by_user_id UUID NOT NULL REFERENCES users(id),
    expires_at TIMESTAMPTZ NOT NULL,
    used_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS external_oauth_credentials (
    provider VARCHAR(40) PRIMARY KEY,
    access_token_encrypted TEXT NOT NULL,
    refresh_token_encrypted TEXT,
    expires_at TIMESTAMPTZ NOT NULL,
    connected_by_user_id UUID NOT NULL REFERENCES users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================
-- ÍNDICES
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_users_role_id ON users(role_id);
CREATE INDEX IF NOT EXISTS idx_registration_tokens_email_expiry ON registration_email_tokens(email, expires_at DESC);
CREATE INDEX IF NOT EXISTS idx_user_roles_user_active ON user_roles(user_id, revoked_at);
CREATE INDEX IF NOT EXISTS idx_users_status ON users(status);
CREATE INDEX IF NOT EXISTS idx_persons_document ON persons(document_type, document_number);
CREATE INDEX IF NOT EXISTS idx_patients_person_id ON patients(person_id);
CREATE INDEX IF NOT EXISTS idx_clinical_records_patient_type ON clinical_records(patient_id, record_type);
CREATE INDEX IF NOT EXISTS idx_vital_signs_patient_recorded ON vital_signs(patient_id, recorded_at DESC);
CREATE INDEX IF NOT EXISTS idx_emergency_patient_status ON emergency_events(patient_id, status);
CREATE INDEX IF NOT EXISTS idx_emergency_status ON emergency_events(status);
CREATE INDEX IF NOT EXISTS idx_appointments_patient_start ON appointments(patient_id, start_at DESC);
CREATE INDEX IF NOT EXISTS idx_appointments_professional_start ON appointments(professional_id, start_at DESC);
CREATE INDEX IF NOT EXISTS idx_ai_conversations_patient ON ai_conversations(patient_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_payment_orders_user_status ON payment_orders(user_id, status);
CREATE INDEX IF NOT EXISTS idx_coin_wallets_user ON coin_wallets(user_id);
CREATE INDEX IF NOT EXISTS idx_coin_lots_wallet_expiry ON coin_lots(wallet_id, expires_at) WHERE remaining_amount > 0;
CREATE INDEX IF NOT EXISTS idx_coin_transactions_wallet_time ON coin_transactions(wallet_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_coin_purchases_user_status ON coin_purchases(user_id, status);
CREATE INDEX IF NOT EXISTS idx_partner_subscriptions_partner_status ON partner_subscriptions(partner_id, status);
CREATE INDEX IF NOT EXISTS idx_audit_events_module_action ON audit_events(module, action);
CREATE INDEX IF NOT EXISTS idx_audit_events_entity ON audit_events(entity_type, entity_id);
CREATE INDEX IF NOT EXISTS idx_clinical_access_patient ON clinical_access_logs(patient_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_work_shifts_professional_start ON work_shifts(professional_id, start_at DESC);
CREATE INDEX IF NOT EXISTS idx_home_services_status_requested ON home_service_requests(status, requested_for);
CREATE INDEX IF NOT EXISTS idx_realtime_locations_service_time ON realtime_locations(home_service_id, recorded_at DESC);
CREATE INDEX IF NOT EXISTS idx_realtime_locations_emergency_time ON realtime_locations(emergency_id, recorded_at DESC);
CREATE INDEX IF NOT EXISTS idx_partner_requests_partner_status ON partner_requests(partner_id, status);
CREATE INDEX IF NOT EXISTS idx_deliveries_status ON deliveries(status, created_at);
CREATE INDEX IF NOT EXISTS idx_notifications_user_status ON notifications(user_id, status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_push_device_tokens_user_active ON push_device_tokens(user_id, is_active, last_seen_at DESC);

-- Índices GIN para búsquedas JSONB
CREATE INDEX IF NOT EXISTS idx_clinical_records_content_gin ON clinical_records USING GIN (content);
CREATE INDEX IF NOT EXISTS idx_audit_old_values_gin ON audit_events USING GIN (old_values);
CREATE INDEX IF NOT EXISTS idx_audit_new_values_gin ON audit_events USING GIN (new_values);

-- ============================================================

-- ============================================================
-- FIN ESTRUCTURA
-- ============================================================



-- Atención contextual de emergencias y signos profesionales.
ALTER TABLE emergency_events ADD COLUMN IF NOT EXISTS accepted_at TIMESTAMPTZ;
ALTER TABLE emergency_care_records ADD COLUMN IF NOT EXISTS content JSONB NOT NULL DEFAULT '{}'::jsonb;
ALTER TABLE vital_signs ADD COLUMN IF NOT EXISTS related_appointment_id UUID REFERENCES appointments(id);
ALTER TABLE vital_signs ADD COLUMN IF NOT EXISTS related_emergency_id UUID REFERENCES emergency_events(id);
CREATE TABLE IF NOT EXISTS emergency_assignment_decisions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  emergency_id UUID NOT NULL REFERENCES emergency_events(id),
  professional_id UUID NOT NULL REFERENCES professionals(id),
  decision VARCHAR(20) NOT NULL CHECK(decision IN ('accepted','rejected')),
  reason TEXT, created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK(decision<>'rejected' OR COALESCE(length(trim(reason)),0)>=3)
);


ALTER TABLE work_shifts ADD COLUMN IF NOT EXISTS area_text VARCHAR(160);

ALTER TABLE family_authorizations ADD COLUMN IF NOT EXISTS valid_from TIMESTAMPTZ NOT NULL DEFAULT now();
ALTER TABLE family_authorizations ADD COLUMN IF NOT EXISTS valid_until TIMESTAMPTZ;


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

ALTER TABLE professionals ADD COLUMN IF NOT EXISTS academic_background TEXT;
ALTER TABLE professionals ADD COLUMN IF NOT EXISTS public_certifications TEXT[] NOT NULL DEFAULT '{}';
ALTER TABLE appointment_ratings ADD COLUMN IF NOT EXISTS public_comment BOOLEAN NOT NULL DEFAULT FALSE;


ALTER TABLE clinical_records ADD COLUMN IF NOT EXISTS patient_visible BOOLEAN NOT NULL DEFAULT TRUE;

ALTER TABLE benefits ADD COLUMN IF NOT EXISTS requires_profile_reward BOOLEAN NOT NULL DEFAULT FALSE;
