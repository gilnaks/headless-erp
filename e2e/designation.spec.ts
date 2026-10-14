import { expect, test } from "@playwright/test";
import { createOrganization, label, signIn } from "./helpers";

test("presets are seeded and a new designation shows in the list", async ({ page }) => {
    const stamp = Date.now().toString(36);
    const name = `Designation ${stamp}`;

    await signIn(page, "E2E_DESIGNATION");
    const org = await createOrganization(page, `Designation Org ${stamp}`);

    await page.goto(`${org}/setup/designation`);
    await expect(page.getByRole("row", { name: /^Accountant/ })).toBeVisible();

    await page.getByRole("link", { name: "New Designation" }).first().click();
    await page.getByRole("textbox", { name: label("Designation") }).fill(name);
    await page.getByRole("textbox", { name: label("Description") }).fill("Created by e2e");
    await page.getByRole("button", { name: /^Save/ }).click();
    await expect(page).toHaveURL(new RegExp(`${org}/setup/designation/[0-9a-f-]{36}$`));

    await page.goto(`${org}/setup/designation?q=${stamp}`);
    await expect(page.getByRole("row").filter({ hasText: name })).toContainText("Created by e2e");
});
