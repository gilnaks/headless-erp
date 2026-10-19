-- Default General Ledger: Categorize by Voucher (Consolidated).
-- Ports the opening / entry / total / closing shape of execute() in
-- erpnext/accounts/report/general_ledger/general_ledger.py.
-- Other categorize modes, party filters, and cancelled-row display wait.

create or replace function app.report_general_ledger(p_filters jsonb)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  v_company uuid;
  v_from date;
  v_to date;
  v_show_opening boolean;
  v_accounts uuid[];
  v_open_debit numeric := 0;
  v_open_credit numeric := 0;
  v_open_balance numeric := 0;
  v_total_debit numeric := 0;
  v_total_credit numeric := 0;
  v_balance numeric := 0;
  v_rows jsonb := '[]'::jsonb;
  r record;
begin
  if p_filters is null or nullif(p_filters ->> 'company', '') is null then
    raise exception using errcode = 'P0001', message = 'gl_company: Company is mandatory';
  end if;
  v_company := (p_filters ->> 'company')::uuid;

  if nullif(p_filters ->> 'from_date', '') is null or nullif(p_filters ->> 'to_date', '') is null then
    raise exception using errcode = 'P0001', message = 'gl_dates: From Date and To Date are mandatory';
  end if;
  v_from := (p_filters ->> 'from_date')::date;
  v_to := (p_filters ->> 'to_date')::date;
  if v_from > v_to then
    raise exception using errcode = 'P0001', message = 'gl_dates: From Date must be before To Date';
  end if;

  v_show_opening := coalesce((p_filters ->> 'show_opening_entries')::boolean, false);

  select coalesce(array_agg(t.account_id::uuid), '{}'::uuid[])
    into v_accounts
    from jsonb_array_elements_text(coalesce(p_filters -> 'account', '[]'::jsonb)) as t(account_id);

  select coalesce(sum(g.debit), 0), coalesce(sum(g.credit), 0)
    into v_open_debit, v_open_credit
    from public.gl_entry g
    join public.account a on a.id = g.account_id
   where g.company_id = v_company
     and not g.is_cancelled
     and (
       g.posting_date < v_from
       or (g.is_opening and g.posting_date between v_from and v_to and not v_show_opening)
     )
     and (
       cardinality(v_accounts) = 0
       or exists (
         select 1
           from public.account sel
          where sel.id = any (v_accounts)
            and a.path operator(extensions.<@) sel.path
       )
     );

  v_open_debit := app.round(v_open_debit, 2);
  v_open_credit := app.round(v_open_credit, 2);
  v_open_balance := app.round(v_open_debit - v_open_credit, 2);
  v_balance := v_open_balance;

  v_rows := v_rows || jsonb_build_array(jsonb_build_object(
    'row_type', 'opening',
    'account', 'Opening',
    'debit', v_open_debit,
    'credit', v_open_credit,
    'balance', v_open_balance
  ));

  for r in
    select g.voucher_id,
           g.voucher_type,
           g.voucher_no,
           g.account_id,
           min(g.posting_date) as posting_date,
           app.round(sum(g.debit), 2) as debit,
           app.round(sum(g.credit), 2) as credit,
           max(a.name) as account_name,
           max(g.against) as against,
           max(cc.name) as cost_center,
           max(g.remarks) as remarks
      from public.gl_entry g
      join public.account a on a.id = g.account_id
      left join public.cost_center cc on cc.id = g.cost_center_id
     where g.company_id = v_company
       and not g.is_cancelled
       and g.posting_date between v_from and v_to
       and (v_show_opening or not g.is_opening)
       and (
         cardinality(v_accounts) = 0
         or exists (
           select 1
             from public.account sel
            where sel.id = any (v_accounts)
              and a.path operator(extensions.<@) sel.path
         )
       )
     group by g.voucher_id, g.voucher_type, g.voucher_no, g.account_id
     order by min(g.posting_date), g.voucher_no, max(a.name)
  loop
    v_balance := app.round(v_balance + r.debit - r.credit, 2);
    v_total_debit := v_total_debit + r.debit;
    v_total_credit := v_total_credit + r.credit;
    v_rows := v_rows || jsonb_build_array(jsonb_build_object(
      'row_type', 'entry',
      'posting_date', r.posting_date,
      'account', r.account_name,
      'debit', r.debit,
      'credit', r.credit,
      'balance', v_balance,
      'voucher_type', r.voucher_type,
      'voucher_no', r.voucher_no,
      'voucher_id', r.voucher_id,
      'against', r.against,
      'cost_center', r.cost_center,
      'remarks', r.remarks
    ));
  end loop;

  v_total_debit := app.round(v_total_debit, 2);
  v_total_credit := app.round(v_total_credit, 2);

  v_rows := v_rows || jsonb_build_array(
    jsonb_build_object(
      'row_type', 'total',
      'account', 'Total',
      'debit', v_total_debit,
      'credit', v_total_credit,
      'balance', app.round(v_total_debit - v_total_credit, 2)
    ),
    jsonb_build_object(
      'row_type', 'closing',
      'account', 'Closing (Opening + Total)',
      'debit', app.round(v_open_debit + v_total_debit, 2),
      'credit', app.round(v_open_credit + v_total_credit, 2),
      'balance', app.round(v_open_balance + v_total_debit - v_total_credit, 2)
    )
  );

  return jsonb_build_object(
    'columns', jsonb_build_array(
      jsonb_build_object('field', 'posting_date', 'label', 'Posting Date'),
      jsonb_build_object('field', 'account', 'label', 'Account'),
      jsonb_build_object('field', 'debit', 'label', 'Debit'),
      jsonb_build_object('field', 'credit', 'label', 'Credit'),
      jsonb_build_object('field', 'balance', 'label', 'Balance'),
      jsonb_build_object('field', 'voucher_type', 'label', 'Voucher Type'),
      jsonb_build_object('field', 'voucher_no', 'label', 'Voucher No'),
      jsonb_build_object('field', 'against', 'label', 'Against Account'),
      jsonb_build_object('field', 'cost_center', 'label', 'Cost Center'),
      jsonb_build_object('field', 'remarks', 'label', 'Remarks')
    ),
    'rows', v_rows
  );
end;
$$;

create or replace function public.report_general_ledger(p_filters jsonb)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  select app.report_general_ledger(p_filters);
$$;

revoke execute on function app.report_general_ledger(jsonb) from public, anon;
grant execute on function app.report_general_ledger(jsonb) to authenticated;
revoke execute on function public.report_general_ledger(jsonb) from public, anon;
grant execute on function public.report_general_ledger(jsonb) to authenticated;
