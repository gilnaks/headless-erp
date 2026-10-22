create or replace function app.delivery_note_item_validate()
returns trigger
language plpgsql
set search_path = ''
as $fn$
declare
  h public.delivery_note;
  v_code text;
  v_item_name text;
  v_disabled boolean;
  v_sales boolean;
  v_stock boolean;
  v_stock_uom uuid;
  v_max numeric;
  v_factor numeric;
  v_whole boolean;
  v_max_text text;
  v_needs_wh boolean;
  v_group boolean;
  v_account_company uuid;
  v_so_name text;
  v_so_status text;
  v_so_docstatus int;
  v_so_company uuid;
  v_so_customer uuid;
  v_so_currency text;
  v_so_item uuid;
  v_so_uom uuid;
  v_so_factor numeric;
  v_so_parent uuid;
  v_src_qty numeric;
  v_src_parent uuid;
  v_already numeric;
begin
  select * into h from public.delivery_note where id = new.parent_id;
  if not found then
    raise exception using errcode = 'P0001', message = 'dn_item: Delivery Note is required';
  end if;
  if h.docstatus <> 0 and current_user = 'authenticated' then
    raise exception using errcode = 'P0001', message = 'docstatus_locked: Use Submit or Cancel';
  end if;
  if h.is_return then
    if new.qty is null or new.qty >= 0 then
      raise exception using errcode = 'P0001',
        message = format('dn_qty: Row %s: Quantity must be less than zero', coalesce(new.idx, 0));
    end if;
  elsif new.qty is null or new.qty <= 0 then
    raise exception using errcode = 'P0001',
      message = format('dn_qty: Row %s: Quantity must be greater than zero', coalesce(new.idx, 0));
  end if;

  select i.item_code, i.item_name, i.disabled, i.is_sales_item, i.is_stock_item, i.stock_uom_id, i.max_discount
    into v_code, v_item_name, v_disabled, v_sales, v_stock, v_stock_uom, v_max
    from public.item i
   where i.id = new.item_id and i.org_id = new.org_id;
  if not found then
    raise exception using errcode = 'P0001', message = 'dn_item: Item is required';
  end if;
  if v_disabled then
    raise exception using errcode = 'P0001',
      message = format('dn_item: Item %s is disabled', v_code);
  end if;
  if not coalesce(v_sales, false) then
    raise exception using errcode = 'P0001',
      message = format('dn_item: Item %s is not a sales item', v_code);
  end if;
  if new.item_name is null or btrim(new.item_name) = '' then
    new.item_name := v_item_name;
  end if;
  new.is_stock_item := coalesce(v_stock, false);
  new.closed := coalesce(new.closed, false);
  if h.docstatus = 0 then
    new.billed_amt := 0;
    new.returned_qty := 0;
    new.received_qty := 0;
    if current_user = 'authenticated' then
      new.incoming_rate := 0;
    end if;
  end if;

  if new.uom_id is null or new.uom_id = v_stock_uom then
    new.uom_id := v_stock_uom;
    new.conversion_factor := 1;
  else
    select u.conversion_factor into v_factor
      from public.item_uom u
     where u.parent_id = new.item_id and u.uom_id = new.uom_id;
    if v_factor is null then
      raise exception using errcode = 'P0001',
        message = format('dn_uom: Row %s: UOM is not allowed for this item', coalesce(new.idx, 0));
    end if;
    new.conversion_factor := v_factor;
  end if;
  new.stock_uom_id := v_stock_uom;
  select u.must_be_whole_number into v_whole from public.uom u where u.id = new.uom_id;
  if coalesce(v_whole, false) and new.qty <> trunc(new.qty) then
    raise exception using errcode = 'P0001',
      message = format('dn_uom: Row %s: Qty cannot be a fraction', coalesce(new.idx, 0));
  end if;

  new.discount_percentage := coalesce(new.discount_percentage, 0);
  if v_max is not null and new.discount_percentage > v_max then
    v_max_text := trim(trailing '.' from trim(trailing '0' from v_max::text));
    raise exception using errcode = 'P0001',
      message = format('dn_discount: Maximum discount for Item %s is %s%%', v_code, v_max_text);
  end if;
  if new.rate is null then
    new.rate := coalesce(new.price_list_rate, 0) * (1 - new.discount_percentage / 100);
  end if;
  new.amount := app.round(new.qty * new.rate, 2);
  new.net_rate := new.rate;
  new.net_amount := new.amount;
  new.stock_qty := new.qty * new.conversion_factor;

  if new.warehouse_id is null and h.set_warehouse_id is not null then
    new.warehouse_id := h.set_warehouse_id;
  end if;
  if new.target_warehouse_id is null and h.set_target_warehouse_id is not null then
    new.target_warehouse_id := h.set_target_warehouse_id;
  end if;
  if new.cost_center_id is null or new.expense_account_id is null then
    select coalesce(new.cost_center_id, c.cost_center_id),
           coalesce(new.expense_account_id, c.default_expense_account_id)
      into new.cost_center_id, new.expense_account_id
      from public.companies c
     where c.id = h.company_id and c.org_id = h.org_id;
  end if;

  v_needs_wh := new.is_stock_item or exists (
    select 1
      from public.product_bundle b
      join public.product_bundle_item bi on bi.parent_id = b.id
      join public.item si on si.id = bi.item_id and si.org_id = bi.org_id
     where b.org_id = new.org_id
       and b.new_item_id = new.item_id
       and b.docstatus = 1
       and b.is_active
       and not b.disabled
       and si.is_stock_item
  );
  if v_needs_wh and new.warehouse_id is null then
    raise exception using errcode = 'P0001',
      message = format('dn_warehouse: Source warehouse required for stock item %s', v_code);
  end if;
  if new.expense_account_id is not null then
    select a.is_group, a.company_id into v_group, v_account_company
      from public.account a
     where a.id = new.expense_account_id and a.org_id = new.org_id;
    if not found or v_account_company is distinct from h.company_id or coalesce(v_group, false) then
      raise exception using errcode = 'P0001',
        message = 'dn_expense: Expense account must be a ledger of the company';
    end if;
  elsif v_needs_wh then
    raise exception using errcode = 'P0001',
      message = format('dn_expense: Expense account is required for stock item %s', v_code);
  end if;

  if new.so_detail_id is not null then
    select i.item_id, i.uom_id, i.conversion_factor, i.parent_id
      into v_so_item, v_so_uom, v_so_factor, v_so_parent
      from public.sales_order_item i
     where i.id = new.so_detail_id and i.org_id = new.org_id;
    if not found then
      raise exception using errcode = 'P0001', message = 'dn_so: Sales Order item was not found';
    end if;
    if new.against_sales_order_id is null then
      new.against_sales_order_id := v_so_parent;
    elsif new.against_sales_order_id is distinct from v_so_parent then
      raise exception using errcode = 'P0001',
        message = 'dn_so: Sales Order item does not belong to the selected Sales Order';
    end if;
    if new.item_id is distinct from v_so_item then
      raise exception using errcode = 'P0001',
        message = format('dn_so: Row %s: Item does not match the Sales Order', coalesce(new.idx, 0));
    end if;
    if new.uom_id is distinct from v_so_uom then
      raise exception using errcode = 'P0001',
        message = format('dn_so: Row %s: UOM does not match the Sales Order', coalesce(new.idx, 0));
    end if;
    if new.conversion_factor is distinct from v_so_factor then
      raise exception using errcode = 'P0001',
        message = format('dn_so: Row %s: Conversion factor does not match the Sales Order', coalesce(new.idx, 0));
    end if;
  end if;

  if new.against_sales_order_id is not null then
    select o.name, o.status, o.docstatus, o.company_id, o.customer_id, o.currency
      into v_so_name, v_so_status, v_so_docstatus, v_so_company, v_so_customer, v_so_currency
      from public.sales_order o
     where o.id = new.against_sales_order_id and o.org_id = new.org_id;
    if not found or v_so_docstatus <> 1 then
      raise exception using errcode = 'P0001',
        message = format('dn_so: Sales Order %s is not submitted', coalesce(v_so_name, ''));
    end if;
    if v_so_status = 'On Hold' then
      raise exception using errcode = 'P0001',
        message = format('dn_so: Sales Order %s is on hold', v_so_name);
    end if;
    if v_so_status = 'Closed' then
      raise exception using errcode = 'P0001',
        message = format('dn_so: Sales Order %s is closed', v_so_name);
    end if;
    if v_so_company is distinct from h.company_id then
      raise exception using errcode = 'P0001',
        message = format('dn_so: Sales Order %s belongs to a different company', v_so_name);
    end if;
    if v_so_customer is distinct from h.customer_id then
      raise exception using errcode = 'P0001',
        message = format('dn_so: Sales Order %s belongs to a different customer', v_so_name);
    end if;
    if v_so_currency is distinct from h.currency then
      raise exception using errcode = 'P0001',
        message = format('dn_so: Sales Order %s uses a different currency', v_so_name);
    end if;
  end if;

  if h.is_return and h.return_against is not null and new.dn_detail_id is null then
    raise exception using errcode = 'P0001',
      message = format('dn_return: Row %s must cite the source row', coalesce(new.idx, 0));
  end if;
  if h.is_return and new.dn_detail_id is not null then
    select i.qty, i.parent_id into v_src_qty, v_src_parent
      from public.delivery_note_item i
     where i.id = new.dn_detail_id and i.org_id = new.org_id;
    if not found then
      raise exception using errcode = 'P0001', message = 'dn_return: Source row was not found';
    end if;
    if h.return_against is not null and v_src_parent is distinct from h.return_against then
      raise exception using errcode = 'P0001',
        message = 'dn_return: Return row does not belong to the source Delivery Note';
    end if;
    select coalesce(sum(abs(i.qty)), 0) into v_already
      from public.delivery_note_item i
      join public.delivery_note d on d.id = i.parent_id
     where i.dn_detail_id = new.dn_detail_id
       and i.id is distinct from new.id
       and d.is_return
       and d.docstatus < 2
       and (d.id = new.parent_id or d.docstatus = 1);
    if abs(new.qty) + v_already > abs(v_src_qty) then
      raise exception using errcode = 'P0001',
        message = 'dn_return: Returned quantity cannot be more than the delivered quantity';
    end if;
  end if;

  return new;
end;
$fn$;


-- Delivery Note stock ledger and perpetual inventory.
-- ERPNext: erpnext/controllers/selling_controller.py (update_stock_ledger, get_item_list),
-- erpnext/controllers/sales_and_purchase_return.py (get_rate_for_return),
-- erpnext/stock/doctype/delivery_note/delivery_note.py (on_submit, on_cancel),
-- erpnext/stock/doctype/delivery_note/services/gl_composer.py.
-- Posts through app.make_sl_entries. billed_amt is not written. Serial columns stay off the note.

create or replace function app.delivery_note_post_stock(p_id uuid, p_cancel boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $fn$
declare
  h public.delivery_note;
  v_entries jsonb;
  v_use_sdbnb boolean;
  v_sdbnb uuid;
begin
  select * into h from public.delivery_note where id = p_id;
  if not found then
    raise exception using errcode = 'P0001', message = 'not_found: Delivery Note not found';
  end if;

  if p_cancel then
    select jsonb_agg(jsonb_build_object(
             'item_id', s.item_id,
             'warehouse_id', s.warehouse_id,
             'company_id', s.company_id,
             'actual_qty', s.actual_qty,
             'posting_date', s.posting_date,
             'posting_time', to_char(s.posting_time, 'HH24:MI:SS'),
             'voucher_type', s.voucher_type,
             'voucher_id', s.voucher_id,
             'voucher_no', s.voucher_no,
             'voucher_detail_id', s.voucher_detail_id
           ) order by s.creation_order desc)
      into v_entries
      from public.stock_ledger_entry s
     where s.voucher_type = 'Delivery Note' and s.voucher_id = p_id and not s.is_cancelled;
    if v_entries is not null then
      perform app.make_sl_entries(v_entries, '{"is_cancelled": true}'::jsonb);
    end if;
    return;
  end if;

  select coalesce(c.enable_stock_delivered_but_not_billed, false)
         and not (h.is_return and coalesce(c.disable_sdbnb_in_sr, false)),
         c.stock_delivered_but_not_billed_id
    into v_use_sdbnb, v_sdbnb
    from public.companies c
   where c.id = h.company_id and c.org_id = h.org_id;

  drop table if exists pg_temp._dn_stock_leg;
  create temp table _dn_stock_leg (
    sort int,
    item_id uuid,
    warehouse_id uuid,
    detail_id uuid,
    actual_qty numeric,
    incoming_rate numeric,
    expense_account_id uuid,
    cost_center_id uuid,
    target_warehouse_id uuid
  ) on commit drop;

  insert into _dn_stock_leg (
    sort, item_id, warehouse_id, detail_id, actual_qty, incoming_rate,
    expense_account_id, cost_center_id, target_warehouse_id
  )
  select i.idx, i.item_id, i.warehouse_id, i.id, -i.stock_qty,
         case
           when h.is_return then coalesce((
             select abs(s.stock_value_difference / nullif(s.actual_qty, 0))
               from public.stock_ledger_entry s
              where s.org_id = h.org_id
                and s.voucher_type = 'Delivery Note'
                and s.voucher_id = h.return_against
                and s.item_id = i.item_id
                and s.warehouse_id = i.warehouse_id
                and s.voucher_detail_id = i.dn_detail_id
                and not s.is_cancelled
                and s.actual_qty < 0
              order by s.creation_order
              limit 1
           ), 0)
           else 0
         end,
         case when v_use_sdbnb then v_sdbnb else i.expense_account_id end,
         i.cost_center_id,
         case
           when i.target_warehouse_id is not null and i.target_warehouse_id is distinct from i.warehouse_id
             then i.target_warehouse_id
         end
    from public.delivery_note_item i
   where i.parent_id = p_id
     and i.is_stock_item
     and i.stock_qty <> 0
     and i.warehouse_id is not null
     and not exists (
       select 1 from public.packed_item p
        where p.parent_detail_id = i.id and p.parent_doctype = 'Delivery Note'
     );

  insert into _dn_stock_leg (
    sort, item_id, warehouse_id, detail_id, actual_qty, incoming_rate,
    expense_account_id, cost_center_id, target_warehouse_id
  )
  select i.idx * 1000 + p.idx, p.item_id, p.warehouse_id, i.id, -p.qty,
         case
           when h.is_return then coalesce((
             select abs(s.stock_value_difference / nullif(s.actual_qty, 0))
               from public.stock_ledger_entry s
              where s.org_id = h.org_id
                and s.voucher_type = 'Delivery Note'
                and s.voucher_id = h.return_against
                and s.item_id = p.item_id
                and s.warehouse_id = p.warehouse_id
                and s.voucher_detail_id = i.dn_detail_id
                and not s.is_cancelled
                and s.actual_qty < 0
              order by s.creation_order
              limit 1
           ), 0)
           else 0
         end,
         case when v_use_sdbnb then v_sdbnb else i.expense_account_id end,
         i.cost_center_id,
         null
    from public.packed_item p
    join public.delivery_note_item i on i.id = p.parent_detail_id
    join public.item it on it.id = p.item_id and it.org_id = p.org_id
   where p.parent_id = p_id
     and p.parent_doctype = 'Delivery Note'
     and it.is_stock_item
     and p.qty <> 0
     and p.warehouse_id is not null;

  select jsonb_agg(jsonb_build_object(
           'item_id', l.item_id,
           'warehouse_id', l.warehouse_id,
           'company_id', h.company_id,
           'actual_qty', l.actual_qty,
           'incoming_rate', l.incoming_rate,
           'posting_date', h.posting_date,
           'posting_time', to_char(h.posting_time, 'HH24:MI:SS'),
           'voucher_type', 'Delivery Note',
           'voucher_id', h.id,
           'voucher_no', h.name,
           'voucher_detail_id', l.detail_id,
           'expense_account_id', l.expense_account_id,
           'cost_center_id', l.cost_center_id
         ) order by l.sort)
    into v_entries
    from _dn_stock_leg l;
  if v_entries is null then
    return;
  end if;
  perform app.make_sl_entries(v_entries, '{}'::jsonb);

  select jsonb_agg(jsonb_build_object(
           'item_id', l.item_id,
           'warehouse_id', l.target_warehouse_id,
           'company_id', h.company_id,
           'actual_qty', -l.actual_qty,
           'incoming_rate', case when l.actual_qty < 0 then s.outgoing_rate else l.incoming_rate end,
           'posting_date', h.posting_date,
           'posting_time', to_char(h.posting_time, 'HH24:MI:SS'),
           'voucher_type', 'Delivery Note',
           'voucher_id', h.id,
           'voucher_no', h.name,
           'voucher_detail_id', l.detail_id,
           'expense_account_id', l.expense_account_id,
           'cost_center_id', l.cost_center_id
         ) order by l.sort)
    into v_entries
    from _dn_stock_leg l
    join public.stock_ledger_entry s
      on s.voucher_type = 'Delivery Note'
     and s.voucher_id = h.id
     and s.voucher_detail_id = l.detail_id
     and s.item_id = l.item_id
     and s.warehouse_id = l.warehouse_id
     and not s.is_cancelled
   where l.target_warehouse_id is not null;
  if v_entries is not null then
    perform app.make_sl_entries(v_entries, '{}'::jsonb);
  end if;

  update public.delivery_note_item i
     set incoming_rate = (
       select case when s.actual_qty < 0 then s.outgoing_rate else s.incoming_rate end
         from public.stock_ledger_entry s
        where s.voucher_type = 'Delivery Note'
          and s.voucher_id = h.id
          and s.voucher_detail_id = i.id
          and s.item_id = i.item_id
          and s.warehouse_id = i.warehouse_id
          and not s.is_cancelled
        order by s.creation_order
        limit 1
     )
   where i.parent_id = p_id
     and exists (
       select 1 from public.stock_ledger_entry s
        where s.voucher_type = 'Delivery Note'
          and s.voucher_id = h.id
          and s.voucher_detail_id = i.id
          and s.item_id = i.item_id
          and s.warehouse_id = i.warehouse_id
          and not s.is_cancelled
     );
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
  perform app.delivery_note_post_stock(p_id, false);
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
  perform app.delivery_note_post_stock(p_id, true);
  update public.delivery_note set status = 'Cancelled' where id = p_id;
end;
$fn$;

revoke all on function app.delivery_note_post_stock(uuid, boolean) from public, anon, authenticated;
