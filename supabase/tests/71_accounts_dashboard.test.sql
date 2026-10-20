begin;
create extension if not exists pgtap with schema extensions;
select plan(6);

insert into auth.users (id, email, aud, role) values
  ('00000000-0000-0000-0000-000000007101', 'dash71@test.local', 'authenticated', 'authenticated');

set local role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-000000007101","role":"authenticated"}', true);
select set_config(
  'test.org',
  public.provision_organization('{
    "org": {"name": "Dashboard Co", "slug": "dash-71", "country": "Philippines", "default_currency": "PHP"},
    "company": {"company_name": "Dashboard Co", "chart_of_accounts": "Philippines", "fy_start_date": "2026-01-01", "fy_end_date": "2026-12-31"}
  }') ->> 'id',
  true
);
select set_config(
  'test.company',
  (select id::text from public.companies where org_id = current_setting('test.org')::uuid limit 1),
  true
);

update public.org_members
   set roles = roles || array['Accounts Manager', 'Sales Manager', 'Purchase Manager']
 where org_id = current_setting('test.org')::uuid
   and user_id = '00000000-0000-0000-0000-000000007101';

select set_config(
  'test.customer',
  (public.save_doc('Customer', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'customer_name', 'Acme'
  )) ->> 'id'),
  true
);
select set_config(
  'test.supplier',
  (public.save_doc('Supplier', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'supplier_name', 'Bolt Supply',
    'supplier_type', 'Company'
  )) ->> 'id'),
  true
);

create function pg_temp.filters() returns jsonb
language sql
as $$
  select jsonb_build_object(
    'company', current_setting('test.company')::uuid,
    'from_date', '2026-01-01',
    'to_date', '2026-10-31'
  );
$$;

create function pg_temp.filters_rejected() returns boolean
language plpgsql
as $$
declare
  v_company boolean := false;
  v_dates boolean := false;
begin
  begin
    perform public.card_sum('payment_entry', 'base_received_amount', '{}'::jsonb);
  exception when others then
    v_company := sqlerrm like '%dash_company%';
  end;
  begin
    perform public.chart_account_balance_timeline(jsonb_build_object(
      'company', current_setting('test.company')::uuid,
      'from_date', '2026-12-31',
      'to_date', '2026-01-01'
    ));
  exception when others then
    v_dates := sqlerrm like '%To Date cannot be less than From Date%';
  end;
  return v_company and v_dates;
end;
$$;

select is(pg_temp.filters_rejected(), true, 'a missing company and reversed dates are rejected');

select set_config(
  'test.receive_journal',
  (public.save_doc('Journal Entry', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'posting_date', '2026-10-16',
    'accounts', jsonb_build_array(
      jsonb_build_object(
        'account_id', (select default_receivable_account_id from public.companies where id = current_setting('test.company')::uuid),
        'party_type', 'Customer',
        'party_id', current_setting('test.customer')::uuid,
        'debit', 100
      ),
      jsonb_build_object(
        'account_id', (select default_income_account_id from public.companies where id = current_setting('test.company')::uuid),
        'credit', 100
      )
    )
  )) ->> 'id'),
  true
);
select set_config('test.receive_journal_submitted', public.submit_doc('Journal Entry', current_setting('test.receive_journal')::uuid)::text, true);

select set_config(
  'test.receive',
  (public.save_doc('Payment Entry', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'posting_date', '2026-10-16',
    'payment_type', 'Receive',
    'party_type', 'Customer',
    'party_id', current_setting('test.customer')::uuid,
    'paid_from_account_id', (select default_receivable_account_id from public.companies where id = current_setting('test.company')::uuid),
    'paid_to_account_id', (select default_cash_account_id from public.companies where id = current_setting('test.company')::uuid),
    'paid_amount', 100,
    'received_amount', 100,
    'references', jsonb_build_array(jsonb_build_object(
      'reference_doctype', 'Journal Entry',
      'reference_id', current_setting('test.receive_journal')::uuid,
      'allocated_amount', 100,
      'account_id', (select default_receivable_account_id from public.companies where id = current_setting('test.company')::uuid)
    ))
  )) ->> 'id'),
  true
);
select set_config('test.receive_submitted', public.submit_doc('Payment Entry', current_setting('test.receive')::uuid)::text, true);

select set_config(
  'test.pay_journal',
  (public.save_doc('Journal Entry', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'posting_date', '2026-10-16',
    'accounts', jsonb_build_array(
      jsonb_build_object(
        'account_id', (select id from public.account where company_id = current_setting('test.company')::uuid and account_number = '5116' and not is_group),
        'debit', 40
      ),
      jsonb_build_object(
        'account_id', (select default_payable_account_id from public.companies where id = current_setting('test.company')::uuid),
        'party_type', 'Supplier',
        'party_id', current_setting('test.supplier')::uuid,
        'credit', 40
      )
    )
  )) ->> 'id'),
  true
);
select set_config('test.pay_journal_submitted', public.submit_doc('Journal Entry', current_setting('test.pay_journal')::uuid)::text, true);

select set_config(
  'test.pay',
  (public.save_doc('Payment Entry', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'posting_date', '2026-10-16',
    'payment_type', 'Pay',
    'party_type', 'Supplier',
    'party_id', current_setting('test.supplier')::uuid,
    'paid_from_account_id', (select default_cash_account_id from public.companies where id = current_setting('test.company')::uuid),
    'paid_to_account_id', (select default_payable_account_id from public.companies where id = current_setting('test.company')::uuid),
    'paid_amount', 40,
    'received_amount', 40,
    'references', jsonb_build_array(jsonb_build_object(
      'reference_doctype', 'Journal Entry',
      'reference_id', current_setting('test.pay_journal')::uuid,
      'allocated_amount', 40,
      'account_id', (select default_payable_account_id from public.companies where id = current_setting('test.company')::uuid)
    ))
  )) ->> 'id'),
  true
);
select set_config('test.pay_submitted', public.submit_doc('Payment Entry', current_setting('test.pay')::uuid)::text, true);

select is(
  (
    select (public.card_sum('payment_entry', 'base_received_amount', pg_temp.filters()) ->> 'value')::numeric = 100
       and (public.card_sum('payment_entry', 'base_received_amount', pg_temp.filters()) ->> 'current')::numeric = 100
       and (public.card_sum('payment_entry', 'base_received_amount', pg_temp.filters()) ->> 'previous')::numeric = 0
       and public.card_sum('payment_entry', 'base_received_amount', pg_temp.filters()) -> 'percent' is null
       and (public.card_sum('payment_entry', 'base_paid_amount', pg_temp.filters()) ->> 'value')::numeric = 40
       and (public.card_sum('payment_entry', 'base_paid_amount', pg_temp.filters()) ->> 'current')::numeric = 40
  ),
  true,
  'a submitted Receive of 100 and Pay of 40 are the card totals'
);

select set_config('test.pay_cancelled', public.cancel_doc('Payment Entry', current_setting('test.pay')::uuid)::text, true);

select is(
  (
    select (public.card_sum('payment_entry', 'base_paid_amount', pg_temp.filters()) ->> 'value')::numeric = 0
       and (public.card_sum('payment_entry', 'base_received_amount', pg_temp.filters()) ->> 'value')::numeric = 100
  ),
  true,
  'cancelling the Pay drops outgoing to 0'
);

select set_config(
  'test.bank_journal',
  (public.save_doc('Journal Entry', jsonb_build_object(
    'org_id', current_setting('test.org')::uuid,
    'company_id', current_setting('test.company')::uuid,
    'posting_date', '2026-03-15',
    'accounts', jsonb_build_array(
      jsonb_build_object(
        'account_id', (select default_bank_account_id from public.companies where id = current_setting('test.company')::uuid),
        'debit', 1000
      ),
      jsonb_build_object(
        'account_id', (select id from public.account where company_id = current_setting('test.company')::uuid and account_number = '3101' and not is_group),
        'credit', 1000
      )
    )
  )) ->> 'id'),
  true
);
select set_config('test.bank_journal_submitted', public.submit_doc('Journal Entry', current_setting('test.bank_journal')::uuid)::text, true);

select is(
  (
    with chart as (
      select public.chart_account_balance_timeline(jsonb_build_object(
        'company', current_setting('test.company')::uuid,
        'from_date', '2026-01-01',
        'to_date', '2026-10-31'
      )) as body
    )
    select (body -> 'chart' ->> 'type') = 'line'
       and jsonb_array_length(body -> 'chart' -> 'labels') = 12
       and (body -> 'chart' -> 'labels' ->> 0) = 'Nov 2025'
       and (body -> 'chart' -> 'datasets' -> 0 -> 'values' ->> 0)::numeric = 0
       and (body -> 'chart' -> 'datasets' -> 0 -> 'values' ->> 3)::numeric = 0
       and (body -> 'chart' -> 'labels' ->> 4) = 'Mar 2026'
       and (body -> 'chart' -> 'datasets' -> 0 -> 'values' ->> 4)::numeric = 1000
       and (body -> 'chart' -> 'labels' ->> 11) = 'Oct 2026'
       and (body -> 'chart' -> 'datasets' -> 0 -> 'values' ->> 11)::numeric = 1000
      from chart
  ),
  true,
  'a March bank debit of 1000 is 0 before March and 1000 through October'
);

select is(
  (
    select (public.card_sum('sales_invoice', 'base_net_total', pg_temp.filters()) ->> 'available') = 'false'
       and (public.chart_timeseries('sales_invoice', 'base_net_total', 'posting_date', 'monthly', 12, pg_temp.filters()) ->> 'available') = 'false'
       and (public.chart_timeseries('purchase_invoice', 'base_net_total', 'posting_date', 'monthly', 12, pg_temp.filters()) ->> 'available') = 'false'
  ),
  true,
  'invoice cards and bill charts are not available yet'
);

select set_config(
  'test.other',
  public.provision_organization('{
    "org": {"name": "Dashboard Other", "slug": "dash-71-b", "country": "Philippines", "default_currency": "PHP"},
    "company": {"company_name": "Dashboard Other", "chart_of_accounts": "Philippines", "fy_start_date": "2026-01-01", "fy_end_date": "2026-12-31"}
  }') ->> 'id',
  true
);
select set_config(
  'test.other_company',
  (select id::text from public.companies where org_id = current_setting('test.other')::uuid limit 1),
  true
);

select is(
  (
    with other_filters as (
      select jsonb_build_object(
        'company', current_setting('test.other_company')::uuid,
        'from_date', '2026-01-01',
        'to_date', '2026-10-31'
      ) as filters
    ),
    cards as (
      select public.card_sum('payment_entry', 'base_received_amount', filters) as body from other_filters
    ),
    bank as (
      select public.chart_account_balance_timeline(filters) as body from other_filters
    )
    select (select (body ->> 'value')::numeric = 0 from cards)
       and (select (body -> 'chart' -> 'datasets' -> 0 -> 'values' ->> 11)::numeric = 0 from bank)
  ),
  true,
  'another organization sees a zero incoming payment and a zero bank balance'
);

select * from finish();
rollback;
