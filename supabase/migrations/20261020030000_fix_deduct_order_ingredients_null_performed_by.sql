-- Fix deduct_order_ingredients function to handle null created_by safely without failing on performed_by NOT NULL constraint
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
  v_performer uuid;
BEGIN
  SELECT * INTO v_order FROM public.orders WHERE id = p_order_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('order_id', p_order_id, 'status', 'not_found');
  END IF;

  -- Resolve performer safely (allow null if not found)
  v_performer := COALESCE(v_order.created_by, auth.uid());

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
            v_performer,
            'Auto deduct for Order #' || COALESCE(v_order.queue_no::text, v_order.id::text),
            now()
          );
        END IF;

        v_deducted_count := v_deducted_count + 1;
      END IF;
    END LOOP;
  END LOOP;

  PERFORM public.update_product_availability_from_inventory();

  RETURN jsonb_build_object('order_id', p_order_id, 'status', 'deducted', 'count', v_deducted_count);
END;
$$;
