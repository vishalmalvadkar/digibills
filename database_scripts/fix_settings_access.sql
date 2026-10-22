-- FIX SETTINGS ACCESS RLS (FIXED v2 with Type Casting)
-- Allows authenticated users to see the settings of their Tenant

-- 1. Ensure RLS is enabled on settings
ALTER TABLE public.settings ENABLE ROW LEVEL SECURITY;

-- 2. Drop existing restrictive policies to avoid conflicts
DROP POLICY IF EXISTS "Enable read access for all users in same tenant" ON public.settings;

-- 3. Create a policy with explicit type casting (text = uuid fix)
CREATE POLICY "Enable read access for all users in same tenant" 
ON public.settings FOR SELECT 
USING (
  user_id::text = auth.uid()::text OR 
  EXISTS (
    SELECT 1 FROM public.users 
    WHERE users.uid::text = auth.uid()::text AND users.tenant_id::text = settings.user_id::text
  )
);

-- 4. Sync tenant_id for existing clients if missing
-- Explicitly cast both sides to text to prevent "operator does not exist" error
UPDATE public.users u
SET tenant_id = c.tenant_id
FROM public.clients c
WHERE u.uid::text = c.client_id::text
AND (u.tenant_id IS NULL OR u.tenant_id::text = u.uid::text OR u.tenant_id = '');

-- 5. Final check on users table
SELECT uid, role, tenant_id FROM public.users LIMIT 10;
