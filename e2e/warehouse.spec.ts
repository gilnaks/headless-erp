import { expect, test } from "@playwright/test";
import { createOrganization, credentials, label, signIn } from "./helpers";

test("a child warehouse is saved under All Warehouses", async ({ page }) => {
    const stamp = Date.now().toString(36);
    const name = `Cold Room ${stamp}`;
    const { email } = credentials("E2E_WAREHOUSE");

    await signIn(page, "E2E_WAREHOUSE");
    const org = await createOrganization(page, `Warehouse Org ${stamp}`);

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

    await page.goto(`${org}/stock/warehouse`);
    await page
        .getByRole("radio", { name: "Tree" })
        .or(page.getByRole("button", { name: "Tree" }))
        .click();
    await expect(page).toHaveURL(/view=tree/);

    const tree = page.getByRole("treegrid", { name: "Warehouse tree" });
    const root = tree.getByRole("row", { name: /^All Warehouses - / });
    await expect(root).toBeVisible();
    await expect(tree.getByRole("row", { name: /^Stores - / })).toBeVisible();
    await root.hover();
    await tree.getByRole("link", { name: /^Add child to All Warehouses - / }).click();
    await expect(page).toHaveURL(/\/stock\/warehouse\/new\?parent_id=/);

    await page.getByRole("textbox", { name: label("Warehouse Name") }).fill(name);
    await page.getByRole("button", { name: /^Save/ }).click();
    await expect(page).toHaveURL(new RegExp(`${org}/stock/warehouse/[0-9a-f-]{36}$`), { timeout: 15_000 });
    await expect(page.getByRole("textbox", { name: label("Warehouse Name") })).toHaveValue(name);

    await page.goto(`${org}/stock/warehouse?view=tree`);
    await expect(page.getByRole("treegrid", { name: "Warehouse tree" }).getByRole("row", { name: new RegExp(name) })).toBeVisible();
});
