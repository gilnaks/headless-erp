begin;
create extension if not exists pgtap with schema extensions;
select plan(24);

insert into auth.users (id, email, aud, role) values
  ('00000000-0000-0000-0000-0000000029a1', 'authrule-owner-a@test.local', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-0000000029a2', 'authrule-sales-user-a@test.local', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-0000000029a3', 'authrule-sales-mgr-a@test.local', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-0000000029a4', 'authrule-acc-mgr-a@test.local', 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-0000000029b1', 'authrule-owner-b@test.local', 'authenticated', 'authenticated');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000029b1","role":"authenticated"}', true);
select set_config('test.org_b', app.create_organization('{"name":"AuthRule Org B","slug":"authrule-org-b","country":"Netherlands","default_currency":"EUR"}') ->> 'id', true);

select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000029a1","role":"authenticated"}', true);
select set_config('test.org', app.create_organization('{"name":"AuthRule Org A","slug":"authrule-org-a","country":"Netherlands","default_currency":"EUR"}') ->> 'id', true);
insert into public.org_members (org_id, user_id, roles) values
  (current_setting('test.org')::uuid, '00000000-0000-0000-0000-0000000029a2', '{Sales User}'),
  (current_setting('test.org')::uuid, '00000000-0000-0000-0000-0000000029a3', '{Sales Manager}'),
  (current_setting('test.org')::uuid, '00000000-0000-0000-0000-0000000029a4', '{Accounts Manager}');
insert into public.companies (id, org_id, company_name, abbr) values
  ('00000000-0000-0000-0000-0000000029c1', current_setting('test.org')::uuid, 'Acme', 'AC'),
  ('00000000-0000-0000-0000-0000000029c2', current_setting('test.org')::uuid, 'Beta', 'BE');

-- Rule validation (AuthorizationRule.validate)
select set_config('test.r1', (public.save_doc('Authorization Rule', jsonb_build_object(
  'org_id', current_setting('test.org'), 'transaction', 'Sales Order', 'company_id', '00000000-0000-0000-0000-0000000029c1',
  'value', 1000, 'approving_role', 'Sales Manager'
))) ->> 'id', true);

select is(
  (select (name, based_on, value)::text from public.authorization_rule where id = current_setting('test.r1')::uuid),
  '(HR-ARU-00001,"Grand Total",1000.000000000)',
  'rules are named HR-ARU-.##### and default to Grand Total'
);
select throws_ok(
  $$select public.save_doc('Authorization Rule', jsonb_build_object('org_id', current_setting('test.org'), 'transaction', 'Sales Order', 'value', 5, 'approving_role', 'Sales Manager'))$$,
  'P0001', 'duplicate: Duplicate Entry. Please check Authorization Rule HR-ARU-00001', 'duplicate rules are rejected'
);
select throws_ok(
  $$select public.save_doc('Authorization Rule', jsonb_build_object('org_id', current_setting('test.org'), 'transaction', 'Sales Order', 'value', 5))$$,
  'P0001', 'approver_required: Please enter Approving Role or Approving User', 'an approver is required'
);
select throws_ok(
  $$select public.save_doc('Authorization Rule', jsonb_build_object('org_id', current_setting('test.org'), 'transaction', 'Sales Order', 'system_role', 'Sales User', 'approving_role', 'Sales User'))$$,
  'P0001', 'approving_role_same: Approving Role cannot be same as role the rule is Applicable To',
  'the approving role differs from the applicable role'
);
select throws_ok(
  $$select public.save_doc('Authorization Rule', jsonb_build_object('org_id', current_setting('test.org'), 'transaction', 'Sales Order', 'system_user', '00000000-0000-0000-0000-0000000029a2', 'approving_user', '00000000-0000-0000-0000-0000000029a2'))$$,
  'P0001', 'approving_user_same: Approving User cannot be same as user the rule is Applicable To',
  'the approving user differs from the applicable user'
);
select throws_ok(
  $$select public.save_doc('Authorization Rule', jsonb_build_object('org_id', current_setting('test.org'), 'transaction', 'Sales Order', 'approving_user', '00000000-0000-0000-0000-0000000029b1'))$$,
  'P0001', 'approving_user_not_member: the user is not a member of this organization', 'approvers are members'
);
select throws_ok(
  $$select public.save_doc('Authorization Rule', jsonb_build_object('org_id', current_setting('test.org'), 'transaction', 'Quotation', 'approving_role', 'Sales Manager'))$$,
  '23514', null, 'only Sales/Purchase Order and Invoice are supported'
);
select is(
  (public.save_doc('Authorization Rule', jsonb_build_object('id', current_setting('test.r1'), 'name', 'Renamed'))) ->> 'name',
  'HR-ARU-00001', 'the name cannot be changed'
);

-- Enforcement (AuthorizationControl.validate_approving_authority)
reset role;
select throws_ok(
  $$select app.validate_approving_authority('Sales Order', '00000000-0000-0000-0000-0000000029c1', 5000, '00000000-0000-0000-0000-0000000029a2')$$,
  'P0001', 'not_authorized: Not authorized since Grand Total exceeds limits. Can be approved by Sales Manager',
  'a total over the threshold needs the approving role'
);
select lives_ok(
  $$select app.validate_approving_authority('Sales Order', '00000000-0000-0000-0000-0000000029c1', 500, '00000000-0000-0000-0000-0000000029a2')$$,
  'a total under the threshold passes'
);
select lives_ok(
  $$select app.validate_approving_authority('Sales Order', '00000000-0000-0000-0000-0000000029c1', 5000, '00000000-0000-0000-0000-0000000029a3')$$,
  'the approving role passes'
);
select lives_ok(
  $$select app.validate_approving_authority('Sales Order', '00000000-0000-0000-0000-0000000029c2', 5000, '00000000-0000-0000-0000-0000000029a2')$$,
  'company-specific rules do not apply to other companies'
);
select lives_ok(
  $$select app.validate_approving_authority('Purchase Order', '00000000-0000-0000-0000-0000000029c1', 1e9, '00000000-0000-0000-0000-0000000029a2')$$,
  'transactions without rules pass'
);

set local role authenticated;
select lives_ok(
  $$select public.save_doc('Authorization Rule', jsonb_build_object('org_id', current_setting('test.org'), 'transaction', 'Sales Order', 'value', 10000, 'approving_user', '00000000-0000-0000-0000-0000000029a4'))$$,
  'a global rule with an approving user'
);
reset role;
select throws_ok(
  $$select app.validate_approving_authority('Sales Order', '00000000-0000-0000-0000-0000000029c2', 20000, '00000000-0000-0000-0000-0000000029a2')$$,
  'P0001', 'not_authorized: Not authorized since Grand Total exceeds limits. Can be approved by authrule-acc-mgr-a@test.local',
  'rules without a company apply when the company has none'
);
select throws_ok(
  $$select app.validate_approving_authority('Sales Order', '00000000-0000-0000-0000-0000000029c1', 20000, '00000000-0000-0000-0000-0000000029a4')$$,
  'P0001', 'not_authorized: Not authorized since Grand Total exceeds limits. Can be approved by Sales Manager',
  'company-specific rules take precedence over rules without a company'
);

-- Role rules replace global rules; user rules replace role rules.
set local role authenticated;
select lives_ok(
  $$select public.save_doc('Authorization Rule', jsonb_build_object('org_id', current_setting('test.org'), 'transaction', 'Sales Order', 'value', 50000, 'system_role', 'Sales User', 'approving_role', 'Accounts Manager'))$$,
  'a rule for a role'
);
reset role;
select lives_ok(
  $$select app.validate_approving_authority('Sales Order', '00000000-0000-0000-0000-0000000029c1', 5000, '00000000-0000-0000-0000-0000000029a2')$$,
  'role rules replace the global rules for holders of the role'
);
select throws_ok(
  $$select app.validate_approving_authority('Sales Order', '00000000-0000-0000-0000-0000000029c1', 60000, '00000000-0000-0000-0000-0000000029a2')$$,
  'P0001', 'not_authorized: Not authorized since Grand Total exceeds limits. Can be approved by Accounts Manager',
  'role rules are enforced'
);
set local role authenticated;
do $$ begin
  perform public.save_doc('Authorization Rule', jsonb_build_object('org_id', current_setting('test.org'), 'transaction', 'Sales Order', 'value', 100, 'system_user', '00000000-0000-0000-0000-0000000029a2', 'approving_user', '00000000-0000-0000-0000-0000000029a3'));
end $$;
reset role;
select throws_ok(
  $$select app.validate_approving_authority('Sales Order', '00000000-0000-0000-0000-0000000029c1', 60000, '00000000-0000-0000-0000-0000000029a2')$$,
  'P0001', 'not_authorized: Not authorized since Grand Total exceeds limits. Can be approved by authrule-sales-mgr-a@test.local',
  'user rules replace the role rules'
);
select ok(
  not has_function_privilege('authenticated', 'app.validate_approving_authority(text, uuid, numeric, uuid)', 'execute'),
  'API roles cannot call the enforcement function'
);

-- Permissions and isolation
set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000029a3","role":"authenticated"}', true);
select is((select count(*)::int from public.authorization_rule), 0, 'only System Managers read rules');
select throws_ok(
  $$select public.save_doc('Authorization Rule', jsonb_build_object('org_id', current_setting('test.org'), 'transaction', 'Purchase Order', 'approving_role', 'Purchase Manager'))$$,
  '42501', null, 'only System Managers create rules'
);
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000029b1","role":"authenticated"}', true);
select is(
  (public.save_doc('Authorization Rule', jsonb_build_object('org_id', current_setting('test.org_b'), 'transaction', 'Sales Order', 'approving_role', 'Sales Manager'))) ->> 'name',
  'HR-ARU-00001', 'each organization has its own series and only sees its own rules'
);

select * from finish();
rollback;
