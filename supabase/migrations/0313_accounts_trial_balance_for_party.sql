-- Default Trial Balance for Party: one row per Customer or Supplier.
-- Ports execute() in erpnext/accounts/report/trial_balance_for_party/trial_balance_for_party.py
-- for the default flags (party type Customer, exclude zero balances, hide zero rows).
-- The account filter, Party Name, and finance books wait.

create or replace function app.report_trial_balance_for_party(p_filters jsonb)
returns jsonb
language plpgsql
stable
security invoker
set search_path = ''
as $$
declare
  v_company uuid;
  v_org uuid;
  v_fy uuid;
  v_start date;
  v_end date;
  v_from date;
  v_to date;
  v_party_type text;
  v_parties uuid[];
  v_zeros boolean;
  v_exclude boolean;
  v_warnings jsonb := '[]'::jsonb;
  v_rows jsonb := '[]'::jsonb;
  v_total jsonb;
begin
  if p_filters is null or nullif(p_filters ->> 'company', '') is null
     or (p_filters ->> 'company') !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
    raise exception using errcode = 'P0001', message = 'tbp_company: Company is mandatory';
  end if;
  v_company := (p_filters ->> 'company')::uuid;

  select c.org_id into v_org from public.companies c where c.id = v_company;
  if v_org is null then
    raise exception using errcode = 'P0001', message = 'tbp_company: Company is mandatory';
  end if;

  if nullif(p_filters ->> 'fiscal_year', '') is null
     or (p_filters ->> 'fiscal_year') !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
    raise exception using errcode = 'P0001', message = 'tbp_fiscal_year: Fiscal Year is required';
  end if;
  v_fy := (p_filters ->> 'fiscal_year')::uuid;

  select fy.year_start_date, fy.year_end_date
    into v_start, v_end
    from public.fiscal_year fy
   where fy.id = v_fy
     and fy.org_id = v_org;
  if v_start is null then
    raise exception using errcode = 'P0001',
      message = format('tbp_fiscal_year: Fiscal Year %s does not exist', p_filters ->> 'fiscal_year');
  end if;

  v_from := coalesce(nullif(p_filters ->> 'from_date', '')::date, v_start);
  v_to := coalesce(nullif(p_filters ->> 'to_date', '')::date, v_end);
  if v_from > v_to then
    raise exception using errcode = 'P0001', message = 'tbp_dates: From Date cannot be greater than To Date';
  end if;
  if v_from < v_start or v_from > v_end then
    v_warnings := v_warnings || jsonb_build_array(
      format('From Date should be within the Fiscal Year. Assuming From Date = %s', to_char(v_start, 'YYYY-MM-DD'))
    );
    v_from := v_start;
  end if;
  if v_to < v_start or v_to > v_end then
    v_warnings := v_warnings || jsonb_build_array(
      format('To Date should be within the Fiscal Year. Assuming To Date = %s', to_char(v_end, 'YYYY-MM-DD'))
    );
    v_to := v_end;
  end if;

  v_party_type := nullif(p_filters ->> 'party_type', '');
  if v_party_type is null then
    raise exception using errcode = 'P0001', message = 'tbp_party_type: Party Type is required';
  end if;
  if v_party_type not in ('Customer', 'Supplier') then
    raise exception using errcode = 'P0001', message = 'tbp_party_type: Party Type must be Customer or Supplier';
  end if;

  select coalesce(array_agg(t.party_id::uuid), '{}'::uuid[])
    into v_parties
    from jsonb_array_elements_text(coalesce(p_filters -> 'party', '[]'::jsonb)) as t(party_id)
   where t.party_id ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$';

  v_zeros := coalesce(nullif(p_filters ->> 'show_zero_values', '')::boolean, false);
  v_exclude := coalesce(nullif(p_filters ->> 'exclude_zero_balance_parties', '')::boolean, true);

  with parties as (
    select c.id, c.name
      from public.customer c
     where v_party_type = 'Customer'
       and c.org_id = v_org
       and (cardinality(v_parties) = 0 or c.id = any (v_parties))
    union all
    select s.id, s.name
      from public.supplier s
     where v_party_type = 'Supplier'
       and s.org_id = v_org
       and (cardinality(v_parties) = 0 or s.id = any (v_parties))
  ),
  raw as (
    select p.id,
           p.name,
           coalesce(sum(g.debit) filter (where
             g.posting_date < v_from or (g.is_opening and g.posting_date <= v_to)
           ), 0) as raw_open_debit,
           coalesce(sum(g.credit) filter (where
             g.posting_date < v_from or (g.is_opening and g.posting_date <= v_to)
           ), 0) as raw_open_credit,
           coalesce(sum(g.debit) filter (where
             g.posting_date between v_from and v_to and not g.is_opening
           ), 0) as debit,
           coalesce(sum(g.credit) filter (where
             g.posting_date between v_from and v_to and not g.is_opening
           ), 0) as credit
      from parties p
      left join public.gl_entry g
        on g.party_id = p.id
       and g.company_id = v_company
       and g.party_type = v_party_type
       and not g.is_cancelled
     group by p.id, p.name
  ),
  opened as (
    select id,
           name,
           debit,
           credit,
           case when raw_open_debit > raw_open_credit then raw_open_debit - raw_open_credit else 0 end as opening_debit,
           case when raw_open_debit > raw_open_credit then 0 else raw_open_credit - raw_open_debit end as opening_credit
      from raw
  ),
  closed as (
    select id,
           name,
           opening_debit,
           opening_credit,
           debit,
           credit,
           case
             when opening_debit + debit > opening_credit + credit
               then (opening_debit + debit) - (opening_credit + credit)
             else 0
           end as closing_debit,
           case
             when opening_debit + debit > opening_credit + credit then 0
             else (opening_credit + credit) - (opening_debit + debit)
           end as closing_credit
      from opened
  ),
  visible as (
    select c.*
      from closed c
     where not (v_exclude and c.closing_debit = 0 and c.closing_credit = 0)
       and (
         v_zeros
         or abs(c.opening_debit) >= 0.005
         or abs(c.opening_credit) >= 0.005
         or abs(c.debit) >= 0.005
         or abs(c.credit) >= 0.005
         or abs(c.closing_debit) >= 0.005
         or abs(c.closing_credit) >= 0.005
       )
  )
  select coalesce((
           select jsonb_agg(
             jsonb_build_object(
               'row_type', 'party',
               'party_id', v.id,
               'party', v.name,
               'opening_debit', app.round(v.opening_debit, 2),
               'opening_credit', app.round(v.opening_credit, 2),
               'debit', app.round(v.debit, 2),
               'credit', app.round(v.credit, 2),
               'closing_debit', app.round(v.closing_debit, 2),
               'closing_credit', app.round(v.closing_credit, 2)
             )
             order by v.name
           )
             from visible v
         ), '[]'::jsonb),
         (
           select jsonb_build_object(
             'row_type', 'total',
             'party', 'Totals',
             'opening_debit', app.round(coalesce(sum(v.opening_debit), 0), 2),
             'opening_credit', app.round(coalesce(sum(v.opening_credit), 0), 2),
             'debit', app.round(coalesce(sum(v.debit), 0), 2),
             'credit', app.round(coalesce(sum(v.credit), 0), 2),
             'closing_debit', app.round(coalesce(sum(v.closing_debit), 0), 2),
             'closing_credit', app.round(coalesce(sum(v.closing_credit), 0), 2)
           )
             from visible v
         )
    into v_rows, v_total;

  v_rows := v_rows || jsonb_build_array(v_total);

  return jsonb_build_object(
    'columns', jsonb_build_array(
      jsonb_build_object('field', 'party', 'label', v_party_type),
      jsonb_build_object('field', 'opening_debit', 'label', 'Opening (Dr)'),
      jsonb_build_object('field', 'opening_credit', 'label', 'Opening (Cr)'),
      jsonb_build_object('field', 'debit', 'label', 'Debit'),
      jsonb_build_object('field', 'credit', 'label', 'Credit'),
      jsonb_build_object('field', 'closing_debit', 'label', 'Closing (Dr)'),
      jsonb_build_object('field', 'closing_credit', 'label', 'Closing (Cr)')
    ),
    'rows', v_rows,
    'warnings', v_warnings,
    'from_date', v_from,
    'to_date', v_to
  );
end;
$$;

create or replace function public.report_trial_balance_for_party(p_filters jsonb)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  select app.report_trial_balance_for_party(p_filters);
$$;

revoke execute on function app.report_trial_balance_for_party(jsonb) from public, anon;
grant execute on function app.report_trial_balance_for_party(jsonb) to authenticated;
revoke execute on function public.report_trial_balance_for_party(jsonb) from public, anon;
grant execute on function public.report_trial_balance_for_party(jsonb) to authenticated;
