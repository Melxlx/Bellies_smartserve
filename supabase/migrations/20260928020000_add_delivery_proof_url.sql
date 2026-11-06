-- Add delivery_proof_url column to orders table
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS delivery_proof_url text;

-- Create storage bucket for delivery proof photos if storage schema exists
INSERT INTO storage.buckets (id, name, public)
VALUES ('delivery_proofs', 'delivery_proofs', true)
ON CONFLICT (id) DO NOTHING;

-- Storage policies for delivery_proofs bucket
DROP POLICY IF EXISTS "Public View Delivery Proofs" ON storage.objects;
CREATE POLICY "Public View Delivery Proofs"
ON storage.objects FOR SELECT
USING (bucket_id = 'delivery_proofs');

DROP POLICY IF EXISTS "Staff Upload Delivery Proofs" ON storage.objects;
CREATE POLICY "Staff Upload Delivery Proofs"
ON storage.objects FOR INSERT
WITH CHECK (bucket_id = 'delivery_proofs');

DROP POLICY IF EXISTS "Staff Update Delivery Proofs" ON storage.objects;
CREATE POLICY "Staff Update Delivery Proofs"
ON storage.objects FOR UPDATE
USING (bucket_id = 'delivery_proofs');
