begin;
create extension if not exists pgtap with schema extensions;
select plan(8);

insert into auth.users (id, email, aud, role) values
  ('00000000-0000-0000-0000-0000000047a1', 'terms-owner@test.local', 'authenticated', 'authenticated');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-0000000047a1","role":"authenticated"}', true);
select set_config(
  'test.org',
  app.create_organization('{"name":"Terms Org","slug":"terms-org","country":"Ivory Coast","default_currency":"XOF"}') ->> 'id',
  true
);

insert into public.companies (id, org_id, company_name, abbr) values
  ('20000000-0000-0000-0000-0000000047a1', current_setting('test.org')::uuid, 'Terms Co', 'TC');

select lives_ok(
  $$insert into public.payment_term (id, org_id, payment_term_name)
    values (
      '30000000-0000-0000-0000-0000000047b1',
      current_setting('test.org')::uuid,
      'Net 30'
    )$$,
  'System Manager can add a payment term'
);

select lives_ok(
  $$
    set constraints payment_terms_template_refresh, payment_terms_detail_refresh deferred;
    insert into public.payment_terms_template (id, org_id, template_name)
    values ('30000000-0000-0000-0000-0000000047c1', current_setting('test.org')::uuid, 'Standard');
    insert into public.payment_terms_template_detail (org_id, parent_id, idx, invoice_portion, due_date_based_on, payment_term_id)
    values (
      current_setting('test.org')::uuid,
      '30000000-0000-0000-0000-0000000047c1',
      1, 100, 'Day(s) after invoice date',
      '30000000-0000-0000-0000-0000000047b1'
    );
    set constraints payment_terms_template_refresh, payment_terms_detail_refresh immediate;
    set constraints payment_terms_template_refresh, payment_terms_detail_refresh deferred;
  $$,
  'a template whose portions add to 100% saves'
);

select throws_ok(
  $$
    set constraints payment_terms_template_refresh, payment_terms_detail_refresh deferred;
    insert into public.payment_terms_template (id, org_id, template_name)
    values ('30000000-0000-0000-0000-0000000047c2', current_setting('test.org')::uuid, 'Short');
    insert into public.payment_terms_template_detail (org_id, parent_id, idx, invoice_portion, due_date_based_on)
    values (
      current_setting('test.org')::uuid,
      '30000000-0000-0000-0000-0000000047c2',
      1, 90, 'Day(s) after invoice date'
    );
    set constraints payment_terms_template_refresh, payment_terms_detail_refresh immediate;
  $$,
  'P0001',
  'payment_terms_portion: Combined invoice portion must equal 100%',
  'a template whose portions are not 100% is rejected'
);

select throws_ok(
  $$
    set constraints payment_terms_template_refresh, payment_terms_detail_refresh deferred;
    insert into public.payment_terms_template (id, org_id, template_name, allocate_payment_based_on_payment_terms)
    values ('30000000-0000-0000-0000-0000000047c3', current_setting('test.org')::uuid, 'Allocate', true);
    insert into public.payment_terms_template_detail (org_id, parent_id, idx, invoice_portion, due_date_based_on)
    values (
      current_setting('test.org')::uuid,
      '30000000-0000-0000-0000-0000000047c3',
      1, 100, 'Day(s) after invoice date'
    );
    set constraints payment_terms_template_refresh, payment_terms_detail_refresh immediate;
  $$,
  'P0001',
  'payment_term_required: Row 1: Payment Term is mandatory',
  'allocate requires a payment term on every row'
);

select throws_ok(
  $$
    set constraints payment_terms_template_refresh, payment_terms_detail_refresh deferred;
    insert into public.payment_terms_template (id, org_id, template_name)
    values ('30000000-0000-0000-0000-0000000047c4', current_setting('test.org')::uuid, 'Twice');
    insert into public.payment_terms_template_detail (org_id, parent_id, idx, invoice_portion, due_date_based_on, payment_term_id)
    values
      (
        current_setting('test.org')::uuid,
        '30000000-0000-0000-0000-0000000047c4',
        1, 40, 'Day(s) after invoice date',
        '30000000-0000-0000-0000-0000000047b1'
      ),
      (
        current_setting('test.org')::uuid,
        '30000000-0000-0000-0000-0000000047c4',
        2, 60, 'Day(s) after invoice date',
        '30000000-0000-0000-0000-0000000047b1'
      );
    set constraints payment_terms_template_refresh, payment_terms_detail_refresh immediate;
  $$,
  'P0001',
  'payment_term_duplicate: Duplicate payment term rows',
  'the same payment term cannot be entered twice'
);

reset role;
update public.companies
   set payment_terms_id = '30000000-0000-0000-0000-0000000047c1'
 where id = '20000000-0000-0000-0000-0000000047a1';
select is(
  (select payment_terms_id::text from public.companies where id = '20000000-0000-0000-0000-0000000047a1'),
  '30000000-0000-0000-0000-0000000047c1',
  'a company can point at its own template'
);

delete from public.payment_terms_template where id = '30000000-0000-0000-0000-0000000047c1';
select is(
  (select payment_terms_id is null from public.companies where id = '20000000-0000-0000-0000-0000000047a1'),
  true,
  'deleting that template nulls the company link'
);

select lives_ok(
  $$
    set constraints payment_terms_template_refresh, payment_terms_detail_refresh deferred;
    insert into public.payment_terms_template (id, org_id, template_name)
    values ('30000000-0000-0000-0000-0000000047c5', current_setting('test.org')::uuid, 'Again');
    insert into public.payment_terms_template_detail (org_id, parent_id, idx, invoice_portion, due_date_based_on, payment_term_id)
    values (
      current_setting('test.org')::uuid,
      '30000000-0000-0000-0000-0000000047c5',
      1, 100, 'Day(s) after invoice date',
      '30000000-0000-0000-0000-0000000047b1'
    );
    set constraints payment_terms_template_refresh, payment_terms_detail_refresh immediate;
    set constraints payment_terms_template_refresh, payment_terms_detail_refresh deferred;
    delete from public.organizations where id = current_setting('test.org')::uuid;
    set constraints all immediate;
  $$,
  'deleting an organization that owns a term and a template succeeds'
);

select * from finish();
rollback;
