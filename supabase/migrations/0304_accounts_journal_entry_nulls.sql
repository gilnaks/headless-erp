-- An empty currency input is saved as null, which overrides the column default.
-- Treat that as zero so a draft journal can be saved before a write-off amount is entered.

create or replace function app.journal_entry_validate()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.id is null then
    new.id := gen_random_uuid();
  end if;
  if new.name is null or btrim(new.name) = '' then
    new.name := 'DRAFT-' || new.id::text;
  end if;
  if new.naming_series is null or btrim(new.naming_series) = '' then
    new.naming_series := 'ACC-JV-.YYYY.-';
  end if;
  if new.posting_date is null then
    new.posting_date := current_date;
  end if;
  if new.voucher_type = 'Opening Entry' then
    new.is_opening := 'Yes';
  end if;
  new.multi_currency := false;
  new.write_off_amount := coalesce(new.write_off_amount, 0);
  if new.amended_from is not null and tg_op = 'INSERT' then
    new.clearance_date := null;
    new.docstatus := 0;
  end if;
  if tg_op = 'UPDATE' and new.docstatus is distinct from old.docstatus and current_user = 'authenticated' then
    raise exception using errcode = 'P0001', message = 'docstatus_locked: Use Submit or Cancel';
  end if;
  if not new.custom_remark and nullif(btrim(new.user_remark), '') is null and new.cheque_no is not null then
    new.user_remark := 'Reference #' || new.cheque_no || coalesce(' dated ' || new.cheque_date::text, '');
  end if;
  return new;
end;
$$;

revoke execute on function app.journal_entry_validate() from public, anon, authenticated;
