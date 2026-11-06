-- Allow SALE_DEDUCTION and other movement types in inventory_movements check constraint
ALTER TABLE IF EXISTS public.inventory_movements DROP CONSTRAINT IF EXISTS inventory_movements_movement_type_check;
ALTER TABLE IF EXISTS public.inventory_movements ADD CONSTRAINT inventory_movements_movement_type_check
CHECK (movement_type IN ('SALE_DEDUCTION', 'ORDER_DEDUCTION', 'STOCK_IN', 'RESTOCK', 'ADJUSTMENT', 'DAMAGE', 'RETURN', 'SALE', 'PURCHASE'));
