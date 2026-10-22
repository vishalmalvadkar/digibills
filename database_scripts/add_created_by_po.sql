-- Add created_by column to purchase_orders table if it doesn't exist
DO $$ 
BEGIN 
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'purchase_orders' AND column_name = 'created_by') THEN 
        ALTER TABLE public.purchase_orders ADD COLUMN created_by uuid REFERENCES auth.users(id); 
    END IF; 
END $$;
