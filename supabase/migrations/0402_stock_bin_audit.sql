-- 0402 stock: Bin carries updated_by so app.touch_updated can run on a recompute.

alter table public.bin add column if not exists updated_by uuid;
