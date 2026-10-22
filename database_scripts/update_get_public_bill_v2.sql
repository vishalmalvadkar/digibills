-- v2 ROBUST FIX for Public Bill/Quote Access
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

-- 2. Drop OLD functions to prevent signature conflicts
DROP FUNCTION IF EXISTS public.get_public_bill(text);
DROP FUNCTION IF EXISTS public.get_public_bill(uuid);
DROP FUNCTION IF EXISTS public.get_public_quote(text);
DROP FUNCTION IF EXISTS public.get_public_quote(uuid);

-- 3. Create Functions with RELATION FETCHING (Items + Payments)
-- This ensures the App gets a Full Bill Object, not just the header.

CREATE OR REPLACE FUNCTION public.get_public_bill(p_bill_id text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_result jsonb;
BEGIN
    SELECT jsonb_build_object(
        'bill_id', b.bill_id,
        'tenant_id', b.tenant_id,
        'created_by', b.created_by,
        'client_id', b.client_id,
        'customer_name', b.customer_name,
        'invoice_number', b.invoice_number,
        'bill_date', b.bill_date,
        'created_at', b.created_at,
        'total_amount', b.total_amount,
        'tax_amount', b.tax_amount,
        'advance_amount', b.advance_amount,
        'status', b.payment_status,
        'payment_status', b.payment_status,
        'whatsapp_number', b.whatsapp_number,
        'client_address', b.client_address,
        -- Fetch Items
        'bill_items', (
            SELECT jsonb_agg(to_jsonb(i.*)) 
            FROM public.bill_items i 
            WHERE i.bill_id::text = b.bill_id::text
        ),
        -- Fetch Payments
        'bill_payments', (
            SELECT jsonb_agg(to_jsonb(p.*)) 
            FROM public.bill_payments p 
            WHERE p.bill_id::text = b.bill_id::text
        )
    ) INTO v_result
    FROM public.bills b
    WHERE b.bill_id::text = p_bill_id; -- Robust Cast
    
    RETURN v_result;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_public_quote(quote_uuid text)
RETURNS jsonb -- Changed to jsonb for consistency
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_result jsonb;
BEGIN
  SELECT jsonb_build_object(
      'quote_id', q.quote_id,
      'tenant_id', q.tenant_id,
      'created_by', q.created_by,
      'client_id', q.client_id,
      'customer_name', q.customer_name,
      'quote_number', q.quote_number,
      'date', q.date,
      'expiry_date', q.expiry_date,
      'total_amount', q.total_amount,
      'status', q.status,
      'doc_type', q.doc_type,
      'whatsapp_number', q.whatsapp_number,
      'items', q.items -- JSONB column, direct usage
  ) INTO v_result
  FROM public.quotations q
  WHERE q.quote_id::text = quote_uuid; -- Robust Cast
  
  RETURN v_result;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_public_po(p_po_id text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_result jsonb;
BEGIN
    SELECT jsonb_build_object(
        'po_id', po.po_id,
        'tenant_id', po.tenant_id,
        'po_number', po.po_number,
        'vendor_name', po.vendor_name,
        'vendor_contact', po.vendor_contact,
        'vendor_address', po.vendor_address,
        'vendor_gst', po.vendor_gst,
        'date', po.date,
        'expected_delivery_date', po.expected_delivery_date,
        'status', po.status,
        'total_amount', po.total_amount,
        'notes', po.notes,
        'tax_percentage', po.tax_percentage,
        'items', (
            SELECT jsonb_agg(to_jsonb(i.*)) 
            FROM public.bill_items i 
            WHERE i.bill_id::text = po.po_id::text -- Items stored in common bill_items table linked by ID
        )
    ) INTO v_result
    FROM public.purchase_orders po
    WHERE po.po_id::text = p_po_id;

    RETURN v_result;
END;
$$;

-- 4. BACKFILL existing records (Fixes logic for old bills)
-- If created_by is NULL, try to use the tenant_id owner (Vendor)
UPDATE public.bills 
SET created_by = (SELECT uid FROM public.users WHERE tenant_id = bills.tenant_id LIMIT 1) 
WHERE created_by IS NULL;

UPDATE public.quotations 
SET created_by = (SELECT uid FROM public.users WHERE tenant_id = quotations.tenant_id LIMIT 1) 
WHERE created_by IS NULL;

-- 5. Permissions
GRANT EXECUTE ON FUNCTION public.get_public_bill(text) TO anon;
GRANT EXECUTE ON FUNCTION public.get_public_bill(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_public_quote(text) TO anon;
GRANT EXECUTE ON FUNCTION public.get_public_quote(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_public_po(text) TO anon;
GRANT EXECUTE ON FUNCTION public.get_public_po(text) TO authenticated;
