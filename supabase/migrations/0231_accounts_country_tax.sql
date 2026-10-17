-- 0231 accounts: country tax seed (docs/modules/00-setup.md B7).
-- ERPNext: erpnext/setup/setup_wizard/operations/taxes_setup.py create_default_tax_template.
-- The country rows are loaded by 0232. Regional tax settings are not ported.
-- companies_seed_taxes is named so it runs after companies_seed_cost_centers and before
-- companies_seed_warehouses.

create table if not exists public.country_wise_tax (
  country text primary key references public.country (country_name),
  data    jsonb not null
);

alter table public.country_wise_tax enable row level security;
alter table public.country_wise_tax force row level security;
drop policy if exists country_wise_tax_select on public.country_wise_tax;
create policy country_wise_tax_select on public.country_wise_tax for select to authenticated using (true);

-- Find or create the Tax ledger described by a country-tax account object.
create or replace function app.tax_account_for(p_company uuid, p_account jsonb)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_org uuid;
  v_currency text;
  v_root text := coalesce(nullif(p_account ->> 'root_type', ''), 'Liability');
  v_name text := p_account ->> 'account_name';
  v_number text := nullif(p_account ->> 'account_number', '');
  v_id uuid;
  v_group uuid;
  v_group_name text;
  v_root_id uuid;
begin
  select org_id, default_currency into v_org, v_currency from public.companies where id = p_company;
  select id into v_id from public.account
   where company_id = p_company and root_type = v_root and not is_group
     and (account_name = v_name or (v_number is not null and account_number = v_number))
   limit 1;
  if v_id is not null then
    -- Numbered charts often omit account_type on the VAT account the tax file names differently.
    update public.account a
       set account_type = 'Tax',
           tax_rate = coalesce(a.tax_rate, nullif(p_account ->> 'tax_rate', '')::numeric)
     where a.id = v_id and a.account_type is null;
    return v_id;
  end if;

  select id into v_group from public.account
   where company_id = p_company and is_group and root_type = v_root and account_type = 'Tax'
   limit 1;
  if v_group is null then
    v_group_name := case when v_root = 'Liability' then 'Duties and Taxes' else 'Tax Assets' end;
    select id into v_group from public.account
     where company_id = p_company and is_group and root_type = v_root and account_name = v_group_name
     limit 1;
  end if;
  if v_group is null then
    select id into v_root_id from public.account
     where company_id = p_company and is_group and root_type = v_root and parent_id is null
     limit 1;
    insert into public.account (
      org_id, account_name, is_group, company_id, root_type, account_currency, parent_id, account_type
    ) values (
      v_org, v_group_name, true, p_company, v_root, v_currency, v_root_id, 'Tax'
    ) returning id into v_group;
  end if;

  insert into public.account (
    org_id, account_name, account_number, is_group, company_id, root_type, account_currency,
    parent_id, account_type, tax_rate
  ) values (
    v_org, v_name, v_number, false, p_company, v_root, v_currency, v_group, 'Tax',
    coalesce(nullif(p_account ->> 'tax_rate', '')::numeric, 0)
  ) returning id into v_id;
  return v_id;
end;
$$;

create or replace function app.create_default_tax_templates(p_company uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_org uuid;
  v_country text;
  v_chart text;
  v_cc uuid;
  v_data jsonb;
  v_block jsonb;
  v_title text;
  v_tpl jsonb;
  v_tax jsonb;
  v_account jsonb;
  v_account_id uuid;
  v_template uuid;
  v_idx int;
  v_rate numeric;
  v_desc text;
  v_default boolean;
  v_cat text;
begin
  if exists (
    select 1 from public.sales_taxes_and_charges_template where company_id = p_company
    union all
    select 1 from public.purchase_taxes_and_charges_template where company_id = p_company
    union all
    select 1 from public.item_tax_template where company_id = p_company
  ) then
    return;
  end if;

  select org_id, country, coalesce(nullif(chart_of_accounts, ''), 'Standard'), cost_center_id
    into v_org, v_country, v_chart, v_cc
  from public.companies where id = p_company;

  select data into v_data from public.country_wise_tax where country = v_country;
  if v_data is null then
    return;
  end if;

  if jsonb_typeof(v_data -> 'tax_categories') = 'array' then
    for v_tpl in select value from jsonb_array_elements(v_data -> 'tax_categories') loop
      v_cat := coalesce(v_tpl ->> 'title', v_tpl #>> '{}');
      if v_cat is not null and v_cat <> '' then
        insert into public.tax_category (org_id, title)
        values (v_org, v_cat)
        on conflict (org_id, lower(title)) do nothing;
      end if;
    end loop;
  end if;

  if v_data ? 'chart_of_accounts' then
    v_block := coalesce(v_data -> 'chart_of_accounts' -> v_chart, v_data -> 'chart_of_accounts' -> '*');
  else
    v_block := jsonb_build_object('item_tax_templates', '[]'::jsonb, 'sales_tax_templates', '[]'::jsonb, 'purchase_tax_templates', '[]'::jsonb);
    for v_title, v_tpl in select key, value from jsonb_each(v_data) where jsonb_typeof(value) = 'object' and value ? 'account_name' loop
      v_account := jsonb_build_object('account_name', v_tpl ->> 'account_name', 'tax_rate', v_tpl -> 'tax_rate');
      v_block := jsonb_set(v_block, '{item_tax_templates}', (v_block -> 'item_tax_templates') || jsonb_build_array(jsonb_build_object(
        'title', v_title, 'taxes', jsonb_build_array(jsonb_build_object('tax_type', v_account))
      )));
      v_block := jsonb_set(v_block, '{sales_tax_templates}', (v_block -> 'sales_tax_templates') || jsonb_build_array(jsonb_build_object(
        'title', v_title, 'is_default', coalesce(v_tpl -> 'default', '0'::jsonb),
        'taxes', jsonb_build_array(jsonb_build_object('account_head', v_account))
      )));
      v_block := jsonb_set(v_block, '{purchase_tax_templates}', v_block -> 'sales_tax_templates');
    end loop;
  end if;

  if v_block is null then
    return;
  end if;

  for v_tpl in select value from jsonb_array_elements(coalesce(v_block -> 'sales_tax_templates', v_block -> '*', '[]'::jsonb)) loop
    if exists (select 1 from public.sales_taxes_and_charges_template where company_id = p_company and title = v_tpl ->> 'title') then
      continue;
    end if;
    v_default := coalesce(v_tpl ->> 'is_default', '0') in ('1', 'true');
    insert into public.sales_taxes_and_charges_template (org_id, title, is_default, company_id)
    values (v_org, v_tpl ->> 'title', v_default, p_company)
    returning id into v_template;
    v_idx := 0;
    for v_tax in select value from jsonb_array_elements(coalesce(v_tpl -> 'taxes', '[]'::jsonb)) loop
      v_idx := v_idx + 1;
      v_account := v_tax -> 'account_head';
      if jsonb_typeof(v_account) = 'object' then
        v_account_id := app.tax_account_for(p_company, v_account);
        v_rate := coalesce(nullif(v_tax ->> 'rate', '')::numeric, nullif(v_account ->> 'tax_rate', '')::numeric);
        v_desc := coalesce(v_tax ->> 'description', (v_account ->> 'account_name') || ' @ ' || coalesce(v_account ->> 'tax_rate', ''));
      else
        v_idx := v_idx - 1;
        continue;
      end if;
      insert into public.sales_taxes_and_charges (
        org_id, parent_id, idx, charge_type, account_head_id, description, cost_center_id, rate
      ) values (
        v_org, v_template, v_idx, coalesce(v_tax ->> 'charge_type', 'On Net Total'), v_account_id, v_desc, v_cc,
        case when coalesce(v_tax ->> 'charge_type', 'On Net Total') = 'Actual' then null else v_rate end
      );
    end loop;
  end loop;

  for v_tpl in select value from jsonb_array_elements(coalesce(v_block -> 'purchase_tax_templates', v_block -> '*', '[]'::jsonb)) loop
    if exists (select 1 from public.purchase_taxes_and_charges_template where company_id = p_company and title = v_tpl ->> 'title') then
      continue;
    end if;
    v_default := coalesce(v_tpl ->> 'is_default', '0') in ('1', 'true');
    insert into public.purchase_taxes_and_charges_template (org_id, title, is_default, company_id)
    values (v_org, v_tpl ->> 'title', v_default, p_company)
    returning id into v_template;
    v_idx := 0;
    for v_tax in select value from jsonb_array_elements(coalesce(v_tpl -> 'taxes', '[]'::jsonb)) loop
      v_idx := v_idx + 1;
      v_account := v_tax -> 'account_head';
      if jsonb_typeof(v_account) <> 'object' then
        v_idx := v_idx - 1;
        continue;
      end if;
      v_account_id := app.tax_account_for(p_company, v_account);
      v_rate := coalesce(nullif(v_tax ->> 'rate', '')::numeric, nullif(v_account ->> 'tax_rate', '')::numeric);
      v_desc := coalesce(v_tax ->> 'description', (v_account ->> 'account_name') || ' @ ' || coalesce(v_account ->> 'tax_rate', ''));
      insert into public.purchase_taxes_and_charges (
        org_id, parent_id, idx, category, add_deduct_tax, charge_type, account_head_id, description, cost_center_id, rate
      ) values (
        v_org, v_template, v_idx, coalesce(v_tax ->> 'category', 'Total'), coalesce(v_tax ->> 'add_deduct_tax', 'Add'),
        coalesce(v_tax ->> 'charge_type', 'On Net Total'), v_account_id, v_desc, v_cc,
        case when coalesce(v_tax ->> 'charge_type', 'On Net Total') = 'Actual' then null else v_rate end
      );
    end loop;
  end loop;

  -- Tests that set constraints immediate would reject the template before its rate row exists.
  alter table public.item_tax_template disable trigger item_tax_template_rows;
  alter table public.item_tax_template_detail disable trigger item_tax_detail_rows;
  for v_tpl in select value from jsonb_array_elements(coalesce(v_block -> 'item_tax_templates', '[]'::jsonb)) loop
    if exists (select 1 from public.item_tax_template where company_id = p_company and title = v_tpl ->> 'title') then
      continue;
    end if;
    insert into public.item_tax_template (org_id, title, company_id)
    values (v_org, v_tpl ->> 'title', p_company)
    returning id into v_template;
    v_idx := 0;
    for v_tax in select value from jsonb_array_elements(coalesce(v_tpl -> 'taxes', '[]'::jsonb)) loop
      v_account := v_tax -> 'tax_type';
      if jsonb_typeof(v_account) <> 'object' then
        continue;
      end if;
      v_idx := v_idx + 1;
      v_account_id := app.tax_account_for(p_company, v_account);
      insert into public.item_tax_template_detail (org_id, parent_id, idx, tax_type_id, tax_rate)
      values (
        v_org, v_template, v_idx, v_account_id,
        coalesce(nullif(v_tax ->> 'tax_rate', '')::numeric, nullif(v_account ->> 'tax_rate', '')::numeric, 0)
      );
    end loop;
    if v_idx = 0 then
      delete from public.item_tax_template where id = v_template;
    end if;
  end loop;
  alter table public.item_tax_template enable trigger item_tax_template_rows;
  alter table public.item_tax_template_detail enable trigger item_tax_detail_rows;
end;
$$;

create or replace function app.companies_seed_taxes()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform app.create_default_tax_templates(new.id);
  return null;
end;
$$;

create or replace function public.create_default_tax_templates(p_company uuid)
returns void
language sql
security invoker
set search_path = ''
as $$
  select app.create_default_tax_templates(p_company);
$$;

revoke all on function app.tax_account_for(uuid, jsonb) from public, anon, authenticated;
revoke all on function app.companies_seed_taxes() from public, anon, authenticated;
revoke all on function app.create_default_tax_templates(uuid) from public, anon;
grant execute on function app.create_default_tax_templates(uuid) to authenticated;
revoke all on function public.create_default_tax_templates(uuid) from public, anon;
grant execute on function public.create_default_tax_templates(uuid) to authenticated;

drop trigger if exists companies_seed_taxes on public.companies;
create trigger companies_seed_taxes after insert on public.companies
  for each row execute function app.companies_seed_taxes();
