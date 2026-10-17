-- 0236 selling: customer-group child policies must not bind parent_id to the group tree.

drop policy if exists customer_group_party_account_select on public.customer_group_party_account;
create policy customer_group_party_account_select on public.customer_group_party_account for select to authenticated
  using (exists (
    select 1 from public.customer_group p
    where p.id = customer_group_party_account.parent_id
  ));

drop policy if exists customer_group_credit_limit_select on public.customer_group_credit_limit;
create policy customer_group_credit_limit_select on public.customer_group_credit_limit for select to authenticated
  using (exists (
    select 1 from public.customer_group p
    where p.id = customer_group_credit_limit.parent_id
  ));
