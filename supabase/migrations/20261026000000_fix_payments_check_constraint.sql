-- Migration: Fix payments_check constraint on public.payments table
-- Allows both uppercase and lowercase payment_status and payment_method values

DO $$
BEGIN
  -- Drop existing legacy or restrictive constraints if they exist
  ALTER TABLE public.payments DROP CONSTRAINT IF EXISTS payments_check;
  ALTER TABLE public.payments DROP CONSTRAINT IF EXISTS payments_payment_status_check;
  ALTER TABLE public.payments DROP CONSTRAINT IF EXISTS payments_payment_method_check;

  -- Add comprehensive check constraint on payments table
  ALTER TABLE public.payments ADD CONSTRAINT payments_check
    CHECK (
      (payment_status IS NULL OR payment_status IN ('PAID', 'UNPAID', 'PENDING', 'REJECTED', 'FAILED', 'paid', 'unpaid', 'pending', 'rejected', 'failed'))
      AND
      (payment_method IS NULL OR payment_method IN ('CASH', 'GCASH', 'COD', 'cash', 'gcash', 'cod'))
    );
EXCEPTION
  WHEN undefined_table THEN
    NULL;
  WHEN others THEN
    NULL;
END $$;
