-- Company valuation lock once a stock ledger row exists.
-- ERPNext: erpnext/setup/doctype/company/company.py
-- cant_change_valuation_method, validate_perpetual_inventory,
-- validate_inventory_account_settings.
-- The perpetual check blocks turning the flag off whenever a non-cancelled
-- row exists. See docs deviation 20.

create or replace function app.companies_validate()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_org public.organizations;
  v_parent_reporting text;
begin
  new.company_name := trim(new.company_name);
  new.name := new.company_name;

  -- defaults from the organization (setup wizard passes them explicitly)
  if new.default_currency is null or new.country is null then
    select * into v_org from public.organizations where id = new.org_id;
    new.default_currency := coalesce(new.default_currency, v_org.default_currency);
    new.country := coalesce(new.country, v_org.country);
  end if;

  -- validate_abbr
  if new.abbr is null or trim(new.abbr) = '' then
    new.abbr := upper(array_to_string(array(
      select left(w, 1) from regexp_split_to_table(new.company_name, '\s+') w where w <> ''), ''));
  end if;
  new.abbr := trim(new.abbr);
  if new.abbr = '' then
    raise exception using errcode = 'P0001', message = 'abbr_required: Abbreviation is mandatory';
  end if;
  if exists (select 1 from public.companies c
             where c.org_id = new.org_id and lower(c.abbr) = lower(new.abbr) and c.id <> new.id) then
    raise exception using errcode = 'P0001', message = 'abbr_taken: Abbreviation already used for another company';
  end if;

  -- set_chart_of_accounts: a parent company forces the parent's chart
  if new.parent_id is not null then
    new.create_chart_of_accounts_based_on := 'Existing Company';
    new.existing_company_id := new.parent_id;
  end if;

  -- validate_coa_input
  if new.create_chart_of_accounts_based_on = 'Existing Company' then
    new.chart_of_accounts := null;
    if new.existing_company_id is null then
      raise exception using errcode = 'P0001', message = 'coa_input: Please select Existing Company for creating Chart of Accounts';
    end if;
  else
    new.existing_company_id := null;
    new.chart_of_accounts := coalesce(nullif(new.chart_of_accounts, ''), 'Standard');
  end if;

  -- set_reporting_currency (validate_parent_company is enforced by app.tree_maintain_path)
  new.reporting_currency := new.default_currency;
  if new.parent_id is not null then
    select c.reporting_currency into v_parent_reporting from public.companies c where c.id = new.parent_id;
    new.reporting_currency := coalesce(v_parent_reporting, new.default_currency);
  end if;

  -- validate_sdbnb_configuration (skipped for new documents, as in ERPNext)
  if tg_op = 'UPDATE' and new.enable_stock_delivered_but_not_billed and new.stock_delivered_but_not_billed_id is null then
    raise exception using errcode = 'P0001', message = 'sdbnb_account_required: Please select Stock Delivered But Not Billed Account';
  end if;

  if tg_op = 'UPDATE' then
    if old.enable_perpetual_inventory and not new.enable_perpetual_inventory
       and exists (
         select 1 from public.stock_ledger_entry s
          where s.company_id = new.id and not s.is_cancelled
       ) then
      raise exception using errcode = 'P0001',
        message = 'company_perpetual: Cannot disable perpetual inventory, as there are existing Stock Ledger Entries for the company '
          || new.company_name || '. Please cancel the stock transactions first and try again.';
    end if;

    if old.enable_item_wise_inventory_account is distinct from new.enable_item_wise_inventory_account
       and old.enable_perpetual_inventory
       and exists (
         select 1 from public.stock_ledger_entry s
          where s.company_id = new.id and not s.is_cancelled
       ) then
      raise exception using errcode = 'P0001',
        message = 'company_inventory: Cannot enable Item-wise Inventory Account, as there are existing Stock Ledger Entries for the company '
          || new.company_name || ' with Warehouse-wise Inventory Account. Please cancel the stock transactions first and try again.';
    end if;

    if old.valuation_method is distinct from new.valuation_method
       and exists (
         select 1
           from public.stock_ledger_entry s
           join public.item i on i.id = s.item_id and i.org_id = s.org_id
          where s.company_id = new.id
            and nullif(btrim(i.valuation_method), '') is null
       ) then
      raise exception using errcode = 'P0001',
        message = 'company_valuation: Can''t change the valuation method, as there are transactions against some items which do not have its own valuation method';
    end if;
  end if;

  return new;
end;
$$;

revoke execute on function app.companies_validate() from public, anon, authenticated;
