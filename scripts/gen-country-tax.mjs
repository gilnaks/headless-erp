import { readFileSync, statSync, writeFileSync } from "node:fs";

const data = JSON.parse(readFileSync("C:/Users/John/Desktop/erpnext/erpnext/setup/setup_wizard/data/country_wise_tax.json", "utf8"));
const out = [
    "-- 0232 accounts: load country_wise_tax.json and seed templates for existing companies (00-setup B7).",
    "-- Source: erpnext/setup/setup_wizard/data/country_wise_tax.json",
];
for (const [country, body] of Object.entries(data)) {
    const c = country.replaceAll("'", "''");
    out.push(
        `insert into public.country_wise_tax (country, data) select country_name, $json$${JSON.stringify(body)}$json$::jsonb from public.country where country_name = '${c}' on conflict (country) do update set data = excluded.data;`,
    );
}
out.push("select app.create_default_tax_templates(c.id) from public.companies c;");
const path = "supabase/migrations/0232_accounts_country_tax_data.sql";
writeFileSync(path, `${out.join("\n")}\n`);
console.log("countries", Object.keys(data).length, "bytes", statSync(path).size);
