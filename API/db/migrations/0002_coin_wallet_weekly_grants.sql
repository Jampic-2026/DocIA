-- Agrega el sistema de billetera, lotes y monedas gratuitas semanales
-- para bases existentes creadas antes del cobro por IA.
CREATE TABLE IF NOT EXISTS coin_packages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(80) UNIQUE NOT NULL,
    name VARCHAR(160) NOT NULL,
    description TEXT,
    coin_amount BIGINT NOT NULL CHECK (coin_amount > 0),
    bonus_coin_amount BIGINT NOT NULL DEFAULT 0 CHECK (bonus_coin_amount >= 0),
    price NUMERIC(12,2) NOT NULL CHECK (price > 0),
    currency CHAR(3) NOT NULL DEFAULT 'BOB',
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
    transaction_type VARCHAR(40) NOT NULL,
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

CREATE INDEX IF NOT EXISTS idx_coin_wallets_user ON coin_wallets(user_id);
CREATE INDEX IF NOT EXISTS idx_coin_lots_wallet_expiry
    ON coin_lots(wallet_id, expires_at)
    WHERE remaining_amount > 0;
CREATE INDEX IF NOT EXISTS idx_coin_transactions_wallet_time
    ON coin_transactions(wallet_id, created_at DESC);

ALTER TABLE coin_wallets ENABLE ROW LEVEL SECURITY;
ALTER TABLE coin_lots ENABLE ROW LEVEL SECURITY;
ALTER TABLE weekly_free_coin_grants ENABLE ROW LEVEL SECURITY;
ALTER TABLE coin_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE coin_transaction_allocations ENABLE ROW LEVEL SECURITY;
ALTER TABLE coin_purchases ENABLE ROW LEVEL SECURITY;
ALTER TABLE coin_packages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS coin_packages_active_select ON coin_packages;
CREATE POLICY coin_packages_active_select ON coin_packages
FOR SELECT USING (
    is_active
    OR app_has_role('admin')
    OR app_has_permission('coins.manage')
);

DROP POLICY IF EXISTS coin_packages_manage_insert ON coin_packages;
CREATE POLICY coin_packages_manage_insert ON coin_packages
FOR INSERT WITH CHECK (
    app_has_role('admin') OR app_has_permission('coins.manage')
);

DROP POLICY IF EXISTS coin_packages_manage_update ON coin_packages;
CREATE POLICY coin_packages_manage_update ON coin_packages
FOR UPDATE USING (
    app_has_role('admin') OR app_has_permission('coins.manage')
)
WITH CHECK (
    app_has_role('admin') OR app_has_permission('coins.manage')
);

DROP POLICY IF EXISTS coin_wallets_self_or_admin ON coin_wallets;
CREATE POLICY coin_wallets_self_or_admin ON coin_wallets
FOR ALL
USING (
    user_id = app_current_user_id()
    OR app_has_role('admin')
    OR app_has_permission('coins.manage')
    OR app_has_permission('payments.manage')
)
WITH CHECK (
    user_id = app_current_user_id()
    OR app_has_role('admin')
    OR app_has_permission('coins.manage')
    OR app_has_permission('payments.manage')
);

DROP POLICY IF EXISTS coin_lots_self_or_admin ON coin_lots;
CREATE POLICY coin_lots_self_or_admin ON coin_lots
FOR ALL
USING (
    EXISTS (
        SELECT 1 FROM coin_wallets cw
        WHERE cw.id = coin_lots.wallet_id
          AND (
              cw.user_id = app_current_user_id()
              OR app_has_role('admin')
              OR app_has_permission('coins.manage')
              OR app_has_permission('payments.manage')
          )
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1 FROM coin_wallets cw
        WHERE cw.id = coin_lots.wallet_id
          AND (
              cw.user_id = app_current_user_id()
              OR app_has_role('admin')
              OR app_has_permission('coins.manage')
              OR app_has_permission('payments.manage')
          )
    )
);

DROP POLICY IF EXISTS weekly_free_coin_grants_self_or_admin ON weekly_free_coin_grants;
CREATE POLICY weekly_free_coin_grants_self_or_admin ON weekly_free_coin_grants
FOR ALL
USING (
    user_id = app_current_user_id()
    OR app_has_role('admin')
    OR app_has_permission('coins.manage')
)
WITH CHECK (
    user_id = app_current_user_id()
    OR app_has_role('admin')
    OR app_has_permission('coins.manage')
);

DROP POLICY IF EXISTS coin_transactions_self_or_admin ON coin_transactions;
CREATE POLICY coin_transactions_self_or_admin ON coin_transactions
FOR ALL
USING (
    EXISTS (
        SELECT 1 FROM coin_wallets cw
        WHERE cw.id = coin_transactions.wallet_id
          AND (
              cw.user_id = app_current_user_id()
              OR app_has_role('admin')
              OR app_has_permission('coins.manage')
              OR app_has_permission('payments.manage')
          )
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1 FROM coin_wallets cw
        WHERE cw.id = coin_transactions.wallet_id
          AND (
              cw.user_id = app_current_user_id()
              OR app_has_role('admin')
              OR app_has_permission('coins.manage')
              OR app_has_permission('payments.manage')
          )
    )
);

DROP POLICY IF EXISTS coin_transaction_allocations_self_or_admin ON coin_transaction_allocations;
CREATE POLICY coin_transaction_allocations_self_or_admin ON coin_transaction_allocations
FOR ALL
USING (
    EXISTS (
        SELECT 1
        FROM coin_transactions ct
        JOIN coin_wallets cw ON cw.id = ct.wallet_id
        WHERE ct.id = coin_transaction_allocations.transaction_id
          AND (
              cw.user_id = app_current_user_id()
              OR app_has_role('admin')
              OR app_has_permission('coins.manage')
              OR app_has_permission('payments.manage')
          )
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1
        FROM coin_transactions ct
        JOIN coin_wallets cw ON cw.id = ct.wallet_id
        WHERE ct.id = coin_transaction_allocations.transaction_id
          AND (
              cw.user_id = app_current_user_id()
              OR app_has_role('admin')
              OR app_has_permission('coins.manage')
              OR app_has_permission('payments.manage')
          )
    )
);

DROP POLICY IF EXISTS coin_purchases_self_or_admin ON coin_purchases;
CREATE POLICY coin_purchases_self_or_admin ON coin_purchases
FOR ALL
USING (
    user_id = app_current_user_id()
    OR app_has_role('admin')
    OR app_has_permission('coins.manage')
    OR app_has_permission('payments.manage')
)
WITH CHECK (
    user_id = app_current_user_id()
    OR app_has_role('admin')
    OR app_has_permission('coins.manage')
    OR app_has_permission('payments.manage')
);
