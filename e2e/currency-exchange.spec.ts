import { expect, test } from "@playwright/test";
import { createOrganization, credentials, label, pick, signIn } from "./helpers";

test("a saved rate is named from its date and currencies", async ({ page }) => {
    const stamp = Date.now().toString(36);
    const { email } = credentials("E2E_CURRENCY_EXCHANGE");

    await signIn(page, "E2E_CURRENCY_EXCHANGE");
    const org = await createOrganization(page, `FX Org ${stamp}`);

    await page.goto(`${org}/setup/users`);
    await page.getByRole("row").filter({ hasText: email }).click();
    await expect(page).toHaveURL(new RegExp(`${org}/setup/users/[0-9a-f-]{36}$`));
    await page.getByRole("button", { name: /System Manager/ }).click();
    const search = page.getByPlaceholder("Search").last();
    await search.fill("");
    await search.pressSequentially("Accounts Manager");
    await page.getByRole("option", { name: "Accounts Manager", exact: true }).click();
    await page.keyboard.press("Escape");
    await page.keyboard.press("Escape");
    await page.getByRole("button", { name: /^Save/ }).click();
    await expect(page.getByText("Not Saved")).toBeHidden();

    await page.goto(`${org}/accounts/currency-exchange/new`);
    await page.getByLabel(label("Date")).fill("2026-03-01");
    await pick(page, "From Currency", "USD", /^USD/);
    await pick(page, "To Currency", "PHP", /^PHP/);
    await page.getByLabel(label("Exchange Rate")).fill("56.5");
    await page.getByRole("button", { name: /^Save/ }).click();
    await expect(page).toHaveURL(new RegExp(`${org}/accounts/currency-exchange/[0-9a-f-]{36}$`), { timeout: 15_000 });
    await expect(page.getByRole("textbox", { name: label("Name") })).toHaveValue("2026-03-01-USD-PHP-Selling-Buying");
});
