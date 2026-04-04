-- Purchase audit trail for receipt validation
CREATE TABLE IF NOT EXISTS wt_purchases (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  product_id TEXT NOT NULL,
  platform TEXT NOT NULL CHECK (platform IN ('android', 'ios')),
  purchase_token TEXT,
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'cancelled', 'expired', 'refunded')),
  expires_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- RLS: users can only see their own purchases
ALTER TABLE wt_purchases ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own purchases"
  ON wt_purchases FOR SELECT
  USING (user_id = auth.uid());

-- Only the service role (Edge Function) can insert/update purchases
-- No INSERT/UPDATE/DELETE policies for authenticated users

CREATE INDEX idx_purchases_user ON wt_purchases(user_id);
CREATE INDEX idx_purchases_status ON wt_purchases(user_id, status) WHERE status = 'active';
