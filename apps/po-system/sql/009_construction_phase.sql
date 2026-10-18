-- ===========================================================
--  Purchase orders - set the construction-phase orders aside
--  Applied 18 Oct 2026 through execute_sql, at Karolina's request.
--
--  The 26 orders dated before June 2026 were raised while the clinic was
--  being built (about £1.08m, none with an invoice linked). They are kept,
--  so their numbers are never issued again, but the app leaves them out of
--  the register and the dashboard totals unless asked to show them.
--  The app reads the flag from the table; the register view was left as it
--  was, because recreating it needs a drop the database tools would not run.
-- ===========================================================
alter table public.purchase_orders add column if not exists construction boolean not null default false;

comment on column public.purchase_orders.construction is 'Raised while the clinic was being built (before June 2026). Kept for the record, left out of the register and totals unless asked for.';

update public.purchase_orders set construction = true where po_date < '2026-06-01' and not construction;
