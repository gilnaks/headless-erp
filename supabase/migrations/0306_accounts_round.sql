-- Half-even rounding used by the journal and the general ledger.
-- The taxes-and-totals pipeline can replace this body later; the signature stays.

create or replace function app.round(p_value numeric, p_precision int)
returns numeric
language plpgsql
immutable
set search_path = ''
as $$
declare
  v_factor numeric := power(10::numeric, p_precision);
  v_scaled numeric;
  v_floor numeric;
  v_diff numeric;
  v_whole numeric;
begin
  if p_value < 0 then
    return -app.round(-p_value, p_precision);
  end if;
  v_scaled := p_value * v_factor;
  v_floor := trunc(v_scaled);
  v_diff := v_scaled - v_floor;
  if v_diff > 0.5 then
    v_whole := v_floor + 1;
  elsif v_diff < 0.5 then
    v_whole := v_floor;
  elsif mod(v_floor, 2) = 0 then
    v_whole := v_floor;
  else
    v_whole := v_floor + 1;
  end if;
  return v_whole / v_factor;
end;
$$;

revoke execute on function app.round(numeric, int) from public, anon;
grant execute on function app.round(numeric, int) to authenticated;
