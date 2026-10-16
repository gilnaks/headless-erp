import { expect, test } from "@playwright/test";
import { createOrganization, credentials, label, signIn } from "./helpers";

test("a child supplier group is saved under All Supplier Groups", async ({ page }) => {
    const stamp = Date.now().toString(36);
    const name = `Packaging ${stamp}`;
    const { email } = credentials("E2E_SUPPLIER_GROUP");

    await signIn(page, "E2E_SUPPLIER_GROUP");
    const org = await createOrganization(page, `Supplier Group Org ${stamp}`);

    await page.goto(`${org}/setup/users`);
    await page.getByRole("row").filter({ hasText: email }).click();
    await expect(page).toHaveURL(new RegExp(`${org}/setup/users/[0-9a-f-]{36}$`));
    await page.getByRole("button", { name: /System Manager/ }).click();
    const search = page.getByPlaceholder("Search").last();
    await search.fill("");
    await search.pressSequentially("Purchase Manager");
    await page.getByRole("option", { name: "Purchase Manager", exact: true }).click();
    await page.keyboard.press("Escape");
    await page.keyboard.press("Escape");
    await page.getByRole("button", { name: /^Save/ }).click();
    await expect(page.getByText("Not Saved")).toBeHidden();

    await page.goto(`${org}/buying/supplier-group`);
    await page
        .getByRole("radio", { name: "Tree" })
        .or(page.getByRole("button", { name: "Tree" }))
        .click();
    await expect(page).toHaveURL(/view=tree/);

    const tree = page.getByRole("treegrid", { name: "Supplier Group tree" });
    await expect(tree.getByRole("row", { name: /^All Supplier Groups/ })).toBeVisible();
    await expect(tree.getByRole("row", { name: /^Services/ })).toBeVisible();

    await tree.getByRole("row", { name: /^All Supplier Groups/ }).hover();
    await tree.getByRole("link", { name: "Add child to All Supplier Groups" }).click();
    await expect(page).toHaveURL(/\/buying\/supplier-group\/new\?parent_id=/);
    await page.getByRole("textbox", { name: label("Supplier Group Name") }).fill(name);
    await page.getByRole("button", { name: /^Save/ }).click();
    await expect(page).toHaveURL(new RegExp(`${org}/buying/supplier-group/[0-9a-f-]{36}$`), { timeout: 15_000 });
    await expect(page.getByRole("textbox", { name: label("Supplier Group Name") })).toHaveValue(name);
});
