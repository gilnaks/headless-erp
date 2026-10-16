-- 0222 accounts: Payment Terms Template (docs/modules/01-accounts.md §2.6).
-- ERPNext: erpnext/accounts/doctype/payment_terms_template/payment_terms_template.{json,py},
-- payment_terms_template_detail/payment_terms_template_detail.json.
-- Company payment-terms and default selling/buying terms links were left plain uuid in 0208.

create table if not exists public.payment_terms_template (
  id                                      uuid primary key default gen_random_uuid(),
  org_id                                  uuid not null references public.organizations (id) on delete cascade,
  name                                    text not null,
  template_name                           text not null check (length(trim(template_name)) > 0),
  allocate_payment_based_on_payment_terms boolean not null default false,
  created_at                              timestamptz not null default now(),
  created_by                              uuid default auth.uid(),
  updated_at                              timestamptz not null default now(),
  updated_by                              uuid,
  unique (org_id, id)
);

create unique index if not exists payment_terms_template_name_uniq
  on public.payment_terms_template (org_id, lower(template_name));

create table if not exists public.payment_terms_template_detail (
  id                         uuid primary key default gen_random_uuid(),
  org_id                     uuid not null,
  parent_id                  uuid not null,
  idx                        int not null,
  payment_term_id            uuid,
  invoice_portion            numeric(21,9) not null,
  due_date_based_on          text not null default 'Day(s) after invoice date' check (due_date_based_on in (
    'Day(s) after invoice date',
    'Day(s) after the end of the invoice month',
    'Month(s) after the end of the invoice month'
  )),
  credit_days                int not null default 0,
  credit_months              int not null default 0,
  mode_of_payment_id         uuid,
  discount_type              text not null default 'Percentage' check (discount_type in ('Percentage', 'Amount')),
  discount                   numeric(21,9),
  discount_validity_based_on text check (discount_validity_based_on is null or discount_validity_based_on in (
    'Day(s) after invoice date',
    'Day(s) after the end of the invoice month',
    'Month(s) after the end of the invoice month'
  )),
  discount_validity          int,
  description                text,
  unique (parent_id, idx) deferrable initially deferred,
  foreign key (org_id, parent_id) references public.payment_terms_template (org_id, id) on delete cascade,
  constraint payment_terms_template_detail_term_fk
    foreign key (org_id, payment_term_id) references public.payment_term (org_id, id),
  constraint payment_terms_template_detail_mode_fk
    foreign key (org_id, mode_of_payment_id) references public.mode_of_payment (org_id, id)
    on delete set null (mode_of_payment_id)
);

create index if not exists payment_terms_template_detail_parent_idx
  on public.payment_terms_template_detail (org_id, parent_id);
create index if not exists payment_terms_template_detail_term_idx
  on public.payment_terms_template_detail (org_id, payment_term_id);
create index if not exists payment_terms_template_detail_mode_idx
  on public.payment_terms_template_detail (org_id, mode_of_payment_id);

create or replace function app.payment_terms_template_validate()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.template_name := trim(new.template_name);
  new.name := new.template_name;
  return new;
end;
$$;

create or replace function app.payment_terms_template_refresh(p_template uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_sum numeric;
  v_allocate boolean;
  v_row int;
begin
  select allocate_payment_based_on_payment_terms into v_allocate
    from public.payment_terms_template where id = p_template;
  if not found then
    return;
  end if;
  select coalesce(sum(invoice_portion), 0) into v_sum
    from public.payment_terms_template_detail where parent_id = p_template;
  if v_sum <> 100 then
    raise exception using errcode = 'P0001',
      message = 'payment_terms_portion: Combined invoice portion must equal 100%';
  end if;
  if v_allocate then
    select idx into v_row from public.payment_terms_template_detail
     where parent_id = p_template and payment_term_id is null
     order by idx limit 1;
    if found then
      raise exception using errcode = 'P0001',
        message = format('payment_term_required: Row %s: Payment Term is mandatory', v_row);
    end if;
  end if;
  if exists (
    select 1 from public.payment_terms_template_detail
     where parent_id = p_template and payment_term_id is not null
     group by payment_term_id having count(*) > 1
  ) then
    raise exception using errcode = 'P0001', message = 'payment_term_duplicate: Duplicate payment term rows';
  end if;
end;
$$;

create or replace function app.payment_terms_template_refresh_trigger()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform app.payment_terms_template_refresh(coalesce(new.id, old.id));
  return null;
end;
$$;

create or replace function app.payment_terms_detail_refresh_trigger()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform app.payment_terms_template_refresh(coalesce(new.parent_id, old.parent_id));
  return null;
end;
$$;

revoke execute on function
  app.payment_terms_template_validate(),
  app.payment_terms_template_refresh(uuid),
  app.payment_terms_template_refresh_trigger(),
  app.payment_terms_detail_refresh_trigger()
from public, anon, authenticated;

drop trigger if exists payment_terms_template_validate on public.payment_terms_template;
create trigger payment_terms_template_validate before insert or update on public.payment_terms_template
  for each row execute function app.payment_terms_template_validate();
drop trigger if exists touch_updated on public.payment_terms_template;
create trigger touch_updated before update on public.payment_terms_template
  for each row execute function app.touch_updated();
drop trigger if exists payment_terms_template_refresh on public.payment_terms_template;
create constraint trigger payment_terms_template_refresh
  after insert or update on public.payment_terms_template
  deferrable initially deferred
  for each row execute function app.payment_terms_template_refresh_trigger();

drop trigger if exists payment_terms_detail_refresh on public.payment_terms_template_detail;
create constraint trigger payment_terms_detail_refresh
  after insert or update or delete on public.payment_terms_template_detail
  deferrable initially deferred
  for each row execute function app.payment_terms_detail_refresh_trigger();

alter table public.companies drop constraint if exists companies_payment_terms_fk;
alter table public.companies
  add constraint companies_payment_terms_fk
  foreign key (org_id, payment_terms_id) references public.payment_terms_template (org_id, id)
  on delete set null (payment_terms_id);

alter table public.companies drop constraint if exists companies_default_selling_terms_fk;
alter table public.companies
  add constraint companies_default_selling_terms_fk
  foreign key (org_id, default_selling_terms_id) references public.terms_and_conditions (org_id, id)
  on delete set null (default_selling_terms_id);
alter table public.companies drop constraint if exists companies_default_buying_terms_fk;
alter table public.companies
  add constraint companies_default_buying_terms_fk
  foreign key (org_id, default_buying_terms_id) references public.terms_and_conditions (org_id, id)
  on delete set null (default_buying_terms_id);

create index if not exists companies_payment_terms_idx on public.companies (org_id, payment_terms_id);
create index if not exists companies_selling_terms_idx on public.companies (org_id, default_selling_terms_id);
create index if not exists companies_buying_terms_idx on public.companies (org_id, default_buying_terms_id);

alter table public.payment_terms_template enable row level security;
alter table public.payment_terms_template force row level security;
alter table public.payment_terms_template_detail enable row level security;
alter table public.payment_terms_template_detail force row level security;

drop policy if exists payment_terms_template_select on public.payment_terms_template;
create policy payment_terms_template_select on public.payment_terms_template for select to authenticated
  using (org_id = any ((select app.orgs_with_perm('Payment Terms Template', 'read'))::uuid[]));
drop policy if exists payment_terms_template_insert on public.payment_terms_template;
create policy payment_terms_template_insert on public.payment_terms_template for insert to authenticated
  with check (org_id = any ((select app.orgs_with_perm('Payment Terms Template', 'create'))::uuid[]));
drop policy if exists payment_terms_template_update on public.payment_terms_template;
create policy payment_terms_template_update on public.payment_terms_template for update to authenticated
  using (org_id = any ((select app.orgs_with_perm('Payment Terms Template', 'write'))::uuid[]))
  with check (org_id = any ((select app.orgs_with_perm('Payment Terms Template', 'write'))::uuid[]));
drop policy if exists payment_terms_template_delete on public.payment_terms_template;
create policy payment_terms_template_delete on public.payment_terms_template for delete to authenticated
  using (org_id = any ((select app.orgs_with_perm('Payment Terms Template', 'delete'))::uuid[]));

drop policy if exists payment_terms_template_detail_select on public.payment_terms_template_detail;
create policy payment_terms_template_detail_select on public.payment_terms_template_detail for select to authenticated
  using (exists (select 1 from public.payment_terms_template p where p.id = parent_id));
drop policy if exists payment_terms_template_detail_insert on public.payment_terms_template_detail;
create policy payment_terms_template_detail_insert on public.payment_terms_template_detail for insert to authenticated
  with check (org_id = any ((select app.orgs_with_perm('Payment Terms Template', 'write'))::uuid[])
              or org_id = any ((select app.orgs_with_perm('Payment Terms Template', 'create'))::uuid[]));
drop policy if exists payment_terms_template_detail_update on public.payment_terms_template_detail;
create policy payment_terms_template_detail_update on public.payment_terms_template_detail for update to authenticated
  using (org_id = any ((select app.orgs_with_perm('Payment Terms Template', 'write'))::uuid[]))
  with check (org_id = any ((select app.orgs_with_perm('Payment Terms Template', 'write'))::uuid[]));
drop policy if exists payment_terms_template_detail_delete on public.payment_terms_template_detail;
create policy payment_terms_template_detail_delete on public.payment_terms_template_detail for delete to authenticated
  using (org_id = any ((select app.orgs_with_perm('Payment Terms Template', 'write'))::uuid[]));

insert into public.doctype_meta (doctype, table_name, module, title_field)
values ('Payment Terms Template', 'payment_terms_template', 'accounts', 'name')
on conflict (doctype) do update
  set table_name = excluded.table_name, module = excluded.module, title_field = excluded.title_field;

insert into public.doctype_meta (doctype, table_name, module, is_child, parent_doctype, child_field)
values ('Payment Terms Template Detail', 'payment_terms_template_detail', 'accounts', true, 'Payment Terms Template', 'terms')
on conflict (doctype) do update
  set table_name = excluded.table_name, is_child = true, parent_doctype = excluded.parent_doctype, child_field = excluded.child_field;

insert into public.role_permission_template (role, doctype, can_read, can_write, can_create, can_delete)
values
  ('System Manager', 'Payment Terms Template', true, true, true, true),
  ('Accounts User', 'Payment Terms Template', true, true, true, true),
  ('Accounts Manager', 'Payment Terms Template', true, true, true, true),
  ('Purchase Manager', 'Payment Terms Template', true, false, false, false),
  ('Purchase User', 'Payment Terms Template', true, false, false, false),
  ('Sales Manager', 'Payment Terms Template', true, false, false, false),
  ('Sales User', 'Payment Terms Template', true, false, false, false),
  ('Manufacturing Manager', 'Payment Terms Template', true, false, false, false)
on conflict (role, doctype) do update
  set can_read = excluded.can_read, can_write = excluded.can_write,
      can_create = excluded.can_create, can_delete = excluded.can_delete;

select app.sync_role_permissions();
