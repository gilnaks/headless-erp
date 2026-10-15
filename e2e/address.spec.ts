import { expect, test } from "@playwright/test";
import { createOrganization, label, pick, signIn } from "./helpers";

test("an address linked to the company is named after it and flagged as a company address", async ({ page }) => {
    test.slow();
    const stamp = Date.now().toString(36);
    const orgName = `Address Org ${stamp}`;

    await signIn(page, "E2E_ADDRESS");
    const org = await createOrganization(page, orgName);

    await page.goto(`${org}/setup/address/new`);
    await expect(async () => {
        await page.getByRole("textbox", { name: label("Address Line 1") }).fill("1 Ayala Ave");
        await expect(page.getByRole("textbox", { name: label("Address Line 1") })).toHaveValue("1 Ayala Ave", { timeout: 1_000 });
    }).toPass();
    await page.getByRole("textbox", { name: label("City/Town") }).fill("Makati");
    await page.getByRole("checkbox", { name: "Preferred Billing Address" }).check({ force: true });

    await page.getByRole("button", { name: "Add row" }).click();
    await page.getByRole("button", { name: /Link Document Type/ }).click();
    await page.getByRole("option", { name: "Company" }).click();
    await pick(page, "Link Name", orgName.slice(0, 12), new RegExp(`^${orgName}`));

    await page.getByRole("button", { name: /^Save/ }).click();
    await expect(page).toHaveURL(new RegExp(`${org}/setup/address/[0-9a-f-]{36}$`), { timeout: 15_000 });
    await expect(page.getByRole("textbox", { name: label("Address Name") })).toHaveValue(`${orgName}-Billing`);
    await expect(page.getByRole("checkbox", { name: /Is Your Company Address/ })).toBeChecked();
    await expect(page.getByRole("combobox", { name: label("Country") })).toHaveValue("Philippines");

    await page.goto(`${org}/setup/address`);
    await expect(page.getByRole("row", { name: new RegExp(`^${orgName}-Billing`) })).toBeVisible();
});
