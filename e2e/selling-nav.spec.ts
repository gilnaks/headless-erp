import { expect, test } from "@playwright/test";
import { createOrganization, signIn } from "./helpers";

test("selling aliases open the canonical screens", async ({ page }) => {
    const stamp = Date.now().toString(36);

    await signIn(page, "E2E_SELLING_NAV");
    const org = await createOrganization(page, `Selling Nav Org ${stamp}`);

    await page.getByRole("link", { name: "Selling" }).click();
    const selling = page.getByRole("navigation", { name: "Selling navigation" });
    const openItems = async () => {
        const item = selling.getByRole("link", { name: "Item", exact: true });
        if (!(await item.isVisible())) await selling.getByRole("button", { name: "Items" }).click();
    };

    await selling.getByRole("link", { name: "Delivery Note" }).click();
    await expect(page).toHaveURL(new RegExp(`${org}/stock/delivery-note$`));
    await expect(page.getByRole("heading", { name: "Delivery Note" })).toBeVisible();

    await page.getByRole("link", { name: "Selling" }).click();
    await selling.getByRole("link", { name: "Sales Invoice" }).click();
    await expect(page).toHaveURL(new RegExp(`${org}/accounts/sales-invoice$`));
    await expect(page.getByRole("heading", { name: "Sales Invoice" })).toBeVisible();
    await expect(page.getByText("Not built yet (phase P5)")).toHaveCount(0);

    await page.getByRole("link", { name: "Selling" }).click();
    await openItems();
    await selling.getByRole("link", { name: "Item", exact: true }).click();
    await expect(page).toHaveURL(new RegExp(`${org}/stock/item$`));
    await expect(page.getByRole("heading", { name: "Item", exact: true })).toBeVisible();

    await page.getByRole("link", { name: "Selling" }).click();
    await openItems();
    await selling.getByRole("link", { name: "Price List" }).click();
    await expect(page).toHaveURL(new RegExp(`${org}/stock/price-list$`));
    await expect(page.getByRole("heading", { name: "Price List" })).toBeVisible();
});
