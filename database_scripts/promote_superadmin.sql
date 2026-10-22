-- PROMOTING A USER TO SUPERADMIN
-- Fixed script for 'admin@dg.com'

UPDATE public.users
SET role = 'superAdmin'
WHERE email = 'admin@dg.com';

-- Verify the change
SELECT * FROM public.users WHERE role = 'superAdmin';
