-- Deleting an account clears the Mode of Payment link so an organization delete can
-- remove the chart. The company row itself still goes away with the company.

alter table public.mode_of_payment_account
  drop constraint if exists mode_of_payment_account_org_id_default_account_id_fkey;

alter table public.mode_of_payment_account
  add constraint mode_of_payment_account_account_fk
  foreign key (org_id, default_account_id) references public.account (org_id, id) on delete set null;
