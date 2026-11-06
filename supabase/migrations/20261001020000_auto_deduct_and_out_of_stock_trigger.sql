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

-- Enhanced Deduct Order Ingredients with Deduplication
CREATE OR REPLACE FUNCTION public.deduct_order_ingredients(p_order_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_item RECORD;
  v_recipe RECORD;
  v_ingredient RECORD;
  v_order RECORD;
  v_total_deducted numeric(14,3);
  v_prev_qty numeric(14,3);
  v_new_qty numeric(14,3);
  v_deducted_count int := 0;
  v_already_deducted boolean := false;
BEGIN
  SELECT * INTO v_order FROM public.orders WHERE id = p_order_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('order_id', p_order_id, 'status', 'not_found');
  END IF;

  -- Check if order ingredients were already deducted
  IF to_regclass('public.inventory_movements') IS NOT NULL THEN
    SELECT EXISTS (
      SELECT 1 FROM public.inventory_movements
      WHERE reason LIKE '%' || COALESCE(v_order.queue_no::text, v_order.id::text) || '%'
      AND movement_type = 'ORDER_DEDUCTION'
    ) INTO v_already_deducted;
  END IF;

  IF v_already_deducted THEN
    RETURN jsonb_build_object('order_id', p_order_id, 'status', 'already_deducted');
  END IF;

  -- Loop through order items
  FOR v_item IN
    SELECT * FROM public.order_items WHERE order_id = p_order_id
  LOOP
    FOR v_recipe IN
      SELECT * FROM public.product_recipes WHERE product_id = v_item.product_id
    LOOP
      SELECT * INTO v_ingredient FROM public.ingredients WHERE id = v_recipe.ingredient_id FOR UPDATE;

      IF FOUND THEN
        v_total_deducted := v_recipe.quantity_required * v_item.quantity;
        v_prev_qty := v_ingredient.current_quantity;
        v_new_qty := GREATEST(0, v_prev_qty - v_total_deducted);

        UPDATE public.ingredients
        SET current_quantity = v_new_qty,
            updated_at = now()
        WHERE id = v_ingredient.id;

        IF to_regclass('public.inventory_movements') IS NOT NULL THEN
          INSERT INTO public.inventory_movements (
            product_id,
            product_code,
            product_name,
            movement_type,
            quantity,
            previous_quantity,
            updated_quantity,
            new_quantity,
            reference_type,
            performed_by,
            reason,
            created_at
          )
          VALUES (
            v_ingredient.id,
            v_ingredient.code,
            v_ingredient.name,
            'ORDER_DEDUCTION',
            v_total_deducted,
            v_prev_qty,
            v_new_qty,
            v_new_qty,
            'ORDER',
            v_order.created_by,
            'Auto deduct for Order #' || COALESCE(v_order.queue_no::text, v_order.id::text),
            now()
          );
        END IF;

        v_deducted_count := v_deducted_count + 1;
      END IF;
    END LOOP;
  END LOOP;

  -- Automatically update product availability
  PERFORM public.update_product_availability_from_inventory();

  RETURN jsonb_build_object(
    'order_id', p_order_id,
    'deducted_ingredients_count', v_deducted_count
  );
END;
$$;

-- Database Trigger on Order Receive / Creation
CREATE OR REPLACE FUNCTION public.trg_auto_deduct_order_ingredients()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF (TG_OP = 'INSERT' AND LOWER(COALESCE(NEW.status, '')) IN ('received', 'preparing', 'ready')) OR
     (TG_OP = 'UPDATE' AND LOWER(COALESCE(NEW.status, '')) IN ('received', 'preparing', 'ready') AND LOWER(COALESCE(OLD.status, '')) NOT IN ('received', 'preparing', 'ready', 'completed')) THEN
    PERFORM public.deduct_order_ingredients(NEW.id);
    PERFORM public.update_product_availability_from_inventory();
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_orders_auto_deduct ON public.orders;
CREATE TRIGGER trg_orders_auto_deduct
AFTER INSERT OR UPDATE ON public.orders
FOR EACH ROW
EXECUTE FUNCTION public.trg_auto_deduct_order_ingredients();

NOTIFY pgrst, 'reload schema';
