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
CREATE POLICY "Enable all access for tenant users based on tenant_id" ON public.purchase_orders
    AS PERMISSIVE FOR ALL
    TO public
    USING (auth.uid() IN ( 
        SELECT uid FROM public.users WHERE tenant_id = purchase_orders.tenant_id 
    ))
    WITH CHECK (auth.uid() IN ( 
        SELECT uid FROM public.users WHERE tenant_id = purchase_orders.tenant_id 
    ));

-- Create Policy: Simple fallback for development (optional, if user_roles logic is complex)
-- CREATE POLICY "Allow full access to authenticated users" ON public.purchase_orders
--    FOR ALL USING (auth.role() = 'authenticated');
