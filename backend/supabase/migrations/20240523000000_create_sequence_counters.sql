-- Create sequence_counters table to track invoice numbers
create table if not exists public.sequence_counters (
  tenant_id uuid not null references public.users(uid),
  entity_type text not null, -- 'INVOICE', 'QUOTE'
  prefix text,
  current_value bigint default 0,
  updated_at timestamp with time zone default now(),
  primary key (tenant_id, entity_type)
);

-- Enable RLS
alter table public.sequence_counters enable row level security;

-- Policy: Users can see and update their own counters
create policy "Users can manage their own counters"
  on public.sequence_counters
  for all
  using (auth.uid() = tenant_id)
  with check (auth.uid() = tenant_id);

-- RPC function for atomic increment
create or replace function public.increment_invoice_counter(
  p_tenant_id uuid,
  p_entity_type text
) returns bigint
language plpgsql
security definer
as $$
declare
  v_current bigint;
  v_new bigint;
begin
  -- Lock the row for update
  select current_value into v_current
  from public.sequence_counters
  where tenant_id = p_tenant_id and entity_type = p_entity_type
  for update;

  if not found then
    -- Initialize if missing (default start 0)
    insert into public.sequence_counters (tenant_id, entity_type, current_value)
    values (p_tenant_id, p_entity_type, 1)
    returning current_value into v_new;
  else
    v_new := v_current + 1;
    update public.sequence_counters
    set current_value = v_new, updated_at = now()
    where tenant_id = p_tenant_id and entity_type = p_entity_type;
  end if;

  return v_new;
end;
$$;
