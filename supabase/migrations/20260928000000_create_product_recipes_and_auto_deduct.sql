-- Create product_recipes table linking products to required raw ingredients
CREATE TABLE IF NOT EXISTS public.product_recipes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id uuid NOT NULL REFERENCES public.products(id) ON DELETE CASCADE,
  ingredient_id uuid NOT NULL REFERENCES public.ingredients(id) ON DELETE CASCADE,
  quantity_required numeric(14, 3) NOT NULL DEFAULT 1 CHECK (quantity_required > 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT product_recipes_unique UNIQUE (product_id, ingredient_id)
);

-- Enable RLS
ALTER TABLE public.product_recipes ENABLE ROW LEVEL SECURITY;

-- Policies for product_recipes
DROP POLICY IF EXISTS "Staff can view product recipes" ON public.product_recipes;
CREATE POLICY "Staff can view product recipes"
ON public.product_recipes FOR SELECT
USING (public.is_staff() OR auth.role() = 'anon');

DROP POLICY IF EXISTS "Staff can insert product recipes" ON public.product_recipes;
CREATE POLICY "Staff can insert product recipes"
ON public.product_recipes FOR INSERT
WITH CHECK (public.is_staff());

DROP POLICY IF EXISTS "Staff can update product recipes" ON public.product_recipes;
CREATE POLICY "Staff can update product recipes"
ON public.product_recipes FOR UPDATE
USING (public.is_staff());

DROP POLICY IF EXISTS "Staff can delete product recipes" ON public.product_recipes;
CREATE POLICY "Staff can delete product recipes"
ON public.product_recipes FOR DELETE
USING (public.is_staff());

-- RPC Function: Deduct order ingredients atomically from inventory
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
BEGIN
  -- Get order details
  SELECT * INTO v_order FROM public.orders WHERE id = p_order_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Order with ID % not found', p_order_id;
  END IF;

  -- Loop through order items
  FOR v_item IN
    SELECT * FROM public.order_items WHERE order_id = p_order_id
  LOOP
    -- Loop through recipe items for this product
    FOR v_recipe IN
      SELECT * FROM public.product_recipes WHERE product_id = v_item.product_id
    LOOP
      -- Get current ingredient
      SELECT * INTO v_ingredient FROM public.ingredients WHERE id = v_recipe.ingredient_id FOR UPDATE;

      IF FOUND THEN
        v_total_deducted := v_recipe.quantity_required * v_item.quantity;
        v_prev_qty := v_ingredient.current_quantity;
        v_new_qty := GREATEST(0, v_prev_qty - v_total_deducted);

        -- Update ingredient quantity
        UPDATE public.ingredients
        SET current_quantity = v_new_qty,
            updated_at = now()
        WHERE id = v_ingredient.id;

        -- Record inventory movement log if table exists
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

  RETURN jsonb_build_object(
    'order_id', p_order_id,
    'deducted_ingredients_count', v_deducted_count
  );
END;
$$;
