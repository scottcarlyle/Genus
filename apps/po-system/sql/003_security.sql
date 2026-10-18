-- ===========================================================
--  Purchase orders - capabilities, row level security, storage
--
--  Admins inherit every capability that is not listed in explicit_caps, so
--  none of these need adding to an admin by hand.
-- ===========================================================

insert into public.capabilities (cap, section, label, note, sort) values
 ('po.view',      'Purchase orders', 'view',       'See the PO register and dashboard', 180),
 ('po.raise',     'Purchase orders', 'raise',      'Create a PO, edit a draft, and issue it to a supplier', 190),
 ('po.delete',    'Purchase orders', 'delete',     'Remove a PO from the register', 200),
 ('products.edit','Purchase orders', 'price list', 'Add and change products and prices', 210)
on conflict (cap) do update
  set section = excluded.section, label = excluded.label, note = excluded.note, sort = excluded.sort;


alter table public.products        enable row level security;
alter table public.purchase_orders enable row level security;
alter table public.po_lines        enable row level security;
alter table public.po_terms        enable row level security;

create policy p_prod_read  on public.products        for select using (has_cap('po.view') or has_cap('invoices.view'));
create policy p_prod_write on public.products        for insert with check (has_cap('products.edit'));
create policy p_prod_upd   on public.products        for update using (has_cap('products.edit')) with check (has_cap('products.edit'));
create policy p_prod_del   on public.products        for delete using (has_cap('products.edit'));

create policy p_po_read    on public.purchase_orders for select using (has_cap('po.view'));
create policy p_po_write   on public.purchase_orders for insert with check (has_cap('po.raise'));
create policy p_po_upd     on public.purchase_orders for update using (has_cap('po.raise')) with check (has_cap('po.raise'));
create policy p_po_del     on public.purchase_orders for delete using (has_cap('po.delete'));

create policy p_pol_read   on public.po_lines        for select using (has_cap('po.view'));
create policy p_pol_write  on public.po_lines        for insert with check (has_cap('po.raise'));
create policy p_pol_upd    on public.po_lines        for update using (has_cap('po.raise')) with check (has_cap('po.raise'));
create policy p_pol_del    on public.po_lines        for delete using (has_cap('po.raise'));

create policy p_terms_read on public.po_terms        for select using (has_cap('po.view'));
create policy p_terms_upd  on public.po_terms        for all    using (has_cap('admin.settings')) with check (has_cap('admin.settings'));


--  Raising a PO needs the supplier list, and the old rule only showed you
--  suppliers you already had an invoice against. Bank details are a separate
--  table behind suppliers.bank, so this exposes nothing financial.
alter policy p_sup_read on public.suppliers using (
  (has_cap('invoices.view') and (sees_all_invoices() or supplier_is_mine(id)))
  or has_cap('po.view')
);


insert into storage.buckets (id, name, public) values ('purchase-orders','purchase-orders', false)
on conflict (id) do nothing;

create policy "po docs readable"    on storage.objects for select using (bucket_id='purchase-orders' and has_cap('po.view'));
create policy "po docs writable"    on storage.objects for insert with check (bucket_id='purchase-orders' and has_cap('po.raise'));
create policy "po docs replaceable" on storage.objects for update using (bucket_id='purchase-orders' and has_cap('po.raise'))
                                                              with check (bucket_id='purchase-orders' and has_cap('po.raise'));
create policy "po docs removable"   on storage.objects for delete using (bucket_id='purchase-orders' and has_cap('po.delete'));
