-- Add trusted customer flag and private owner notes to profiles table
ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS is_trusted_customer BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS owner_notes TEXT;
