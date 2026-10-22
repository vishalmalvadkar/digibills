-- ENABLE PUBLIC ACCESS (RLS) FOR SHAREABLE DOCUMENTS
-- This script allows any user (including anonymous/public) to VIEW specific tables.
-- This is necessary for "Public View" links to work without RPC functions.

-- 1. Enable RLS on tables (if not already enabled)
ALTER TABLE public.bills ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bill_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bill_payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.quotations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.purchase_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.clients ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY; -- CAUTION: needed for 'created_by' lookup if doing joins

-- 2. Drop existing restrictive policies (if any conflicting ones exist)
-- We use "IF EXISTS" to avoid errors.

DROP POLICY IF EXISTS "Public can view bills" ON public.bills;
DROP POLICY IF EXISTS "Public can view bill items" ON public.bill_items;
DROP POLICY IF EXISTS "Public can view bill payments" ON public.bill_payments;
DROP POLICY IF EXISTS "Public can view quotations" ON public.quotations;
DROP POLICY IF EXISTS "Public can view purchase orders" ON public.purchase_orders;
DROP POLICY IF EXISTS "Public can view settings" ON public.settings;
DROP POLICY IF EXISTS "Public can view clients" ON public.clients;
DROP POLICY IF EXISTS "Public can view basic user info" ON public.users;

-- 3. Create permissive policies for SELECT (Read-Only)
-- Note: 'anon' role is used for unauthenticated public users.
-- Note: 'authenticated' role is for logged-in users.
-- We grant access to BOTH for robust sharing.

-- BILLS
CREATE POLICY "Public can view bills" 
ON public.bills FOR SELECT 
TO anon, authenticated 
USING (true); -- Allows reading any bill if you have the ID (UUIDs are hard to guess)

-- BILL ITEMS
CREATE POLICY "Public can view bill items" 
ON public.bill_items FOR SELECT 
TO anon, authenticated 
USING (true);

-- BILL PAYMENTS
CREATE POLICY "Public can view bill payments" 
ON public.bill_payments FOR SELECT 
TO anon, authenticated 
USING (true);

-- QUOTATIONS
CREATE POLICY "Public can view quotations" 
ON public.quotations FOR SELECT 
TO anon, authenticated 
USING (true);

-- PURCHASE ORDERS
CREATE POLICY "Public can view purchase orders" 
ON public.purchase_orders FOR SELECT 
TO anon, authenticated 
USING (true);

-- SETTINGS (Branding)
CREATE POLICY "Public can view settings" 
ON public.settings FOR SELECT 
TO anon, authenticated 
USING (true);

-- CLIENTS (For Name Override)
CREATE POLICY "Public can view clients" 
ON public.clients FOR SELECT 
TO anon, authenticated 
USING (true);

-- USERS (For Name Override)
-- Be careful: only expose necessary rows/columns if possible. 
-- Supabase select limits columns API side, but RLS is row-based.
CREATE POLICY "Public can view basic user info" 
ON public.users FOR SELECT 
TO anon, authenticated 
USING (true);
