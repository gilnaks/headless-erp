-- 0413 stock: daily reorder (docs/modules/04-stock.md §3.4).
-- ERPNext: erpnext/stock/reorder_item.py.
-- Drafts one Material Request per company and purpose. It does not submit and it does not email.

create or replace function app.reorder_items()
returns int
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_group record;
  v_id uuid;
  v_created int := 0;
begin
  drop table if exists pg_temp._reorder;
  create temp table _reorder (
    org_id uuid,
    company_id uuid,
    material_request_type text,
    item_id uuid,
    warehouse_id uuid,
    qty numeric,
    uom_id uuid,
    schedule_date date
  ) on commit drop;

  insert into pg_temp._reorder (
    org_id, company_id, material_request_type, item_id, warehouse_id, qty, uom_id, schedule_date
  )
  select
    i.org_id,
    w.company_id,
    r.material_request_type,
    i.id,
    r.warehouse_id,
    case when u.must_be_whole_number then ceil(r.warehouse_reorder_qty) else r.warehouse_reorder_qty end,
    i.stock_uom_id,
    current_date + coalesce(i.lead_time_days, 0)
  from public.item_reorder r
  join public.item i on i.id = r.parent_id and i.org_id = r.org_id
  join public.stock_settings s on s.org_id = i.org_id and s.auto_indent
  join public.warehouse w on w.id = r.warehouse_id and w.org_id = r.org_id
  join public.uom u on u.id = i.stock_uom_id
  where i.is_stock_item
    and not i.disabled
    and i.end_of_life >= current_date
    and not w.disabled
    and r.warehouse_id is not null
    and r.material_request_type not in ('Customer Provided', 'Material Transfer')
    and r.warehouse_reorder_qty > 0
    and coalesce((
      select sum(b.actual_qty + b.indented_qty + b.ordered_qty - b.reserved_qty)
        from public.bin b
        join public.warehouse bw on bw.id = b.warehouse_id and bw.org_id = b.org_id
        join public.warehouse g on g.id = r.warehouse_group_id and g.org_id = r.org_id
       where b.org_id = r.org_id
         and b.item_id = i.id
         and bw.path operator(extensions.<@) g.path
    ), 0) < r.warehouse_reorder_level
    and not exists (
      select 1
        from public.material_request_item mi
        join public.material_request m on m.id = mi.parent_id and m.org_id = mi.org_id
       where mi.org_id = r.org_id
         and mi.item_id = i.id
         and mi.warehouse_id = r.warehouse_id
         and m.docstatus in (0, 1)
         and m.status not in ('Stopped', 'Cancelled', 'Ordered', 'Transferred', 'Issued', 'Received')
    );

  for v_group in
    select distinct org_id, company_id, material_request_type
      from pg_temp._reorder
     order by org_id, company_id, material_request_type
  loop
    begin
      insert into public.material_request (org_id, company_id, material_request_type)
      values (v_group.org_id, v_group.company_id, v_group.material_request_type)
      returning id into v_id;

      insert into public.material_request_item (
        org_id, parent_id, idx, item_id, qty, uom_id, conversion_factor, schedule_date, warehouse_id
      )
      select
        c.org_id,
        v_id,
        row_number() over (order by i.item_code),
        c.item_id,
        c.qty,
        c.uom_id,
        1,
        c.schedule_date,
        c.warehouse_id
      from pg_temp._reorder c
      join public.item i on i.id = c.item_id
      where c.org_id = v_group.org_id
        and c.company_id = v_group.company_id
        and c.material_request_type = v_group.material_request_type;

      v_created := v_created + 1;
    exception when others then
      null;
    end;
  end loop;

  return v_created;
end;
$$;

revoke execute on function app.reorder_items() from public, anon, authenticated;

-- Daily, after auto-create-fiscal-year at 00:15. Re-running the migration replaces the job.
select cron.schedule('reorder-items', '45 0 * * *', 'select app.reorder_items()');
