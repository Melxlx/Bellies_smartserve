-- Ensure employee_details table RLS policies allow staff/owner updates and daily_rate saving
CREATE TABLE IF NOT EXISTS public.employee_details (
    user_id UUID PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
    position VARCHAR(100) DEFAULT 'Staff Member',
    daily_rate NUMERIC(12, 2) NOT NULL DEFAULT 500.00
);

ALTER TABLE public.employee_details ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow manage employee details" ON public.employee_details;
CREATE POLICY "Allow manage employee details"
ON public.employee_details FOR ALL
USING (true)
WITH CHECK (true);
