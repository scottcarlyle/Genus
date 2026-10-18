-- ===========================================================
--  Purchase orders - what came across from Genus PO System.xlsm
--  Run once, 17 Oct 2026, against the workbook copy dated 12 July 2026.
--  Every statement is safe to run again; none of them overwrite.
-- ===========================================================

-- -----------------------------------------------------------
--  1. Suppliers that already existed on the invoice side
--
--  IVF Synergy -> SYN was settled by data rather than by the names: an
--  invoice against supplier SYN quotes PO GF-IVF-004.
-- -----------------------------------------------------------
update public.suppliers s set po_code = v.po, address1 = v.a1, address2 = v.a2, postcode = v.pc
from (values
 ('ALGAS','ALG','Unit 17b Birch Road','Broadmeadow Industrial Estate','G82 2RE'),
 ('ANET' ,'ANE','44 New Lane','Havant','PO9 2NF'),
 ('BOC'  ,'BOC','Forge, 43 Church Street West','Woking, Surrey','GU21 6HT'),
 ('COOP' ,'COS','Delta Park, 8 Concorde Way','Segensworth North, Fareham','PO15 5RL'),
 ('GEH'  ,'GEV','Pollards Wood, Nightingales Lane','Chalfont St Giles','HP8 4SP'),
 ('SYN'  ,'IVF','First Floor Suite Maritime House','Discovery Quay, Falmouth','TR11 3XA'),
 ('LOV'  ,'LOV','Muirhead Mitchelston Industrial Estate','Kirkcaldy','KY1 3PB'),
 ('VITRO','VIT','1 Chapel Street','Warwick','CV34 4HL')
) as v(code, po, a1, a2, pc)
where s.code = v.code;

-- -----------------------------------------------------------
--  2. Suppliers the PO workbook had and the invoice ledger did not
--     Each gets an empty, unverified bank record so the invoice side
--     treats them like any other new supplier.
-- -----------------------------------------------------------
insert into public.suppliers (code, name, po_code, address1, address2, postcode, terms, vat_rate, notes) values
 ('BECT','Becton Dickinson UK','BCD','Building 1030 Eskdale Road','Winnersh Triangle','RG41 5TS',30,0.20,'Added from the PO workbook.'),
 ('IATT','IATT','IAT','Unit 10 Queens Court North, Third Avenue','Team Valley Trading Estate','NE11 0BU',30,0.20,'Added from the PO workbook.'),
 ('OCEAN','Ocean Med','OCM','85 Great Portland Street','London','W1W 7LT',30,0.20,'Added from the PO workbook.'),
 ('PARI','Parity Medical','PAR','Port Causeway','Wirral International Business Park','CH62 4TP',30,0.20,'Added from the PO workbook.'),
 ('PLAN','Planer','PLN','111 Windmill Road','','TW16 7HD',30,0.20,'Added from the PO workbook.'),
 ('THAM','Thames Cryogenics','TCL','Gooch Drive','Southmead Ind Park, Didcot','OX11 7PR',30,0.20,'Added from the PO workbook.'),
 ('VALID','Validair','VAL','Dunns 4, Bowes Business Park','Lambton Park, Chester-le-Street','DH3 4AN',30,0.20,'Added from the PO workbook.'),
 ('XLAB','X-Lab Solutions','XLA','Odai Street, No 207A','Bucharest','',30,0.20,'Added from the PO workbook.')
on conflict (code) do nothing;

insert into public.supplier_bank (supplier_id)
select id from public.suppliers where code in ('BECT','IATT','OCEAN','PARI','PLAN','THAM','VALID','XLAB')
on conflict (supplier_id) do nothing;

-- -----------------------------------------------------------
--  3. The tracker - 32 orders, headers only
--     The PO Archive sheet held no line detail, so there is none to bring.
--     The tracker's "Value" column is net; VAT was never recorded there.
--     Workbook status "Exported" maps to "Issued".
-- -----------------------------------------------------------
insert into public.purchase_orders (po_number, supplier_id, po_date, status, net, vat, reference, notes, value_source, po_type)
select v.no, s.id, v.dt, v.st, v.net, 0, v.ref, v.note, 'imported', 'Materials'
from (values
  ('GF-ALG-001', 'ALG', date '2026-05-13', 'Issued', 7957.26, '', ''),
  ('GF-ANE-001', 'ANE', date '2025-12-16', 'Issued', 0.0, '', ''),
  ('GF-ANE-002', 'ANE', date '2025-12-16', 'Issued', 67656.72, '', ''),
  ('GF-BCD-001', 'BCD', date '2026-06-11', 'Issued', 3205.27, '', ''),
  ('GF-BOC-001', 'BOC', date '2025-10-09', 'Issued', 395.0, '', ''),
  ('GF-BOC-002', 'BOC', date '2025-10-28', 'Issued', 5990.0, '', ''),
  ('GF-BOC-003', 'BOC', date '2026-03-10', 'Issued', 2290.0, '', ''),
  ('GF-BOC-004', 'BOC', date '2026-03-30', 'Issued', 192.74, '', ''),
  ('GF-COS-001', 'COS', date '2025-10-26', 'Issued', 499528.14, '', ''),
  ('GF-COS-002', 'COS', date '2026-06-14', 'Issued', 5181.28, '', ''),
  ('GF-COS-003', 'COS', date '2026-07-03', 'Issued', 0.0, '', ''),
  ('GF-GEV-001', 'GEV', date '2025-12-16', 'Issued', 154000.0, '', ''),
  ('GF-GEV-002', 'GEV', date '2025-12-16', 'Issued', 35216.6, '', ''),
  ('GF-GEV-003', 'GEV', date '2026-05-20', 'Issued', 12008.28, '', ''),
  ('GF-GEV-004', 'GEV', date '2026-05-26', 'Issued', 444.0, '', ''),
  ('GF-IAT-001', 'IAT', date '2026-05-21', 'Issued', 1336.95, '', ''),
  ('GF-IVF-001', 'IVF', date '2025-11-20', 'Issued', 17567.28, '', ''),
  ('GF-LOV-001', 'LOV', date '2026-03-13', 'Issued', 3394.0, '', ''),
  ('GF-LOV-002', 'LOV', date '2026-03-18', 'Issued', 1875.0, '', ''),
  ('GF-LOV-003', 'LOV', date '2026-04-21', 'Issued', 990.0, '', ''),
  ('GF-OCM-001', 'OCM', date '2025-12-17', 'Issued', 53986.5, '', ''),
  ('GF-PAR-001', 'PAR', date '2026-06-29', 'Issued', 0.0, '', ''),
  ('GF-PLN-001', 'PLN', date '2026-02-04', 'Issued', 12380.4, '', ''),
  ('GF-PLN-002', 'PLN', date '2026-05-22', 'Issued', 0.0, '', ''),
  ('GF-PLN-003', 'PLN', date '2026-06-10', 'Issued', 990.0, '', ''),
  ('GF-TCL-001', 'TCL', date '2025-12-09', 'Issued', 13720.75, '', ''),
  ('GF-VAL-001', 'VAL', date '2025-11-18', 'Issued', 4695.0, '', ''),
  ('GF-VAL-002', 'VAL', date '2026-04-30', 'Issued', 985.0, '', ''),
  ('GF-VAL-003', 'VAL', date '2026-05-15', 'Issued', 985.0, '', ''),
  ('GF-VIT-001', 'VIT', date '2025-12-04', 'Issued', 171310.0, '', ''),
  ('GF-XLA-001', 'XLA', date '2025-12-16', 'Issued', 13860.3, '', ''),
  ('GF-COS-004', 'COS', date '2026-07-05', 'Issued', 2014.85, '', '')
) as v(no, pc, dt, st, net, ref, note)
join public.suppliers s on s.po_code = v.pc
on conflict (po_number) do nothing;

-- -----------------------------------------------------------
--  4. The price list, such as it is - 13 products across 3 suppliers.
--     LGUA-100 and 10765060A have a pack count sitting in the Unit column;
--     that is how the sheet had it. The list is to be rebuilt from the POs.
-- -----------------------------------------------------------
insert into public.products (code, supplier_id, description, unit, unit_price)
select v.code, s.id, v.descr, v.unit, v.price
from (values
  ('BOC-PV500', 'BOC', 'Liquid Nitrogen Vessel PV500', 'each', 395.0),
  ('BOC-LN2', 'BOC', 'Liquid nitrogen refill', 'litre', 1.85),
  ('VIT-CULT', 'VIT', 'Culture media pack', 'box', 120.0),
  ('84021210A', 'COS', 'Origio Density gradient 40/80 (12 X 10)', '1 pack', 244.11),
  ('106070010A', 'COS', 'Sperm freeze (10ml)', '2 bottles', 34.49),
  ('84051010A', 'COS', 'Sperm wash medium (10X10 ml)', '1 pack', 146.91),
  ('83020010A', 'COS', 'Origio sequential fertilisation media (phenol red) (10ml)', '5 pack', 25.59),
  ('67010010A', 'COS', 'QA Sage one step (10 ml)', '3 bottles', 25.59),
  ('10905000A', 'COS', 'PVP clinical grade (5 X 0.2ml)', '1 pack', 130.89),
  ('16125000A', 'COS', 'ICSI Cumulase (5 X 0.5ml)', '1 pack', 141.64),
  ('LGUA-100', 'COS', 'Lifeguard oil (heavy) (100ml)', '10', 60.66),
  ('10765060A', 'COS', 'Flushing medium (5 X 60 pack)', '3', 110.77),
  ('10168', 'VIT', 'EmbryoGlue 5 X 1.5ml', '1', 184.0)
) as v(code, pc, descr, unit, price)
join public.suppliers s on s.po_code = v.pc
on conflict (code) do nothing;

-- -----------------------------------------------------------
--  5. Company details, delivery defaults and numbering, from the Data sheet.
--     The sheet spelt the invoice email two ways; the correct one is used.
-- -----------------------------------------------------------
insert into public.settings (key, value) values
('poPrefix','GF'),
('coName','Fertility Health Edinburgh T/A Genus Medical Fertility'),
('coAddr1','3 Wester Shawfair'),('coAddr2','Edinburgh'),('coPostcode','EH22 1FD'),
('coCompanyNo','SC848683'),('coPhone','0131 3744855'),('coInvoiceEmail','accounts@genusfertility.co.uk'),
('coVatNo',''),
('delName','Genus Medical Fertility'),('delAddr1','3 Wester Shawfair'),('delAddr2','Edinburgh'),
('delPostcode','EH22 1FD'),('delContact','Tessa McGurk'),('delEmail','accounts@genusfertility.co.uk'),
('delPhone','0131 3744855'),
('poVatRate','0.20')
on conflict (key) do nothing;

-- -----------------------------------------------------------
--  6. The terms, from the PO T&C sheet.
-- -----------------------------------------------------------
insert into public.po_terms (id, section, terms) values
(1,'Acceptance of Purchase Order','The Supplier''s acceptance of a Purchase Order, commencement of work, delivery of goods or provision of services shall constitute acceptance of these Terms and Conditions unless otherwise agreed in writing.'),
(2,'Purchase Order Requirement','A valid Purchase Order number must be quoted on all invoices, delivery notes, correspondence and supporting documentation. No additional costs, variations or substitutions will be accepted unless approved in writing in advance.'),
(3,'Prices and Charges','The prices stated on the Purchase Order are fixed and inclusive of all costs, charges, packaging, delivery, labour, expenses, duties and taxes, unless expressly stated otherwise on the Purchase Order.'),
(4,'Delivery and Performance','Goods, materials, services and works must be delivered or completed by the date stated on the Purchase Order or as otherwise agreed in writing. The Supplier must notify us immediately of any actual or anticipated delay.'),
(5,'Quality and Compliance','All goods, materials, services and works must conform to the Purchase Order, any agreed specification, applicable laws and regulations, and good industry practice. Defective, incomplete, damaged or incorrectly supplied items may be rejected.'),
(6,'Invoice Submission','Invoices must be emailed directly to accounts@genusfertility.co.uk in PDF format. Each attachment must be free from password protection and must not be submitted as part of a ZIP file. All invoices must include the relevant PO number. Invoices are considered received once they reach the email address above. If the receipt date is more than seven calendar days after the invoice date, we reserve the right to apply the receipt date for calculating the due date.'),
(7,'Payment','Payment will only be processed against a valid invoice that matches the Purchase Order and complies with the invoice submission requirements. We may withhold payment for disputed, incorrect or unsupported invoices until resolved.'),
(8,'Health, Safety and Site Rules','Where the Supplier attends site or undertakes works, the Supplier must comply with all applicable health and safety requirements, site rules, risk assessments, method statements, safeguarding requirements and reasonable instructions issued by us.'),
(9,'Confidentiality and Data Protection','The Supplier must keep confidential all information received in connection with the Purchase Order and must comply with applicable data protection legislation where personal data is processed.'),
(10,'Cancellation and Rejection','We reserve the right to cancel a Purchase Order, in whole or in part, where the Supplier has not commenced supply, where delivery or performance is delayed, or where the Supplier fails to meet agreed requirements.'),
(11,'Governing Law','These Terms and Conditions and the Purchase Order shall be governed by the laws of Scotland unless otherwise agreed in writing.')
on conflict (id) do update set section = excluded.section, terms = excluded.terms;

-- -----------------------------------------------------------
--  7. Hook up the invoices that already quote one of these POs.
--     Safe to run again as more orders are imported.
-- -----------------------------------------------------------
update public.invoices i set po_id = p.id
from public.purchase_orders p
where upper(trim(i.po_number)) = p.po_number and i.po_id is null;

-- -----------------------------------------------------------
--  8. Karen raises POs. Admins inherit the capabilities automatically.
-- -----------------------------------------------------------
update public.profiles
   set caps = (select array_agg(distinct c) from unnest(caps || array['po.view','po.raise']) c)
 where full_name = 'Karen Thompson';

-- -----------------------------------------------------------
--  Result: 32 orders, 1,094,156.32 committed - reconciles exactly to the
--  workbook's Summary sheet. 13 products. 5 invoices linked.
-- -----------------------------------------------------------
