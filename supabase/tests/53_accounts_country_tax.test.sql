begin;
create extension if not exists pgtap with schema extensions;
select plan(8);

insert into auth.users (id, email, aud, role) values
  ('00000000-0000-0000-0000-0000000053a1', 'country-tax-owner@test.local', 'authenticated', 'authenticated');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000053a1","role":"authenticated"}', true);
select set_config(
  'test.org',
  app.create_organization('{"name":"Country Tax Org","slug":"country-tax-org","country":"Ivory Coast","default_currency":"XOF"}') ->> 'id',
  true
);

insert into public.companies (id, org_id, company_name, abbr, country) values
  ('20000000-0000-0000-0000-0000000053c1', current_setting('test.org')::uuid, 'Tax Co', 'IC', 'Ivory Coast'),
  ('20000000-0000-0000-0000-0000000053c2', current_setting('test.org')::uuid, 'Ice Co', 'GL', 'Greenland');

set constraints item_tax_template_rows, item_tax_detail_rows immediate;
set constraints item_tax_template_rows, item_tax_detail_rows deferred;

do $$
begin
  perform public.create_default_tax_templates('20000000-0000-0000-0000-0000000053c1');
end $$;

select is(
  (
    select t.name
      from public.sales_taxes_and_charges_template t
     where t.company_id = '20000000-0000-0000-0000-0000000053c1'
  ),
  'Ivory Coast - IC',
  'an Ivory Coast company gets a sales template named Ivory Coast - IC'
);
select is(
  (
    select t.name
      from public.purchase_taxes_and_charges_template t
     where t.company_id = '20000000-0000-0000-0000-0000000053c1'
  ),
  'Ivory Coast - IC',
  'an Ivory Coast company gets a purchase template named Ivory Coast - IC'
);
select is(
  (
    select t.name
      from public.item_tax_template t
     where t.company_id = '20000000-0000-0000-0000-0000000053c1'
  ),
  'Ivory Coast - IC',
  'an Ivory Coast company gets an item tax template named Ivory Coast - IC'
);
select is(
  (
    select d.tax_rate
      from public.item_tax_template_detail d
      join public.item_tax_template t on t.id = d.parent_id
     where t.company_id = '20000000-0000-0000-0000-0000000053c1'
  ),
  18::numeric,
  'the item tax rate is 18'
);
select is(
  (
    select a.account_name
      from public.item_tax_template_detail d
      join public.account a on a.id = d.tax_type_id
      join public.item_tax_template t on t.id = d.parent_id
     where t.company_id = '20000000-0000-0000-0000-0000000053c1'
  ),
  'Metric',
  'the item tax account is named Metric'
);
select is(
  (
    select count(*)::int
      from public.sales_taxes_and_charges_template t
     where t.company_id = '20000000-0000-0000-0000-0000000053c1'
  ),
  1,
  'calling the function again does not add a second template'
);
select is(
  (
    select count(*)::int
      from public.sales_taxes_and_charges_template t
     where t.company_id = '20000000-0000-0000-0000-0000000053c2'
  ),
  0,
  'a Greenland company gets no template'
);

reset role;
select lives_ok(
  $$
    delete from public.organizations where id = current_setting('test.org')::uuid;
    set constraints item_tax_template_rows, item_tax_detail_rows immediate;
  $$,
  'deleting the organization succeeds'
);

select * from finish();
rollback;
