-- 0406 stock: an Adjustment Entry keeps quantity, so its stock ledger row has actual_qty 0.
-- The 0401 check rejected that row. A zero quantity is allowed only when the row is an adjustment.

alter table public.stock_ledger_entry drop constraint stock_ledger_entry_actual_qty_check;

alter table public.stock_ledger_entry
  add constraint stock_ledger_entry_actual_qty_check
  check (actual_qty <> 0 or is_adjustment_entry);
