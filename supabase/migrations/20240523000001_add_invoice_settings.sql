-- Add invoice settings columns to settings table
ALTER TABLE public.settings 
ADD COLUMN IF NOT EXISTS invoice_prefix text DEFAULT 'INV-',
ADD COLUMN IF NOT EXISTS invoice_start_number bigint DEFAULT 1;
