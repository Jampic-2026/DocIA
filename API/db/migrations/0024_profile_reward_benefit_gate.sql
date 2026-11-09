ALTER TABLE benefits ADD COLUMN IF NOT EXISTS requires_profile_reward BOOLEAN NOT NULL DEFAULT FALSE;
-- Keep the benefit gated after a campaign is replaced or disabled.
UPDATE benefits SET requires_profile_reward=TRUE WHERE id IN (
  SELECT benefit_id FROM profile_reward_grants
  UNION SELECT NULLIF(policy->>'benefitId','')::uuid FROM profile_completion_policy WHERE policy ? 'benefitId'
);
