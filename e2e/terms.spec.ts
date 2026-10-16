import { expect, test } from "@playwright/test";
import { createOrganization, label, signIn } from "./helpers";

test("a new terms template is saved and listed", async ({ page }) => {
    const stamp = Date.now().toString(36);
    const name = `Standard ${stamp}`;

    await signIn(page, "E2E_TERMS");
    const org = await createOrganization(page, `Terms Org ${stamp}`);

    await page.goto(`${org}/setup/terms-and-conditions/new`);
    await page.getByRole("textbox", { name: label("Title") }).fill(name);
    await page.getByRole("button", { name: /^Save/ }).click();
    await expect(page).toHaveURL(new RegExp(`${org}/setup/terms-and-conditions/[0-9a-f-]{36}$`), { timeout: 15_000 });

    await page.goto(`${org}/setup/terms-and-conditions`);
    await page.getByRole("textbox", { name: "Search Terms and Conditions" }).fill(name);
    await expect(page.getByRole("row", { name: new RegExp(name) })).toBeVisible();
});
