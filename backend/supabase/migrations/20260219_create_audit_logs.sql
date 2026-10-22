create table public.audit_logs (
  id uuid not null default gen_random_uuid (),
  entity_type text not null,
  entity_id text not null,
  action text not null,
  changes jsonb null,
  performed_by text not null,
  timestamp timestamp with time zone not null default now(),
  constraint audit_logs_pkey primary key (id)
);

alter table public.audit_logs enable row level security;

create policy "Enable read access for all users" on public.audit_logs for select using (true);
create policy "Enable insert access for authenticated users" on public.audit_logs for insert with check (auth.role() = 'authenticated');
