import { expect, test } from "@playwright/test";
import { createOrganization, credentials, label, signIn } from "./helpers";

test("a child territory is saved under All Territories", async ({ page }) => {
    const stamp = Date.now().toString(36);
    const name = `Luzon ${stamp}`;
    const { email } = credentials("E2E_TERRITORY");

    await signIn(page, "E2E_TERRITORY");
    const org = await createOrganization(page, `Territory Org ${stamp}`);

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

    await page.goto(`${org}/selling/territory`);
    await page
        .getByRole("radio", { name: "Tree" })
        .or(page.getByRole("button", { name: "Tree" }))
        .click();
    await expect(page).toHaveURL(/view=tree/);

    const tree = page.getByRole("treegrid", { name: "Territory tree" });
    await expect(tree.getByRole("row", { name: /^All Territories/ })).toBeVisible();
    await expect(tree.getByRole("row", { name: /^Philippines/ })).toBeVisible();
    await expect(tree.getByRole("row", { name: /^Rest Of The World/ })).toBeVisible();

    await tree.getByRole("row", { name: /^All Territories/ }).hover();
    await tree.getByRole("link", { name: "Add child to All Territories" }).click();
    await expect(page).toHaveURL(/\/selling\/territory\/new\?parent_id=/);
    await page.getByRole("textbox", { name: label("Territory Name") }).fill(name);
    await page.getByRole("button", { name: /^Save/ }).click();
    await expect(page).toHaveURL(new RegExp(`${org}/selling/territory/[0-9a-f-]{36}$`), { timeout: 15_000 });
    await expect(page.getByRole("textbox", { name: label("Territory Name") })).toHaveValue(name);
});
