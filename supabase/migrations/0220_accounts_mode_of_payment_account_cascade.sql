-- A composite foreign key cannot set only default_account_id to null. Deleting the
-- account removes the Mode of Payment row that points at it, which lets an
-- organization delete remove the chart.

alter table public.mode_of_payment_account
  drop constraint if exists mode_of_payment_account_account_fk;

alter table public.mode_of_payment_account
  add constraint mode_of_payment_account_account_fk
  foreign key (org_id, default_account_id) references public.account (org_id, id) on delete cascade;
