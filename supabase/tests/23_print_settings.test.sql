begin;
create extension if not exists pgtap with schema extensions;
select plan(11);

insert into auth.users (id, email, aud, role) values
  ('00000000-0000-0000-0000-0000000023a1', 'ps-owner-a@test.local', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-0000000023a2', 'ps-sales-a@test.local', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-0000000023b1', 'ps-owner-b@test.local', 'authenticated', 'authenticated');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000023b1","role":"authenticated"}', true);
select set_config('test.org_b', app.create_organization('{"name":"PS Org B","slug":"ps-org-b"}') ->> 'id', true);
insert into public.letter_head (id, org_id, letter_head_name) values
  ('00000000-0000-0000-0000-0000000023f1', current_setting('test.org_b')::uuid, 'B Letter Head');
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000023a1","role":"authenticated"}', true);
select set_config('test.org', app.create_organization('{"name":"PS Org A","slug":"ps-org-a"}') ->> 'id', true);
insert into public.org_members (org_id, user_id, roles) values
  (current_setting('test.org')::uuid, '00000000-0000-0000-0000-0000000023a2', '{Sales User}');

select is((select count(*)::int from public.print_settings), 1, 'each organization gets one print settings row; others are invisible');
select results_eq(
  $$select print_style, font, font_size, pdf_page_size, with_letterhead, allow_print_for_draft, allow_print_for_cancelled,
           add_draft_heading, repeat_header_footer, compact_item_print, print_uom_after_quantity, print_taxes_with_zero_amount
      from public.print_settings$$,
  $$values ('Modern', 'Default', 9.0::numeric, 'A4', true, true, false, true, true, true, false, false)$$,
  'defaults follow Frappe and erpnext/setup/install.py'
);
select throws_ok(
  $$update public.print_settings set print_style = 'Classic'$$,
  '23514', null, 'only the Modern print style is supported'
);
select throws_ok(
  $$update public.print_settings set pdf_page_size = 'Custom'$$,
  '23514', null, 'a Custom page size needs a height and width'
);
update public.print_settings set pdf_page_size = 'Custom', pdf_page_height = 200, pdf_page_width = 100;
select is((select pdf_page_size from public.print_settings), 'Custom', 'a Custom page size with dimensions is accepted');
select throws_ok(
  $$update public.print_settings set letter_head_id = '00000000-0000-0000-0000-0000000023f1'$$,
  '23503', null, 'another organization''s letter head cannot be the print letter head'
);
insert into public.letter_head (id, org_id, letter_head_name) values
  ('00000000-0000-0000-0000-0000000023e1', current_setting('test.org')::uuid, 'A Letter Head');
update public.print_settings set letter_head_id = '00000000-0000-0000-0000-0000000023e1';
delete from public.letter_head where id = '00000000-0000-0000-0000-0000000023e1';
select is((select letter_head_id from public.print_settings), null, 'deleting the letter head clears it from print settings');
select throws_ok(
  $$insert into public.print_settings (org_id) values (current_setting('test.org')::uuid)$$,
  '42501', null, 'print settings rows cannot be inserted'
);

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000023a2","role":"authenticated"}', true);
select is((select count(*)::int from public.print_settings), 1, 'every member reads print settings');
update public.print_settings set font_size = 12;
select is((select font_size from public.print_settings), 9.0::numeric, 'non System Managers cannot change print settings');

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000023a1","role":"authenticated"}', true);
update public.print_settings set font_size = 12;
select is((select font_size from public.print_settings), 12.0::numeric, 'System Managers change print settings');

select * from finish();
rollback;
