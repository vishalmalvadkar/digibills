-- Add client_city column to bills table
ALTER TABLE bills 
ADD COLUMN IF NOT EXISTS client_city TEXT;

-- Optional: Add index if needed for filtering by city later
-- CREATE INDEX IF NOT EXISTS idx_bills_client_city ON bills(client_city);
