-- Smart Public Settings RPC
-- Mimics the logic of SettingsService.fetchSettings but on the server side for public access.
-- Logic:
-- 1. Fetch base settings for the tenant_id (Vendor/Admin).
-- 2. If created_by is provided, check if that user is a Client.
-- 3. If Client, override tenant_name with clients.business_name.

CREATE OR REPLACE FUNCTION public.get_public_settings_v2(p_tenant_id uuid, p_created_by uuid DEFAULT NULL)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_settings jsonb;
    v_client_name text;
    v_user_name text;
BEGIN
    -- 1. Fetch Base Settings (from settings table using tenant_id)
    SELECT to_jsonb(s.*) INTO v_settings
    FROM public.settings s
    WHERE s.user_id = p_tenant_id;

    -- If no settings found, creates a default structure (or leave null to be handled by app)
    -- But let's assume the app handles null v_settings by using defaults.
    -- However, we want to start with something if we can.
    
    IF v_settings IS NULL THEN
        -- Create a minimal default object matching AppSettings structure
        v_settings := jsonb_build_object(
            'tenant_name', 'Start-Up Agency',
            'user_id', p_tenant_id
        );
    END IF;

    -- 2. Check for Client Override
    IF p_created_by IS NOT NULL THEN
        -- Check if user is a client and has a business name
        SELECT c.business_name INTO v_client_name
        FROM public.clients c
        WHERE c.client_id = p_created_by;

        -- Also fetch user name as fallback
        SELECT u.name INTO v_user_name
        FROM public.users u
        WHERE u.uid = p_created_by;

        IF v_client_name IS NOT NULL AND v_client_name <> '' THEN
            -- Override Name
            v_settings := v_settings || jsonb_build_object('tenant_name', v_client_name);
        ELSIF v_user_name IS NOT NULL AND v_user_name <> '' THEN
             -- Fallback to user name if client has no business name (or if not a client but just a user)
             -- Logic in Dart: if role == 'client' ...
             -- Here we can just see: if the base settings is 'Start-Up Agency' OR we want to show the creator's name?
             -- Usually, if it's a staff member, we show the Company Name (Settings).
             -- If it's a Client, we show the Client's Name.
             
             -- Let's check role to be safe?
             IF EXISTS (SELECT 1 FROM public.users WHERE uid = p_created_by AND role = 'client') THEN
                 v_settings := v_settings || jsonb_build_object('tenant_name', v_user_name);
             END IF;
        END IF;
    END IF;

    RETURN v_settings;
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION public.get_public_settings_v2(uuid, uuid) TO anon, authenticated, service_role;
