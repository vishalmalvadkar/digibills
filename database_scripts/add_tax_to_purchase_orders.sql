-- Add tax_percentage column to purchase_orders table
ALTER TABLE public.purchase_orders 
ADD COLUMN IF NOT EXISTS tax_percentage double precision DEFAULT 0;
