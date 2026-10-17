begin;
create extension if not exists pgtap with schema extensions;
select plan(12);

insert into auth.users (id, email, aud, role) values
  ('00000000-0000-0000-0000-0000000059a1', 'tax-rule-owner@test.local', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-0000000059a2', 'tax-rule-manager@test.local', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-0000000059a3', 'tax-rule-user@test.local', 'authenticated', 'authenticated');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000059a1","role":"authenticated"}', true);
select set_config(
  'test.org',
  app.create_organization('{"name":"Tax Rule Org","slug":"tax-rule-org","country":"Ivory Coast","default_currency":"XOF"}') ->> 'id',
  true
);

reset role;
insert into public.org_members (org_id, user_id, roles) values
  (current_setting('test.org')::uuid, '00000000-0000-0000-0000-0000000059a2', '{Accounts Manager}'),
  (current_setting('test.org')::uuid, '00000000-0000-0000-0000-0000000059a3', '{Accounts User}');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000059a1","role":"authenticated"}', true);
insert into public.companies (id, org_id, company_name, abbr) values
  ('20000000-0000-0000-0000-0000000059c1', current_setting('test.org')::uuid, 'Price Co', 'PC'),
  ('20000000-0000-0000-0000-0000000059c2', current_setting('test.org')::uuid, 'Other Co', 'OC');

reset role;
select set_config('test.seeded', (
  select t.id::text from public.sales_taxes_and_charges_template t
   where t.company_id = '20000000-0000-0000-0000-0000000059c1'
   order by t.created_at
   limit 1
), true);
select set_config('test.other', (
  select t.id::text from public.sales_taxes_and_charges_template t
   where t.company_id = '20000000-0000-0000-0000-0000000059c2'
   order by t.created_at
   limit 1
), true);
insert into public.sales_taxes_and_charges_template (id, org_id, title, company_id) values
  ('20000000-0000-0000-0000-0000000059e1', current_setting('test.org')::uuid, 'Retail', '20000000-0000-0000-0000-0000000059c1'),
  ('20000000-0000-0000-0000-0000000059e2', current_setting('test.org')::uuid, 'Group', '20000000-0000-0000-0000-0000000059c1');
select set_config('test.all_groups', (
  select g.id::text from public.customer_group g
   where g.org_id = current_setting('test.org')::uuid and g.customer_group_name = 'All Customer Groups'
), true);
select set_config('test.individual', (
  select g.id::text from public.customer_group g
   where g.org_id = current_setting('test.org')::uuid and g.customer_group_name = 'Individual'
), true);

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000059a2","role":"authenticated"}', true);
insert into public.tax_rule (
  id, org_id, company_id, tax_type, sales_tax_template_id, purchase_tax_template_id, supplier_id
) values (
  '20000000-0000-0000-0000-0000000059d1',
  current_setting('test.org')::uuid,
  '20000000-0000-0000-0000-0000000059c1',
  'Sales',
  '20000000-0000-0000-0000-0000000059e1',
  current_setting('test.other')::uuid,
  '20000000-0000-0000-0000-0000000059f1'
);
select ok(
  (
    select name from public.tax_rule
     where id = '20000000-0000-0000-0000-0000000059d1'
  ) like 'ACC-TAX-RULE-%',
  'the name matches ACC-TAX-RULE-'
);
select ok(
  (
    select r.supplier_id is null and r.purchase_tax_template_id is null
      from public.tax_rule r
     where r.id = '20000000-0000-0000-0000-0000000059d1'
  ),
  'a sales rule clears a supplier and a purchase template'
);

select throws_ok(
  $$insert into public.tax_rule (org_id, company_id, tax_type)
    values (current_setting('test.org')::uuid, '20000000-0000-0000-0000-0000000059c1', 'Sales')$$,
  'P0001',
  'tax_rule_template: Tax Template is mandatory',
  'a missing template is rejected'
);
select throws_ok(
  $$insert into public.tax_rule (org_id, company_id, tax_type, sales_tax_template_id)
    values (
      current_setting('test.org')::uuid,
      '20000000-0000-0000-0000-0000000059c1',
      'Sales',
      current_setting('test.other')::uuid
    )$$,
  'P0001',
  'tax_rule_company: Tax Template does not belong to the company',
  'a template from another company is rejected'
);
select throws_ok(
  $$insert into public.tax_rule (org_id, company_id, tax_type, sales_tax_template_id, from_date, to_date)
    values (
      current_setting('test.org')::uuid,
      '20000000-0000-0000-0000-0000000059c1',
      'Sales',
      '20000000-0000-0000-0000-0000000059e1',
      current_date,
      current_date - 1
    )$$,
  'P0001',
  'tax_rule_dates: To Date cannot be before From Date',
  'a to-date before the from-date is rejected'
);

select set_config(
  'test.name',
  (select name from public.tax_rule where id = '20000000-0000-0000-0000-0000000059d1'),
  true
);
select throws_ok(
  $$insert into public.tax_rule (org_id, company_id, tax_type, sales_tax_template_id, priority)
    values (
      current_setting('test.org')::uuid,
      '20000000-0000-0000-0000-0000000059c1',
      'Sales',
      '20000000-0000-0000-0000-0000000059e1',
      1
    )$$,
  'P0001',
  'tax_rule_conflict: Tax Rule Conflicts with ' || current_setting('test.name'),
  'the same filters and priority conflict'
);
select lives_ok(
  $$insert into public.tax_rule (id, org_id, company_id, tax_type, sales_tax_template_id, priority)
    values (
      '20000000-0000-0000-0000-0000000059d2',
      current_setting('test.org')::uuid,
      '20000000-0000-0000-0000-0000000059c1',
      'Sales',
      '20000000-0000-0000-0000-0000000059e1',
      2
    )$$,
  'a higher priority does not conflict'
);

insert into public.tax_rule (id, org_id, company_id, tax_type, sales_tax_template_id, customer_group_id)
values (
  '20000000-0000-0000-0000-0000000059d3',
  current_setting('test.org')::uuid,
  '20000000-0000-0000-0000-0000000059c1',
  'Sales',
  '20000000-0000-0000-0000-0000000059e2',
  current_setting('test.all_groups')::uuid
);
select is(
  (
    select public.get_tax_template(
      current_date,
      jsonb_build_object(
        'company_id', '20000000-0000-0000-0000-0000000059c1',
        'customer_group_id', current_setting('test.individual')
      )
    )
  ),
  '20000000-0000-0000-0000-0000000059e2'::uuid,
  'a customer-group ancestor matches'
);

insert into public.tax_rule (id, org_id, company_id, tax_type, sales_tax_template_id, billing_country)
values (
  '20000000-0000-0000-0000-0000000059d4',
  current_setting('test.org')::uuid,
  '20000000-0000-0000-0000-0000000059c1',
  'Sales',
  current_setting('test.seeded')::uuid,
  'Philippines'
);
select is(
  (
    select public.get_tax_template(
      current_date,
      jsonb_build_object(
        'company_id', '20000000-0000-0000-0000-0000000059c1',
        'billing_country', 'Philippines'
      )
    )
  ),
  current_setting('test.seeded')::uuid,
  'get_tax_template prefers the rule with more filled filters'
);

reset role;
update public.sales_taxes_and_charges_template
   set disabled = true, is_default = false
 where id = current_setting('test.seeded')::uuid;
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000059a2","role":"authenticated"}', true);
select ok(
  (
    select public.get_tax_template(
      current_date,
      jsonb_build_object(
        'company_id', '20000000-0000-0000-0000-0000000059c1',
        'billing_country', 'Philippines'
      )
    )
  ) is null,
  'a disabled template returns null'
);

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000059a3","role":"authenticated"}', true);
select throws_ok(
  $$insert into public.tax_rule (org_id, company_id, tax_type, sales_tax_template_id, billing_city)
    values (
      current_setting('test.org')::uuid,
      '20000000-0000-0000-0000-0000000059c1',
      'Sales',
      '20000000-0000-0000-0000-0000000059e1',
      'Nowhere'
    )$$,
  '42501',
  null,
  'Accounts User cannot create'
);

reset role;
select lives_ok(
  $$delete from public.organizations where id = current_setting('test.org')::uuid$$,
  'deleting the organization succeeds'
);

select * from finish();
rollback;
