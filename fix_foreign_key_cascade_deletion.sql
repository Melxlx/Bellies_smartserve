-- Supabase SQL Script to allow deleting users/profiles without Foreign Key constraint errors
-- Run this in your Supabase Dashboard -> SQL Editor

-- 1. Update created_by foreign key on orders to ON DELETE CASCADE
ALTER TABLE public.orders
DROP CONSTRAINT IF EXISTS orders_created_by_fkey;

ALTER TABLE public.orders
ADD CONSTRAINT orders_created_by_fkey
  FOREIGN KEY (created_by) REFERENCES public.profiles(id)
  ON DELETE CASCADE;

-- 2. Update rider_id foreign key on orders to ON DELETE SET NULL
ALTER TABLE public.orders
DROP CONSTRAINT IF EXISTS orders_rider_id_fkey;

ALTER TABLE public.orders
ADD CONSTRAINT orders_rider_id_fkey
  FOREIGN KEY (rider_id) REFERENCES public.profiles(id)
  ON DELETE SET NULL;

-- 3. Update user_id foreign key on attendance to ON DELETE CASCADE
ALTER TABLE public.attendance
DROP CONSTRAINT IF EXISTS attendance_user_id_fkey;

ALTER TABLE public.attendance
ADD CONSTRAINT attendance_user_id_fkey
  FOREIGN KEY (user_id) REFERENCES public.profiles(id)
  ON DELETE CASCADE;

-- 4. Update user_id foreign key on payrolls to ON DELETE CASCADE
ALTER TABLE public.payrolls
DROP CONSTRAINT IF EXISTS payrolls_user_id_fkey;

ALTER TABLE public.payrolls
ADD CONSTRAINT payrolls_user_id_fkey
  FOREIGN KEY (user_id) REFERENCES public.profiles(id)
  ON DELETE CASCADE;

-- 5. Reload Schema Cache
NOTIFY pgrst, 'reload schema';
