-- The naming helper is revoked from authenticated. Header triggers call it, so they run as the owner.
alter function app.sales_taxes_and_charges_template_validate() security definer;
alter function app.purchase_taxes_and_charges_template_validate() security definer;
