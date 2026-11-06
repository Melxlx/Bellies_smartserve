-- Migration: Auto Sync and Split Profile Names (full_name <-> first_name, middle_name, last_name)

CREATE OR REPLACE FUNCTION public.sync_profile_names()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_parts text[];
  v_len int;
BEGIN
  -- If first_name is empty or null, auto-split from full_name
  IF (NEW.first_name IS NULL OR trim(NEW.first_name) = '') AND (NEW.full_name IS NOT NULL AND trim(NEW.full_name) <> '') THEN
    v_parts := string_to_array(trim(regexp_replace(NEW.full_name, '\s+', ' ', 'g')), ' ');
    v_len := array_length(v_parts, 1);

    IF v_len = 1 THEN
      NEW.first_name := v_parts[1];
      NEW.middle_name := NULL;
      NEW.last_name := NULL;
    ELSIF v_len = 2 THEN
      NEW.first_name := v_parts[1];
      NEW.middle_name := NULL;
      NEW.last_name := v_parts[2];
    ELSIF v_len >= 3 THEN
      NEW.first_name := v_parts[1];
      NEW.last_name := v_parts[v_len];
      NEW.middle_name := array_to_string(v_parts[2:v_len-1], ' ');
    END IF;
  -- If first_name is provided but full_name is empty or null, compute full_name
  ELSIF (NEW.first_name IS NOT NULL AND trim(NEW.first_name) <> '') AND (NEW.full_name IS NULL OR trim(NEW.full_name) = '') THEN
    NEW.full_name := trim(concat_ws(' ', NEW.first_name, NEW.middle_name, NEW.last_name));
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_profile_names ON public.profiles;
CREATE TRIGGER trg_sync_profile_names
BEFORE INSERT OR UPDATE ON public.profiles
FOR EACH ROW
EXECUTE FUNCTION public.sync_profile_names();

-- Run one-time sync for all existing profile records in database
UPDATE public.profiles
SET updated_at = now()
WHERE first_name IS NULL OR trim(first_name) = '';

NOTIFY pgrst, 'reload schema';
