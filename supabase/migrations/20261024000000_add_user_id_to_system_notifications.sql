-- Add user_id and target_role columns to system_notifications table if they don't exist
ALTER TABLE public.system_notifications
ADD COLUMN IF NOT EXISTS user_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE,
ADD COLUMN IF NOT EXISTS target_role text;

-- Index for fast user-specific notification lookup
CREATE INDEX IF NOT EXISTS system_notifs_user_id_idx ON public.system_notifications (user_id, created_at DESC);
