-- Create system_notifications table for Owner/Staff Notification Center
CREATE TABLE IF NOT EXISTS public.system_notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  message text NOT NULL,
  category text NOT NULL DEFAULT 'SYSTEM',
  route text,
  is_read boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.system_notifications ENABLE ROW LEVEL SECURITY;

-- Policies for system_notifications
DROP POLICY IF EXISTS "Staff can view system notifications" ON public.system_notifications;
CREATE POLICY "Staff can view system notifications"
ON public.system_notifications FOR SELECT
USING (public.is_staff() OR auth.role() = 'anon');

DROP POLICY IF EXISTS "Staff can insert system notifications" ON public.system_notifications;
CREATE POLICY "Staff can insert system notifications"
ON public.system_notifications FOR INSERT
WITH CHECK (public.is_staff() OR auth.role() = 'anon');

DROP POLICY IF EXISTS "Staff can update system notifications" ON public.system_notifications;
CREATE POLICY "Staff can update system notifications"
ON public.system_notifications FOR UPDATE
USING (public.is_staff() OR auth.role() = 'anon');

-- Index for fast sorting and unread queries
CREATE INDEX IF NOT EXISTS system_notifs_is_read_idx ON public.system_notifications (is_read, created_at DESC);
