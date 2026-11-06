-- Keep inventory movement values aligned with the product inventory RPC.
alter table if exists public.inventory_movements
  drop constraint if exists inventory_movements_movement_type_check;

alter table if exists public.inventory_movements
  add constraint inventory_movements_movement_type_check
  check (
    upper(btrim(coalesce(movement_type, ''))) in (
      'STOCK_IN',
      'STOCK_OUT',
      'WASTAGE',
      'DAMAGED',
      'MANUAL_STOCK_OUT'
    )
  );
