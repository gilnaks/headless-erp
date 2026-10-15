-- 0211 stock: Dozen is in the curated UOM list (00-setup A19) but not in ERPNext's uom_data.json.
-- Insert it as a whole-number count unit, and teach copy_uoms to do the same for later organizations.

create or replace function app.copy_uoms(p_org uuid, p_all boolean)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_names text[];
begin
  if p_all then
    select array_agg(uom_name) into v_names from public.uom_template;
  else
    v_names := app.uom_names_curated();
  end if;

  insert into public.uom_category (org_id, category_name)
  select distinct p_org, t.category
  from public.uom_template t
  where t.uom_name = any (v_names) and t.category is not null
  on conflict (org_id, lower(category_name)) do nothing;

  insert into public.uom (org_id, uom_name, must_be_whole_number, category_id)
  select p_org, t.uom_name, t.must_be_whole_number, c.id
  from public.uom_template t
  left join public.uom_category c on c.org_id = p_org and lower(c.category_name) = lower(t.category)
  where t.uom_name = any (v_names)
  on conflict (org_id, lower(uom_name)) do nothing;

  -- Curated names the global template does not ship (Dozen).
  insert into public.uom (org_id, uom_name, must_be_whole_number)
  select p_org, n, true
  from unnest(app.uom_names_curated()) as n
  where not exists (select 1 from public.uom u where u.org_id = p_org and lower(u.uom_name) = lower(n));

  insert into public.uom_conversion_factor (org_id, category, from_uom, to_uom, value)
  select p_org, c.category, c.from_uom, c.to_uom, c.value
  from public.uom_conversion_template c
  where exists (select 1 from public.uom u where u.org_id = p_org and u.uom_name = c.from_uom)
    and exists (select 1 from public.uom u where u.org_id = p_org and u.uom_name = c.to_uom)
  on conflict (org_id, from_uom, to_uom) do nothing;
end;
$$;

revoke execute on function app.copy_uoms(uuid, boolean) from public, anon, authenticated;

select app.copy_uoms(o.id, false) from public.organizations o;
