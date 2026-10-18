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
| Dashboard | Committed, invoiced, left to invoice, open orders, drafts. Issued orders with nothing invoiced against them, and invoices quoting a PO we do not hold. |
| Purchase orders | The register. Open an order for its lines, its invoices, and the PDF. Mark sent, receipted or cancelled. |
| Raise a PO | Supplier, lines (item codes come from the price list), VAT, delivery. Save as a draft or issue it. |
| Price list | Products and prices by supplier. |
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

## Still open

- The register holds the tracker as at **12 July 2026**. Invoices already quote
  GF-COS-010, GF-ANE-003, GF-LOV-004, GF-PLN-004, GF-VIT-002 and GF-IVF-004, so
  the live workbook is ahead. Import from the current one before treating the
  register as complete. Numbering is safe either way.
- The 32 historic PDFs have not been attached. They are in
  `.../Genus Fertility Operations/Finance/PO/`.
- The price list needs rebuilding from the POs: 13 products across 3 suppliers
  against 32 orders from 16 suppliers, so most lines are typed free today.
- GF-BIOMED-001 and GMF-SLS-001 appear on invoices but fit no scheme the
  workbook used.
- Emailing a PO to the supplier is not built. The PDF opens for attaching.
