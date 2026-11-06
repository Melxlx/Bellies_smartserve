-- Product-based inventory fields and atomic stock movement recording.

create sequence if not exists public.product_inventory_code_seq;
create sequence if not exists public.inventory_movement_no_seq;

create or replace function public.next_product_inventory_code()
returns text
language plpgsql
as $$
begin
  return 'PROD-' || lpad(nextval('public.product_inventory_code_seq')::text, 3, '0');
end;
$$;

alter table if exists public.products
  add column if not exists product_code text,
  add column if not exists inventory_unit text not null default 'PIECE',
  add column if not exists inventory_quantity numeric(14, 3) not null default 0,
  add column if not exists inventory_reorder_level numeric(14, 3) not null default 0,
  add column if not exists inventory_updated_at timestamptz not null default now();

update public.products
set product_code = public.next_product_inventory_code()
where product_code is null or btrim(product_code) = '';

do $$
declare
  v_max_code bigint;
begin
  select max(substring(product_code from 6)::bigint)
  into v_max_code
  from public.products
  where product_code ~ '^PROD-[0-9]+$';

  if v_max_code is null then
    perform setval('public.product_inventory_code_seq', 1, false);
  else
    perform setval('public.product_inventory_code_seq', v_max_code, true);
  end if;
end
$$;

update public.products
set inventory_quantity = greatest(inventory_quantity, 0),
    inventory_reorder_level = greatest(inventory_reorder_level, 0);

alter table if exists public.products
  alter column product_code set default public.next_product_inventory_code(),
  alter column product_code set not null;

-- Inventory products do not require a selling price. Keep the legacy
-- product field for menu items, but allow zero for quantity-only products.
do $$
begin
  if to_regclass('public.products') is not null then
    alter table public.products
      drop constraint if exists products_selling_price_check;
    alter table public.products
      add constraint products_selling_price_check
      check (selling_price >= 0);
  end if;
end
$$;

do $$
begin
  if to_regclass('public.products') is not null
     and not exists (
       select 1
       from pg_constraint
       where conname = 'products_product_code_key'
         and conrelid = 'public.products'::regclass
     ) then
    alter table public.products
      add constraint products_product_code_key unique (product_code);
  end if;
end
$$;

do $$
begin
  if to_regclass('public.products') is not null
     and not exists (
       select 1
       from pg_constraint
       where conname = 'products_inventory_quantity_nonnegative'
         and conrelid = 'public.products'::regclass
     ) then
    alter table public.products
      add constraint products_inventory_quantity_nonnegative
      check (inventory_quantity >= 0);
  end if;
end
$$;

alter table if exists public.inventory_movements
  add column if not exists product_id uuid,
  add column if not exists product_code text,
  add column if not exists product_name text,
  add column if not exists previous_quantity numeric(14, 3) not null default 0,
  add column if not exists updated_quantity numeric(14, 3) not null default 0,
  add column if not exists new_quantity numeric(14, 3) not null default 0,
  add column if not exists reference_type text,
  add column if not exists performed_by text,
  add column if not exists user_id uuid,
  add column if not exists user_name text;

do $$
declare
  v_max_movement_no bigint;
begin
  if to_regclass('public.inventory_movements') is not null then
    select coalesce(
        max(nullif(regexp_replace(movement_no, '\D', '', 'g'), '')::bigint),
        0
      )
        into v_max_movement_no
        from public.inventory_movements;

    if v_max_movement_no > 0 then
      perform setval(
        'public.inventory_movement_no_seq',
        v_max_movement_no,
        true
      );
    end if;

    alter table public.inventory_movements
      alter column movement_no
      set default nextval('public.inventory_movement_no_seq')::text;
  end if;
end
$$;

alter table if exists public.inventory_movements
  alter column ingredient_id drop not null;

alter table if exists public.inventory_movements
  drop constraint if exists inventory_movements_reference_type_check;

alter table if exists public.inventory_movements
  drop column if exists expiry_date;

create index if not exists inventory_movements_product_created_idx
  on public.inventory_movements (product_id, created_at desc);

create or replace function public.record_product_inventory_movement(
  p_product_id uuid,
  p_movement_type text,
  p_quantity numeric,
  p_unit_cost numeric default 0,
  p_reason text default null
)
returns jsonb
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_product public.products%rowtype;
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
    raise exception 'Unsupported inventory movement type: %', p_movement_type;
  end if;

  select *
  into v_product
  from public.products
  where id = p_product_id
  for update;

  if not found then
    raise exception 'Product not found';
  end if;

  v_previous := v_product.inventory_quantity;
  v_delta := case when v_type = 'STOCK_IN' then p_quantity else -p_quantity end;
  v_updated := v_previous + v_delta;

  if v_updated < 0 then
    raise exception 'Insufficient stock. Available quantity: %', v_previous;
  end if;

  update public.products
  set inventory_quantity = v_updated,
      inventory_updated_at = now()
  where id = p_product_id;

  insert into public.inventory_movements (
    product_id,
    product_code,
    product_name,
    movement_type,
    quantity,
    unit_cost,
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
    v_product.id,
    v_product.product_code,
    v_product.name,
    v_type,
    p_quantity,
    0,
    v_previous,
    v_updated,
    v_updated,
    v_type,
    v_user_id,
    p_reason,
    v_user_id,
    v_user_name,
    now()
  );

  return jsonb_build_object(
    'product_id', v_product.id,
    'product_code', v_product.product_code,
    'previous_quantity', v_previous,
    'updated_quantity', v_updated
  );
end;
$$;

notify pgrst, 'reload schema';
