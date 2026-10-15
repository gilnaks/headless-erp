import { expect, test } from "@playwright/test";
import { createOrganization, label, pick, signIn } from "./helpers";

test("a contact takes its email and phone from the primary rows and becomes the company's sales contact", async ({ page }) => {
    test.slow();
    const stamp = Date.now().toString(36);
    const orgName = `Contact Org ${stamp}`;
    const contactName = `Maria Santos-${orgName}`;

    await signIn(page, "E2E_CONTACT");
    const org = await createOrganization(page, orgName);

    await page.goto(`${org}/setup/contact/new`);
    await expect(async () => {
        await page.getByRole("textbox", { name: label("First Name") }).fill("Maria");
        await expect(page.getByRole("textbox", { name: label("First Name") })).toHaveValue("Maria", { timeout: 1_000 });
    }).toPass();
    await page.getByRole("textbox", { name: label("Last Name") }).fill("Santos");

    await page.getByRole("button", { name: "Add row" }).nth(0).click();
    await page.locator('[data-grid="email_ids"][data-col="email_id"] input:visible').fill("maria@example.test");
    await page.locator('[data-grid="email_ids"][data-col="is_primary"] input:visible').check({ force: true });

    await page.getByRole("button", { name: "Add row" }).nth(1).click();
    await page.locator('[data-grid="phone_nos"][data-col="phone"] input:visible').fill("+63 2 8123 4567");
    await page.locator('[data-grid="phone_nos"][data-col="is_primary_mobile_no"] input:visible').check({ force: true });

    await page.getByRole("button", { name: "Add row" }).nth(2).click();
    await page.getByRole("button", { name: /Link Document Type/ }).click();
    await page.getByRole("option", { name: "Company" }).click();
    await pick(page, "Link Name", orgName.slice(0, 12), new RegExp(`^${orgName}`));

    await page.getByRole("button", { name: /^Save/ }).click();
    await expect(page).toHaveURL(new RegExp(`${org}/setup/contact/[0-9a-f-]{36}$`), { timeout: 15_000 });
    await expect(page.getByRole("textbox", { name: label("Contact Name") })).toHaveValue(contactName);
    await expect(page.getByRole("textbox", { name: label("Email Address") })).toHaveValue("maria@example.test");
    await expect(page.getByRole("textbox", { name: label("Mobile No") })).toHaveValue("+63 2 8123 4567");

    await page.goto(`${org}/setup/company`);
    await page
        .getByRole("row", { name: new RegExp(`^${orgName}`) })
        .first()
        .click();
    await expect(page).toHaveURL(new RegExp(`${org}/setup/company/[0-9a-f-]{36}$`));
    await page.getByRole("tab", { name: "Buying and Selling" }).click();
    await pick(page, "Default Sales Contact", "Maria", new RegExp(`^${contactName}`));
    await page.getByRole("button", { name: /^Save/ }).click();
    await expect(page.getByText("Not Saved")).toBeHidden();
    await page.reload();
    // The tab only switches once the form has hydrated.
    await expect(async () => {
        await page.getByRole("tab", { name: "Buying and Selling" }).click();
        await expect(page.getByRole("combobox", { name: label("Default Sales Contact") })).toHaveValue(contactName, { timeout: 1_000 });
    }).toPass();
});
