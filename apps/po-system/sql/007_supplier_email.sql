-- ===========================================================
--  Purchase orders - let whoever emails a PO record the supplier's address
--  Applied 18 Oct 2026 through execute_sql.
--
--  Emailing a PO to a supplier with no address held asks for one and keeps
--  it. Updating suppliers otherwise needs suppliers.edit, which a PO raiser
--  may not have, so this sets the email only, and logs it.
-- ===========================================================
create or replace function public.set_supplier_email(p_supplier uuid, p_email text)
returns void language plpgsql security definer set search_path to 'public' as $$
declare e text := lower(trim(coalesce(p_email,''))); nm text; old text;
begin
  if not (has_cap('po.raise') or has_cap('suppliers.edit')) then
    raise exception 'You are not allowed to change supplier details.';
  end if;
  if e !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' then raise exception 'That does not look like an email address.'; end if;
  select name, email into nm, old from suppliers where id = p_supplier;
  if nm is null then raise exception 'That supplier was not found.'; end if;
  update suppliers set email = e, updated_at = now() where id = p_supplier;
  insert into audit_log (actor, actor_name, action, entity, entity_id, detail)
  values (auth.uid(), coalesce((select full_name from profiles where id = auth.uid()), ''),
          'supplier.email_set', 'supplier', p_supplier,
          jsonb_build_object('supplier', nm, 'old', old, 'new', e));
end $$;
