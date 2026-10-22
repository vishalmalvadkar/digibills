-- Create supplier_bills table
CREATE TABLE IF NOT EXISTS public.supplier_bills (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    supplier_name text NOT NULL,
    supplier_gst text,
    invoice_number text,
    date timestamp with time zone NOT NULL,
    total_amount numeric NOT NULL DEFAULT 0,
    tax_amount numeric NOT NULL DEFAULT 0,
    cgst_amount numeric DEFAULT 0,
    sgst_amount numeric DEFAULT 0,
    igst_amount numeric DEFAULT 0,
    items jsonb DEFAULT '[]'::jsonb,
    category text,
    notes text,
    tenant_id text NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    
    CONSTRAINT supplier_bills_pkey PRIMARY KEY (id)
);

-- Enable Row Level Security
ALTER TABLE public.supplier_bills ENABLE ROW LEVEL SECURITY;

-- Create Policy: Tenants can only see their own Bills
CREATE POLICY "Enable all access for tenant users based on tenant_id" ON public.supplier_bills
    FOR ALL
    TO public
    USING (auth.uid() IN ( 
        SELECT uid FROM public.users WHERE tenant_id = supplier_bills.tenant_id
    ))
    WITH CHECK (auth.uid() IN ( 
        SELECT uid FROM public.users WHERE tenant_id = supplier_bills.tenant_id
    ));

-- Enable Realtime
alter publication supabase_realtime add table supplier_bills;
