-- Ensure official Owner account has 'OWNER' role in profiles table
UPDATE public.profiles
SET role = 'OWNER', position = 'Owner / Manager'
WHERE LOWER(email) IN ('mberuela11@gmail.com', 'owner@bellies.com');
