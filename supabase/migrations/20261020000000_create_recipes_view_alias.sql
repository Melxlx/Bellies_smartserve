-- Create recipes view as an alias to product_recipes to fix any legacy trigger references
CREATE OR REPLACE VIEW public.recipes AS
SELECT * FROM public.product_recipes;
