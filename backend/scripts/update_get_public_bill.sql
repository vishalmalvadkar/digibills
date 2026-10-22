-- ROBUST FIX for Public Bill/Quote Access
-- 1. Ensure columns exist
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'bills' AND column_name = 'created_by') THEN
        ALTER TABLE public.bills ADD COLUMN created_by uuid DEFAULT auth.uid();
    END IF;

    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'quotations' AND column_name = 'created_by') THEN
        ALTER TABLE public.quotations ADD COLUMN created_by uuid DEFAULT auth.uid();
    END IF;
END $$;

-- 2. Clean up ALL potential old function signatures to prevent conflicts
DROP FUNCTION IF EXISTS public.get_public_bill(text);
DROP FUNCTION IF EXISTS public.get_public_bill(uuid);
DROP FUNCTION IF EXISTS public.get_public_quote(text);
DROP FUNCTION IF EXISTS public.get_public_quote(uuid);

-- 3. Re-create functions SAFE and ROBUST

-- Function to get Public Bill + created_by
CREATE OR REPLACE FUNCTION public.get_public_bill(p_bill_id text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public -- Security Best Practice
AS $$
DECLARE
    v_result jsonb;
BEGIN
    -- Use raw row_to_json to be safe, then cast to jsonb
    -- We assume the bill_id is text or castable.
    -- If bill_id column is UUID, p_bill_id string will auto-cast if valid, or fail if invalid.
    -- But since we handle legacy text IDs, bill_id column is likely Text.
    SELECT to_jsonb(b.*) INTO v_result
    FROM public.bills b
    WHERE b.bill_id = p_bill_id;
    
    RETURN v_result;
END;
$$;

-- Function to get Public Quote + created_by
CREATE OR REPLACE FUNCTION public.get_public_quote(quote_uuid text)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  result json;
BEGIN
  SELECT row_to_json(q) INTO result
  FROM public.quotations q
  WHERE q.quote_id = quote_uuid;
  return result;
END;
$$;

-- 4. Grant access (just in case)
GRANT EXECUTE ON FUNCTION public.get_public_bill(text) TO anon;
GRANT EXECUTE ON FUNCTION public.get_public_bill(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_public_quote(text) TO anon;
GRANT EXECUTE ON FUNCTION public.get_public_quote(text) TO authenticated;
