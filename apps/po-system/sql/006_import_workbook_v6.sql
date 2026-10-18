-- ===========================================================
--  Purchase orders - bring the register level with the last workbook
--  Applied 18 Oct 2026 with Karolina's go-ahead, one statement at a time
--  through execute_sql. Source: Genus_PO_System_6.xlsm (now archived in
--  Finance/PO/Archive).
--
--  Decisions taken with Karolina:
--  - Biomedical supply UK ltd is its own supplier, not the ledger's Kitazato.
--  - GF-VIT-002-1, GF-AMD-001-1 and GF-COS-008-1 are duplicate re-saves and
--    come across as Cancelled.
--  - GF-COS-009 was never on the tracker; it is added from its PDF.
--  - GF-ANE-003's two items are priced from its PDF.
--
--  Result: 59 orders (3 cancelled), 70 lines, 40 products, 22 suppliers with
--  a PO code. Net of all orders 1,109,395.58 = the workbook's 1,108,470.41
--  plus GF-COS-009. 12 invoices linked to their PO (was 5).
-- ===========================================================

-- 1. Give the PO code and address to ledger suppliers that had none
update public.suppliers s set
  po_code  = v.po,
  address1 = case when s.address1 = '' then v.a1 else s.address1 end,
  address2 = case when s.address2 = '' then v.a2 else s.address2 end,
  postcode = case when s.postcode = '' then v.pc else s.postcode end,
  email    = case when s.email    = '' then v.em else s.email    end,
  vat_reg  = case when s.vat_reg  = '' then v.vr else s.vat_reg  end,
  updated_at = now()
from (values
  ('AMD', 'AMD', 'Newmarket Drive', 'Derby', 'DE24 8SW', '', ''),
  ('SLS', 'SLS', 'Orchard House, The Square', 'Hessle', 'H13 0AE', 'scotlandorders@scientific-labs.com', ''),
  ('HUNT', 'HUNT', 'Unit 1 Priors Hall, Widdington', 'Saffron Walden, Essex', 'CB11 3SB', 'sales@hunterscientific.com', '')
) v(code, po, a1, a2, pc, em, vr)
where s.code = v.code and s.po_code = ''
returning s.code, s.name, s.po_code;

-- 2. Suppliers the PO workbook has and the ledger does not
insert into public.suppliers (code, name, po_code, address1, address2, postcode, email, vat_reg, terms, vat_rate, notes) values
  ('BIOMED', 'Biomedical supply UK ltd', 'BIOMED', '19, The circle, Queen Elizabeth Street', 'London', 'SE1 2JE', '', '', 30, 0.20, 'Added from the PO workbook.'),
  ('NEQAS', 'Manchester University NHS Trust', 'NEQAS', 'Dept of reproductive medicine, Old st Marys hospital', 'Oxford Road, Manchester', 'M13 9WL', 'repscience@ukneqas.org', '', 30, 0.20, 'Added from the PO workbook.'),
  ('LABD', 'Lab Dynamics', 'LABD', '20-22 Wenlock Road', 'London', 'N1 7GU', 'sales@labdynamics.co.uk', '442 6325 09', 30, 0.20, 'Added from the PO workbook. Contact - Martyn selley.')
on conflict (code) do nothing
returning code, name, po_code;

-- 3. Each new supplier gets an empty, unverified bank record, as the invoice side expects
insert into public.supplier_bank (supplier_id)
select id from public.suppliers where code in ('BIOMED', 'NEQAS', 'LABD')
on conflict (supplier_id) do nothing
returning supplier_id;

-- 5. Price list: the workbook's 38 materials plus the two Anetic Aid items from GF-ANE-003's PDF. Existing codes keep their description and take the workbook's supplier, unit and price.
insert into public.products (code, supplier_id, description, unit, unit_price)
select v.code, s.id, v.descr, v.unit, v.price
from (values
  ('BOC-PV500', 'BOC', 'Liquid Nitrogen Vessel PV500', 'each', 395.0),
  ('BOC-LN2', 'BOC', 'Liquid nitrogen refill', 'litre', 1.85),
  ('84021210A', 'COS', 'Origio Density gradient 40/80 (12 X 10)', '1', 244.11),
  ('106070010A', 'COS', 'Sperm freeze (10ml)', 'each', 34.49),
  ('84051010A', 'COS', 'Sperm wash medium (10X10 ml)', '1 pack', 146.91),
  ('83020010A', 'COS', 'Origio sequential fertilisation media (phenol red) (10ml)', 'each', 25.59),
  ('83110060M', 'COS', 'Origio handling media (phenol red) (60ml)', 'each', 46.23),
  ('67010010A', 'COS', 'QA Sage one step (10 ml)', 'each', 36.82),
  ('10905000A', 'COS', 'PVP clinical grade (5 X 0.2ml)', '1 pack', 130.89),
  ('16125000A', 'COS', 'ICSI Cumulase (5 X 0.5ml)', '1 pack', 141.64),
  ('LGUA-100', 'COS', 'Lifeguard oil (heavy) (100ml)', 'each', 60.66),
  ('10765060A', 'COS', 'Flushing medium (5 X 60 pack)', 'pack', 110.77),
  ('ZMH3000', 'COS', 'ZyMot® Multi (3mL) Sperm Separation Device', '1 box', 468.16),
  ('6-70-710', 'COS', 'Brady- Ribbon (M71-R4300)', '1', 65.77),
  ('6-70-720', 'COS', 'Brady - Label (M71-19-427)', '1', 38.48),
  ('6-70-103/50', 'COS', 'RFID slim tags (pack of 50)', '1 pack', 165.11),
  ('FGY4GM508CULTAC1', 'PLN', 'FGY4GM508CULTAC1 Cult active', '1', 80.4),
  ('VIT-CULT', 'VIT', 'Culture media pack', 'box', 120.0),
  ('10168', 'VIT', 'EmbryoGlue 5 X 1.5ml', '1', 184.0),
  ('VT601', 'BIOMED', 'Kitazato 91101 VT601 vitrification solutions', '1 box', 102.5),
  ('VT602UF', 'BIOMED', 'Kitazato 91255 VT602UF - TS x4 Ultra fast warm', '1 box', 155.22),
  ('PM-EXDEMO 1', 'PAR', 'Versalite EPR Ex-demo cart Asset 1754* with KBM tray but no laptop bracket or profile', 'each', 350.0),
  ('PM-EXDEMO 2', 'PAR', 'Versalite EPR Ex-demo cart Asset 1909* with KBM tray but no laptop bracket or profile', 'each', 350.0),
  ('Z05A01', 'AMD', 'Kwills pack of five x30 per carton', '1', 243.4),
  ('OODSF-02000', 'IVF', 'Dilutable Laboratory Surface Disinfectant with dosing cap', '1', 106.7),
  ('MIC3226', 'SLS', 'Select coverslips 22 X 50', '1 pack', 12.15),
  ('3KB7114', 'IVF', 'Water Baxter Alternative Sterile Water for C60, C200&C201', '1', 15.5),
  ('IVFS-CPI - 25', 'IVF', 'Carriage, package and insurance', '1', 25.0),
  ('CellVu - DRM 900', 'IVF', 'Cell Vu DRM 900 Pre Stained Morphology Slides (75)', '1', 218.0),
  ('1605/1', 'HUNT', 'Pasante CE Lubricated non- latex condoms. 3 pack', '1', 6.25),
  ('16003', 'VIT', 'Micro droplet culture dish (400/case)', '1', 489.0),
  ('PF12512', 'LABD', 'Umonium 38 CE Marked, Class IIa Floor disinfectant 5L', '1', 270.0),
  ('PF10800', 'LABD', 'Ultrasound Probe wipes - 100 per tub', '1', 75.0),
  ('VT602', 'BIOMED', 'Kitazao VT602 thawing solutions', '1', 89.18),
  ('OOIF-STO6', 'IVF', 'Oosafe filter, 6 month filter', '1', 168.0),
  ('ULTRA-001', 'COS', 'Origio gas line filter', '1', 80.15),
  ('6-70-101/50', 'COS', 'RFID Time lapse tags (pack of 50)', '1', 165.11),
  ('6-70-104/50', 'COS', 'RFID Rectangular tags (pack of 50)', '1', 165.11),
  ('10105', 'ANE', 'S-Arm retainer - L shaped', 'each', 29.0),
  ('10115', 'ANE', 'S-Arm retainer pad', 'each', 28.0)
) v(code, po, descr, unit, price)
join public.suppliers s on s.po_code = v.po
on conflict (code) do update set
  supplier_id = excluded.supplier_id,
  unit        = excluded.unit,
  unit_price  = excluded.unit_price,
  archived    = false,
  updated_at  = now()
returning code, unit_price;

-- 6. The 27 orders raised after the July snapshot. Values are net, as the tracker kept them.
insert into public.purchase_orders (po_number, supplier_id, po_date, status, net, vat, reference, notes, value_source, po_type)
select v.no, s.id, v.dt, v.st, v.net, 0, v.ref, v.note, 'imported', 'Materials'
from (values
  ('GF-VIT-002', 'VIT', date '2026-07-14', 'Issued', 184.0, '', 'Imported from the workbook.'),
  ('GF-VIT-002-1', 'VIT', date '2026-07-14', 'Cancelled', 184.0, 'EmbryoGlue 5 X 1.5ml', 'Duplicate of GF-VIT-002 with the same lines. Imported as cancelled so it is not counted twice.'),
  ('GF-PLN-004', 'PLN', date '2026-07-15', 'Issued', 200.8, 'FGY4GM508CULTAC1 Cult active', 'Imported from the workbook.'),
  ('GF-COS-005', 'COS', date '2026-07-15', 'Issued', 737.52, 'ZyMot® Multi (3mL) Sperm Separation Device', 'Imported from the workbook.'),
  ('GF-BIOMED-001', 'BIOMED', date '2026-07-15', 'Issued', 1028.32, 'Kitazato 91101 VT601 vitrification solutions', 'Imported from the workbook.'),
  ('GF-PAR-002', 'PAR', date '2026-07-20', 'Issued', 865.0, 'Versalite EPR Ex-demo cart Asset 1754* with KBM tray but no laptop bracket or profile', 'Imported from the workbook.'),
  ('GF-AMD-001', 'AMD', date '2026-07-27', 'Issued', 243.4, 'Kwills pack of five x30 per carton', 'Imported from the workbook.'),
  ('GF-AMD-001-1', 'AMD', date '2026-07-27', 'Cancelled', 243.4, 'Kwills pack of five x30 per carton', 'Duplicate of GF-AMD-001 with the same lines. Imported as cancelled so it is not counted twice.'),
  ('GF-NEQAS-001', 'NEQAS', date '2026-07-27', 'Issued', 988.12, 'Registration for GMF on UK NEQAS scheme - see attached registration form', 'Imported from the workbook.'),
  ('GF-IVF-002', 'IVF', date '2026-07-31', 'Issued', 106.7, 'Dilutable Laboratory Surface Disinfectant with dosing cap', 'Imported from the workbook.'),
  ('GF-SLS-003', 'SLS', date '2026-08-10', 'Issued', 24.3, 'Select coverslips 22 X 50', 'Imported from the workbook.'),
  ('GF-IVF-003', 'IVF', date '2026-08-10', 'Issued', 320.5, 'Cell Vu DRM 900 Pre Stained Morphology Slides (75)', 'Imported from the workbook.'),
  ('GF-HUNT-001', 'HUNT', date '2026-08-12', 'Issued', 31.25, 'Pasante CE Lubricated non- latex condoms. 3 pack', 'Imported from the workbook.'),
  ('GF-COS-006', 'COS', date '2026-08-19', 'Issued', 495.88, 'Origio Density gradient 40/80 (12 X 10)', 'Imported from the workbook.'),
  ('GF-VIT-004', 'VIT', date '2026-08-19', 'Issued', 673.0, 'EmbryoGlue 5 X 1.5ml', 'Imported from the workbook.'),
  ('GF-ALG-002', 'ALG', date '2026-08-19', 'Issued', 1498.2, 'Annual Gas detection PPM CAM-3017-VO-001', 'Imported from the workbook.'),
  ('GF-LOV-004', 'LOV', date '2026-09-03', 'Issued', 1145.4, 'PTSG Tank Clean', 'Imported from the workbook.'),
  ('GF-COS-007', 'COS', date '2026-09-03', 'Issued', 817.47, 'Origio Density gradient 40/80 (12 X 10)', 'Imported from the workbook.'),
  ('GF-LABD-001', 'LABD', date '2026-09-07', 'Issued', 345.0, 'Umonium 38 CE Marked, Class IIa Floor disinfectant 5L', 'Imported from the workbook.'),
  ('GF-BIOMED-002', 'BIOMED', date '2026-09-07', 'Issued', 601.68, 'Kitazato 91101 VT601 vitrification solutions', 'Imported from the workbook.'),
  ('GF-COS-008', 'COS', date '2026-09-14', 'Issued', 1223.47, 'Origio sequential fertilisation media (phenol red) (10ml)', 'Imported from the workbook. Its PDF is blank. The lines priced from the current price list come to £1,228.47 against £1,223.47 on the tracker. GF-COS-009 has the same items except the oil.'),
  ('GF-COS-008-1', 'COS', date '2026-09-14', 'Cancelled', 1223.47, 'Origio sequential fertilisation media (phenol red) (10ml)', 'Duplicate of GF-COS-008 with the same lines. Imported as cancelled so it is not counted twice.'),
  ('GF-IVF-004', 'IVF', date '2026-09-21', 'Issued', 361.0, 'Oosafe filter, 6 month filter', 'Imported from the workbook.'),
  ('GF-COS-010', 'COS', date '2026-09-24', 'Issued', 485.71, 'Origio gas line filter', 'Imported from the workbook.'),
  ('GF-ANE-003', 'ANE', date '2026-10-06', 'Issued', 114.0, 'S-Arm retainer- L shaped', 'Imported from the workbook.'),
  ('GF-LOV-005', 'LOV', date '2026-10-06', 'Issued', 172.5, 'Reactive call out charge for blocked toilets and sink V0080592', 'Imported from the workbook.'),
  ('GF-COS-009', 'COS', date '2026-09-21', 'Issued', 925.17, 'Origio sequential fertilisation media (phenol red) (10ml)', 'Added from its PDF; it was never entered on the workbook tracker.')
) v(no, po, dt, st, net, ref, note)
join public.suppliers s on s.po_code = v.po
on conflict (po_number) do nothing
returning po_number;

-- 7. Order lines from the PO Archive sheet, priced from the price list. Shipping, delivery and service lines take what is left of the order value.
insert into public.po_lines (po_id, line, product_id, item_code, description, unit, qty, unit_price)
select p.id, v.line, pr.id, v.code, v.descr, v.unit, v.qty, v.price
from (values
  ('GF-VIT-002', 1, '10168', 'EmbryoGlue 5 X 1.5ml', '1', 1.0, 184.0),
  ('GF-VIT-002-1', 1, '10168', 'EmbryoGlue 5 X 1.5ml', '1', 1.0, 184.0),
  ('GF-PLN-004', 1, 'FGY4GM508CULTAC1', 'FGY4GM508CULTAC1 Cult active', '1', 2.0, 80.4),
  ('GF-PLN-004', 2, '', 'Shipping', 'each', 1.0, 40.0),
  ('GF-COS-005', 1, 'ZMH3000', 'ZyMot® Multi (3mL) Sperm Separation Device', '1 box', 1.0, 468.16),
  ('GF-COS-005', 2, '6-70-710', 'Brady- Ribbon (M71-R4300)', '1', 1.0, 65.77),
  ('GF-COS-005', 3, '6-70-720', 'Brady - Label (M71-19-427)', '1', 1.0, 38.48),
  ('GF-COS-005', 4, '6-70-103/50', 'RFID slim tags (pack of 50)', '1 pack', 1.0, 165.11),
  ('GF-BIOMED-001', 1, 'VT601', 'Kitazato 91101 VT601 vitrification solutions', '1 box', 5.0, 102.5),
  ('GF-BIOMED-001', 2, 'VT602UF', 'Kitazato 91255 VT602UF - TS x4 Ultra fast warm', '1 box', 2.0, 155.22),
  ('GF-BIOMED-001', 3, '', 'Shipping', 'each', 1.0, 205.38),
  ('GF-PAR-002', 1, 'PM-EXDEMO 1', 'Versalite EPR Ex-demo cart Asset 1754* with KBM tray but no laptop bracket or profile', 'each', 1.0, 350.0),
  ('GF-PAR-002', 2, 'PM-EXDEMO 2', 'Versalite EPR Ex-demo cart Asset 1909* with KBM tray but no laptop bracket or profile', 'each', 1.0, 350.0),
  ('GF-PAR-002', 3, '', 'Delivery', 'each', 1.0, 165.0),
  ('GF-AMD-001', 1, 'Z05A01', 'Kwills pack of five x30 per carton', '1', 1.0, 243.4),
  ('GF-AMD-001-1', 1, 'Z05A01', 'Kwills pack of five x30 per carton', '1', 1.0, 243.4),
  ('GF-NEQAS-001', 1, '', 'Registration for GMF on UK NEQAS scheme - see attached registration form', 'each', 1.0, 988.12),
  ('GF-IVF-002', 1, 'OODSF-02000', 'Dilutable Laboratory Surface Disinfectant with dosing cap', '1', 1.0, 106.7),
  ('GF-SLS-003', 1, 'MIC3226', 'Select coverslips 22 X 50', '1 pack', 2.0, 12.15),
  ('GF-IVF-003', 1, 'CellVu - DRM 900', 'Cell Vu DRM 900 Pre Stained Morphology Slides (75)', '1', 1.0, 218.0),
  ('GF-IVF-003', 2, '3KB7114', 'Water Baxter Alternative Sterile Water for C60, C200&C201', '1', 5.0, 15.5),
  ('GF-IVF-003', 3, 'IVFS-CPI - 25', 'Carriage, package and insurance', '1', 1.0, 25.0),
  ('GF-HUNT-001', 1, '1605/1', 'Pasante CE Lubricated non- latex condoms. 3 pack', '1', 5.0, 6.25),
  ('GF-COS-006', 1, '84021210A', 'Origio Density gradient 40/80 (12 X 10)', '1', 1.0, 244.11),
  ('GF-COS-006', 2, '106070010A', 'Sperm freeze (10ml)', 'each', 1.0, 34.49),
  ('GF-COS-006', 3, '83020010A', 'Origio sequential fertilisation media (phenol red) (10ml)', 'each', 2.0, 25.59),
  ('GF-COS-006', 4, '83110060M', 'Origio handling media (phenol red) (60ml)', 'each', 2.0, 46.23),
  ('GF-COS-006', 5, '67010010A', 'QA Sage one step (10 ml)', 'each', 2.0, 36.82),
  ('GF-VIT-004', 1, '10168', 'EmbryoGlue 5 X 1.5ml', '1', 1.0, 184.0),
  ('GF-VIT-004', 2, '16003', 'Micro droplet culture dish (400/case)', '1', 1.0, 489.0),
  ('GF-ALG-002', 1, '', 'Annual Gas detection PPM CAM-3017-VO-001', 'each', 1.0, 1498.2),
  ('GF-LOV-004', 1, '', 'PTSG Tank Clean', 'each', 1.0, 1145.4),
  ('GF-COS-007', 1, '84021210A', 'Origio Density gradient 40/80 (12 X 10)', '1', 1.0, 244.11),
  ('GF-COS-007', 2, '106070010A', 'Sperm freeze (10ml)', 'each', 1.0, 34.49),
  ('GF-COS-007', 3, '83110060M', 'Origio handling media (phenol red) (60ml)', 'each', 2.0, 46.23),
  ('GF-COS-007', 4, '83020010A', 'Origio sequential fertilisation media (phenol red) (10ml)', 'each', 3.0, 25.59),
  ('GF-COS-007', 5, '67010010A', 'QA Sage one step (10 ml)', 'each', 2.0, 36.82),
  ('GF-COS-007', 6, '10905000A', 'PVP clinical grade (5 X 0.2ml)', '1 pack', 1.0, 130.89),
  ('GF-COS-007', 7, '6-70-103/50', 'RFID slim tags (pack of 50)', '1 pack', 1.0, 165.11),
  ('GF-LABD-001', 1, 'PF12512', 'Umonium 38 CE Marked, Class IIa Floor disinfectant 5L', '1', 1.0, 270.0),
  ('GF-LABD-001', 2, 'PF10800', 'Ultrasound Probe wipes - 100 per tub', '1', 1.0, 75.0),
  ('GF-BIOMED-002', 1, 'VT601', 'Kitazato 91101 VT601 vitrification solutions', '1 box', 5.0, 102.5),
  ('GF-BIOMED-002', 2, 'VT602', 'Kitazao VT602 thawing solutions', '1', 1.0, 89.18),
  ('GF-COS-008', 1, '83020010A', 'Origio sequential fertilisation media (phenol red) (10ml)', 'each', 10.0, 25.59),
  ('GF-COS-008', 2, '67010010A', 'QA Sage one step (10 ml)', 'each', 4.0, 36.82),
  ('GF-COS-008', 3, '83110060M', 'Origio handling media (phenol red) (60ml)', 'each', 3.0, 46.23),
  ('GF-COS-008', 4, '16125000A', 'ICSI Cumulase (5 X 0.5ml)', '1 pack', 1.0, 141.64),
  ('GF-COS-008', 5, '10905000A', 'PVP clinical grade (5 X 0.2ml)', '1 pack', 1.0, 130.89),
  ('GF-COS-008', 6, '10765060A', 'Flushing medium (5 X 60 pack)', 'pack', 1.0, 110.77),
  ('GF-COS-008', 7, 'LGUA-100', 'Lifeguard oil (heavy) (100ml)', 'each', 5.0, 60.66),
  ('GF-COS-008-1', 1, '83020010A', 'Origio sequential fertilisation media (phenol red) (10ml)', 'each', 10.0, 25.59),
  ('GF-COS-008-1', 2, '67010010A', 'QA Sage one step (10 ml)', 'each', 4.0, 36.82),
  ('GF-COS-008-1', 3, '83110060M', 'Origio handling media (phenol red) (60ml)', 'each', 3.0, 46.23),
  ('GF-COS-008-1', 4, '16125000A', 'ICSI Cumulase (5 X 0.5ml)', '1 pack', 1.0, 141.64),
  ('GF-COS-008-1', 5, '10905000A', 'PVP clinical grade (5 X 0.2ml)', '1 pack', 1.0, 130.89),
  ('GF-COS-008-1', 6, '10765060A', 'Flushing medium (5 X 60 pack)', 'pack', 1.0, 110.77),
  ('GF-COS-008-1', 7, 'LGUA-100', 'Lifeguard oil (heavy) (100ml)', 'each', 5.0, 60.66),
  ('GF-IVF-004', 1, 'OOIF-STO6', 'Oosafe filter, 6 month filter', '1', 2.0, 168.0),
  ('GF-IVF-004', 2, 'IVFS-CPI - 25', 'Carriage, package and insurance', '1', 1.0, 25.0),
  ('GF-COS-010', 1, 'ULTRA-001', 'Origio gas line filter', '1', 4.0, 80.15),
  ('GF-COS-010', 2, '6-70-104/50', 'RFID Rectangular tags (pack of 50)', '1', 1.0, 165.11),
  ('GF-ANE-003', 1, '10105', 'S-Arm retainer - L shaped', 'each', 2.0, 29.0),
  ('GF-ANE-003', 2, '10115', 'S-Arm retainer pad', 'each', 2.0, 28.0),
  ('GF-LOV-005', 1, '', 'Reactive call out charge for blocked toilets and sink V0080592', 'each', 1.0, 172.5),
  ('GF-COS-009', 1, '83020010A', 'Origio sequential fertilisation media (phenol red) (10ml)', 'each', 10.0, 25.59),
  ('GF-COS-009', 2, '67010010A', 'QA Sage one step (10 ml)', 'each', 4.0, 36.82),
  ('GF-COS-009', 3, '10765060A', 'Flushing medium (5 X 60 pack)', 'pack', 1.0, 110.77),
  ('GF-COS-009', 4, '16125000A', 'ICSI Cumulase (5 X 0.5ml)', '1 pack', 1.0, 141.64),
  ('GF-COS-009', 5, '83110060M', 'Origio handling media (phenol red) (60ml)', 'each', 3.0, 46.23),
  ('GF-COS-009', 6, '10905000A', 'PVP clinical grade (5 X 0.2ml)', '1 pack', 1.0, 130.89)
) v(no, line, code, descr, unit, qty, price)
join public.purchase_orders p on p.po_number = v.no
left join public.products pr on pr.code = v.code and v.code <> ''
where not exists (select 1 from public.po_lines l where l.po_id = p.id and l.line = v.line)
returning line_total;

-- 8. Record the import in the audit log
insert into public.audit_log (actor, actor_name, action, entity, entity_id, detail)
select null, 'Workbook import (Claude, for Karolina)', 'po.imported', 'purchase_order', p.id,
       jsonb_build_object('po_number', p.po_number, 'source', 'Genus_PO_System_6.xlsm')
from public.purchase_orders p
where p.po_number in ('GF-ALG-002', 'GF-AMD-001', 'GF-AMD-001-1', 'GF-ANE-003', 'GF-BIOMED-001', 'GF-BIOMED-002', 'GF-COS-005', 'GF-COS-006', 'GF-COS-007', 'GF-COS-008', 'GF-COS-008-1', 'GF-COS-009', 'GF-COS-010', 'GF-HUNT-001', 'GF-IVF-002', 'GF-IVF-003', 'GF-IVF-004', 'GF-LABD-001', 'GF-LOV-004', 'GF-LOV-005', 'GF-NEQAS-001', 'GF-PAR-002', 'GF-PLN-004', 'GF-SLS-003', 'GF-VIT-002', 'GF-VIT-002-1', 'GF-VIT-004')
returning entity_id;
