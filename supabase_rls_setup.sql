-- Bellie's SmartServe Supabase Row Level Security (RLS) Setup

-- 1. Enable RLS on core tables
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE payments ENABLE ROW LEVEL SECURITY;

-- Helper function to check if current user is staff/owner
CREATE OR REPLACE FUNCTION public.is_staff()
RETURNS boolean AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid()
    AND role IN ('OWNER', 'CASHIER', 'KITCHEN', 'RIDER')
    AND account_status = 'ACTIVE'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Profiles Policies
-- Customers can view and update their own profile; Staff can view all profiles
DROP POLICY IF EXISTS "Users can view own profile or staff view all" ON profiles;
CREATE POLICY "Users can view own profile or staff view all"
ON profiles FOR SELECT
USING (auth.uid() = id OR public.is_staff());

DROP POLICY IF EXISTS "Users can insert own profile" ON profiles;
CREATE POLICY "Users can insert own profile"
ON profiles FOR INSERT
WITH CHECK (auth.uid() = id OR public.is_staff());

DROP POLICY IF EXISTS "Users can update own profile or staff update" ON profiles;
CREATE POLICY "Users can update own profile or staff update"
ON profiles FOR UPDATE
USING (auth.uid() = id OR public.is_staff());

-- 3. Orders Policies
-- Customers can view & create their own orders; Staff can view and manage all orders
DROP POLICY IF EXISTS "Customers view own orders or staff view all" ON orders;
CREATE POLICY "Customers view own orders or staff view all"
ON orders FOR SELECT
USING (created_by = auth.uid() OR public.is_staff());

DROP POLICY IF EXISTS "Customers insert own orders or staff insert" ON orders;
CREATE POLICY "Customers insert own orders or staff insert"
ON orders FOR INSERT
WITH CHECK (created_by = auth.uid() OR auth.role() = 'anon' OR public.is_staff());

DROP POLICY IF EXISTS "Staff or customer update own orders" ON orders;
CREATE POLICY "Staff or customer update own orders"
ON orders FOR UPDATE
USING (created_by = auth.uid() OR public.is_staff());

-- 4. Order Items Policies
DROP POLICY IF EXISTS "View order items" ON order_items;
CREATE POLICY "View order items"
ON order_items FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM orders
    WHERE orders.id = order_items.order_id
    AND (orders.created_by = auth.uid() OR public.is_staff())
  )
);

DROP POLICY IF EXISTS "Insert order items" ON order_items;
CREATE POLICY "Insert order items"
ON order_items FOR INSERT
WITH CHECK (
  EXISTS (
    SELECT 1 FROM orders
    WHERE orders.id = order_items.order_id
    AND (orders.created_by = auth.uid() OR auth.role() = 'anon' OR public.is_staff())
  )
);

-- 5. Payments Policies
DROP POLICY IF EXISTS "View payments" ON payments;
CREATE POLICY "View payments"
ON payments FOR SELECT
USING (
  EXISTS (
    SELECT 1 FROM orders
    WHERE orders.id = payments.order_id
    AND (orders.created_by = auth.uid() OR public.is_staff())
  )
);
