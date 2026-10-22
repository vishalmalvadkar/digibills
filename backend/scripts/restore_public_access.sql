-- RESTORE PUBLIC ACCESS RPCS
-- These functions allow unauthenticated access to specific documents via UUID.

DROP FUNCTION IF EXISTS public.get_public_bill(uuid);
DROP FUNCTION IF EXISTS public.get_public_quote(uuid);
DROP FUNCTION IF EXISTS public.get_public_po(uuid);
DROP FUNCTION IF EXISTS public.get_public_settings(uuid);

-- 1. Public Bill Access
CREATE OR REPLACE FUNCTION public.get_public_bill(id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    result json;
BEGIN
    SELECT row_to_json(t) INTO result
    FROM (
        SELECT * FROM public.bills WHERE bill_id = id
    ) t;
    RETURN result;
END;
$$;

-- 2. Public Quote Access
CREATE OR REPLACE FUNCTION public.get_public_quote(id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    result json;
BEGIN
    SELECT row_to_json(t) INTO result
    FROM (
        SELECT * FROM public.quotes WHERE quote_id = id
    ) t;
    RETURN result;
END;
$$;

-- 3. Public PO Access
CREATE OR REPLACE FUNCTION public.get_public_po(id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    result json;
BEGIN
    SELECT row_to_json(t) INTO result
    FROM (
        SELECT * FROM public.purchase_orders WHERE po_id = id
    ) t;
    RETURN result;
END;
$$;

-- 4. Public Settings Access (Fetch by Tenant/User ID)
-- This allows fetching the Business Name/Logo for the header.
CREATE OR REPLACE FUNCTION public.get_public_settings(target_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    result json;
BEGIN
    SELECT row_to_json(t) INTO result
    FROM (
        SELECT * FROM public.settings WHERE user_id = target_id
    ) t;
    RETURN result;
END;
$$;

-- GRANT EXECUTE TO PUBLIC (Anon)
GRANT EXECUTE ON FUNCTION public.get_public_bill(uuid) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_public_quote(uuid) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_public_po(uuid) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_public_settings(uuid) TO anon, authenticated, service_role;
