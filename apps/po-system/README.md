# PO system

Raises purchase orders for Genus Medical Fertility, keeps the register, and ties
each PO to the invoices that come in against it.

Replaces `Genus PO System.xlsm`. The workbook stays readable as the historic
archive but is no longer where POs are raised.

- **Hosting**: a single file, `Genus Purchase Orders.html`, kept in
  `OneDrive: Documents\GMP\PO` next to `Genus Invoices.html`. Nothing is held in
  the file itself, so copies are harmless and none of them can drift.
- **Database**: the Genus Supabase project (London). Same project as the invoice
  system — same accounts, same suppliers, same capabilities, same audit log.

## What it does

| Screen | |
|---|---|
| Dashboard | Committed, invoiced, left to invoice, open orders, drafts. Issued orders with nothing invoiced against them, and invoices quoting a PO we do not hold, each with a Link button to tie it to the right order. |
| Purchase orders | The register. Open an order for its lines, its invoices, and the PDF. Mark sent, receipted or cancelled. Email the PDF to the supplier. Import orders pasted from the workbook tracker, and attach PDFs (matched by the PO number in the file name). |
| Raise a PO | Supplier, lines (item codes come from the price list), VAT, delivery. Save as a draft or issue it. |
| Price list | Products and prices by supplier. Import prices pasted from a sheet, or pick up item codes used on past orders. |
| Suppliers | PO codes and the address that prints on the order. |
| Admin | Company details, delivery defaults, numbering, and the terms printed on page two. |

Issuing a PO builds the PDF in the browser and files it to the private
`purchase-orders` bucket, so it is attached to the order from then on.

## Numbering

`GF-<po code>-NNN`, as the workbook did. The supplier's PO code lives on the
supplier record (`suppliers.po_code`) and is deliberately separate from the
invoice ledger's code — the two grew apart years ago, and keeping both means
existing PO numbers carry on rather than restarting.

`next_po_number()` looks at the register **and** at PO numbers already quoted on
invoices, because orders were raised in the workbook after the tracker snapshot
came across. The number is allocated inside the transaction that creates the PO,
so two people raising at once cannot collide.

## Who can do what

Four capabilities, in a Purchase orders section of the invoice app's Accounts
screen: `po.view`, `po.raise`, `po.delete`, `products.edit`. Admins inherit them.

Someone who can only raise POs sees suppliers and products but no bank details,
no payment runs and no audit log — the supplier read rule was widened by
`or has_cap('po.view')`, and bank details are a separate table behind
`suppliers.bank`.

## Building

The page is built, not hand-assembled — the libraries and the logo are inlined
so it needs no CDN.

```
cd apps/po-system/src
npm install
npm run build          # bundles supabase-js with esbuild, then runs build.py
```

Edit `src/app.html`, never the built file at the app root.

`src/build.py` explains why supabase-js is re-bundled rather than taken from its
own `dist/umd` build. Short version: that one is webpack's and throws on an
inline script.

## Database

`sql/` holds what was applied, in order. They are a record rather than a
migration runner — the Genus project has no migration tooling.

| File | |
|---|---|
| `001_tables.sql` | products, purchase_orders, po_lines, po_terms, plus the new columns on suppliers and invoices |
| `002_functions.sql` | numbering, the totals trigger, logging, create/issue, the register view |
| `003_security.sql` | capabilities, row level security, the storage bucket |
| `004_migrate_from_workbook.sql` | everything that came across from the .xlsm |
| `005_link_invoices.sql` | Applied 18 Oct 2026. Keeps invoices linked to their PO from either side, and `link_invoice_po` for the dashboard's Link button |

## Importing

Copy rows from the sheet, heading row included, and paste. Excel puts tabs
between cells, so there is no need to save a CSV. Each import shows what it
found and what it will do before anything is saved.

- **Orders**: needs a PO number, a date and a value (taken as net, as the
  tracker kept it). Status and reference are used when present. The supplier
  comes from the code in the middle of the PO number. Orders already held are
  left alone.
- **Prices**: needs code, price and supplier (PO code, ledger code or name).
  A code already on the list is updated.
- **PDFs**: pick any number of files. Each lands on the order whose number is
  in its file name and is filed as `<po number>.pdf`.

## Emailing a PO

There is no mail server behind the page. Email the supplier saves the PDF as
`<po number>.pdf` in Downloads and opens a filled-in email in the default mail
app, to the supplier's email if one is held. Attach the PDF and send, then
mark the order as sent.

## Still open

- The register holds the tracker as at **12 July 2026**. Invoices already quote
  GF-COS-010, GF-ANE-003, GF-LOV-004, GF-PLN-004, GF-VIT-002 and GF-IVF-004, so
  the live workbook is ahead. Import from the current one (Import orders)
  before treating the register as complete. Numbering is safe either way.
- The 32 historic PDFs have not been attached. They are in
  `.../Genus Fertility Operations/Finance/PO/` (Attach PDFs).
- The price list needs rebuilding from the POs: 13 products across 3 suppliers
  against 32 orders from 16 suppliers. The imported orders carry no lines, so
  this has to come from the PDFs or a price sheet (Import prices).
- GF-BIOMED-001 and GMF-SLS-001 appear on invoices but fit no scheme the
  workbook used. Link them by hand once it is known which order they are.
- Only 5 of 50 suppliers have an email address, so most PO emails need the
  address typed in.
