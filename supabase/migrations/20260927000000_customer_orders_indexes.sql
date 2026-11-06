-- Optimize customer order queries by user account ID and email inside customer_details JSONB
CREATE INDEX IF NOT EXISTS orders_created_by_idx ON public.orders (created_by);
CREATE INDEX IF NOT EXISTS orders_customer_email_idx ON public.orders ((customer_details->>'email'));
