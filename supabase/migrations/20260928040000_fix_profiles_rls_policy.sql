-- Fix RLS policies on public.profiles to allow customer profile creation during sign-up
DROP POLICY IF EXISTS "Users can insert own profile" ON public.profiles;
CREATE POLICY "Users can insert own profile"
ON public.profiles FOR INSERT
WITH CHECK (true);

DROP POLICY IF EXISTS "Users can update own profile or staff update" ON public.profiles;
CREATE POLICY "Users can update own profile or staff update"
ON public.profiles FOR UPDATE
USING (auth.uid() = id OR auth.uid() IS NULL OR public.is_staff());
