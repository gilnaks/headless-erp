-- Selling mappers. ERPNext selling/doctype/quotation/quotation.py make_sales_order,
-- selling/doctype/sales_order/sales_order.py make_delivery_note, and
-- controllers/sales_and_purchase_return.py make_return_doc.
-- Each call inserts a draft and returns its id. Ordered and delivered quantities
-- stay 0 until app.update_prevdoc_status, so the first map copies the full remainder.
-- A return's remainder is the source qty minus submitted return rows. No taxes,
-- payment schedule, stock ledger, or GL. Invoice targets wait for Sales Invoice.

create or replace function app.map_quotation_to_sales_order(p_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  h public.quotation;
  r record;
  v_order uuid;
  v_name text;
  v_idx int := 0;
  v_qty numeric;
begin
  select * into h from public.quotation where id = p_id;
  if not found then
    raise exception using errcode = 'P0001', message = 'not_found: Quotation not found';
  end if;
  if not app.has_perm(h.org_id, 'Quotation', 'read')
     or not app.has_perm(h.org_id, 'Sales Order', 'create') then
    raise exception using errcode = 'P0001', message = 'permission_denied: Not permitted';
  end if;
  if h.docstatus <> 1 then
    raise exception using errcode = 'P0001',
      message = format('map_status: Quotation %s has not been submitted', h.name);
  end if;
  if h.status = 'Lost' then
    raise exception using errcode = 'P0001',
      message = 'map_lost: Cannot make a Sales Order from a Lost quotation';
  end if;
  if not h.is_active then
    raise exception using errcode = 'P0001',
      message = format('map_status: Quotation %s is inactive', h.name);
  end if;
  if h.status = 'Expired'
     or (h.valid_till is not null and (h.valid_till < h.transaction_date or h.valid_till < current_date)) then
    raise exception using errcode = 'P0001',
      message = 'map_expired: Validity period of this quotation has ended.';
  end if;

  insert into public.sales_order (
    org_id, customer_id, company_id, transaction_date, delivery_date,
    order_type, currency, conversion_rate, selling_price_list_id
  ) values (
    h.org_id, h.customer_id, h.company_id, current_date, current_date,
    h.order_type, h.currency, h.conversion_rate, h.selling_price_list_id
  )
  returning id into v_order;

  for r in
    select * from public.quotation_item i
     where i.parent_id = h.id
       and not i.is_alternative
     order by i.idx
  loop
    if coalesce(r.conversion_factor, 0) = 0 then
      continue;
    end if;
    v_qty := (r.stock_qty - r.ordered_qty) / r.conversion_factor;
    if v_qty <= 0 then
      continue;
    end if;
    v_idx := v_idx + 1;
    insert into public.sales_order_item (
      org_id, parent_id, idx, item_id, item_name, qty, uom_id, conversion_factor,
      rate, price_list_rate, discount_percentage, warehouse_id, prevdoc_id, quotation_item_id
    ) values (
      h.org_id, v_order, v_idx, r.item_id, r.item_name, v_qty, r.uom_id, r.conversion_factor,
      r.rate, r.price_list_rate, r.discount_percentage, r.warehouse_id, h.id, r.id
    );
  end loop;
  if v_idx = 0 then
    raise exception using errcode = 'P0001', message = 'map_empty: No items with quantity pending';
  end if;
  select s.name into v_name from public.sales_order s where s.id = v_order;
  return jsonb_build_object('id', v_order, 'name', v_name);
end;
$fn$;

create or replace function app.map_sales_order_to_delivery_note(p_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  h public.sales_order;
  r record;
  v_note uuid;
  v_name text;
  v_idx int := 0;
  v_qty numeric;
begin
  select * into h from public.sales_order where id = p_id;
  if not found then
    raise exception using errcode = 'P0001', message = 'not_found: Sales Order not found';
  end if;
  if not app.has_perm(h.org_id, 'Sales Order', 'read')
     or not app.has_perm(h.org_id, 'Delivery Note', 'create') then
    raise exception using errcode = 'P0001', message = 'permission_denied: Not permitted';
  end if;
  if h.docstatus <> 1 then
    raise exception using errcode = 'P0001',
      message = format('map_status: Sales Order %s has not been submitted', h.name);
  end if;
  if h.status = 'On Hold' then
    raise exception using errcode = 'P0001',
      message = format('map_status: Sales Order %s is on hold', h.name);
  end if;
  if h.status = 'Closed' then
    raise exception using errcode = 'P0001',
      message = format('map_status: Sales Order %s is closed', h.name);
  end if;

  insert into public.delivery_note (
    org_id, customer_id, company_id, posting_date, currency, conversion_rate,
    selling_price_list_id, set_warehouse_id
  ) values (
    h.org_id, h.customer_id, h.company_id, current_date, h.currency, h.conversion_rate,
    h.selling_price_list_id, h.set_warehouse_id
  )
  returning id into v_note;

  for r in
    select * from public.sales_order_item i
     where i.parent_id = h.id
       and not i.closed
       and not i.delivered_by_supplier
       and not i.skip_delivery
       and i.delivered_qty < i.qty
     order by i.idx
  loop
    v_qty := r.qty - r.delivered_qty;
    if v_qty <= 0 then
      continue;
    end if;
    v_idx := v_idx + 1;
    insert into public.delivery_note_item (
      org_id, parent_id, idx, item_id, item_name, qty, uom_id, conversion_factor,
      rate, price_list_rate, discount_percentage, warehouse_id,
      against_sales_order_id, so_detail_id
    ) values (
      h.org_id, v_note, v_idx, r.item_id, r.item_name, v_qty, r.uom_id, r.conversion_factor,
      r.rate, r.price_list_rate, r.discount_percentage, r.warehouse_id,
      h.id, r.id
    );
  end loop;
  if v_idx = 0 then
    raise exception using errcode = 'P0001', message = 'map_empty: No items with quantity pending';
  end if;
  select n.name into v_name from public.delivery_note n where n.id = v_note;
  return jsonb_build_object('id', v_note, 'name', v_name);
end;
$fn$;

create or replace function app.map_delivery_note_return(p_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  h public.delivery_note;
  r record;
  v_note uuid;
  v_name text;
  v_idx int := 0;
  v_already numeric;
  v_qty numeric;
begin
  select * into h from public.delivery_note where id = p_id;
  if not found then
    raise exception using errcode = 'P0001', message = 'not_found: Delivery Note not found';
  end if;
  if not app.has_perm(h.org_id, 'Delivery Note', 'read')
     or not app.has_perm(h.org_id, 'Delivery Note', 'create') then
    raise exception using errcode = 'P0001', message = 'permission_denied: Not permitted';
  end if;
  if h.docstatus <> 1 then
    raise exception using errcode = 'P0001',
      message = format('map_status: Delivery Note %s has not been submitted', h.name);
  end if;
  if h.is_return then
    raise exception using errcode = 'P0001',
      message = format('map_status: Delivery Note %s is already a return', h.name);
  end if;

  insert into public.delivery_note (
    org_id, customer_id, company_id, posting_date, is_return, return_against,
    currency, conversion_rate, selling_price_list_id, set_warehouse_id
  ) values (
    h.org_id, h.customer_id, h.company_id, current_date, true, h.id,
    h.currency, h.conversion_rate, h.selling_price_list_id, h.set_warehouse_id
  )
  returning id into v_note;

  for r in
    select * from public.delivery_note_item i
     where i.parent_id = h.id
     order by i.idx
  loop
    select coalesce(sum(abs(i.qty)), 0) into v_already
      from public.delivery_note_item i
      join public.delivery_note d on d.id = i.parent_id
     where i.dn_detail_id = r.id
       and d.is_return
       and d.docstatus = 1;
    v_qty := r.qty - v_already;
    if v_qty <= 0 then
      continue;
    end if;
    v_idx := v_idx + 1;
    insert into public.delivery_note_item (
      org_id, parent_id, idx, item_id, item_name, qty, uom_id, conversion_factor,
      rate, price_list_rate, discount_percentage, warehouse_id, dn_detail_id,
      against_sales_order_id, so_detail_id
    ) values (
      h.org_id, v_note, v_idx, r.item_id, r.item_name, -v_qty, r.uom_id, r.conversion_factor,
      r.rate, r.price_list_rate, r.discount_percentage, r.warehouse_id, r.id,
      r.against_sales_order_id, r.so_detail_id
    );
  end loop;
  if v_idx = 0 then
    raise exception using errcode = 'P0001', message = 'map_empty: No items with quantity pending';
  end if;
  select n.name into v_name from public.delivery_note n where n.id = v_note;
  return jsonb_build_object('id', v_note, 'name', v_name);
end;
$fn$;

create or replace function app.map_doc(p_source_doctype text, p_source_id uuid, p_target_doctype text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
begin
  if p_source_doctype = 'Quotation' and p_target_doctype = 'Sales Order' then
    return app.map_quotation_to_sales_order(p_source_id);
  elsif p_source_doctype = 'Sales Order' and p_target_doctype = 'Delivery Note' then
    return app.map_sales_order_to_delivery_note(p_source_id);
  elsif p_source_doctype = 'Delivery Note' and p_target_doctype = 'Delivery Note' then
    return app.map_delivery_note_return(p_source_id);
  end if;
  raise exception using errcode = 'P0001', message = 'map_status: This document cannot be mapped';
end;
$fn$;

create or replace function app.make_return_doc(p_doctype text, p_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $fn$
begin
  if p_doctype is distinct from 'Delivery Note' then
    raise exception using errcode = 'P0001',
      message = 'map_status: A return is built from a Delivery Note';
  end if;
  return app.map_delivery_note_return(p_id);
end;
$fn$;

revoke all on function app.map_quotation_to_sales_order(uuid) from public, anon, authenticated;
revoke all on function app.map_sales_order_to_delivery_note(uuid) from public, anon, authenticated;
revoke all on function app.map_delivery_note_return(uuid) from public, anon, authenticated;
revoke all on function app.map_doc(text, uuid, text) from public, anon;
revoke all on function app.make_return_doc(text, uuid) from public, anon;
grant execute on function app.map_doc(text, uuid, text) to authenticated;
grant execute on function app.make_return_doc(text, uuid) to authenticated;

create or replace function public.map_doc(p_source_doctype text, p_source_id uuid, p_target_doctype text)
returns jsonb
language sql
security invoker
set search_path = ''
as $$
  select app.map_doc(p_source_doctype, p_source_id, p_target_doctype);
$$;

create or replace function public.make_return_doc(p_doctype text, p_id uuid)
returns jsonb
language sql
security invoker
set search_path = ''
as $$
  select app.make_return_doc(p_doctype, p_id);
$$;

revoke all on function public.map_doc(text, uuid, text) from public, anon;
revoke all on function public.make_return_doc(text, uuid) from public, anon;
grant execute on function public.map_doc(text, uuid, text) to authenticated;
grant execute on function public.make_return_doc(text, uuid) to authenticated;
