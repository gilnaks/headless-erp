begin;
create extension if not exists pgtap with schema extensions;
select plan(22);

-- The document-level checks are deferred to commit (after app.save_doc writes the links); fire them per save.
create function pg_temp.save(p_doctype text, p_payload jsonb) returns jsonb language plpgsql as $$
declare r jsonb;
begin
  r := public.save_doc(p_doctype, p_payload);
  set constraints all immediate;
  set constraints all deferred;
  return r;
end
$$;

insert into auth.users (id, email, aud, role) values
  ('00000000-0000-0000-0000-0000000025a1', 'addr-owner-a@test.local', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-0000000025a2', 'addr-acc-mgr-a@test.local', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-0000000025a3', 'addr-hr-a@test.local', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-0000000025b1', 'addr-owner-b@test.local', 'authenticated', 'authenticated');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000025b1","role":"authenticated"}', true);
select set_config('test.org_b', app.create_organization('{"name":"Addr Org B","slug":"addr-org-b","country":"Netherlands","default_currency":"EUR"}') ->> 'id', true);
insert into public.companies (id, org_id, company_name, abbr) values
  ('00000000-0000-0000-0000-0000000025d1', current_setting('test.org_b')::uuid, 'Other Co', 'OC');

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000025a1","role":"authenticated"}', true);
select set_config('test.org', app.create_organization('{"name":"Addr Org A","slug":"addr-org-a","country":"Germany","default_currency":"EUR"}') ->> 'id', true);
insert into public.org_members (org_id, user_id, roles) values
  (current_setting('test.org')::uuid, '00000000-0000-0000-0000-0000000025a2', '{Accounts Manager}'),
  (current_setting('test.org')::uuid, '00000000-0000-0000-0000-0000000025a3', '{Projects User}');
insert into public.companies (id, org_id, company_name, abbr) values
  ('00000000-0000-0000-0000-0000000025c1', current_setting('test.org')::uuid, 'Acme', 'AC'),
  ('00000000-0000-0000-0000-0000000025c2', current_setting('test.org')::uuid, 'Beta', 'BE');

select set_config('test.a1', (pg_temp.save('Address', jsonb_build_object(
  'org_id', current_setting('test.org'), 'address_line1', ' Hauptstr. 1 ', 'city', 'Berlin', 'pincode', '10115',
  'is_primary_address', true, 'is_shipping_address', true,
  'links', jsonb_build_array(jsonb_build_object('link_doctype', 'Company', 'link_id', '00000000-0000-0000-0000-0000000025c1'))
))) ->> 'id', true);

select is(
  (select (name, address_title, address_type, country, address_line1, is_your_company_address)::text
     from public.address where id = current_setting('test.a1')::uuid),
  '(Acme-Billing,Acme,Billing,Germany,"Hauptstr. 1",t)',
  'name is "<title>-<type>", the title defaults to the first link, country to the organization''s, Company link flags it'
);
select is(
  (select link_title from public.address_link where parent_id = current_setting('test.a1')::uuid),
  'Acme', 'link rows carry the linked record''s title'
);

select set_config('test.a2', (pg_temp.save('Address', jsonb_build_object(
  'org_id', current_setting('test.org'), 'address_line1', 'Lager 5', 'city', 'Hamburg', 'is_primary_address', true,
  'links', jsonb_build_array(jsonb_build_object('link_doctype', 'Company', 'link_id', '00000000-0000-0000-0000-0000000025c1'))
))) ->> 'id', true);
select is(
  (select name from public.address where id = current_setting('test.a2')::uuid),
  'Acme-Billing-1', 'a clashing name gets a -1 suffix'
);
select is(
  (select array_agg((name, is_primary_address, is_shipping_address)::text order by name) from public.address),
  array['(Acme-Billing,f,t)', '(Acme-Billing-1,t,f)'], 'a new primary address unsets the previous one for the same party'
);

select set_config('test.a3', (pg_temp.save('Address', jsonb_build_object(
  'org_id', current_setting('test.org'), 'address_title', 'Beta Plant', 'address_type', 'Plant',
  'address_line1', 'Werk 1', 'city', 'Munich', 'country', 'Germany', 'is_primary_address', true,
  'links', jsonb_build_array(jsonb_build_object('link_doctype', 'Company', 'link_id', '00000000-0000-0000-0000-0000000025c2'))
))) ->> 'id', true);
select is(
  (select is_primary_address from public.address where id = current_setting('test.a2')::uuid),
  true, 'primary addresses of other parties are left alone'
);
select is(
  (select name from public.address where id = current_setting('test.a3')::uuid),
  'Beta Plant-Plant', 'an explicit title is kept'
);

update public.address set address_type = 'Office', address_title = 'Renamed' where id = current_setting('test.a3')::uuid;
select is(
  (select name from public.address where id = current_setting('test.a3')::uuid),
  'Beta Plant-Plant', 'the name is set once (Frappe autoname)'
);

select throws_ok(
  $$select pg_temp.save('Address', jsonb_build_object('org_id', current_setting('test.org'), 'address_line1', 'Nowhere 1', 'city', 'Bonn'))$$,
  'P0001', 'address_title_required: Address Title is mandatory.', 'an address needs a title or a link'
);
select throws_ok(
  $$select pg_temp.save('Address', jsonb_build_object('org_id', current_setting('test.org'), 'address_title', 'Mine',
      'address_line1', 'Nowhere 1', 'city', 'Bonn', 'is_your_company_address', true))$$,
  'P0001', 'address_company_link: Address needs to be linked to a Company. Please add a row for Company in the Links table.',
  'a company address needs a Company link (validate_reference)'
);
select throws_ok(
  $$select pg_temp.save('Address', jsonb_build_object('org_id', current_setting('test.org'), 'address_line1', 'X 1', 'city', 'Bonn',
      'links', jsonb_build_array(jsonb_build_object('link_doctype', 'Company', 'link_id', '00000000-0000-0000-0000-0000000025d1'))))$$,
  'P0001', 'link_invalid: Company not found', 'links must point at a record of the same organization'
);
select throws_ok(
  $$select pg_temp.save('Address', jsonb_build_object('org_id', current_setting('test.org'), 'address_title', 'T', 'address_line1', 'X 1', 'city', 'Bonn',
      'links', jsonb_build_array(jsonb_build_object('link_doctype', 'Customer', 'link_id', '00000000-0000-0000-0000-0000000025c1'))))$$,
  'P0001', 'link_invalid: Customer is not a document type', 'link doctypes are limited to the parties in scope'
);
select throws_ok(
  $$select pg_temp.save('Address', jsonb_build_object('org_id', current_setting('test.org'), 'address_title', 'T', 'address_line1', 'X 1', 'city', 'Bonn',
      'links', jsonb_build_array(
        jsonb_build_object('link_doctype', 'Company', 'link_id', '00000000-0000-0000-0000-0000000025c1'),
        jsonb_build_object('link_doctype', 'Company', 'link_id', '00000000-0000-0000-0000-0000000025c1'))))$$,
  '23505', null, 'a party is linked once per address'
);
select throws_ok(
  $$insert into public.address (org_id, address_title, address_type, address_line1, city) values (current_setting('test.org')::uuid, 'T', 'Home', 'X 1', 'Bonn')$$,
  '23514', null, 'address_type is one of the ERPNext options'
);

select is(
  (select name from public.company_address('00000000-0000-0000-0000-0000000025c1')),
  'Acme-Billing-1', 'company_address: the primary company address'
);
select is(
  (select name from public.company_address('00000000-0000-0000-0000-0000000025c1', 'shipping')),
  'Acme-Billing', 'company_address(shipping): the shipping company address'
);
select is(
  (select array_agg(name) from public.party_addresses('Company', '00000000-0000-0000-0000-0000000025c1')),
  array['Acme-Billing-1', 'Acme-Billing'], 'party_addresses: primary first'
);

update public.companies set company_name = 'Acme GmbH' where id = '00000000-0000-0000-0000-0000000025c1';
select is(
  (select array_agg(distinct link_title) from public.address_link where link_id = '00000000-0000-0000-0000-0000000025c1'),
  array['Acme GmbH'], 'renaming the party refreshes link titles'
);

delete from public.companies where id = '00000000-0000-0000-0000-0000000025c2';
select is(
  (select (is_your_company_address, (select count(*) from public.address_link l where l.parent_id = a.id))::text
     from public.address a where a.id = current_setting('test.a3')::uuid),
  '(f,0)', 'deleting the party removes its links and the company-address flag'
);

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000025a2","role":"authenticated"}', true);
select is(
  (select (select count(*) from public.address)::int + (select count(*) from public.address_link)::int),
  5, 'Accounts Manager reads addresses and links (not another organization''s)'
);
select throws_ok(
  $$insert into public.address (org_id, address_title, address_line1, city) values (current_setting('test.org')::uuid, 'T', 'X 1', 'Bonn')$$,
  '42501', null, 'Accounts Manager cannot create addresses'
);

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000025a3","role":"authenticated"}', true);
select is((select count(*)::int from public.address), 0, 'roles without a rule see no addresses');
select is((select count(*)::int from public.party_addresses('Company', '00000000-0000-0000-0000-0000000025c1')), 0, 'party_addresses applies RLS');

select * from finish();
rollback;
