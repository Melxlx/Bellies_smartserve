-- Ensure payrolls table has all required columns including daily_rate
CREATE TABLE IF NOT EXISTS public.payrolls (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE,
  days_present integer DEFAULT 1,
  daily_rate numeric(12,2) DEFAULT 0.00,
  gross_pay numeric(12,2) DEFAULT 0.00,
  net_pay numeric(12,2) DEFAULT 0.00,
  status text DEFAULT 'PAID',
  paid_at timestamptz DEFAULT now(),
  period_start timestamptz DEFAULT now(),
  period_end timestamptz DEFAULT now(),
  created_at timestamptz DEFAULT now()
);

ALTER TABLE public.payrolls ADD COLUMN IF NOT EXISTS daily_rate numeric(12,2) DEFAULT 0.00;
ALTER TABLE public.payrolls ADD COLUMN IF NOT EXISTS days_present integer DEFAULT 1;
ALTER TABLE public.payrolls ADD COLUMN IF NOT EXISTS gross_pay numeric(12,2) DEFAULT 0.00;
ALTER TABLE public.payrolls ADD COLUMN IF NOT EXISTS net_pay numeric(12,2) DEFAULT 0.00;
ALTER TABLE public.payrolls ADD COLUMN IF NOT EXISTS status text DEFAULT 'PAID';
ALTER TABLE public.payrolls ADD COLUMN IF NOT EXISTS paid_at timestamptz DEFAULT now();

ALTER TABLE public.payrolls ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow staff and owner payroll access" ON public.payrolls;
CREATE POLICY "Allow staff and owner payroll access"
ON public.payrolls FOR ALL
USING (true)
WITH CHECK (true);

-- Reload PostgREST schema cache
NOTIFY pgrst, 'reload schema';
