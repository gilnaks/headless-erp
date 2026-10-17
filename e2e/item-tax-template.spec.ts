import { expect, test } from "@playwright/test";
import { companyAbbr } from "../src/lib/schemas/organization";
import { createOrganization, label, pick, signIn } from "./helpers";

test("a saved item tax template is named from the title and the company", async ({ page }) => {
    const stamp = Date.now().toString(36);
    const orgName = `Item Tax Org ${stamp}`;
    const abbr = companyAbbr(orgName);

    await signIn(page, "E2E_ITEM_TAX");
    const org = await createOrganization(page, orgName);

    await page.goto(`${org}/accounts/item-tax-template/new`);
    await page.getByRole("textbox", { name: label("Title") }).fill("VAT");
    await pick(page, "Company", orgName, new RegExp(orgName));
    await page.getByRole("button", { name: "Add row" }).click();
    const tax = page.locator('[data-grid="taxes"][data-row="0"][data-col="tax_type_id"] input:visible').first();
    await tax.click();
    await tax.pressSequentially("2201");
    await page.getByRole("option", { name: new RegExp(`2201 - VAT Output Tax - ${abbr}$`) }).click();
    await page.locator('[data-grid="taxes"][data-row="0"][data-col="tax_rate"] input:visible').fill("12");
    await page.getByRole("button", { name: /^Save/ }).click();
    await expect(page).toHaveURL(new RegExp(`${org}/accounts/item-tax-template/[0-9a-f-]{36}$`), { timeout: 15_000 });
    await expect(page.getByRole("textbox", { name: label("Name") })).toHaveValue(new RegExp(`^VAT - ${abbr}$`));
});
