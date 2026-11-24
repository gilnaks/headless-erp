import { expect, test } from "@playwright/test";
import { createOrganization, signIn } from "./helpers";

test("selling settings keep skip delivery after save", async ({ page }) => {
    const stamp = Date.now().toString(36);

    await signIn(page, "E2E_SELLING_SETTINGS");
    const org = await createOrganization(page, `Selling Settings Org ${stamp}`);

    await page.getByRole("link", { name: "Selling" }).click();
    const nav = page.getByRole("navigation", { name: "Selling navigation" });
    await nav.getByRole("button", { name: "Setup" }).click();
    await nav.getByRole("link", { name: "Settings" }).click();
    await expect(page).toHaveURL(new RegExp(`${org}/selling/settings$`));
    await page.getByRole("tab", { name: "Transaction" }).click();

    const skip = page.getByRole("checkbox", { name: "Skip Delivery Note Creation for Service Items" });
    await expect(skip).not.toBeChecked();
    await skip.click({ force: true });
    await expect(skip).toBeChecked();
    await page.getByRole("button", { name: /^Save/ }).click();
    await expect(page.getByText("Saved.")).toBeVisible();

    await page.reload();
    await page.getByRole("tab", { name: "Transaction" }).click();
    await expect(page.getByRole("checkbox", { name: "Skip Delivery Note Creation for Service Items" })).toBeChecked();
});
