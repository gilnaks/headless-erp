-- Default Trial Balance: netted opening, period, and closing on the account tree.
-- Ports execute() in erpnext/accounts/report/trial_balance/trial_balance.py for the default flags
-- (show_net_values, show_group_accounts, show_zero_values off the unclosed-profit flag).
-- Cost center, project, and show_unclosed_fy_pl_balances wait. There is no Period Closing Voucher.

create or replace function app.report_trial_balance(p_filters jsonb)
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
  v_net boolean;
  v_groups boolean;
  v_zeros boolean;
  v_ignore boolean := false;
  v_warnings jsonb := '[]'::jsonb;
  v_rows jsonb := '[]'::jsonb;
  v_total jsonb;
begin
  if p_filters is null or nullif(p_filters ->> 'company', '') is null
     or (p_filters ->> 'company') !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
    raise exception using errcode = 'P0001', message = 'tb_company: Company is mandatory';
  end if;
  v_company := (p_filters ->> 'company')::uuid;

  select c.org_id into v_org from public.companies c where c.id = v_company;
  if v_org is null then
    raise exception using errcode = 'P0001', message = 'tb_company: Company is mandatory';
  end if;

  if nullif(p_filters ->> 'fiscal_year', '') is null
     or (p_filters ->> 'fiscal_year') !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
    raise exception using errcode = 'P0001', message = 'tb_fiscal_year: Fiscal Year is required';
  end if;
  v_fy := (p_filters ->> 'fiscal_year')::uuid;

  select fy.year_start_date, fy.year_end_date
    into v_start, v_end
    from public.fiscal_year fy
   where fy.id = v_fy
     and fy.org_id = v_org;
  if v_start is null then
    raise exception using errcode = 'P0001',
      message = format('tb_fiscal_year: Fiscal Year %s does not exist', p_filters ->> 'fiscal_year');
  end if;

  v_from := coalesce(nullif(p_filters ->> 'from_date', '')::date, v_start);
  v_to := coalesce(nullif(p_filters ->> 'to_date', '')::date, v_end);
  if v_from > v_to then
    raise exception using errcode = 'P0001', message = 'tb_dates: From Date cannot be greater than To Date';
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

  v_net := coalesce(nullif(p_filters ->> 'show_net_values', '')::boolean, true);
  v_groups := coalesce(nullif(p_filters ->> 'show_group_accounts', '')::boolean, true);
  v_zeros := coalesce(nullif(p_filters ->> 'show_zero_values', '')::boolean, false);

  select s.ignore_is_opening_check_for_reporting
    into v_ignore
    from public.accounts_settings s
   where s.org_id = v_org;
  v_ignore := coalesce(v_ignore, false);

  with leaves as (
    select a.id,
           a.path,
           a.root_type,
           coalesce(sum(g.debit) filter (where
             case
               when a.report_type = 'Profit and Loss' and g.posting_date < v_start then false
               when v_ignore then g.posting_date < v_from
               else g.posting_date < v_from or g.is_opening
             end
           ), 0) as opening_debit,
           coalesce(sum(g.credit) filter (where
             case
               when a.report_type = 'Profit and Loss' and g.posting_date < v_start then false
               when v_ignore then g.posting_date < v_from
               else g.posting_date < v_from or g.is_opening
             end
           ), 0) as opening_credit,
           coalesce(sum(g.debit) filter (where
             g.posting_date between v_from and v_to
             and (v_ignore or not g.is_opening)
           ), 0) as debit,
           coalesce(sum(g.credit) filter (where
             g.posting_date between v_from and v_to
             and (v_ignore or not g.is_opening)
           ), 0) as credit
      from public.account a
      left join public.gl_entry g
        on g.account_id = a.id
       and g.company_id = v_company
       and not g.is_cancelled
     where a.company_id = v_company
       and not a.is_group
     group by a.id, a.path, a.root_type, a.report_type
  ),
  netted_leaves as (
    select id,
           path,
           root_type,
           case
             when not v_net then opening_debit
             when root_type in ('Asset', 'Equity', 'Expense') and opening_debit - opening_credit >= 0 then opening_debit - opening_credit
             when root_type in ('Asset', 'Equity', 'Expense') then 0
             when opening_credit - opening_debit >= 0 then 0
             else opening_debit - opening_credit
           end as opening_debit,
           case
             when not v_net then opening_credit
             when root_type in ('Asset', 'Equity', 'Expense') and opening_debit - opening_credit >= 0 then 0
             when root_type in ('Asset', 'Equity', 'Expense') then opening_credit - opening_debit
             when opening_credit - opening_debit >= 0 then opening_credit - opening_debit
             else 0
           end as opening_credit,
           debit,
           credit,
           case
             when not v_net then opening_debit + debit
             when root_type in ('Asset', 'Equity', 'Expense')
              and (opening_debit + debit) - (opening_credit + credit) >= 0
               then (opening_debit + debit) - (opening_credit + credit)
             when root_type in ('Asset', 'Equity', 'Expense') then 0
             when (opening_credit + credit) - (opening_debit + debit) >= 0 then 0
             else (opening_debit + debit) - (opening_credit + credit)
           end as closing_debit,
           case
             when not v_net then opening_credit + credit
             when root_type in ('Asset', 'Equity', 'Expense')
              and (opening_debit + debit) - (opening_credit + credit) >= 0 then 0
             when root_type in ('Asset', 'Equity', 'Expense')
               then (opening_credit + credit) - (opening_debit + debit)
             when (opening_credit + credit) - (opening_debit + debit) >= 0
               then (opening_credit + credit) - (opening_debit + debit)
             else 0
           end as closing_credit
      from leaves
  ),
  rolled as (
    select p.id,
           p.parent_id,
           p.is_group,
           p.path,
           p.root_type,
           p.account_name,
           p.account_number,
           coalesce(sum(l.opening_debit), 0) as opening_debit,
           coalesce(sum(l.opening_credit), 0) as opening_credit,
           coalesce(sum(l.debit), 0) as debit,
           coalesce(sum(l.credit), 0) as credit,
           coalesce(sum(l.closing_debit), 0) as closing_debit,
           coalesce(sum(l.closing_credit), 0) as closing_credit
      from public.account p
      left join netted_leaves l
        on l.path operator(extensions.<@) p.path
     where p.company_id = v_company
     group by p.id, p.parent_id, p.is_group, p.path, p.root_type, p.account_name, p.account_number
  ),
  netted as (
    select id,
           parent_id,
           is_group,
           path,
           root_type,
           account_name,
           account_number,
           case
             when not v_net or not is_group then opening_debit
             when root_type in ('Asset', 'Equity', 'Expense') and opening_debit - opening_credit >= 0 then opening_debit - opening_credit
             when root_type in ('Asset', 'Equity', 'Expense') then 0
             when opening_credit - opening_debit >= 0 then 0
             else opening_debit - opening_credit
           end as opening_debit,
           case
             when not v_net or not is_group then opening_credit
             when root_type in ('Asset', 'Equity', 'Expense') and opening_debit - opening_credit >= 0 then 0
             when root_type in ('Asset', 'Equity', 'Expense') then opening_credit - opening_debit
             when opening_credit - opening_debit >= 0 then opening_credit - opening_debit
             else 0
           end as opening_credit,
           debit,
           credit,
           case
             when not v_net or not is_group then closing_debit
             when root_type in ('Asset', 'Equity', 'Expense') and closing_debit - closing_credit >= 0 then closing_debit - closing_credit
             when root_type in ('Asset', 'Equity', 'Expense') then 0
             when closing_credit - closing_debit >= 0 then 0
             else closing_debit - closing_credit
           end as closing_debit,
           case
             when not v_net or not is_group then closing_credit
             when root_type in ('Asset', 'Equity', 'Expense') and closing_debit - closing_credit >= 0 then 0
             when root_type in ('Asset', 'Equity', 'Expense') then closing_credit - closing_debit
             when closing_credit - closing_debit >= 0 then closing_credit - closing_debit
             else 0
           end as closing_credit
      from rolled
  ),
  marked as (
    select n.*,
           abs(n.opening_debit) >= 0.005
            or abs(n.opening_credit) >= 0.005
            or abs(n.debit) >= 0.005
            or abs(n.credit) >= 0.005
            or abs(n.closing_debit) >= 0.005
            or abs(n.closing_credit) >= 0.005 as has_value
      from netted n
  ),
  visible as (
    select m.*
      from marked m
     where (v_groups or not m.is_group)
       and (
         v_zeros
         or exists (
           select 1
             from marked child
            where child.has_value
              and child.path operator(extensions.<@) m.path
         )
       )
  )
  select coalesce((
           select jsonb_agg(
             jsonb_build_object(
               'row_type', 'account',
               'account_id', v.id,
               'indent', case when v_groups then extensions.nlevel(v.path) - 1 else 0 end,
               'is_group', v.is_group,
               'account', case
                 when nullif(v.account_number, '') is not null then v.account_number || ' - ' || v.account_name
                 else v.account_name
               end,
               'opening_debit', app.round(v.opening_debit, 2),
               'opening_credit', app.round(v.opening_credit, 2),
               'debit', app.round(v.debit, 2),
               'credit', app.round(v.credit, 2),
               'closing_debit', app.round(v.closing_debit, 2),
               'closing_credit', app.round(v.closing_credit, 2)
             )
             order by v.path
           )
             from visible v
         ), '[]'::jsonb),
         (
           select jsonb_build_object(
             'row_type', 'total',
             'account', 'Total',
             'indent', 0,
             'opening_debit', app.round(coalesce(sum(n.opening_debit), 0), 2),
             'opening_credit', app.round(coalesce(sum(n.opening_credit), 0), 2),
             'debit', app.round(coalesce(sum(n.debit), 0), 2),
             'credit', app.round(coalesce(sum(n.credit), 0), 2),
             'closing_debit', app.round(coalesce(sum(n.closing_debit), 0), 2),
             'closing_credit', app.round(coalesce(sum(n.closing_credit), 0), 2)
           )
             from netted n
            where (v_groups and n.parent_id is null)
               or (not v_groups and not n.is_group)
         )
    into v_rows, v_total;

  v_rows := v_rows || jsonb_build_array(v_total);

  return jsonb_build_object(
    'columns', jsonb_build_array(
      jsonb_build_object('field', 'account', 'label', 'Account'),
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

create or replace function public.report_trial_balance(p_filters jsonb)
returns jsonb
language sql
stable
security invoker
set search_path = ''
as $$
  select app.report_trial_balance(p_filters);
$$;

revoke execute on function app.report_trial_balance(jsonb) from public, anon;
grant execute on function app.report_trial_balance(jsonb) to authenticated;
revoke execute on function public.report_trial_balance(jsonb) from public, anon;
grant execute on function public.report_trial_balance(jsonb) to authenticated;
