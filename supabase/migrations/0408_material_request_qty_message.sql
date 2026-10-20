-- 0408 stock: trim the trailing decimal point from the Material Request over-qty message.
-- to_char with a decimal mask leaves "11." for a whole number. 0407 is already applied.

create or replace function app.refresh_material_request(p_id uuid, p_from_stock_entry boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  h public.material_request;
  r record;
  v_ordered numeric;
  v_allow numeric;
  v_allowed numeric;
  v_per numeric;
  v_code text;
begin
  select * into h from public.material_request where id = p_id;
  if not found then
    return;
  end if;
  if p_from_stock_entry and h.status in ('Stopped', 'Cancelled') then
    raise exception using errcode = 'P0001',
      message = format('mr_stopped: Material Request %s is cancelled or stopped', h.name);
  end if;

  if h.material_request_type in ('Material Issue', 'Material Transfer', 'Customer Provided') then
    select s.mr_qty_allowance into v_allow from public.stock_settings s where s.org_id = h.org_id;
    for r in
      select i.*, it.item_code
        from public.material_request_item i
        join public.item it on it.id = i.item_id
       where i.parent_id = h.id
    loop
      select coalesce(sum(d.transfer_qty), 0) into v_ordered
        from public.stock_entry_detail d
        join public.stock_entry e on e.id = d.parent_id
       where d.material_request_item = r.id and e.docstatus = 1;
      if v_allow is not null then
        v_allowed := r.stock_qty + (r.stock_qty * v_allow / 100);
      else
        v_allowed := r.stock_qty;
      end if;
      if v_ordered > v_allowed then
        v_code := case when v_allow is not null then 'allowed requested quantity' else 'requested quantity' end;
        raise exception using errcode = 'P0001',
          message = format(
            'mr_qty: The total Issue / Transfer quantity %s in Material Request %s cannot be greater than %s %s for Item %s',
            rtrim(to_char(v_ordered, 'FM999999990.999999999'), '.'),
            h.name,
            v_code,
            rtrim(to_char(v_allowed, 'FM999999990.999999999'), '.'),
            r.item_code
          );
      end if;
      update public.material_request_item set ordered_qty = v_ordered where id = r.id;
    end loop;
  end if;

  select case when coalesce(sum(abs(i.stock_qty)), 0) = 0 then 0
              else app.round(
                sum(least(abs(i.ordered_qty), abs(i.stock_qty))) / sum(abs(i.stock_qty)) * 100,
                6
              ) end
    into v_per
    from public.material_request_item i
   where i.parent_id = h.id;
  update public.material_request set per_ordered = coalesce(v_per, 0) where id = h.id;
  update public.material_request set status = app.material_request_status(id) where id = h.id;

  for r in
    select distinct i.item_id, i.warehouse_id
      from public.material_request_item i
     where i.parent_id = h.id and i.warehouse_id is not null
  loop
    perform app.refresh_indented_qty(h.org_id, r.item_id, r.warehouse_id);
  end loop;
end;
$$;
