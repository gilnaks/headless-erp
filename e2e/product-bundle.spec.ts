import { expect, test } from "@playwright/test";
import { createOrganization, credentials, label, pick, signIn } from "./helpers";

test("a saved product bundle is named from its parent item and can be submitted", async ({ page }) => {
    const stamp = Date.now().toString(36);
    const part = `Part ${stamp}`;
    const kit = `Kit ${stamp}`;
    const { email } = credentials("E2E_PRODUCT_BUNDLE");

    await signIn(page, "E2E_PRODUCT_BUNDLE");
    const org = await createOrganization(page, `Bundle Org ${stamp}`);

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

    await page.goto(`${org}/stock/item/new`);
    await page.getByRole("textbox", { name: label("Item Code") }).fill(part);
    await pick(page, "Item Group", "Products", /^Products/);
    await pick(page, "Default Unit of Measure", "Nos", /^Nos/);
    await page.getByRole("button", { name: /^Save/ }).click();
    await expect(page).toHaveURL(new RegExp(`${org}/stock/item/[0-9a-f-]{36}$`), { timeout: 15_000 });

    await page.goto(`${org}/stock/item/new`);
    await page.getByRole("textbox", { name: label("Item Code") }).fill(kit);
    await pick(page, "Item Group", "Products", /^Products/);
    await pick(page, "Default Unit of Measure", "Nos", /^Nos/);
    await page.getByRole("checkbox", { name: "Maintain Stock" }).uncheck({ force: true });
    await page.getByRole("button", { name: /^Save/ }).click();
    await expect(page).toHaveURL(new RegExp(`${org}/stock/item/[0-9a-f-]{36}$`), { timeout: 15_000 });

    await page.goto(`${org}/setup/users`);
    await page.getByRole("row").filter({ hasText: email }).click();
    await page.getByRole("button", { name: /System Manager/ }).click();
    await search.fill("");
    await search.pressSequentially("Stock Manager");
    await page.getByRole("option", { name: "Stock Manager", exact: true }).click();
    await page.keyboard.press("Escape");
    await page.keyboard.press("Escape");
    await page.getByRole("button", { name: /^Save/ }).click();
    await expect(page.getByText("Not Saved")).toBeHidden();

    await page.goto(`${org}/selling/product-bundle/new`);
    await pick(page, "Parent Item", kit, new RegExp(`^${kit}`));
    await page.getByRole("button", { name: "Add row" }).click();
    await pick(page, "Item", part, new RegExp(`^${part}`));
    await page.getByRole("textbox", { name: label("Qty") }).fill("1");
    await page.getByRole("button", { name: /^Save/ }).click();
    await expect(page).toHaveURL(new RegExp(`${org}/selling/product-bundle/[0-9a-f-]{36}$`), { timeout: 15_000 });
    await expect(page.getByRole("textbox", { name: label("Name") })).toHaveValue(new RegExp(`^PB-${kit}-001$`));

    await page.getByRole("button", { name: "Submit" }).click();
    await expect(page.getByText("Submitted", { exact: true })).toBeVisible();
});
