import { expect, test } from "@playwright/test";
import { createOrganization, credentials, label, signIn } from "./helpers";

test("a child item group is saved under All Item Groups", async ({ page }) => {
    const stamp = Date.now().toString(36);
    const name = `Spare Parts ${stamp}`;
    const { email } = credentials("E2E_ITEM_GROUP");

    await signIn(page, "E2E_ITEM_GROUP");
    const org = await createOrganization(page, `Item Group Org ${stamp}`);

    await page.goto(`${org}/setup/users`);
    await page.getByRole("row").filter({ hasText: email }).click();
    await expect(page).toHaveURL(new RegExp(`${org}/setup/users/[0-9a-f-]{36}$`));
    await page.getByRole("button", { name: /System Manager/ }).click();
    const search = page.getByPlaceholder("Search").last();
    await search.fill("");
    await search.pressSequentially("Item Manager");
    await page.getByRole("option", { name: "Item Manager", exact: true }).click();
    await page.keyboard.press("Escape");
    await page.keyboard.press("Escape");
    await page.getByRole("button", { name: /^Save/ }).click();
    await expect(page.getByText("Not Saved")).toBeHidden();

    await page.goto(`${org}/stock/item-group`);
    await page
        .getByRole("radio", { name: "Tree" })
        .or(page.getByRole("button", { name: "Tree" }))
        .click();
    await expect(page).toHaveURL(/view=tree/);

    const tree = page.getByRole("treegrid", { name: "Item Group tree" });
    await expect(tree.getByRole("row", { name: /^All Item Groups/ })).toBeVisible();
    await expect(tree.getByRole("row", { name: /^Products/ })).toBeVisible();

    await tree.getByRole("row", { name: /^All Item Groups/ }).hover();
    await tree.getByRole("link", { name: "Add child to All Item Groups" }).click();
    await expect(page).toHaveURL(/\/stock\/item-group\/new\?parent_id=/);
    await page.getByRole("textbox", { name: label("Item Group Name") }).fill(name);
    await page.getByRole("button", { name: /^Save/ }).click();
    await expect(page).toHaveURL(new RegExp(`${org}/stock/item-group/[0-9a-f-]{36}$`), { timeout: 15_000 });
    await expect(page.getByRole("textbox", { name: label("Item Group Name") })).toHaveValue(name);
});
