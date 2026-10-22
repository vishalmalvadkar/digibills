-- CLEANUP PUBLIC FEATURES (WhatsApp/Public Link Logic)
-- Dropping functions as requested by user to remove flawed implementation.

DROP FUNCTION IF EXISTS public.get_public_bill(text);
DROP FUNCTION IF EXISTS public.get_public_bill(uuid);

DROP FUNCTION IF EXISTS public.get_public_quote(text);
DROP FUNCTION IF EXISTS public.get_public_quote(uuid);

DROP FUNCTION IF EXISTS public.get_public_po(text);
DROP FUNCTION IF EXISTS public.get_public_po(uuid);

DROP FUNCTION IF EXISTS public.get_public_settings(text);
