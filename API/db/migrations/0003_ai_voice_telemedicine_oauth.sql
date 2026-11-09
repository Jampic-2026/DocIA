-- Backfill AI voice, telemedicine, and Google Meet OAuth tables for databases
-- created before these modules were added to the consolidated base schema.

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
    sender VARCHAR(20) NOT NULL,
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
    recommended_action VARCHAR(120),
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
    event_type VARCHAR(60) NOT NULL,
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

CREATE INDEX IF NOT EXISTS idx_ai_conversations_patient
ON ai_conversations(patient_id, created_at DESC);

DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.tables
        WHERE table_name = 'coin_transactions'
    ) AND NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'ai_voice_sessions_coin_transaction_fk'
    ) THEN
        ALTER TABLE ai_voice_sessions
            ADD CONSTRAINT ai_voice_sessions_coin_transaction_fk
            FOREIGN KEY (coin_transaction_id) REFERENCES coin_transactions(id);
    END IF;
END $$;

ALTER TABLE ai_conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_risk_assessments ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_voice_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE telemedicine_rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE telemedicine_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE telemedicine_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE telemedicine_shared_files ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS ai_conversations_patient_manage ON ai_conversations;
CREATE POLICY ai_conversations_patient_manage ON ai_conversations
FOR ALL USING (
    created_by_user_id = app_current_user_id()
) WITH CHECK (
    created_by_user_id = app_current_user_id()
    AND EXISTS (
        SELECT 1
        FROM patients patient
        JOIN persons person ON person.id = patient.person_id
        WHERE patient.id = ai_conversations.patient_id
          AND person.user_id = app_current_user_id()
    )
);

DROP POLICY IF EXISTS ai_messages_patient_manage ON ai_messages;
CREATE POLICY ai_messages_patient_manage ON ai_messages
FOR ALL USING (
    EXISTS (
        SELECT 1 FROM ai_conversations conversation
        WHERE conversation.id = ai_messages.conversation_id
          AND conversation.created_by_user_id = app_current_user_id()
    )
) WITH CHECK (
    EXISTS (
        SELECT 1 FROM ai_conversations conversation
        WHERE conversation.id = ai_messages.conversation_id
          AND conversation.created_by_user_id = app_current_user_id()
    )
);

DROP POLICY IF EXISTS ai_risk_patient_manage ON ai_risk_assessments;
CREATE POLICY ai_risk_patient_manage ON ai_risk_assessments
FOR ALL USING (
    EXISTS (
        SELECT 1 FROM ai_conversations conversation
        WHERE conversation.id = ai_risk_assessments.conversation_id
          AND conversation.created_by_user_id = app_current_user_id()
    )
) WITH CHECK (
    EXISTS (
        SELECT 1 FROM ai_conversations conversation
        WHERE conversation.id = ai_risk_assessments.conversation_id
          AND conversation.created_by_user_id = app_current_user_id()
    )
);

DROP POLICY IF EXISTS ai_voice_sessions_patient_manage ON ai_voice_sessions;
CREATE POLICY ai_voice_sessions_patient_manage ON ai_voice_sessions
FOR ALL USING (
    user_id = app_current_user_id()
) WITH CHECK (
    user_id = app_current_user_id()
);

DROP POLICY IF EXISTS telemedicine_rooms_authorized_select ON telemedicine_rooms;
CREATE POLICY telemedicine_rooms_authorized_select ON telemedicine_rooms
FOR SELECT USING (
    EXISTS (
        SELECT 1
        FROM appointments appointment
        JOIN patients patient ON patient.id = appointment.patient_id
        JOIN persons patient_person ON patient_person.id = patient.person_id
        JOIN professionals professional ON professional.id = appointment.professional_id
        WHERE appointment.id = telemedicine_rooms.appointment_id
          AND (
              patient_person.user_id = app_current_user_id()
              OR professional.user_id = app_current_user_id()
              OR app_has_role('admin')
              OR app_has_role('operator')
          )
    )
);

DROP POLICY IF EXISTS telemedicine_rooms_staff_insert ON telemedicine_rooms;
CREATE POLICY telemedicine_rooms_staff_insert ON telemedicine_rooms
FOR INSERT WITH CHECK (
    EXISTS (
        SELECT 1
        FROM appointments appointment
        JOIN professionals professional ON professional.id = appointment.professional_id
        WHERE appointment.id = telemedicine_rooms.appointment_id
          AND (
              professional.user_id = app_current_user_id()
              OR app_has_role('admin')
              OR app_has_role('operator')
          )
    )
);

DROP POLICY IF EXISTS telemedicine_participants_authorized ON telemedicine_participants;
CREATE POLICY telemedicine_participants_authorized ON telemedicine_participants
FOR ALL USING (
    user_id = app_current_user_id()
    OR app_has_role('admin')
    OR app_has_role('operator')
) WITH CHECK (
    user_id = app_current_user_id()
    OR app_has_role('admin')
    OR app_has_role('operator')
    OR EXISTS (
        SELECT 1
        FROM telemedicine_rooms room
        JOIN appointments appointment ON appointment.id = room.appointment_id
        JOIN professionals professional ON professional.id = appointment.professional_id
        WHERE room.id = telemedicine_participants.room_id
          AND professional.user_id = app_current_user_id()
    )
);

DROP POLICY IF EXISTS telemedicine_events_participant_insert ON telemedicine_events;
CREATE POLICY telemedicine_events_participant_insert ON telemedicine_events
FOR INSERT WITH CHECK (
    user_id = app_current_user_id()
    AND EXISTS (
        SELECT 1
        FROM telemedicine_participants participant
        WHERE participant.room_id = telemedicine_events.room_id
          AND participant.user_id = app_current_user_id()
    )
);

DROP POLICY IF EXISTS telemedicine_participants_room_select ON telemedicine_participants;
CREATE POLICY telemedicine_participants_room_select ON telemedicine_participants
FOR SELECT USING (EXISTS (
    SELECT 1 FROM telemedicine_rooms room
    JOIN appointments appointment ON appointment.id = room.appointment_id
    JOIN patients patient ON patient.id = appointment.patient_id
    JOIN persons patient_person ON patient_person.id = patient.person_id
    JOIN professionals professional ON professional.id = appointment.professional_id
    WHERE room.id = telemedicine_participants.room_id
      AND (patient_person.user_id = app_current_user_id()
        OR professional.user_id = app_current_user_id())
));

DROP POLICY IF EXISTS telemedicine_events_room_select ON telemedicine_events;
CREATE POLICY telemedicine_events_room_select ON telemedicine_events
FOR SELECT USING (EXISTS (
    SELECT 1 FROM telemedicine_rooms room
    JOIN appointments appointment ON appointment.id = room.appointment_id
    JOIN patients patient ON patient.id = appointment.patient_id
    JOIN persons patient_person ON patient_person.id = patient.person_id
    JOIN professionals professional ON professional.id = appointment.professional_id
    WHERE room.id = telemedicine_events.room_id
      AND (patient_person.user_id = app_current_user_id()
        OR professional.user_id = app_current_user_id())
));

DROP POLICY IF EXISTS telemedicine_shared_files_room_select ON telemedicine_shared_files;
CREATE POLICY telemedicine_shared_files_room_select ON telemedicine_shared_files
FOR SELECT USING (EXISTS (
    SELECT 1 FROM telemedicine_rooms room
    JOIN appointments appointment ON appointment.id = room.appointment_id
    WHERE room.id = telemedicine_shared_files.room_id
      AND app_can_read_patient(appointment.patient_id)
));

DROP POLICY IF EXISTS telemedicine_shared_files_participant_insert ON telemedicine_shared_files;
CREATE POLICY telemedicine_shared_files_participant_insert ON telemedicine_shared_files
FOR INSERT WITH CHECK (shared_by_user_id = app_current_user_id() AND EXISTS (
    SELECT 1 FROM telemedicine_participants participant
    WHERE participant.room_id = telemedicine_shared_files.room_id
      AND participant.user_id = app_current_user_id()
));

REVOKE ALL ON oauth_authorization_states FROM PUBLIC;
REVOKE ALL ON external_oauth_credentials FROM PUBLIC;
