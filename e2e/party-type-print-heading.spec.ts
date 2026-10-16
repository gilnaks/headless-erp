import { expect, test } from "@playwright/test";
import { createOrganization, label, signIn } from "./helpers";

test("a new organization has the fixtures and a saved heading keeps its name", async ({ page }) => {
    const stamp = Date.now().toString(36);

    await signIn(page, "E2E_PARTY_TYPE");
    const org = await createOrganization(page, `Party Org ${stamp}`);

    await page.goto(`${org}/accounts/party-type`);
    await expect(page.getByRole("row", { name: /Customer/ })).toContainText("Receivable");
    await expect(page.getByRole("row", { name: /Supplier/ })).toContainText("Payable");
    await expect(page.getByRole("row", { name: /Employee/ })).toHaveCount(0);

    await page.goto(`${org}/setup/print-heading`);
    await expect(page.getByRole("row", { name: /Credit Note/ })).toBeVisible();
    await expect(page.getByRole("row", { name: /Debit Note/ })).toBeVisible();

    await page.getByRole("link", { name: "New Print Heading" }).first().click();
    await page.getByRole("textbox", { name: label("Print Heading") }).fill("Provisional");
    await page.getByRole("button", { name: /^Save/ }).click();
    await expect(page).toHaveURL(new RegExp(`${org}/setup/print-heading/[0-9a-f-]{36}$`), { timeout: 15_000 });
    await expect(page.getByRole("textbox", { name: label("Name") })).toHaveValue("Provisional");
});
