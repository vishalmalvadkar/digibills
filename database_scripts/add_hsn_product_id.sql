-- Add hsn_code and product_id to bill_items table
-- This script ensures columns exist to prevent "column not found" errors.

DO $$ 
BEGIN
    -- Add hsn_code if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'bill_items' AND column_name = 'hsn_code') THEN
        ALTER TABLE public.bill_items ADD COLUMN hsn_code text;
    END IF;

    -- Add product_id if it doesn't exist
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'bill_items' AND column_name = 'product_id') THEN
        ALTER TABLE public.bill_items ADD COLUMN product_id text; 
    END IF;
END $$;
