-- ===========================================================
--  Purchase orders - tables
--  Applied to the Genus Supabase project, 17 Oct 2026.
--
--  POs share suppliers, profiles, capabilities and the audit log with the
--  invoice system. Nothing on the invoice side changes except invoices
--  gaining a po_id alongside the po_number text it already had.
-- ===========================================================

--  The PO code is kept apart from the ledger code because the workbook and
--  the invoice ledger grew their own: ALG vs ALGAS, COS vs COOP. PO numbers
--  are built from this one, so existing numbering carries on untouched.
--  The address is here because the PO PDF prints it; invoices never needed it.
alter table public.suppliers
  add column if not exists po_code  text not null default '',
  add column if not exists address1 text not null default '',
  add column if not exists address2 text not null default '',
  add column if not exists postcode text not null default '',
  add column if not exists vat_reg  text not null default '';

comment on column public.suppliers.po_code is
  'Short code used in PO numbers (GF-<po_code>-NNN). Separate from code because the PO workbook and the invoice ledger grew their own codes.';

create unique index if not exists suppliers_po_code_uidx
  on public.suppliers (po_code) where po_code <> '';


create table if not exists public.products (
  id          uuid primary key default gen_random_uuid(),
  code        text not null unique,
  supplier_id uuid not null references public.suppliers(id),
  description text not null default '',
  unit        text not null default 'each',
  unit_price  numeric not null default 0,
  notes       text not null default '',
  archived    boolean not null default false,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);
create index if not exists products_supplier_idx on public.products (supplier_id) where not archived;


create table if not exists public.purchase_orders (
  id             uuid primary key default gen_random_uuid(),
  po_number      text not null unique,
  supplier_id    uuid not null references public.suppliers(id),
  po_date        date not null default current_date,
  po_type        text not null default 'Materials',
  reference      text not null default '',
  status         text not null default 'Draft'
                 check (status in ('Draft','Issued','Sent to supplier','Receipted','Cancelled')),
  net            numeric not null default 0,
  vat            numeric not null default 0,
  gross          numeric generated always as (net + vat) stored,
  vat_rate       numeric not null default 0.20,
  value_source   text not null default 'lines' check (value_source in ('lines','imported')),
  delivery_to    text not null default '',
  needed_by      date,
  notes          text not null default '',
  pdf_path       text not null default '',
  issued_at      timestamptz,
  issued_by_name text not null default '',
  created_by     uuid references public.profiles(id),
  created_by_name text not null default '',
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);
comment on column public.purchase_orders.value_source is
  'lines = net is kept in step with po_lines by trigger. imported = the value came from the workbook tracker, which held no line detail, so leave it alone.';
create index if not exists po_supplier_idx on public.purchase_orders (supplier_id);
create index if not exists po_date_idx     on public.purchase_orders (po_date desc);


create table if not exists public.po_lines (
  id          uuid primary key default gen_random_uuid(),
  po_id       uuid not null references public.purchase_orders(id) on delete cascade,
  line        integer not null,
  product_id  uuid references public.products(id),
  item_code   text not null default '',
  description text not null default '',
  unit        text not null default '',
  qty         numeric not null default 0,
  unit_price  numeric not null default 0,
  line_total  numeric generated always as (qty * unit_price) stored,
  unique (po_id, line)
);
create index if not exists po_lines_po_idx on public.po_lines (po_id);


--  The link the whole exercise is for. po_number stays as the text the
--  supplier actually quoted, which is not always a PO we raised.
alter table public.invoices
  add column if not exists po_id uuid references public.purchase_orders(id);
comment on column public.invoices.po_id is
  'The PO this invoice belongs to. po_number stays as the text the supplier quoted, which is not always a PO we raised.';
create index if not exists invoices_po_idx on public.invoices (po_id);


--  Printed on page two of every PO. In Admin rather than buried in a sheet.
create table if not exists public.po_terms (
  id      integer primary key,
  section text not null default '',
  terms   text not null default '',
  active  boolean not null default true
);


create trigger t_products_touch before update on public.products
  for each row execute function public.touch_updated_at();
create trigger t_po_touch before update on public.purchase_orders
  for each row execute function public.touch_updated_at();
