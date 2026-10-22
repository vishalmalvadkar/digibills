-- Add customer_email column to quotations table
alter table public.quotations 
add column if not exists customer_email text;
