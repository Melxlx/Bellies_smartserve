-- Migration: Add address and contact_number columns to public.profiles table

ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS address text;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS contact_number text;

-- Reload PostgREST schema cache so PostgREST immediately picks up the new columns
NOTIFY pgrst, 'reload schema';
