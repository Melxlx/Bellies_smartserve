-- Create or update business_settings table with delivery fee pricing rules
CREATE TABLE IF NOT EXISTS public.business_settings (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  store_name text DEFAULT 'Bellie''s Kitchen',
  store_address text DEFAULT 'Sta. Cruz, Laguna',
  contact_number text DEFAULT '09171234567',
  delivery_base_fee numeric(12,2) DEFAULT 30.00,
  delivery_included_distance_km numeric(12,2) DEFAULT 2.00,
  delivery_rate_per_km numeric(12,2) DEFAULT 10.00,
  default_delivery_fee numeric(12,2) DEFAULT 30.00,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

ALTER TABLE public.business_settings ADD COLUMN IF NOT EXISTS delivery_base_fee numeric(12,2) DEFAULT 30.00;
ALTER TABLE public.business_settings ADD COLUMN IF NOT EXISTS delivery_included_distance_km numeric(12,2) DEFAULT 2.00;
ALTER TABLE public.business_settings ADD COLUMN IF NOT EXISTS delivery_rate_per_km numeric(12,2) DEFAULT 10.00;
ALTER TABLE public.business_settings ADD COLUMN IF NOT EXISTS default_delivery_fee numeric(12,2) DEFAULT 30.00;

-- Ensure at least 1 settings row exists
INSERT INTO public.business_settings (store_name, store_address, contact_number, delivery_base_fee, delivery_included_distance_km, delivery_rate_per_km, default_delivery_fee)
SELECT 'Bellie''s Kitchen', 'Sta. Cruz, Laguna', '09171234567', 30.00, 2.00, 10.00, 30.00
WHERE NOT EXISTS (SELECT 1 FROM public.business_settings);

-- Enable RLS
ALTER TABLE public.business_settings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Everyone can view business settings" ON public.business_settings;
CREATE POLICY "Everyone can view business settings"
ON public.business_settings FOR SELECT
USING (true);

DROP POLICY IF EXISTS "Staff can update business settings" ON public.business_settings;
CREATE POLICY "Staff can update business settings"
ON public.business_settings FOR UPDATE
USING (true);

-- Add delivery_distance_km column to orders table
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS delivery_distance_km numeric(12,2) DEFAULT 0.00;

-- Server-side RPC to calculate and validate delivery fee based on road distance
CREATE OR REPLACE FUNCTION public.calculate_delivery_fee(p_distance_km numeric)
RETURNS numeric
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_base_fee numeric(12,2) := 30.00;
  v_included_dist numeric(12,2) := 2.00;
  v_rate_per_km numeric(12,2) := 10.00;
  v_extra_dist numeric(12,2);
  v_fee numeric(12,2);
BEGIN
  IF p_distance_km IS NULL OR p_distance_km <= 0 THEN
    RETURN 0.00;
  END IF;

  SELECT
    COALESCE(delivery_base_fee, default_delivery_fee, 30.00),
    COALESCE(delivery_included_distance_km, 2.00),
    COALESCE(delivery_rate_per_km, 10.00)
  INTO v_base_fee, v_included_dist, v_rate_per_km
  FROM public.business_settings
  LIMIT 1;

  v_extra_dist := GREATEST(0.00, p_distance_km - v_included_dist);
  v_fee := v_base_fee + (v_extra_dist * v_rate_per_km);

  RETURN ROUND(v_fee, 2);
END;
$$;

NOTIFY pgrst, 'reload schema';
