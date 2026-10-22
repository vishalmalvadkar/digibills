-- v8 FINAL ROBUST BRANDING RPC (Type Casting Fix)
-- Ensure we handle UUID vs Text comparisons robustly
-- And ensure we prioritize Client Name correctly.

CREATE OR REPLACE FUNCTION public.get_public_settings(p_tenant_id text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_result jsonb;
    v_business_name text;
    v_boss_id text;
BEGIN
    -- 1. FETCH PRIMARY SETTINGS (Logo, Bank, etc.)
    -- User might have saved settings in 'settings' table.
    SELECT to_jsonb(s.*) INTO v_result
    FROM public.settings s
    WHERE s.user_id::text = p_tenant_id;

    -- 2. IDENTIFY BUSINESS NAME PRIORITY
    
    -- A. Try Settings Table First (Explicit User Override)
    IF v_result IS NOT NULL AND (v_result->>'tenant_name' IS NOT NULL AND v_result->>'tenant_name' <> 'Start-Up Agency' AND v_result->>'tenant_name' <> '') THEN
        v_business_name := v_result->>'tenant_name';
    END IF;

    -- B. Fallback to Clients Table (Admin/License Name)
    -- CRITICAL FIX: Cast both sides to text explicitly for safety
    IF v_business_name IS NULL OR v_business_name = '' OR v_business_name = 'Start-Up Agency' THEN
        SELECT business_name INTO v_business_name
        FROM public.clients 
        WHERE client_id::text = p_tenant_id
        AND business_name IS NOT NULL 
        AND business_name <> ''
        LIMIT 1;
    END IF;

    -- C. Fallback to Users Table Profile Name
    IF v_business_name IS NULL OR v_business_name = '' OR v_business_name = 'Start-Up Agency' THEN
        SELECT name, tenant_id::text INTO v_business_name, v_boss_id
        FROM public.users
        WHERE uid::text = p_tenant_id
        LIMIT 1;

        -- If this user is just a Staff member (tenant_id != uid), try to get Boss's branding
        IF v_boss_id IS NOT NULL AND v_boss_id <> p_tenant_id THEN
             -- Try Boss Settings
             IF v_result IS NULL THEN
                 SELECT to_jsonb(s.*) INTO v_result
                 FROM public.settings s
                 WHERE s.user_id::text = v_boss_id;
             END IF;
             
             -- Try Boss Client Name
             IF v_business_name IS NULL OR v_business_name = '' OR v_business_name = 'Start-Up Agency' THEN
                SELECT business_name INTO v_business_name
                FROM public.clients 
                WHERE client_id::text = v_boss_id
                LIMIT 1;
             END IF;
        END IF;
    END IF;

    -- 3. FINAL DEFAULT
    IF v_business_name IS NULL OR v_business_name = '' THEN
        v_business_name := 'Start-Up Agency';
    END IF;

    -- 4. CONSTRUCT FINAL RESPONSE
    IF v_result IS NULL THEN
        v_result := jsonb_build_object(
            'tenant_name', v_business_name,
            'user_id', p_tenant_id
        );
    ELSE
        -- Inject the resolved name into the result
        v_result := v_result || jsonb_build_object('tenant_name', v_business_name);
    END IF;

    RETURN v_result;
END;
$$;
