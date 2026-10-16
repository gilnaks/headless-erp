-- 0213 accounts: Account display names are computed inside the row trigger.
-- app.account_validate is not security definer, so the inserting user must be able to call it.
-- ERPNext: erpnext/accounts/utils.py get_autoname_with_number.

grant execute on function app.account_display_name(text, text, text) to authenticated;
