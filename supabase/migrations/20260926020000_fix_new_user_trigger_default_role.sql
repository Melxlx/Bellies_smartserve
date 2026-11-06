-- Step 1: Drop old check constraint if needed and set default role
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_role_check;
ALTER TABLE public.profiles ADD CONSTRAINT profiles_role_check
CHECK (UPPER(role) IN ('OWNER', 'CASHIER', 'KITCHEN', 'RIDER', 'GUEST', 'CUSTOMER'));

-- Step 2: Restore Cashiers (alfonhallel@gmail.com, eberuela11@gmail.com, s28362286@gmail.com)
UPDATE public.profiles
SET role = 'CASHIER', position = 'Cashier Staff'
WHERE email IN ('alfonhallel@gmail.com', 'eberuela11@gmail.com', 's28362286@gmail.com')
   OR email ILIKE '%cashier%';

INSERT INTO public.employee_details (user_id, position, daily_rate)
SELECT id, 'Cashier Staff', 500.00
FROM public.profiles
WHERE email IN ('alfonhallel@gmail.com', 'eberuela11@gmail.com', 's28362286@gmail.com')
   OR email ILIKE '%cashier%'
ON CONFLICT (user_id) DO UPDATE
SET daily_rate = 500.00, position = 'Cashier Staff';

-- Step 3: Restore Kitchen Staff (emilioberuela11@gmail.com)
UPDATE public.profiles
SET role = 'KITCHEN', position = 'Kitchen Staff'
WHERE email = 'emilioberuela11@gmail.com' OR email ILIKE '%kitchen%';

INSERT INTO public.employee_details (user_id, position, daily_rate)
SELECT id, 'Kitchen Staff', 500.00
FROM public.profiles
WHERE email = 'emilioberuela11@gmail.com' OR email ILIKE '%kitchen%'
ON CONFLICT (user_id) DO UPDATE
SET daily_rate = 500.00, position = 'Kitchen Staff';

-- Step 4: Restore Rider Staff (watcher.dota@gmail.com)
UPDATE public.profiles
SET role = 'RIDER', position = 'Delivery Rider'
WHERE email = 'watcher.dota@gmail.com' OR email ILIKE '%rider%';

INSERT INTO public.employee_details (user_id, position, daily_rate)
SELECT id, 'Delivery Rider', 500.00
FROM public.profiles
WHERE email = 'watcher.dota@gmail.com' OR email ILIKE '%rider%'
ON CONFLICT (user_id) DO UPDATE
SET daily_rate = 500.00, position = 'Delivery Rider';
