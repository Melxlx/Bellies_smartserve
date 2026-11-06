-- Migration: Ensure 'REJECTED' is allowed in orders.payment_status check constraint

DO $$
BEGIN
  ALTER TABLE public.orders DROP CONSTRAINT IF EXISTS orders_payment_status_check;
  ALTER TABLE public.orders ADD CONSTRAINT orders_payment_status_check
    CHECK (payment_status IN ('PENDING', 'PAID', 'UNPAID', 'REJECTED', 'FAILED', 'pending', 'paid', 'unpaid', 'rejected', 'failed'));
EXCEPTION
  WHEN undefined_table THEN
    NULL;
  WHEN others THEN
    NULL;
END $$;
