-- Create RPC function to record ingredient inventory movement and log it in inventory_movements
CREATE OR REPLACE FUNCTION public.record_ingredient_inventory_movement(
  p_ingredient_id uuid,
  p_movement_type text,
  p_quantity numeric,
  p_reason text default null
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ingredient public.ingredients%rowtype;
  v_previous numeric;
  v_updated numeric;
  v_delta numeric;
  v_type text := upper(trim(p_movement_type));
  v_user_id uuid := auth.uid();
  v_user_name text := coalesce(auth.jwt() ->> 'email', 'System');
begin
  if p_quantity is null or p_quantity <= 0 then
    raise exception 'Quantity must be greater than zero';
  end if;

  if v_type not in ('STOCK_IN', 'STOCK_OUT', 'WASTAGE', 'DAMAGED', 'MANUAL_STOCK_OUT') then
    raise exception 'Unsupported movement type: %', p_movement_type;
  end if;

  select *
  into v_ingredient
  from public.ingredients
  where id = p_ingredient_id
  for update;

  if not found then
    raise exception 'Ingredient not found';
  end if;

  v_previous := v_ingredient.current_quantity;
  v_delta := case when v_type = 'STOCK_IN' then p_quantity else -p_quantity end;
  v_updated := greatest(0, v_previous + v_delta);

  update public.ingredients
  set current_quantity = v_updated,
      updated_at = now()
  where id = p_ingredient_id;

  if to_regclass('public.inventory_movements') is not null then
    insert into public.inventory_movements (
      ingredient_id,
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
      user_id,
      user_name,
      created_at
    )
    values (
      v_ingredient.id,
      v_ingredient.id,
      v_ingredient.code,
      v_ingredient.name,
      v_type,
      p_quantity,
      v_previous,
      v_updated,
      v_updated,
      v_type,
      v_user_name,
      p_reason,
      v_user_id,
      v_user_name,
      now()
    );
  end if;

  -- Automatically update product availability
  PERFORM public.update_product_availability_from_inventory();

  return jsonb_build_object(
    'ingredient_id', v_ingredient.id,
    'code', v_ingredient.code,
    'previous_quantity', v_previous,
    'updated_quantity', v_updated
  );
end;
$$;

NOTIFY pgrst, 'reload schema';
