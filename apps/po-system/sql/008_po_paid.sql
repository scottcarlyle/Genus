-- ===========================================================
--  Purchase orders - how much has been paid against each order
--  Applied 18 Oct 2026 through execute_sql.
-- ===========================================================
create or replace function public.po_paid(p_po uuid)
returns numeric language sql stable security definer set search_path to 'public' as $$
  --  How much has been paid on the invoices linked to a PO. Whole, for the
  --  same reason as po_invoiced: an approver sees only their own invoices.
  select case when public.has_cap('po.view')
    then coalesce((select sum(amount_paid) from public.invoices where po_id = p_po), 0)
    else null end
$$;

create or replace view public.v_purchase_orders
with (security_invoker = on) as
select p.*,
       s.code    as supplier_code,
       s.po_code as supplier_po_code,
       s.name    as supplier_name,
       (select count(*) from public.po_lines l where l.po_id = p.id) as line_count,
       public.po_invoiced(p.id)                                      as invoiced,
       p.gross - coalesce(public.po_invoiced(p.id), 0)               as left_to_invoice,
       public.po_paid(p.id)                                          as paid
  from public.purchase_orders p
  join public.suppliers s on s.id = p.supplier_id;
