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

DROP TRIGGER IF EXISTS trg_enqueue_notification_push ON notifications;
CREATE TRIGGER trg_enqueue_notification_push
AFTER INSERT ON notifications
FOR EACH ROW EXECUTE FUNCTION enqueue_notification_push();

DROP TRIGGER IF EXISTS trg_apply_notification_preference ON notifications;
CREATE TRIGGER trg_apply_notification_preference
BEFORE INSERT ON notifications
FOR EACH ROW EXECUTE FUNCTION apply_notification_preference();
