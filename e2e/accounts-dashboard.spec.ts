import { expect, test } from "@playwright/test";
import { createOrganization, signIn } from "./helpers";

test("the accounts dashboard shows payments, profit and loss, and the waiting widgets", async ({ page }) => {
    const stamp = Date.now().toString(36);
    const orgName = `Dash Org ${stamp}`;

    await signIn(page, "E2E_DASH");
    const org = await createOrganization(page, orgName);

    await page.getByRole("link", { name: "Accounting" }).click();
    await page.getByRole("navigation", { name: "Accounting navigation" }).getByRole("link", { name: "Dashboard" }).click();
    await expect(page).toHaveURL(new RegExp(`${org}/accounts/dashboard$`));
    await expect(page.getByRole("region", { name: "Total Incoming Payment" })).toBeVisible();
    await expect(page.getByRole("heading", { name: "Profit and Loss" })).toBeVisible();
    await expect(page.getByRole("region", { name: "Accounts Receivable Ageing" }).getByText("Not available yet")).toBeVisible();
});
