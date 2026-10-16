import { expect, test } from "@playwright/test";
import { createOrganization, label, signIn } from "./helpers";

test("a payment term and a 100% template can be saved", async ({ page }) => {
    const stamp = Date.now().toString(36);
    const term = `Net ${stamp}`;
    const template = `Standard ${stamp}`;

    await signIn(page, "E2E_PAYMENT_TERMS");
    const org = await createOrganization(page, `Terms Org ${stamp}`);

    await page.goto(`${org}/accounts/payment-term/new`);
    await page.getByRole("textbox", { name: label("Payment Term Name") }).fill(term);
    await page.getByRole("button", { name: /^Save/ }).click();
    await expect(page).toHaveURL(new RegExp(`${org}/accounts/payment-term/[0-9a-f-]{36}$`), { timeout: 15_000 });
    await expect(page.getByRole("textbox", { name: label("Payment Term Name") })).toHaveValue(term);

    await page.goto(`${org}/accounts/payment-terms-template/new`);
    await page.getByRole("textbox", { name: label("Template Name") }).fill(template);
    await page.getByRole("button", { name: "Add row" }).click();
    await page.locator('[data-grid="terms"][data-col="invoice_portion"] input:visible').first().fill("100");
    await page.getByRole("button", { name: /^Save/ }).click();
    await expect(page).toHaveURL(new RegExp(`${org}/accounts/payment-terms-template/[0-9a-f-]{36}$`), { timeout: 15_000 });
    await expect(page.getByRole("textbox", { name: label("Template Name") })).toHaveValue(template);
});
