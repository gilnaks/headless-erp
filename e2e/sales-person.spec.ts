import { expect, test } from "@playwright/test";
import { createOrganization, credentials, label, signIn } from "./helpers";

test("a child sales person is saved under Sales Team", async ({ page }) => {
    const stamp = Date.now().toString(36);
    const name = `Alex ${stamp}`;
    const { email } = credentials("E2E_SALES_PERSON");

    await signIn(page, "E2E_SALES_PERSON");
    const org = await createOrganization(page, `Sales Person Org ${stamp}`);

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

    await page.goto(`${org}/selling/sales-person`);
    await page
        .getByRole("radio", { name: "Tree" })
        .or(page.getByRole("button", { name: "Tree" }))
        .click();
    await expect(page).toHaveURL(/view=tree/);

    const tree = page.getByRole("treegrid", { name: "Sales Person tree" });
    await expect(tree.getByRole("row", { name: /^Sales Team/ })).toBeVisible();

    await tree.getByRole("row", { name: /^Sales Team/ }).hover();
    await tree.getByRole("link", { name: "Add child to Sales Team" }).click();
    await expect(page).toHaveURL(/\/selling\/sales-person\/new\?parent_id=/);
    await page.getByRole("textbox", { name: label("Sales Person Name") }).fill(name);
    await page.getByRole("button", { name: /^Save/ }).click();
    await expect(page).toHaveURL(new RegExp(`${org}/selling/sales-person/[0-9a-f-]{36}$`), { timeout: 15_000 });
    await expect(page.getByRole("textbox", { name: label("Sales Person Name") })).toHaveValue(name);
});
