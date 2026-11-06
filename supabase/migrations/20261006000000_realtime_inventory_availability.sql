-- Enable Realtime for inventory, products, and recipes
ALTER PUBLICATION supabase_realtime ADD TABLE public.products;
ALTER PUBLICATION supabase_realtime ADD TABLE public.ingredients;
ALTER PUBLICATION supabase_realtime ADD TABLE public.product_recipes;

-- Set replica identity to FULL so realtime events contain all columns
ALTER TABLE public.products REPLICA IDENTITY FULL;
ALTER TABLE public.ingredients REPLICA IDENTITY FULL;
ALTER TABLE public.product_recipes REPLICA IDENTITY FULL;

-- Create trigger on ingredients table to automatically update product availability when stock changes
CREATE OR REPLACE FUNCTION public.trg_auto_update_availability_on_ingredient_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  PERFORM public.update_product_availability_from_inventory();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_ingredients_availability_update ON public.ingredients;
CREATE TRIGGER trg_ingredients_availability_update
AFTER INSERT OR UPDATE OF current_quantity, is_active ON public.ingredients
FOR EACH ROW
EXECUTE FUNCTION public.trg_auto_update_availability_on_ingredient_change();

-- Create trigger on product_recipes table when recipe changes
DROP TRIGGER IF EXISTS trg_product_recipes_availability_update ON public.product_recipes;
CREATE TRIGGER trg_product_recipes_availability_update
AFTER INSERT OR UPDATE OR DELETE ON public.product_recipes
FOR EACH ROW
EXECUTE FUNCTION public.trg_auto_update_availability_on_ingredient_change();

-- Run initial availability check
SELECT public.update_product_availability_from_inventory();

NOTIFY pgrst, 'reload schema';
