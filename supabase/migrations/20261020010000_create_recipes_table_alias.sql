-- Create recipes table as an exact replica/alias of product_recipes to fix legacy triggers querying public.recipes
CREATE TABLE IF NOT EXISTS public.recipes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id uuid NOT NULL,
  ingredient_id uuid NOT NULL,
  quantity_required numeric(14, 3) NOT NULL DEFAULT 1,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.recipes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow all access to recipes" ON public.recipes;
CREATE POLICY "Allow all access to recipes"
ON public.recipes FOR ALL
USING (true)
WITH CHECK (true);

-- Populate it from product_recipes if empty
INSERT INTO public.recipes (id, product_id, ingredient_id, quantity_required, created_at, updated_at)
SELECT id, product_id, ingredient_id, quantity_required, created_at, updated_at
FROM public.product_recipes
ON CONFLICT DO NOTHING;
