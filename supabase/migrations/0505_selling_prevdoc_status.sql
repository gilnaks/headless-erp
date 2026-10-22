-- Previous-document quantities and statuses.
-- ERPNext controllers/status_updater.py update_qty, get_allowance_for,
-- selling/doctype/sales_order/sales_order.py status_updater (ordered_qty),
-- and stock/doctype/delivery_note/delivery_note.py status_updater.
-- Submit runs while docstatus is still 0, and cancel while it is still 1, so the
-- document being submitted is included and the one being cancelled is excluded.
-- billed_amt is not written. No stock ledger and no general ledger.

create or replace function app.quotation_next_status(p_id uuid)
returns text
language plpgsql
stable
security definer
set search_path = ''
as $fn$
declare
  q public.quotation;
  v_open boolean;
  v_some boolean;
  v_rows boolean;
begin
  select * into q from public.quotation where id = p_id;
  if not found then
    return 'Draft';
  end if;
  if q.docstatus = 2 then
    return 'Cancelled';
  end if;
  select
    exists (
      select 1 from public.quotation_item i
       where i.parent_id = q.id and not i.is_alternative and i.ordered_qty < i.stock_qty
    ),
    exists (
      select 1 from public.quotation_item i
       where i.parent_id = q.id and i.ordered_qty > 0
    ),
    exists (
      select 1 from public.quotation_item i
       where i.parent_id = q.id and not i.is_alternative
    )
    into v_open, v_some, v_rows;
  if v_rows and not v_open then
    return 'Ordered';
  end if;
  if v_some then
    return 'Partially Ordered';
  end if;
  if q.status = 'Lost' then
    return 'Lost';
  end if;
  if q.docstatus = 1 then
    return 'Open';
  end if;
  return 'Draft';
end;
$fn$;

create or replace function app.update_prevdoc_status(p_doctype text, p_id uuid, p_cancel boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  r record;
  v_delivered numeric;
  v_returned numeric;
  v_qty numeric;
  v_stock boolean;
  v_item_allowance numeric;
  v_allowance numeric;
  v_code text;
  v_org uuid;
  v_so uuid;
  v_dn uuid;
  v_num numeric;
  v_den numeric;
  v_per numeric;
  v_billed numeric;
  v_del text;
  v_bill text;
  v_current text;
begin
  if p_doctype = 'Sales Order' then
    for r in
      select distinct i.quotation_item_id as item_id
        from public.sales_order_item i
       where i.parent_id = p_id and i.quotation_item_id is not null
    loop
      update public.quotation_item qi
         set ordered_qty = (
           select coalesce(sum(oi.stock_qty), 0)
             from public.sales_order_item oi
             join public.sales_order s on s.id = oi.parent_id
            where oi.quotation_item_id = r.item_id
              and (
                (p_cancel and s.docstatus = 1 and s.id <> p_id)
                or (not p_cancel and (s.docstatus = 1 or s.id = p_id))
              )
         )
       where qi.id = r.item_id;
    end loop;

    for r in
      select distinct qi.parent_id as quotation_id
        from public.quotation_item qi
        join public.sales_order_item oi on oi.quotation_item_id = qi.id
       where oi.parent_id = p_id
    loop
      update public.quotation q
         set status = app.quotation_next_status(q.id)
       where q.id = r.quotation_id and q.docstatus = 1;
    end loop;
    return;
  end if;

  if p_doctype is distinct from 'Delivery Note' then
    raise exception using errcode = 'P0001',
      message = 'prevdoc: This document does not update a previous document';
  end if;

  for r in
    select distinct i.so_detail_id as detail_id
      from public.delivery_note_item i
     where i.parent_id = p_id and i.so_detail_id is not null
  loop
    select coalesce(sum(di.qty), 0) into v_delivered
      from public.delivery_note_item di
      join public.delivery_note d on d.id = di.parent_id
     where di.so_detail_id = r.detail_id
       and (
         (p_cancel and d.docstatus = 1 and d.id <> p_id)
         or (not p_cancel and (d.docstatus = 1 or d.id = p_id))
       );
    select coalesce(sum(-di.qty), 0) into v_returned
      from public.delivery_note_item di
      join public.delivery_note d on d.id = di.parent_id
     where di.so_detail_id = r.detail_id
       and d.is_return
       and (
         (p_cancel and d.docstatus = 1 and d.id <> p_id)
         or (not p_cancel and (d.docstatus = 1 or d.id = p_id))
       );

    select oi.qty, oi.org_id, it.is_stock_item, it.over_delivery_receipt_allowance, it.item_code
      into v_qty, v_org, v_stock, v_item_allowance, v_code
      from public.sales_order_item oi
      join public.item it on it.id = oi.item_id and it.org_id = oi.org_id
     where oi.id = r.detail_id;
    if coalesce(v_stock, false) and coalesce(v_qty, 0) > 0 then
      if coalesce(v_item_allowance, 0) > 0 then
        v_allowance := v_item_allowance;
      else
        select s.over_delivery_receipt_allowance into v_allowance
          from public.stock_settings s
         where s.org_id = v_org;
        v_allowance := coalesce(v_allowance, 0);
      end if;
      if ((v_delivered - v_qty) / v_qty * 100) - v_allowance > 0.01 then
        raise exception using errcode = 'P0001',
          message = format('over_delivery: Delivered quantity for item %s is over the allowance', v_code);
      end if;
    end if;

    update public.sales_order_item
       set delivered_qty = v_delivered,
           returned_qty = v_returned
     where id = r.detail_id;
  end loop;

  for r in
    select distinct i.dn_detail_id as detail_id
      from public.delivery_note_item i
     where i.parent_id = p_id and i.dn_detail_id is not null
  loop
    update public.delivery_note_item src
       set returned_qty = (
         select coalesce(sum(-ri.stock_qty), 0)
           from public.delivery_note_item ri
           join public.delivery_note d on d.id = ri.parent_id
          where ri.dn_detail_id = r.detail_id
            and d.is_return
            and (
              (p_cancel and d.docstatus = 1 and d.id <> p_id)
              or (not p_cancel and (d.docstatus = 1 or d.id = p_id))
            )
       )
     where src.id = r.detail_id;
  end loop;

  for v_so in
    select distinct oi.parent_id
      from public.sales_order_item oi
     where oi.id in (
       select i.so_detail_id
         from public.delivery_note_item i
        where i.parent_id = p_id and i.so_detail_id is not null
     )
  loop
    select coalesce(sum(least(abs(i.delivered_qty), abs(i.qty))) filter (where not i.skip_delivery), 0),
           coalesce(sum(abs(i.qty)) filter (where not i.skip_delivery), 0)
      into v_num, v_den
      from public.sales_order_item i
     where i.parent_id = v_so;
    if v_den = 0 then
      v_per := 100;
      v_del := 'Not Applicable';
    else
      v_per := v_num / v_den * 100;
      if v_per >= 99.999999 then
        v_per := 100;
        v_del := 'Fully Delivered';
      elsif v_per < 0.001 then
        v_per := 0;
        v_del := 'Not Delivered';
      else
        v_del := 'Partly Delivered';
      end if;
    end if;
    select o.per_billed, o.status into v_billed, v_current
      from public.sales_order o
     where o.id = v_so;
    if coalesce(v_billed, 0) < 0.001 then
      v_bill := 'Not Billed';
    elsif v_billed >= 99.999999 then
      v_bill := 'Fully Billed';
    else
      v_bill := 'Partly Billed';
    end if;
    update public.sales_order
       set per_delivered = v_per,
           delivery_status = v_del,
           billing_status = v_bill
     where id = v_so;
    if v_current not in ('Closed', 'On Hold') then
      update public.sales_order
         set status = app.sales_order_next_status(v_so)
       where id = v_so;
    end if;
  end loop;

  for v_dn in
    select distinct src.parent_id
      from public.delivery_note_item src
     where src.id in (
       select i.dn_detail_id
         from public.delivery_note_item i
        where i.parent_id = p_id and i.dn_detail_id is not null
     )
  loop
    select coalesce(sum(i.returned_qty), 0),
           coalesce(sum(abs(i.stock_qty)), 0)
      into v_num, v_den
      from public.delivery_note_item i
     where i.parent_id = v_dn;
    if v_den = 0 then
      v_per := 0;
    else
      v_per := v_num / v_den * 100;
      if v_per >= 99.999999 then
        v_per := 100;
      elsif v_per < 0.001 then
        v_per := 0;
      end if;
    end if;
    update public.delivery_note
       set per_returned = v_per
     where id = v_dn
     returning status into v_current;
    if v_current is distinct from 'Closed' then
      update public.delivery_note
         set status = app.delivery_note_next_status(v_dn)
       where id = v_dn;
    end if;
  end loop;
end;
$fn$;

create or replace function app.on_submit__sales_order(p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_count int;
  v_company uuid;
  v_base numeric;
  v_status text;
begin
  select count(*) into v_count from public.sales_order_item i where i.parent_id = p_id;
  if v_count = 0 then
    raise exception using errcode = 'P0001', message = 'so_items: Items are required';
  end if;

  update public.sales_order q
     set total = s.amt,
         net_total = s.amt,
         grand_total = s.amt,
         base_grand_total = s.amt * q.conversion_rate
    from (
      select coalesce(sum(i.amount), 0) as amt
        from public.sales_order_item i
       where i.parent_id = p_id
    ) s
   where q.id = p_id
  returning q.company_id, q.base_grand_total into v_company, v_base;

  perform app.validate_approving_authority('Sales Order', v_company, v_base);
  perform app.sales_order_check_credit(p_id);
  perform app.update_prevdoc_status('Sales Order', p_id, false);
  v_status := app.sales_order_next_status(p_id);
  update public.sales_order
     set status = v_status,
         delivery_status = 'Not Delivered',
         billing_status = 'Not Billed',
         advance_payment_status = 'Not Requested'
   where id = p_id;
end;
$fn$;

create or replace function app.on_cancel__sales_order(p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_status text;
begin
  select status into v_status from public.sales_order where id = p_id;
  if v_status = 'Closed' then
    raise exception using errcode = 'P0001',
      message = 'so_closed: Closed order cannot be cancelled. Unclose to cancel.';
  end if;
  perform app.update_prevdoc_status('Sales Order', p_id, true);
  update public.sales_order set status = 'Cancelled' where id = p_id;
end;
$fn$;

create or replace function app.on_submit__delivery_note(p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_count int;
  v_status text;
begin
  select count(*) into v_count from public.delivery_note_item i where i.parent_id = p_id;
  if v_count = 0 then
    raise exception using errcode = 'P0001', message = 'dn_items: Items are required';
  end if;
  if exists (
    select 1
      from public.delivery_note_item i
      join public.delivery_note d on d.id = i.parent_id
     where i.parent_id = p_id
       and ((d.is_return and i.qty >= 0) or (not d.is_return and i.qty <= 0))
  ) then
    raise exception using errcode = 'P0001', message = 'dn_qty: Quantity has the wrong sign for this Delivery Note';
  end if;

  update public.delivery_note q
     set total = s.amt,
         net_total = s.amt,
         grand_total = s.amt,
         base_grand_total = s.amt * q.conversion_rate
    from (
      select coalesce(sum(i.amount), 0) as amt
        from public.delivery_note_item i
       where i.parent_id = p_id
    ) s
   where q.id = p_id;

  perform app.make_packing_list('Delivery Note', p_id);
  perform app.delivery_note_check_credit(p_id);
  perform app.update_prevdoc_status('Delivery Note', p_id, false);
  v_status := app.delivery_note_next_status(p_id);
  update public.delivery_note set status = v_status where id = p_id;
end;
$fn$;

create or replace function app.on_cancel__delivery_note(p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_status text;
begin
  select status into v_status from public.delivery_note where id = p_id;
  if v_status = 'Closed' then
    raise exception using errcode = 'P0001',
      message = 'dn_closed: Closed delivery note cannot be cancelled. Re-open to cancel.';
  end if;
  perform app.update_prevdoc_status('Delivery Note', p_id, true);
  update public.delivery_note set status = 'Cancelled' where id = p_id;
end;
$fn$;

create or replace function app.on_cancel__quotation(p_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  v_root uuid;
  v_name text;
  v_order text;
begin
  select q.name into v_name from public.quotation q where q.id = p_id;
  select s.name into v_order
    from public.sales_order_item i
    join public.sales_order s on s.id = i.parent_id
   where s.docstatus = 1
     and (
       i.prevdoc_id = p_id
       or i.quotation_item_id in (
         select qi.id from public.quotation_item qi where qi.parent_id = p_id
       )
     )
   limit 1;
  if v_order is not null then
    raise exception using errcode = 'P0001',
      message = format('quotation_ordered: Quotation %s is linked to Sales Order %s', v_name, v_order);
  end if;
  update public.quotation set status = 'Cancelled' where id = p_id;
  select coalesce(q.revision_of, q.id) into v_root from public.quotation q where q.id = p_id;
  perform app.quotation_refresh_latest(v_root, null, p_id);
end;
$fn$;

revoke all on function app.quotation_next_status(uuid) from public, anon, authenticated;
revoke all on function app.update_prevdoc_status(text, uuid, boolean) from public, anon, authenticated;
