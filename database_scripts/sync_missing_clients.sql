-- SYNC MISSING CLIENTS (v3 Fixed Types)
-- Included casts to ::text for UUID fields to prevent Type Mismatch errors

-- 1. FIX SCHEMA: Add missing columns required by the App
ALTER TABLE public.clients ADD COLUMN IF NOT EXISTS tax_percentage double precision DEFAULT 0.0;
ALTER TABLE public.clients ADD COLUMN IF NOT EXISTS advances jsonb DEFAULT '[]'::jsonb;
ALTER TABLE public.clients ADD COLUMN IF NOT EXISTS amount double precision DEFAULT 0.0;
ALTER TABLE public.clients ADD COLUMN IF NOT EXISTS payment_status text DEFAULT 'Pending';


-- 2. SYNC: Find users missing from 'clients' and create them
INSERT INTO public.clients (
    client_id,
    tenant_id,
    business_name,
    owner_name,
    email,
    whatsapp_number,
    license,
    status,
    amount,
    payment_mode,
    payment_status,
    tax_percentage,
    advances,
    created_at
)
SELECT 
    u.uid::text,            -- CAST UUID TO TEXT
    u.uid::text,            -- CAST UUID TO TEXT
    COALESCE(u.name, 'New Business'), 
    COALESCE(u.name, 'Owner'),        
    u.email,
    '',                     
    '{"plan": "trial", "isActive": true, "endDate": "2026-12-31T00:00:00.000", "startDate": "2024-01-01T00:00:00.000"}'::jsonb, 
    'active',
    0.0,
    'Cash',
    'Pending',
    0.0,
    '[]'::jsonb,
    NOW()
FROM public.users u
WHERE u.role != 'superAdmin' 
  AND NOT EXISTS (
    SELECT 1 FROM public.clients c WHERE c.client_id::text = u.uid::text -- Explicit comparison
  );

-- Verify
SELECT count(*) as new_clients_created FROM public.clients;
