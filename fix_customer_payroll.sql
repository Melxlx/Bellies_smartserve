-- Bellie's SmartServe - Fix Customer Payroll & Staff Profile Filter

-- 1. Update existing customer profiles (like 'MAMAMO') so their role is 'GUEST' and position is 'Customer'
UPDATE profiles
SET role = 'GUEST', position = 'Customer', daily_rate = 0
WHERE role NOT IN ('OWNER', 'CASHIER', 'KITCHEN', 'RIDER')
   OR position ILIKE '%customer%'
   OR (position = 'Staff' AND id NOT IN (SELECT user_id FROM attendance WHERE check_in IS NOT NULL));

-- 2. Update view_pending_payroll to strictly include ONLY actual employees (CASHIER, KITCHEN, RIDER)
CREATE OR REPLACE VIEW view_pending_payroll AS
SELECT
  p.id AS user_id,
  p.full_name,
  p.position,
  p.daily_rate,
  COALESCE(SUM(EXTRACT(EPOCH FROM (COALESCE(a.check_out, NOW()) - a.check_in)) / 3600.0), 0) AS total_hours,
  COUNT(DISTINCT a.id) AS days_present,
  ROUND(COALESCE(COUNT(DISTINCT a.id) * p.daily_rate, 0)::numeric, 2) AS estimated_earnings
FROM profiles p
LEFT JOIN attendance a ON a.user_id = p.id AND a.check_in >= NOW() - INTERVAL '15 days'
WHERE p.role IN ('CASHIER', 'KITCHEN', 'RIDER')
  AND p.account_status = 'ACTIVE'
GROUP BY p.id, p.full_name, p.position, p.daily_rate;
