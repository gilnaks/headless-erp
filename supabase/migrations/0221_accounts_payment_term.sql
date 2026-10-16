-- 0221 accounts: Payment Term (docs/modules/01-accounts.md §2.6).
-- ERPNext: erpnext/accounts/doctype/payment_term/payment_term.json.

create table if not exists public.payment_term (
  id                         uuid primary key default gen_random_uuid(),
  org_id                     uuid not null references public.organizations (id) on delete cascade,
  name                       text not null,
  payment_term_name          text not null check (length(trim(payment_term_name)) > 0),
  invoice_portion            numeric(21,9),
  mode_of_payment_id         uuid,
  due_date_based_on          text check (due_date_based_on is null or due_date_based_on in (
    'Day(s) after invoice date',
    'Day(s) after the end of the invoice month',
    'Month(s) after the end of the invoice month'
  )),
  credit_days                int not null default 0,
  credit_months              int not null default 0,
  discount_type              text not null default 'Percentage' check (discount_type in ('Percentage', 'Amount')),
  discount                   numeric(21,9),
  discount_validity_based_on text not null default 'Day(s) after invoice date' check (discount_validity_based_on in (
    'Day(s) after invoice date',
    'Day(s) after the end of the invoice month',
    'Month(s) after the end of the invoice month'
  )),
  discount_validity          int,
  description                text,
  created_at                 timestamptz not null default now(),
  created_by                 uuid default auth.uid(),
  updated_at                 timestamptz not null default now(),
  updated_by                 uuid,
  unique (org_id, id),
  constraint payment_term_mode_fk
    foreign key (org_id, mode_of_payment_id) references public.mode_of_payment (org_id, id)
    on delete set null (mode_of_payment_id)
);

create unique index if not exists payment_term_name_uniq on public.payment_term (org_id, lower(payment_term_name));
create index if not exists payment_term_mode_idx on public.payment_term (org_id, mode_of_payment_id);

create or replace function app.payment_term_validate()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.payment_term_name := trim(new.payment_term_name);
  new.name := new.payment_term_name;
  new.due_date_based_on := nullif(new.due_date_based_on, '');
  return new;
end;
$$;

revoke execute on function app.payment_term_validate() from public, anon, authenticated;

drop trigger if exists payment_term_validate on public.payment_term;
create trigger payment_term_validate before insert or update on public.payment_term
  for each row execute function app.payment_term_validate();
drop trigger if exists touch_updated on public.payment_term;
create trigger touch_updated before update on public.payment_term
  for each row execute function app.touch_updated();

alter table public.payment_term enable row level security;
alter table public.payment_term force row level security;

drop policy if exists payment_term_select on public.payment_term;
create policy payment_term_select on public.payment_term for select to authenticated
  using (org_id = any ((select app.orgs_with_perm('Payment Term', 'read'))::uuid[]));
drop policy if exists payment_term_insert on public.payment_term;
create policy payment_term_insert on public.payment_term for insert to authenticated
  with check (org_id = any ((select app.orgs_with_perm('Payment Term', 'create'))::uuid[]));
drop policy if exists payment_term_update on public.payment_term;
create policy payment_term_update on public.payment_term for update to authenticated
  using (org_id = any ((select app.orgs_with_perm('Payment Term', 'write'))::uuid[]))
  with check (org_id = any ((select app.orgs_with_perm('Payment Term', 'write'))::uuid[]));
drop policy if exists payment_term_delete on public.payment_term;
create policy payment_term_delete on public.payment_term for delete to authenticated
  using (org_id = any ((select app.orgs_with_perm('Payment Term', 'delete'))::uuid[]));

insert into public.doctype_meta (doctype, table_name, module, title_field)
values ('Payment Term', 'payment_term', 'accounts', 'name')
on conflict (doctype) do update
  set table_name = excluded.table_name, module = excluded.module, title_field = excluded.title_field;

insert into public.role_permission_template (role, doctype, can_read, can_write, can_create, can_delete)
values
  ('System Manager', 'Payment Term', true, true, true, true),
  ('Accounts Manager', 'Payment Term', true, true, true, true),
  ('Accounts User', 'Payment Term', true, true, true, true)
on conflict (role, doctype) do update
  set can_read = excluded.can_read, can_write = excluded.can_write,
      can_create = excluded.can_create, can_delete = excluded.can_delete;

select app.sync_role_permissions();
