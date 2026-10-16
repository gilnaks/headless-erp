import { expect, test } from "@playwright/test";
import { createOrganization, credentials, label, signIn } from "./helpers";

test("a child customer group is saved under All Customer Groups", async ({ page }) => {
    const stamp = Date.now().toString(36);
    const name = `Wholesale ${stamp}`;
    const { email } = credentials("E2E_CUSTOMER_GROUP");

    await signIn(page, "E2E_CUSTOMER_GROUP");
    const org = await createOrganization(page, `Customer Group Org ${stamp}`);

    await page.goto(`${org}/setup/users`);
    await page.getByRole("row").filter({ hasText: email }).click();
    await expect(page).toHaveURL(new RegExp(`${org}/setup/users/[0-9a-f-]{36}$`));
    await page.getByRole("button", { name: /System Manager/ }).click();
    const search = page.getByPlaceholder("Search").last();
    await search.fill("");
    await search.pressSequentially("Sales Manager");
    await page.getByRole("option", { name: "Sales Manager", exact: true }).click();
    await page.keyboard.press("Escape");
    await page.keyboard.press("Escape");
    await page.getByRole("button", { name: /^Save/ }).click();
    await expect(page.getByText("Not Saved")).toBeHidden();

    await page.goto(`${org}/selling/customer-group`);
    await page
        .getByRole("radio", { name: "Tree" })
        .or(page.getByRole("button", { name: "Tree" }))
        .click();
    await expect(page).toHaveURL(/view=tree/);

    const tree = page.getByRole("treegrid", { name: "Customer Group tree" });
    await expect(tree.getByRole("row", { name: /^All Customer Groups/ })).toBeVisible();
    await expect(tree.getByRole("row", { name: /^Commercial/ })).toBeVisible();

    await tree.getByRole("row", { name: /^All Customer Groups/ }).hover();
    await tree.getByRole("link", { name: "Add child to All Customer Groups" }).click();
    await expect(page).toHaveURL(/\/selling\/customer-group\/new\?parent_id=/);
    await page.getByRole("textbox", { name: label("Customer Group Name") }).fill(name);
    await page.getByRole("button", { name: /^Save/ }).click();
    await expect(page).toHaveURL(new RegExp(`${org}/selling/customer-group/[0-9a-f-]{36}$`), { timeout: 15_000 });
    await expect(page.getByRole("textbox", { name: label("Customer Group Name") })).toHaveValue(name);
});
