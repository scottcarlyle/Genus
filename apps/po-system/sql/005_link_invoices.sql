-- ===========================================================
--  Purchase orders - keep invoices linked to their PO
--  Applied 18 Oct 2026 with Karolina's go-ahead (run statement by statement
--  through execute_sql, so it is not in the migration history).
--
--  004 linked invoices to POs once, at migration. Nothing kept that up:
--  an invoice keyed in later, or a PO imported after its invoice arrived,
--  stayed unlinked and showed on the dashboard as quoting a PO we do not
--  hold. These triggers link both ways, and link_invoice_po lets someone
--  with po.raise tie up the odd ones by hand (GF-BIOMED-001 and the like).
-- ===========================================================

--  An invoice whose quoted number matches a PO picks it up. A link set by
--  hand is left alone.
create or replace function public.invoice_link_po() returns trigger
language plpgsql security definer set search_path to 'public' as $$
begin
  if new.po_id is null and coalesce(new.po_number,'') <> '' then
    select id into new.po_id from purchase_orders
     where po_number = upper(trim(new.po_number));
  end if;
  return new;
end $$;

drop trigger if exists t_inv_link_po on public.invoices;
create trigger t_inv_link_po before insert or update of po_number on public.invoices
  for each row execute function public.invoice_link_po();


--  A PO that arrives after its invoice - the usual case for orders imported
--  from the workbook - collects the invoices already quoting it.
create or replace function public.po_link_invoices() returns trigger
language plpgsql security definer set search_path to 'public' as $$
begin
  update invoices set po_id = new.id
   where po_id is null and upper(trim(po_number)) = new.po_number;
  return null;
end $$;

drop trigger if exists t_po_link_invoices on public.purchase_orders;
create trigger t_po_link_invoices after insert on public.purchase_orders
  for each row execute function public.po_link_invoices();


--  By hand, from the dashboard. Pass null for p_po to unlink.
--  Security definer because a PO raiser cannot update invoices directly.
create or replace function public.link_invoice_po(p_invoice uuid, p_po uuid)
returns void language plpgsql security definer set search_path to 'public' as $$
declare nm text;
begin
  if not has_cap('po.raise') then raise exception 'You are not allowed to link invoices to purchase orders.'; end if;
  if p_po is not null then
    select po_number into nm from purchase_orders where id = p_po;
    if nm is null then raise exception 'That PO is not in the register.'; end if;
  end if;
  update invoices set po_id = p_po where id = p_invoice;
  if not found then raise exception 'That invoice was not found.'; end if;
  perform po_log('po.invoice_linked', p_po,
                 jsonb_build_object('invoice_id', p_invoice, 'po_number', nm));
end $$;


--  Catch up on anything that went in between 004 and this.
update public.invoices i set po_id = p.id
from public.purchase_orders p
where upper(trim(i.po_number)) = p.po_number and i.po_id is null;
