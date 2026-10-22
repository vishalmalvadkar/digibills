-- ENABLE PUBLIC ACCESS TO QUOTATIONS (FIXED v2)
-- This creates RPC functions that allow unauthenticated users to view shared quotes

-- 1. Create RPC function for public quote access
-- Using TEXT instead of UUID to match the actual database column type
CREATE OR REPLACE FUNCTION public.get_public_quote(quote_uuid text)
RETURNS jsonb AS $$
DECLARE
    result jsonb;
BEGIN
    SELECT to_jsonb(q.*) INTO result
    FROM public.quotations q
    WHERE q.quote_id::text = quote_uuid;
    
    RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission to anonymous users (for public links)
GRANT EXECUTE ON FUNCTION public.get_public_quote(text) TO anon;
GRANT EXECUTE ON FUNCTION public.get_public_quote(text) TO authenticated;


-- 2. Enable RLS on quotations if not already
ALTER TABLE public.quotations ENABLE ROW LEVEL SECURITY;

-- 3. The function uses SECURITY DEFINER so it bypasses RLS


-- 4. Create public settings function (DEEP MULTI-TENANT FALLBACK)
-- This function is 'Excellent' because it finds branding even if the document was created by a staff member.
CREATE OR REPLACE FUNCTION public.get_public_settings(p_tenant_id text)
RETURNS jsonb AS $$
DECLARE
    result jsonb;
    v_boss_id text;
    v_target_name text;
BEGIN
    -- 1. Try to find settings for the ID directly
    SELECT to_jsonb(s.*) INTO result
    FROM public.settings s
    WHERE s.user_id = p_tenant_id;
    
    -- 2. If settings missing OR the business name is default, we dig deeper
    IF result IS NULL OR (result->>'tenant_name' = 'Start-Up Agency') THEN
    
        -- A. Find the 'Boss' ID (tenant_id) from the users table
        SELECT tenant_id INTO v_boss_id
        FROM public.users
        WHERE uid = p_tenant_id
        LIMIT 1;

        -- B. If this user HAS a boss, try to get the Boss's settings
        IF v_boss_id IS NOT NULL AND v_boss_id <> p_tenant_id THEN
            SELECT to_jsonb(s.*) INTO result
            FROM public.settings s
            WHERE s.user_id = v_boss_id;
        END IF;

        -- C. If we STILL don't have settings, try to find ANY name we can
        IF result IS NULL OR (result->>'tenant_name' = 'Start-Up Agency') THEN
            
            -- Try Clients table (Primary Business Name source)
            SELECT business_name INTO v_target_name
            FROM public.clients 
            WHERE client_id = COALESCE(v_boss_id, p_tenant_id)
            LIMIT 1;

            -- Try Users table (Profile Name)
            IF v_target_name IS NULL THEN
                SELECT name INTO v_target_name
                FROM public.users
                WHERE uid = COALESCE(v_boss_id, p_tenant_id)
                LIMIT 1;
            END IF;

            -- Inject the found name into the object
            IF v_target_name IS NOT NULL THEN
                IF result IS NULL THEN
                    result := jsonb_build_object('tenant_name', v_target_name);
                ELSE
                    result := result || jsonb_build_object('tenant_name', v_target_name);
                END IF;
            END IF;
        END IF;
    END IF;

    -- Ensure we never return absolute NULL if possible
    IF result IS NULL THEN
        result := jsonb_build_object('tenant_name', 'Start-Up Agency');
    END IF;

    RETURN result;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.get_public_settings(text) TO anon;
GRANT EXECUTE ON FUNCTION public.get_public_settings(text) TO authenticated;


-- 5. Directly Access Quote (Unchanged but ensuring it is here)
CREATE OR REPLACE FUNCTION public.get_quote_by_id(p_quote_id text)
RETURNS jsonb AS $$
BEGIN
    RETURN (
        SELECT to_jsonb(q.*)
        FROM public.quotations q
        WHERE q.quote_id = p_quote_id
        LIMIT 1
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.get_quote_by_id(text) TO anon;
GRANT EXECUTE ON FUNCTION public.get_quote_by_id(text) TO authenticated;


-- Verify functions exist
SELECT proname, proargtypes FROM pg_proc WHERE proname IN ('get_public_quote', 'get_public_settings', 'get_quote_by_id');
