-- Create order_reviews table for customer feedback and ratings
CREATE TABLE IF NOT EXISTS public.order_reviews (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id uuid REFERENCES public.orders(id) ON DELETE CASCADE,
  customer_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  customer_name text DEFAULT 'Customer',
  food_rating integer NOT NULL CHECK (food_rating >= 1 AND food_rating <= 5),
  delivery_rating integer CHECK (delivery_rating >= 1 AND delivery_rating <= 5),
  comment text,
  owner_reply text,
  is_read boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT order_reviews_order_unique UNIQUE (order_id)
);

-- Enable RLS
ALTER TABLE public.order_reviews ENABLE ROW LEVEL SECURITY;

-- Policies for order_reviews
DROP POLICY IF EXISTS "Everyone can view order reviews" ON public.order_reviews;
CREATE POLICY "Everyone can view order reviews"
ON public.order_reviews FOR SELECT
USING (true);

DROP POLICY IF EXISTS "Customers and staff can insert reviews" ON public.order_reviews;
CREATE POLICY "Customers and staff can insert reviews"
ON public.order_reviews FOR INSERT
WITH CHECK (true);

DROP POLICY IF EXISTS "Staff can update order reviews" ON public.order_reviews;
CREATE POLICY "Staff can update order reviews"
ON public.order_reviews FOR UPDATE
USING (true);

DROP POLICY IF EXISTS "Staff can delete order reviews" ON public.order_reviews;
CREATE POLICY "Staff can delete order reviews"
ON public.order_reviews FOR DELETE
USING (true);

-- Index for sorting and average calculation
CREATE INDEX IF NOT EXISTS order_reviews_food_rating_idx ON public.order_reviews (food_rating, created_at DESC);

-- Enable Supabase Realtime publication for order_reviews
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.order_reviews;
  END IF;
EXCEPTION
  WHEN OTHERS THEN NULL;
END $$;

NOTIFY pgrst, 'reload schema';
