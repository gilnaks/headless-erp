import { expect, test } from "@playwright/test";
import { createOrganization, credentials, label, pick, signIn } from "./helpers";

test("a saved tax rule is named from the series", async ({ page }) => {
    const stamp = Date.now().toString(36);
    const orgName = `Tax Rule Org ${stamp}`;
    const { email } = credentials("E2E_TAX_RULE");

    await signIn(page, "E2E_TAX_RULE");
    const org = await createOrganization(page, orgName);

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

    await page.goto(`${org}/accounts/tax-rule/new`);
    await pick(page, "Company", orgName, new RegExp(`^${orgName}`));
    await pick(page, "Sales Tax Template", "Philippines Tax", /Philippines Tax/);
    await page.getByRole("button", { name: /^Save/ }).click();
    await expect(page).toHaveURL(new RegExp(`${org}/accounts/tax-rule/[0-9a-f-]{36}$`), { timeout: 15_000 });
    await expect(page.getByRole("textbox", { name: label("Name") })).toHaveValue(/^ACC-TAX-RULE-/);
});
