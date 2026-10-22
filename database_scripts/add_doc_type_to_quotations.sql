-- Add doc_type column to quotations table
ALTER TABLE public.quotations 
ADD COLUMN IF NOT EXISTS doc_type text DEFAULT 'Quote';

-- Optional: Add a check constraint to ensure valid types
-- ALTER TABLE public.quotations ADD CONSTRAINT check_doc_type CHECK (doc_type IN ('Quote', 'Proforma'));
