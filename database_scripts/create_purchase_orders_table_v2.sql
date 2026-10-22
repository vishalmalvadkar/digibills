-- Create purchase_orders table
CREATE TABLE IF NOT EXISTS public.purchase_orders (
    po_id uuid NOT NULL DEFAULT gen_random_uuid(),
    po_number text NOT NULL,
    vendor_name text NOT NULL,
    vendor_contact text,
    vendor_address text,
    vendor_gst text,
    date timestamp with time zone NOT NULL DEFAULT now(),
    expected_delivery_date timestamp with time zone,
    status text NOT NULL DEFAULT 'Draft', -- Draft, Sent, Received, Cancelled
    total_amount numeric NOT NULL DEFAULT 0,
    items jsonb DEFAULT '[]'::jsonb,
    notes text,
    tenant_id uuid NOT NULL, -- Link to specific tenant
    created_at timestamp with time zone DEFAULT now(),
    
    CONSTRAINT purchase_orders_pkey PRIMARY KEY (po_id)
);

-- Enable Row Level Security
ALTER TABLE public.purchase_orders ENABLE ROW LEVEL SECURITY;

-- Create Policy: Tenants can only see their own POs
-- Dropping existing policy if it exists to allow re-run
DROP POLICY IF EXISTS "Enable all access for tenant users based on tenant_id" ON public.purchase_orders;

CREATE POLICY "Enable all access for tenant users based on tenant_id" ON public.purchase_orders
    AS PERMISSIVE FOR ALL
    TO public
    USING (auth.uid() IN ( 
        SELECT uid FROM public.users WHERE tenant_id = CAST(purchase_orders.tenant_id AS text)
        -- Note: If users.tenant_id is uuid, remove CAST. If string, keep it. 
        -- Based on other files, tenant_id seems to be uuid in some, text in others. 
        -- Quotations table uses text for tenant_id. User model says String.
        -- Let's check quotations table again. It says 'tenant_id text not null'.
        -- Purchase orders I defined as 'tenant_id uuid'. This might be a mismatch.
        -- Usage in Dart: `tenantId` is String.
        -- I will change purchase_orders.tenant_id to TEXT to match Quotations and avoid type issues.
    ))
    WITH CHECK (auth.uid() IN ( 
        SELECT uid FROM public.users WHERE tenant_id = CAST(purchase_orders.tenant_id AS text)
    ));

-- Enable Realtime
alter publication supabase_realtime add table purchase_orders;
