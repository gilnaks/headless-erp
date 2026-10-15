import { expect, test } from "@playwright/test";
import { createOrganization, label, signIn } from "./helpers";

test("the company form lists its addresses and contacts, and + New links them to the company", async ({ page }) => {
    test.slow();
    const stamp = Date.now().toString(36);
    const orgName = `Rail Org ${stamp}`;

    await signIn(page, "E2E_RAIL");
    const org = await createOrganization(page, orgName);

    await page.goto(`${org}/setup/company`);
    await page
        .getByRole("row", { name: new RegExp(`^${orgName}`) })
        .first()
        .click();
    await expect(page).toHaveURL(new RegExp(`${org}/setup/company/[0-9a-f-]{36}$`));
    const companyUrl = page.url();
    const companyId = companyUrl.split("/").pop() ?? "";
    const addresses = page.getByRole("region", { name: "Addresses" });
    const contacts = page.getByRole("region", { name: "Contacts" });
    await expect(addresses.getByText("No address yet.")).toBeVisible();
    await expect(contacts.getByText("No contact yet.")).toBeVisible();

    await addresses.getByRole("link", { name: "New Address" }).click();
    await expect(page).toHaveURL(new RegExp(`${org}/setup/address/new\\?`));
    await expect(page.getByRole("combobox", { name: label("Link Name") })).toHaveValue(orgName);
    await expect(async () => {
        await page.getByRole("textbox", { name: label("Address Line 1") }).fill("1 Ayala Ave");
        await expect(page.getByRole("textbox", { name: label("Address Line 1") })).toHaveValue("1 Ayala Ave", { timeout: 1_000 });
    }).toPass();
    await page.getByRole("textbox", { name: label("City/Town") }).fill("Makati");
    await page.getByRole("checkbox", { name: "Preferred Billing Address" }).check({ force: true });
    await page.getByRole("button", { name: /^Save/ }).click();
    await expect(page).toHaveURL(new RegExp(`${org}/setup/address/[0-9a-f-]{36}$`), { timeout: 15_000 });

    await page.goto(companyUrl);
    await expect(addresses.getByRole("link", { name: `${orgName}-Billing` })).toBeVisible();
    await expect(addresses.getByText("Preferred Billing")).toBeVisible();
    await expect(addresses.getByText("Makati")).toBeVisible();

    await contacts.getByRole("link", { name: "New Contact" }).click();
    await expect(page).toHaveURL(new RegExp(`${org}/setup/contact/new\\?`));
    await expect(async () => {
        await page.getByRole("textbox", { name: label("First Name") }).fill("Jose");
        await expect(page.getByRole("textbox", { name: label("First Name") })).toHaveValue("Jose", { timeout: 1_000 });
    }).toPass();
    await page.getByRole("checkbox", { name: "Is Primary Contact" }).check({ force: true });
    await page.getByRole("button", { name: /^Save/ }).click();
    await expect(page).toHaveURL(new RegExp(`${org}/setup/contact/[0-9a-f-]{36}$`), { timeout: 15_000 });
    await expect(page.getByRole("textbox", { name: label("Contact Name") })).toHaveValue(`Jose-${orgName}`);

    await page.goto(companyUrl);
    await expect(contacts.getByRole("link", { name: "Jose" })).toBeVisible();
    await expect(contacts.getByText("Primary")).toBeVisible();

    await page.goto(`/print/company/${companyId}`);
    await expect(page.getByTestId("company-address")).toContainText("1 Ayala Ave");
    await expect(page.getByTestId("company-address")).toContainText("Makati");
});
