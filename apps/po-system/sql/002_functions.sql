-- ===========================================================
--  Purchase orders - functions, triggers and the register view
-- ===========================================================

--  Totals follow the lines, except on orders imported from the workbook
--  tracker, which carry a value but no line detail. Recalculating those
--  would quietly zero them.
create or replace function public.po_recalc() returns trigger
language plpgsql security definer set search_path to 'public' as $$
declare target uuid; total numeric;
begin
  target := coalesce(new.po_id, old.po_id);
  select coalesce(sum(line_total),0) into total from public.po_lines where po_id = target;
  update public.purchase_orders p
     set net = total, vat = round(total * p.vat_rate, 2)
   where p.id = target and p.value_source = 'lines';
  return null;
end $$;

create trigger t_po_lines_recalc after insert or update or delete on public.po_lines
  for each row execute function public.po_recalc();


--  Next number for a supplier: prefix-po_code-NNN.
--
--  It counts the register AND any number already quoted on an invoice. POs
--  were raised in the workbook after the tracker snapshot came across, so the
--  register is behind reality; reusing one of those numbers would put two
--  different orders on the same reference.
create or replace function public.next_po_number(p_supplier uuid)
returns text language plpgsql stable security definer set search_path to 'public' as $$
declare pfx text; sup text; pat text; n integer;
begin
  if not (has_cap('po.view') or has_cap('po.raise')) then
    raise exception 'You are not allowed to see purchase orders.';
  end if;
  select coalesce(nullif(value,''),'GF') into pfx from settings where key='poPrefix';
  pfx := coalesce(pfx,'GF');
  select nullif(po_code,'') into sup from suppliers where id = p_supplier;
  if sup is null then raise exception 'That supplier has no PO code yet. Set one on the supplier first.'; end if;
  pat := '^' || pfx || '-' || sup || '-[0-9]+$';
  select coalesce(max(v), 0) + 1 into n from (
    select (regexp_replace(po_number, '^.*-', ''))::integer as v
      from purchase_orders where po_number ~ pat
    union all
    select (regexp_replace(upper(trim(po_number)), '^.*-', ''))::integer
      from invoices where upper(trim(po_number)) ~ pat
  ) x;
  return pfx || '-' || sup || '-' || lpad(n::text, 3, '0');
end $$;


--  Client writes to the audit log are not allowed, so PO actions log through here.
create or replace function public.po_log(p_action text, p_po uuid, p_detail jsonb default '{}'::jsonb)
returns void language plpgsql security definer set search_path to 'public' as $$
begin
  if not (public.has_cap('po.view') or public.has_cap('po.raise')) then return; end if;
  insert into public.audit_log (actor, actor_name, action, entity, entity_id, detail)
  values (auth.uid(),
          coalesce((select full_name from public.profiles where id = auth.uid()), ''),
          p_action, 'purchase_order', p_po, coalesce(p_detail,'{}'::jsonb));
end $$;


--  The number is allocated inside the transaction and retried on a collision,
--  so two people raising at the same moment cannot land on the same one.
create or replace function public.create_po(p_supplier uuid, p_date date, p_type text,
  p_reference text, p_needed date, p_delivery text, p_vat_rate numeric, p_notes text)
returns uuid language plpgsql security definer set search_path to 'public' as $$
declare v_id uuid; nm text; who text; tries int := 0;
begin
  if not has_cap('po.raise') then raise exception 'You are not allowed to raise purchase orders.'; end if;
  who := coalesce((select full_name from profiles where id = auth.uid()), '');
  loop
    tries := tries + 1; nm := next_po_number(p_supplier);
    begin
      insert into purchase_orders (po_number, supplier_id, po_date, po_type, reference, needed_by,
                                   delivery_to, vat_rate, notes, status, value_source, created_by, created_by_name)
      values (nm, p_supplier, coalesce(p_date, current_date), coalesce(p_type,'Materials'),
              coalesce(p_reference,''), p_needed, coalesce(p_delivery,''), coalesce(p_vat_rate,0.20),
              coalesce(p_notes,''), 'Draft', 'lines', auth.uid(), who)
      returning id into v_id;
      exit;
    exception when unique_violation then if tries >= 5 then raise; end if;
    end;
  end loop;
  perform po_log('po.created', v_id, jsonb_build_object('po_number', nm));
  return v_id;
end $$;


create or replace function public.issue_po(p_id uuid, p_pdf_path text)
returns void language plpgsql security definer set search_path to 'public' as $$
declare who text; nm text;
begin
  if not has_cap('po.raise') then raise exception 'You are not allowed to issue purchase orders.'; end if;
  who := coalesce((select full_name from profiles where id = auth.uid()), '');
  update purchase_orders
     set status = 'Issued', issued_at = now(), issued_by_name = who,
         pdf_path = coalesce(nullif(p_pdf_path,''), pdf_path)
   where id = p_id and status = 'Draft'
   returning po_number into nm;
  if nm is null then raise exception 'That PO is not a draft, so it cannot be issued again.'; end if;
  perform po_log('po.issued', p_id, jsonb_build_object('po_number', nm));
end $$;


--  How much has been invoiced against a PO. Security definer so the figure is
--  whole: an approver sees only their own invoices, and a part-count on a PO
--  would read as a PO still owing money when it does not.
create or replace function public.po_invoiced(p_po uuid)
returns numeric language sql stable security definer set search_path to 'public' as $$
  select case when public.has_cap('po.view')
    then coalesce((select sum(gross) from public.invoices where po_id = p_po), 0)
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
       p.gross - coalesce(public.po_invoiced(p.id), 0)               as left_to_invoice
  from public.purchase_orders p
  join public.suppliers s on s.id = p.supplier_id;
