-- 0214 accounts: blank Account defaults survive an explicit null from the form.
-- save_doc sends balance_must_be and freeze_account as null when the select is empty, which skips the column default.
-- ERPNext: erpnext/accounts/doctype/account/account.json (balance_must_be default "", freeze_account default "No").

create or replace function app.account_validate()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_parent_company uuid;
  v_currency text;
  v_base text;
  v_name text;
  v_n int;
begin
  new.account_name := trim(new.account_name);
  if new.freeze_account is null or new.freeze_account = '' then
    new.freeze_account := 'No';
  end if;
  if new.balance_must_be is null then
    new.balance_must_be := '';
  end if;
  if tg_op = 'UPDATE' and new.company_id is distinct from old.company_id then
    raise exception using errcode = 'P0001', message = 'account_company: Company cannot be changed for an existing account';
  end if;
  if new.parent_id is null and new.root_type is null then
    raise exception using errcode = 'P0001', message = 'root_type_required: Root Type is mandatory';
  end if;
  if new.parent_id is not null then
    select company_id into v_parent_company from public.account where id = new.parent_id and org_id = new.org_id;
    if v_parent_company is distinct from new.company_id then
      raise exception using errcode = 'P0001', message = 'account_parent_company: Parent account must belong to the same company';
    end if;
  end if;
  new.report_type := case
    when new.root_type in ('Asset', 'Liability', 'Equity') then 'Balance Sheet'
    else 'Profit and Loss'
  end;
  select default_currency into v_currency from public.companies where id = new.company_id;
  if new.account_currency is null or new.account_currency = '' then
    new.account_currency := v_currency;
  elsif new.account_currency is distinct from v_currency then
    raise exception using errcode = 'P0001', message = 'account_currency: Account currency must be the company currency';
  end if;
  v_base := app.account_display_name(new.account_number, new.account_name, (
    select abbr from public.companies where id = new.company_id
  ));
  v_name := v_base;
  v_n := 1;
  while exists (
    select 1 from public.account a
    where a.org_id = new.org_id and a.name = v_name and a.id is distinct from new.id
  ) loop
    v_name := v_base || ' ' || v_n;
    v_n := v_n + 1;
  end loop;
  new.name := v_name;
  return new;
end;
$$;

revoke execute on function app.account_validate() from public, anon, authenticated;
