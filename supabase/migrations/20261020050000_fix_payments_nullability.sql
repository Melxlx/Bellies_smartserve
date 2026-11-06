-- Make change_amount and amount_tendered nullable in payments table with default 0.0
ALTER TABLE IF EXISTS public.payments
ALTER COLUMN change_amount DROP NOT NULL,
ALTER COLUMN change_amount SET DEFAULT 0.0,
ALTER COLUMN amount_tendered DROP NOT NULL,
ALTER COLUMN amount_tendered SET DEFAULT 0.0;
