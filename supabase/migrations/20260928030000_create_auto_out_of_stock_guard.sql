-- RPC Function: Auto Out-Of-Stock Guard based on recipe ingredient quantities
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
  v_is_out_of_stock boolean;
  v_updated_count int := 0;
BEGIN
  -- Loop through all active products that have recipes defined
  FOR v_prod IN
    SELECT DISTINCT p.id, p.name, p.status
    FROM public.products p
    JOIN public.product_recipes pr ON pr.product_id = p.id
    WHERE p.status != 'archived'
  LOOP
    v_is_out_of_stock := false;

    -- Check if any required ingredient is below the required recipe quantity or inactive
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
