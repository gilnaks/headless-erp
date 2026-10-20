import { randomUUID } from "node:crypto";
import { createClient } from "@supabase/supabase-js";

/** One confirmed user per spec (env prefix → email local part and profile), so specs never share organizations. */
const USERS = [
    { env: "E2E", local: "smoke", first_name: "Smoke", last_name: "Test" },
    { env: "E2E_ACCESS", local: "access", first_name: "Access", last_name: "Admin" },
    { env: "E2E_USERS", local: "users", first_name: "Users", last_name: "Admin" },
    { env: "E2E_INVITER", local: "inviter", first_name: "Inviting", last_name: "Owner" },
    { env: "E2E_INVITEE", local: "invitee", first_name: "Invited", last_name: "Member" },
    { env: "E2E_PERMS", local: "perms", first_name: "Perms", last_name: "Admin" },
    { env: "E2E_RESTRICTOR", local: "restrictor", first_name: "Restricting", last_name: "Owner" },
    { env: "E2E_RESTRICTED", local: "restricted", first_name: "Restricted", last_name: "Member" },
    { env: "E2E_BRANCH", local: "branch", first_name: "Branch", last_name: "Admin" },
    { env: "E2E_DESIGNATION", local: "designation", first_name: "Designation", last_name: "Admin" },
    { env: "E2E_DEPARTMENT", local: "department", first_name: "Department", last_name: "Admin" },
    { env: "E2E_HOLIDAYS", local: "holidays", first_name: "Holidays", last_name: "Admin" },
    { env: "E2E_FISCAL", local: "fiscal", first_name: "Fiscal", last_name: "Admin" },
    { env: "E2E_ONBOARDING", local: "onboarding", first_name: "Onboarding", last_name: "Owner" },
    { env: "E2E_LETTERHEAD", local: "letterhead", first_name: "Letter", last_name: "Head" },
    { env: "E2E_PRINTSETTINGS", local: "printsettings", first_name: "Print", last_name: "Settings" },
    { env: "E2E_PRINT_A", local: "print-a", first_name: "Printing", last_name: "Owner" },
    { env: "E2E_PRINT_B", local: "print-b", first_name: "Other", last_name: "Owner" },
    { env: "E2E_ADDRESS", local: "address", first_name: "Address", last_name: "Admin" },
    { env: "E2E_CONTACT", local: "contact", first_name: "Contact", last_name: "Admin" },
    { env: "E2E_RAIL", local: "rail", first_name: "Party", last_name: "Rail" },
    { env: "E2E_EMAIL_ACCOUNT", local: "email-account", first_name: "Email", last_name: "Admin" },
    { env: "E2E_EMAIL_TEMPLATE", local: "email-template", first_name: "Template", last_name: "Admin" },
    { env: "E2E_EMAIL_SEND", local: "email-send", first_name: "Sending", last_name: "Owner" },
    { env: "E2E_AUTH_RULE", local: "auth-rule", first_name: "Rule", last_name: "Admin" },
    { env: "E2E_HOME", local: "home", first_name: "Home", last_name: "Owner" },
    { env: "E2E_HOME_MEMBER", local: "home-member", first_name: "Home", last_name: "Member" },
    { env: "E2E_UOM", local: "uom", first_name: "Uom", last_name: "Admin" },
    { env: "E2E_ITEM_GROUP", local: "item-group", first_name: "Item Group", last_name: "Admin" },
    { env: "E2E_BRAND", local: "brand", first_name: "Brand", last_name: "Admin" },
    { env: "E2E_CUSTOMER_GROUP", local: "customer-group", first_name: "Customer Group", last_name: "Admin" },
    { env: "E2E_SALES_PERSON", local: "sales-person", first_name: "Sales Person", last_name: "Admin" },
    { env: "E2E_TERRITORY", local: "territory", first_name: "Territory", last_name: "Admin" },
    { env: "E2E_INDUSTRY_TYPE", local: "industry-type", first_name: "Industry Type", last_name: "Admin" },
    { env: "E2E_SUPPLIER_GROUP", local: "supplier-group", first_name: "Supplier Group", last_name: "Admin" },
    { env: "E2E_TERMS", local: "terms", first_name: "Terms", last_name: "Admin" },
    { env: "E2E_STOCK_ENTRY_TYPE", local: "stock-entry-type", first_name: "Stock Entry Type", last_name: "Admin" },
    { env: "E2E_ACCOUNT_CATEGORY", local: "account-category", first_name: "Account Category", last_name: "Admin" },
    { env: "E2E_ACCOUNT", local: "account", first_name: "Account", last_name: "Admin" },
    { env: "E2E_COST_CENTER", local: "cost-center", first_name: "Cost Center", last_name: "Admin" },
    { env: "E2E_WAREHOUSE", local: "warehouse", first_name: "Warehouse", last_name: "Admin" },
    { env: "E2E_MODE_OF_PAYMENT", local: "mode-of-payment", first_name: "Mode", last_name: "Admin" },
    { env: "E2E_PAYMENT_TERMS", local: "payment-terms", first_name: "Payment Terms", last_name: "Admin" },
    { env: "E2E_CURRENCY_EXCHANGE", local: "currency-exchange", first_name: "Currency", last_name: "Admin" },
    { env: "E2E_PARTY_TYPE", local: "party-type", first_name: "Party", last_name: "Admin" },
    { env: "E2E_TAX_CATEGORY", local: "tax-category", first_name: "Tax", last_name: "Admin" },
    { env: "E2E_TAX_TEMPLATES", local: "tax-templates", first_name: "Tax Templates", last_name: "Admin" },
    { env: "E2E_ITEM_TAX", local: "item-tax", first_name: "Item Tax", last_name: "Admin" },
    { env: "E2E_COUNTRY_TAX", local: "country-tax", first_name: "Country Tax", last_name: "Admin" },
    { env: "E2E_PRICE_LIST", local: "price-list", first_name: "Price List", last_name: "Admin" },
    { env: "E2E_CUSTOMER", local: "customer", first_name: "Customer", last_name: "Admin" },
    { env: "E2E_SUPPLIER", local: "supplier", first_name: "Supplier", last_name: "Admin" },
    { env: "E2E_ITEM", local: "item", first_name: "Item", last_name: "Admin" },
    { env: "E2E_ITEM_PRICE", local: "item-price", first_name: "Item Price", last_name: "Admin" },
    { env: "E2E_TAX_RULE", local: "tax-rule", first_name: "Tax Rule", last_name: "Admin" },
    { env: "E2E_PRODUCT_BUNDLE", local: "product-bundle", first_name: "Product Bundle", last_name: "Admin" },
    { env: "E2E_P2", local: "p2", first_name: "Masters", last_name: "Admin" },
    { env: "E2E_JE", local: "journal", first_name: "Journal", last_name: "Admin" },
    { env: "E2E_PE", local: "payment", first_name: "Payment", last_name: "Admin" },
    { env: "E2E_AS", local: "accounts-settings", first_name: "Accounts", last_name: "Settings" },
    { env: "E2E_OPEN", local: "opening", first_name: "Opening", last_name: "Admin" },
    { env: "E2E_GL", local: "ledger", first_name: "Ledger", last_name: "Admin" },
    { env: "E2E_TB", local: "trial", first_name: "Trial", last_name: "Admin" },
    { env: "E2E_TBP", local: "trial-party", first_name: "Trial Party", last_name: "Admin" },
    { env: "E2E_PL", local: "profit", first_name: "Profit", last_name: "Admin" },
    { env: "E2E_BS", local: "balance", first_name: "Balance", last_name: "Admin" },
    { env: "E2E_CF", local: "cash", first_name: "Cash", last_name: "Admin" },
    { env: "E2E_DASH", local: "dash", first_name: "Dash", last_name: "Admin" },
    { env: "E2E_STOCK_SETTINGS", local: "stock-settings", first_name: "Stock", last_name: "Settings" },
    { env: "E2E_STOCK_ENTRY", local: "stock-entry", first_name: "Stock", last_name: "Entry" },
    { env: "E2E_STOCK_RECONCILIATION", local: "stock-reconciliation", first_name: "Stock", last_name: "Reconciliation" },
] as const;

/**
 * Creates confirmed users for the run (sign-up requires email confirmation, which the tests cannot click).
 * Credentials reach the tests through env vars (`<env>_EMAIL`, `<env>_PASSWORD`), which Playwright passes on to workers.
 */
export default async function globalSetup() {
    const url = process.env.VITE_SUPABASE_URL ?? process.env.NEXT_PUBLIC_SUPABASE_URL;
    const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
    if (!url || !key) throw new Error("e2e needs VITE_SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY (.env.local or CI)");

    const admin = createClient(url, key, { auth: { persistSession: false, autoRefreshToken: false } });
    const stamp = Date.now();
    for (const user of USERS) {
        const email = `${user.local}-${stamp}@example.com`;
        const password = `Smoke-${randomUUID()}`;
        const { error } = await admin.auth.admin.createUser({
            email,
            password,
            email_confirm: true,
            user_metadata: { first_name: user.first_name, last_name: user.last_name },
        });
        if (error) throw error;
        process.env[`${user.env}_EMAIL`] = email;
        process.env[`${user.env}_PASSWORD`] = password;
    }
}
