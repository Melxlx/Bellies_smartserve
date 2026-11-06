-- Step 1: Create dedicated employee_details table
CREATE TABLE IF NOT EXISTS employee_details (
  user_id UUID PRIMARY KEY REFERENCES profiles(id) ON DELETE CASCADE,
  position TEXT NOT NULL DEFAULT 'Staff',
  daily_rate NUMERIC(12, 2) NOT NULL DEFAULT 500.00,
  rfid_uid TEXT,
  is_card_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Step 2: Insert existing non-customer staff into employee_details
INSERT INTO employee_details (user_id, position, daily_rate)
SELECT
  id,
  COALESCE(NULLIF(position, ''), 'Staff'),
  500.00
FROM profiles
WHERE UPPER(role) NOT IN ('CUSTOMER', 'GUEST')
ON CONFLICT (user_id) DO NOTHING;

-- Step 3: Recreate view_pending_payroll to use employee_details table
CREATE OR REPLACE VIEW public.view_pending_payroll
WITH (security_invoker = true)
AS
WITH attendance_summary AS (
  SELECT
    a.user_id,
    COUNT(*) FILTER (
      WHERE UPPER(COALESCE(a.status, 'PRESENT')) IN ('PRESENT', 'LATE')
    )::INTEGER AS days_present,
    COALESCE(
      SUM(
        EXTRACT(
          EPOCH FROM (COALESCE(a.check_out, a.check_in) - a.check_in)
        ) / 3600
      ),
      0
    )::NUMERIC(12, 2) AS total_hours
  FROM public.attendance a
  WHERE a.check_in >= DATE_TRUNC('day', NOW()) - INTERVAL '15 days'
    AND a.check_in < DATE_TRUNC('day', NOW()) + INTERVAL '1 day'
  GROUP BY a.user_id
)
SELECT
  p.id AS user_id,
  p.full_name,
  COALESCE(ed.position, p.position, 'Staff') AS position,
  COALESCE(ed.daily_rate, 500.00)::NUMERIC(12, 2) AS daily_rate,
  COALESCE(s.total_hours, 0)::NUMERIC(12, 2) AS total_hours,
  COALESCE(s.days_present, 0)::INTEGER AS days_present,
  (
    COALESCE(s.days_present, 0) * COALESCE(ed.daily_rate, 500.00)
  )::NUMERIC(12, 2) AS estimated_earnings
FROM public.profiles p
LEFT JOIN public.employee_details ed ON ed.user_id = p.id
LEFT JOIN attendance_summary s ON s.user_id = p.id
WHERE UPPER(COALESCE(p.role, '')) NOT IN ('OWNER', 'GUEST', 'CUSTOMER')
  AND UPPER(COALESCE(p.account_status, 'ACTIVE')) <> 'ARCHIVED'
  AND NOT EXISTS (
    SELECT 1
    FROM public.payrolls py
    WHERE py.user_id = p.id
  );

-- Step 4: Drop old daily_rate and rfid_uid columns from profiles table using CASCADE
ALTER TABLE profiles DROP COLUMN IF EXISTS daily_rate CASCADE;
ALTER TABLE profiles DROP COLUMN IF EXISTS rfid_uid CASCADE;
