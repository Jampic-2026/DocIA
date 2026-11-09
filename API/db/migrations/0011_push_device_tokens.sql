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

CREATE INDEX IF NOT EXISTS idx_push_device_tokens_user_active
ON push_device_tokens(user_id, is_active, last_seen_at DESC);

ALTER TABLE push_device_tokens ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS push_device_tokens_own_select ON push_device_tokens;
CREATE POLICY push_device_tokens_own_select
ON push_device_tokens
FOR SELECT USING (
    user_id = app_current_user_id()
    OR app_has_permission('notifications.manage')
);

DROP POLICY IF EXISTS push_device_tokens_own_insert ON push_device_tokens;
CREATE POLICY push_device_tokens_own_insert
ON push_device_tokens
FOR INSERT WITH CHECK (user_id = app_current_user_id());

DROP POLICY IF EXISTS push_device_tokens_own_update ON push_device_tokens;
CREATE POLICY push_device_tokens_own_update
ON push_device_tokens
FOR UPDATE USING (
    user_id = app_current_user_id()
) WITH CHECK (
    user_id = app_current_user_id()
);
