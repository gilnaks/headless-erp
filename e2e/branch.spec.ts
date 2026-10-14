import { expect, test } from "@playwright/test";
import { createOrganization, label, signIn } from "./helpers";

test("create a branch and find it in the list", async ({ page }) => {
    const stamp = Date.now().toString(36);
    const name = `Branch ${stamp}`;

    await signIn(page, "E2E_BRANCH");
    const org = await createOrganization(page, `Branch Org ${stamp}`);

    await page.goto(`${org}/setup/branch`);
    await page.getByRole("link", { name: "New Branch" }).first().click();
    await page.getByRole("textbox", { name: label("Branch") }).fill(name);
    await page.getByRole("button", { name: /^Save/ }).click();
    await expect(page).toHaveURL(new RegExp(`${org}/setup/branch/[0-9a-f-]{36}$`));

    await page.goto(`${org}/setup/branch/new`);
    await page.getByRole("textbox", { name: label("Branch") }).fill(name.toUpperCase());
    await page.getByRole("button", { name: /^Save/ }).click();
    await expect(page.getByText(/already exists/i).first()).toBeVisible();

    await page.goto(`${org}/setup/branch`);
    await expect(page.getByRole("row").filter({ hasText: name })).toBeVisible();
});
