-- ENABLE SUPABASE REALTIME FOR TABLES
-- This enables automatic updates in StreamBuilder when data changes

-- Enable realtime for clients table
ALTER PUBLICATION supabase_realtime ADD TABLE public.clients;

-- Enable realtime for users table (if needed)
ALTER PUBLICATION supabase_realtime ADD TABLE public.users;

-- Verify which tables have realtime enabled
SELECT * FROM pg_publication_tables WHERE pubname = 'supabase_realtime';
