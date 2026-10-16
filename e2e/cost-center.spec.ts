import { expect, test } from "@playwright/test";
import { createOrganization, credentials, label, signIn } from "./helpers";

test("a child cost center is saved under the company root", async ({ page }) => {
    const stamp = Date.now().toString(36);
    const orgName = `Cost Center Org ${stamp}`;
    const name = `Workshop ${stamp}`;
    const { email } = credentials("E2E_COST_CENTER");

    await signIn(page, "E2E_COST_CENTER");
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

    await page.goto(`${org}/accounts/cost-center`);
    await page
        .getByRole("radio", { name: "Tree" })
        .or(page.getByRole("button", { name: "Tree" }))
        .click();
    await expect(page).toHaveURL(/view=tree/);

    const tree = page.getByRole("treegrid", { name: "Cost Center tree" });
    const root = tree.getByRole("row", { name: new RegExp(`^${orgName}`) });
    await expect(root).toBeVisible();
    await expect(tree.getByRole("row", { name: /^Main - / })).toBeVisible();
    await root.hover();
    await tree.getByRole("link", { name: new RegExp(`^Add child to ${orgName}`) }).click();
    await expect(page).toHaveURL(/\/accounts\/cost-center\/new\?parent_id=/);

    await page.getByRole("textbox", { name: label("Cost Center Name") }).fill(name);
    await page.getByRole("button", { name: /^Save/ }).click();
    await expect(page).toHaveURL(new RegExp(`${org}/accounts/cost-center/[0-9a-f-]{36}$`), { timeout: 15_000 });
    await expect(page.getByRole("textbox", { name: label("Cost Center Name") })).toHaveValue(name);

    await page.goto(`${org}/accounts/cost-center?view=tree`);
    await expect(page.getByRole("treegrid", { name: "Cost Center tree" }).getByRole("row", { name: new RegExp(name) })).toBeVisible();
});
