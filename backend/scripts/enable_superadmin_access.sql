-- COMPREHENSIVE SUPERADMIN RLS FIX
-- This script ensures Superadmin has FULL access to all tables

-- 1. Create/Replace the helper function
CREATE OR REPLACE FUNCTION public.is_superadmin()
RETURNS boolean AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.users 
    WHERE uid::text = auth.uid()::text AND role = 'superAdmin'
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;


-- 2. Enable RLS on tables (if not already)
ALTER TABLE public.clients ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;


-- 3. DROP existing conflicting policies (ignore errors if they don't exist)
DROP POLICY IF EXISTS "Superadmin can view all clients" ON public.clients;
DROP POLICY IF EXISTS "Superadmin can update all clients" ON public.clients;
DROP POLICY IF EXISTS "Superadmin can delete clients" ON public.clients;
DROP POLICY IF EXISTS "Superadmin can insert clients" ON public.clients;

DROP POLICY IF EXISTS "Superadmin can view all users" ON public.users;
DROP POLICY IF EXISTS "Superadmin can update all users" ON public.users;


-- 4. CREATE POLICIES FOR 'clients' TABLE
-- SELECT
CREATE POLICY "Superadmin can view all clients"
ON public.clients FOR SELECT
USING ( is_superadmin() );

-- UPDATE
CREATE POLICY "Superadmin can update all clients"
ON public.clients FOR UPDATE
USING ( is_superadmin() )
WITH CHECK ( is_superadmin() );

-- DELETE
CREATE POLICY "Superadmin can delete clients"
ON public.clients FOR DELETE
USING ( is_superadmin() );

-- INSERT
CREATE POLICY "Superadmin can insert clients"
ON public.clients FOR INSERT
WITH CHECK ( is_superadmin() );


-- 5. CREATE POLICIES FOR 'users' TABLE
CREATE POLICY "Superadmin can view all users"
ON public.users FOR SELECT
USING ( is_superadmin() );

CREATE POLICY "Superadmin can update all users"
ON public.users FOR UPDATE
USING ( is_superadmin() )
WITH CHECK ( is_superadmin() );


-- 6. Verify policies exist
SELECT tablename, policyname FROM pg_policies WHERE schemaname = 'public';
