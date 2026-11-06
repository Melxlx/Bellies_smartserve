-- Create ingredients table for Inventory Management
CREATE TABLE IF NOT EXISTS public.ingredients (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text UNIQUE NOT NULL,
  name text NOT NULL,
  category text NOT NULL DEFAULT 'General',
  unit text NOT NULL DEFAULT 'kilogram',
  current_quantity numeric(14, 3) NOT NULL DEFAULT 0,
  reorder_level numeric(14, 3) NOT NULL DEFAULT 10,
  average_unit_cost numeric(14, 2) NOT NULL DEFAULT 0,
  nearest_expiry_date timestamptz,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- Enable Row Level Security (RLS)
ALTER TABLE public.ingredients ENABLE ROW LEVEL SECURITY;

-- RLS Policies for Staff Access
DROP POLICY IF EXISTS "Staff can view ingredients" ON public.ingredients;
CREATE POLICY "Staff can view ingredients"
ON public.ingredients FOR SELECT
USING (public.is_staff());

DROP POLICY IF EXISTS "Staff can insert ingredients" ON public.ingredients;
CREATE POLICY "Staff can insert ingredients"
ON public.ingredients FOR INSERT
WITH CHECK (public.is_staff());

DROP POLICY IF EXISTS "Staff can update ingredients" ON public.ingredients;
CREATE POLICY "Staff can update ingredients"
ON public.ingredients FOR UPDATE
USING (public.is_staff());

DROP POLICY IF EXISTS "Staff can delete ingredients" ON public.ingredients;
CREATE POLICY "Staff can delete ingredients"
ON public.ingredients FOR DELETE
USING (public.is_staff());
