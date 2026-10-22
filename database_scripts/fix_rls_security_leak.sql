-- CRITICAL SECURITY FIX
-- Revokes "Public View" policies that were too permissive (USING true).
-- Enforces Strict Tenant Isolation.

-- 1. Drop Permissive Policies
DROP POLICY IF EXISTS "Public can view bills" ON public.bills;
DROP POLICY IF EXISTS "Public can view bill items" ON public.bill_items;
DROP POLICY IF EXISTS "Public can view bill payments" ON public.bill_payments;
DROP POLICY IF EXISTS "Public can view quotations" ON public.quotations;
DROP POLICY IF EXISTS "Public can view purchase orders" ON public.purchase_orders;
DROP POLICY IF EXISTS "Public can view settings" ON public.settings;
DROP POLICY IF EXISTS "Public can view clients" ON public.clients;
DROP POLICY IF EXISTS "Public can view basic user info" ON public.users;

-- 2. Create Strict Tenant-Only Policies
-- Only allow users to see records where they are the owner or belong to the tenant.

-- BILLS: Authenticated Tenant Access Only
CREATE POLICY "Tenant Isolation: Bills Select" ON public.bills
FOR SELECT TO authenticated
USING (tenant_id = (select tenant_id from public.users where uid = auth.uid()));

CREATE POLICY "Tenant Isolation: Bills Insert" ON public.bills
FOR INSERT TO authenticated
WITH CHECK (tenant_id = (select tenant_id from public.users where uid = auth.uid()));

CREATE POLICY "Tenant Isolation: Bills Update" ON public.bills
FOR UPDATE TO authenticated
USING (tenant_id = (select tenant_id from public.users where uid = auth.uid()));

CREATE POLICY "Tenant Isolation: Bills Delete" ON public.bills
FOR DELETE TO authenticated
USING (tenant_id = (select tenant_id from public.users where uid = auth.uid()));

-- CLIENTS: Authenticated Tenant Access Only
CREATE POLICY "Tenant Isolation: Clients Select" ON public.clients
FOR SELECT TO authenticated
USING (tenant_id = (select tenant_id from public.users where uid = auth.uid()));

CREATE POLICY "Tenant Isolation: Clients Insert" ON public.clients
FOR INSERT TO authenticated
WITH CHECK (tenant_id = (select tenant_id from public.users where uid = auth.uid()));

CREATE POLICY "Tenant Isolation: Clients Update" ON public.clients
FOR UPDATE TO authenticated
USING (tenant_id = (select tenant_id from public.users where uid = auth.uid()));

CREATE POLICY "Tenant Isolation: Clients Delete" ON public.clients
FOR DELETE TO authenticated
USING (tenant_id = (select tenant_id from public.users where uid = auth.uid()));

-- (Repeat for other tables: quotations, purchase_orders, bill_items, bill_payments)

-- 3. Note on Public Sharing
-- Since we dropped "Public can view...", standard SELECTs from the frontend for public bills will FAIL.
-- The app MUST use the `get_public_bill(id)` RPC function for public views.
-- This function is `SECURITY DEFINER`, meaning it bypasses RLS safely for that specific query.
