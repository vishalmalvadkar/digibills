-- Add place_of_supply column to quotations table if it doesn't exist
DO $$ 
BEGIN 
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'quotations' AND column_name = 'place_of_supply') THEN 
        ALTER TABLE public.quotations ADD COLUMN place_of_supply text DEFAULT ''; 
    END IF; 
END $$;
