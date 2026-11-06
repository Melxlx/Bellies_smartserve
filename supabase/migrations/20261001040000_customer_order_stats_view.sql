-- Create View to calculate completed orders count and total spent per customer for COD trust qualification
CREATE OR REPLACE VIEW public.view_customer_order_stats AS
SELECT
  p.id AS user_id,
  p.full_name,
  p.email,
  p.is_trusted_customer,
  p.owner_notes,
  COALESCE(COUNT(o.id) FILTER (WHERE LOWER(COALESCE(o.status, '')) = 'completed' OR LOWER(COALESCE(o.delivery_status, '')) = 'delivered'), 0)::integer AS completed_orders,
  COALESCE(SUM(o.total_amount) FILTER (WHERE LOWER(COALESCE(o.status, '')) = 'completed' OR LOWER(COALESCE(o.delivery_status, '')) = 'delivered'), 0.00)::numeric(12,2) AS total_spent
FROM public.profiles p
LEFT JOIN public.orders o ON o.created_by = p.id
WHERE LOWER(COALESCE(p.role, '')) IN ('customer', 'guest')
GROUP BY p.id, p.full_name, p.email, p.is_trusted_customer, p.owner_notes;

NOTIFY pgrst, 'reload schema';
