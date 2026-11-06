-- Migration: Enforce Product Sold Out Rule based on Recipe and Ingredient Stock
-- Rule 1: If a product has NO recipe defined, it is automatically marked as 'unavailable' (Sold Out).
-- Rule 2: If a product HAS a recipe, it is 'available' ONLY IF all required ingredients are active and have sufficient quantity (current_quantity >= quantity_required). Otherwise, it is 'unavailable' (Sold Out).

CREATE OR REPLACE FUNCTION public.update_product_availability_from_inventory()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_prod RECORD;
  v_recipe RECORD;
  v_ing RECORD;
  v_recipe_count int;
  v_is_out_of_stock boolean;
  v_updated_count int := 0;
BEGIN
  -- Loop through all active products (excluding archived)
  FOR v_prod IN
    SELECT p.id, p.name, p.status
    FROM public.products p
    WHERE p.status != 'archived'
  LOOP
    v_is_out_of_stock := false;

    -- Count recipe items for this product
    SELECT count(*) INTO v_recipe_count
    FROM public.product_recipes pr
    WHERE pr.product_id = v_prod.id;

    -- RULE 1: If product has NO recipe, automatic sold out (unavailable)
    IF v_recipe_count = 0 THEN
      v_is_out_of_stock := true;
    ELSE
      -- RULE 2: Check if any required ingredient is below required quantity or inactive
      FOR v_recipe IN
        SELECT pr.ingredient_id, pr.quantity_required
        FROM public.product_recipes pr
        WHERE pr.product_id = v_prod.id
      LOOP
        SELECT * INTO v_ing FROM public.ingredients WHERE id = v_recipe.ingredient_id;

        IF FOUND THEN
          IF v_ing.current_quantity < v_recipe.quantity_required OR v_ing.is_active = false THEN
            v_is_out_of_stock := true;
            EXIT;
          END IF;
        ELSE
          v_is_out_of_stock := true;
          EXIT;
        END IF;
      END LOOP;
    END IF;

    -- Automatically toggle product status between 'unavailable' and 'available'
    IF v_is_out_of_stock AND v_prod.status = 'available' THEN
      UPDATE public.products
      SET status = 'unavailable',
          inventory_updated_at = now()
      WHERE id = v_prod.id;
      v_updated_count := v_updated_count + 1;
    ELSIF NOT v_is_out_of_stock AND v_prod.status = 'unavailable' THEN
      UPDATE public.products
      SET status = 'available',
          inventory_updated_at = now()
      WHERE id = v_prod.id;
      v_updated_count := v_updated_count + 1;
    END IF;
  END LOOP;

  RETURN jsonb_build_object('updated_products_count', v_updated_count);
END;
$$;

-- Run the function immediately to apply rules to existing products
SELECT public.update_product_availability_from_inventory();
