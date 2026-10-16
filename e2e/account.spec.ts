import { expect, test } from "@playwright/test";
import { createOrganization, credentials, label, pick, signIn } from "./helpers";

test("a child account is saved under the chart root", async ({ page }) => {
    const stamp = Date.now().toString(36);
    const name = `Petty Cash ${stamp}`;
    const { email } = credentials("E2E_ACCOUNT");

    await signIn(page, "E2E_ACCOUNT");
    const org = await createOrganization(page, `Account Org ${stamp}`);

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

    await page.goto(`${org}/accounts/account`);
    await page
        .getByRole("radio", { name: "Tree" })
        .or(page.getByRole("button", { name: "Tree" }))
        .click();
    await expect(page).toHaveURL(/view=tree/);

    const tree = page.getByRole("treegrid", { name: "Account tree" });
    const root = tree.getByRole("row", { name: /^1000 - Asset/ });
    await expect(root).toBeVisible();
    await root.hover();
    await tree.getByRole("link", { name: /^Add child to 1000 - Asset/ }).click();
    await expect(page).toHaveURL(/\/accounts\/account\/new\?parent_id=/);

    await page.getByRole("textbox", { name: label("Account Name") }).fill(name);
    await page.getByRole("button", { name: /Select Root Type/ }).click();
    await page.getByRole("option", { name: "Asset", exact: true }).click();
    await pick(page, "Currency", "PHP", /^PHP/);
    await page.getByRole("button", { name: /^Save/ }).click();
    await expect(page).toHaveURL(new RegExp(`${org}/accounts/account/[0-9a-f-]{36}$`), { timeout: 15_000 });
    await expect(page.getByRole("textbox", { name: label("Account Name") })).toHaveValue(name);

    await page.goto(`${org}/accounts/account?view=tree`);
    await expect(page.getByRole("treegrid", { name: "Account tree" }).getByRole("row", { name: new RegExp(name) })).toBeVisible();
});
