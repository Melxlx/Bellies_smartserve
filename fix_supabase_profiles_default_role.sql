-- Supabase SQL Script to set default role for new signups to 'GUEST' (Customer)
-- Run this in your Supabase Dashboard -> SQL Editor

-- 1. Set default column value of 'role' on public.profiles to 'GUEST'
ALTER TABLE public.profiles
ALTER COLUMN role SET DEFAULT 'GUEST';

-- 2. Update any test customer profiles that were auto-assigned 'CASHIER' role by default
UPDATE public.profiles
SET role = 'GUEST', position = 'Customer'
WHERE (role IS NULL OR role = 'CASHIER' OR role = 'CUSTOMER')
  AND (position = 'Customer' OR position IS NULL OR position = '')
  AND (daily_rate IS NULL OR daily_rate = 0)
  AND lower(email) NOT IN ('owner@bellies.com', 'staff@bellies.com', 'cashier@bellies.com');

-- 3. Notify PostgREST to reload schema cache
NOTIFY pgrst, 'reload schema';
