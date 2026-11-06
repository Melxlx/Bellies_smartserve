-- Ensure system_notifications table and policies allow full access for staff and authenticated roles
CREATE TABLE IF NOT EXISTS public.system_notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  message text NOT NULL,
  category text NOT NULL DEFAULT 'SYSTEM',
  route text,
  is_read boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.system_notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff can view system notifications" ON public.system_notifications;
DROP POLICY IF EXISTS "Everyone can view system notifications" ON public.system_notifications;
CREATE POLICY "Everyone can view system notifications"
ON public.system_notifications FOR SELECT
USING (true);

DROP POLICY IF EXISTS "Staff can insert system notifications" ON public.system_notifications;
DROP POLICY IF EXISTS "Everyone can insert system notifications" ON public.system_notifications;
CREATE POLICY "Everyone can insert system notifications"
ON public.system_notifications FOR INSERT
WITH CHECK (true);

DROP POLICY IF EXISTS "Staff can update system notifications" ON public.system_notifications;
DROP POLICY IF EXISTS "Everyone can update system notifications" ON public.system_notifications;
CREATE POLICY "Everyone can update system notifications"
ON public.system_notifications FOR UPDATE
USING (true);

DROP POLICY IF EXISTS "Staff can delete system notifications" ON public.system_notifications;
DROP POLICY IF EXISTS "Everyone can delete system notifications" ON public.system_notifications;
CREATE POLICY "Everyone can delete system notifications"
ON public.system_notifications FOR DELETE
USING (true);

CREATE INDEX IF NOT EXISTS system_notifs_is_read_idx ON public.system_notifications (is_read, created_at DESC);
