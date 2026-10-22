-- Create Quotations Table
create table if not exists public.quotations (
    quote_id text not null primary key,
    created_at timestamp with time zone default timezone('utc'::text, now()) not null,
    tenant_id text not null,
    customer_name text not null,
    client_id text,
    date timestamp with time zone not null,
    expiry_date timestamp with time zone not null,
    total_amount double precision not null default 0,
    status text not null default 'Draft', -- Draft, Sent, Accepted, Expired, Converted
    items jsonb not null default '[]'::jsonb,
    quote_number text not null,
    notes text,
    whatsapp_number text,
    tax_percentage double precision default 0
);

-- Enable Row Level Security (RLS)
alter table public.quotations enable row level security;

-- Create Policies (assuming tenant isolation required)
-- Drop existing policies to avoid conflicts
drop policy if exists "Users can view their own tenant's quotations" on public.quotations;
drop policy if exists "Users can insert quotations for their tenant" on public.quotations;
drop policy if exists "Users can update their own tenant's quotations" on public.quotations;
drop policy if exists "Users can delete their own tenant's quotations" on public.quotations;

create policy "Users can view their own tenant's quotations"
    on public.quotations for select
    using (auth.uid() in (
        select uid from public.users where tenant_id = quotations.tenant_id
    ));

create policy "Users can insert quotations for their tenant"
    on public.quotations for insert
    with check (auth.uid() in (
        select uid from public.users where tenant_id = quotations.tenant_id
    ));

create policy "Users can update their own tenant's quotations"
    on public.quotations for update
    using (auth.uid() in (
        select uid from public.users where tenant_id = quotations.tenant_id
    ));

create policy "Users can delete their own tenant's quotations"
    on public.quotations for delete
    using (auth.uid() in (
        select uid from public.users where tenant_id = quotations.tenant_id
    ));

-- Enable Realtime for Quotations Table
alter publication supabase_realtime add table quotations;

-- Create function for Public Quote View (if needed for non-authenticated link sharing)
create or replace function get_public_quote(quote_uuid text)
returns json
language plpgsql
security definer
as $$
declare
  result json;
begin
  select row_to_json(q) into result
  from quotations q
  where q.quote_id = quote_uuid;
  return result;
end;
$$;
