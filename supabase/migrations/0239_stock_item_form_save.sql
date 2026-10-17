-- 0239 stock: Item form save.
-- A blank End of Life is ERPNext's default (2099-12-31). save_doc sends null, which
-- overrides the column default and fails the not-null check.
-- save_doc_children then deletes the stock-UOM row the immediate trigger inserted
-- when the conversion table is empty. The deferred trigger puts that row back at commit.

create or replace function app.item_validate()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_group boolean;
  v_enabled boolean;
  v_series text;
begin
  new.item_code := trim(new.item_code);
  if nullif(trim(new.item_name), '') is null then
    new.item_name := new.item_code;
  else
    new.item_name := trim(new.item_name);
  end if;
  new.name := new.item_code;
  if new.valuation_method = '' then
    new.valuation_method := null;
  end if;
  if new.has_variants then
    raise exception using errcode = 'P0001', message = 'item_variants: Item variants are not built';
  end if;
  if new.stock_uom_id is null then
    select u.id into new.stock_uom_id from public.uom u
     where u.org_id = new.org_id and lower(u.uom_name) = 'nos'
     limit 1;
  end if;
  select is_group into v_group from public.item_group where id = new.item_group_id;
  if v_group then
    raise exception using errcode = 'P0001', message = 'item_group_leaf: Item Group must be a leaf';
  end if;
  select enabled into v_enabled from public.uom where id = new.stock_uom_id;
  if v_enabled is not true then
    raise exception using errcode = 'P0001', message = 'item_uom: Stock UOM is disabled';
  end if;
  if new.end_of_life is null then
    new.end_of_life := '2099-12-31';
  end if;
  if tg_op = 'INSERT' and new.end_of_life < current_date then
    raise exception using errcode = 'P0001', message = 'item_end_of_life: End of Life cannot be before today';
  end if;
  if new.has_serial_no and not new.is_stock_item and not new.is_fixed_asset then
    raise exception using errcode = 'P0001', message = 'item_serial: Has Serial No cannot be Yes for a non-stock item';
  end if;
  if not new.has_serial_no then
    new.serial_no_series := null;
  end if;
  foreach v_series in array array[new.serial_no_series, new.batch_number_series] loop
    if v_series is not null and position('#' in v_series) > 0 and position('.' in v_series) = 0 then
      raise exception using errcode = 'P0001', message = 'item_series: Invalid naming series (. missing)';
    end if;
  end loop;
  return new;
end;
$$;

revoke all on function app.item_validate() from public, anon, authenticated;

drop trigger if exists item_ensure_stock_uom_deferred on public.item;
create constraint trigger item_ensure_stock_uom_deferred
  after insert or update on public.item
  deferrable initially deferred
  for each row execute function app.item_ensure_stock_uom();
