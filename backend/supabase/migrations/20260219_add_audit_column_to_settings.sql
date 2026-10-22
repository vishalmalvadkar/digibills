-- Add is_audit_trail_enabled column to settings table
alter table public.settings 
add column if not exists is_audit_trail_enabled boolean default false;

-- Update existing rows to have a default value (optional but good practice)
update public.settings 
set is_audit_trail_enabled = false 
where is_audit_trail_enabled is null;
