import { expect, test } from "@playwright/test";
import { createCompany, createOrganization, label, signIn } from "./helpers";

test("the start date fills the end date and name, and overlapping years need a company", async ({ page }) => {
    test.slow();
    const stamp = Date.now().toString(36);
    const yearName = page.getByRole("textbox", { name: label("Year Name") });
    const saved = (org: string) => expect(page).toHaveURL(new RegExp(`${org}/accounts/fiscal-year/[0-9a-f-]{36}$`), { timeout: 15_000 });
    // Retried: a value typed before the form hydrates is lost.
    const setStart = (start: string, end: string) =>
        expect(async () => {
            await page.getByLabel(label("Year Start Date")).fill(start);
            await expect(page.getByLabel(label("Year End Date"))).toHaveValue(end, { timeout: 1_000 });
        }).toPass();

    await signIn(page, "E2E_FISCAL");
    const org = await createOrganization(page, `Fiscal Org ${stamp}`);

    await page.goto(`${org}/accounts/fiscal-year/new`);
    await setStart("2026-04-01", "2027-03-31");
    await expect(yearName).toHaveValue("2026-2027");
    await page.getByRole("button", { name: /^Save/ }).click();
    await saved(org);

    await page.goto(`${org}/accounts/fiscal-year/new`);
    await setStart("2026-07-01", "2027-06-30");
    await yearName.fill("Mid 2026");
    await page.getByRole("button", { name: /^Save/ }).click();
    await expect(page.getByText(/overlapping with 2026-2027\. To avoid please set company/).first()).toBeVisible();

    const company = `Fiscal Co ${stamp}`;
    await createCompany(page, org, company, `F${stamp.slice(-3).toUpperCase()}`);
    await page.goto(`${org}/accounts/fiscal-year/new`);
    await setStart("2026-07-01", "2027-06-30");
    await yearName.fill("Mid 2026");
    await page.getByRole("button", { name: "Add row" }).click();
    await page.locator('[data-grid="companies"][data-col="company_id"] input:visible').first().pressSequentially("Fiscal Co");
    await page
        .getByRole("option", { name: new RegExp(company) })
        .first()
        .click();
    await page.getByRole("button", { name: /^Save/ }).click();
    await saved(org);

    await page.goto(`${org}/accounts/fiscal-year`);
    await expect(page.getByRole("row", { name: /^2026-2027/ })).toBeVisible();
    await expect(page.getByRole("row", { name: /^Mid 2026/ })).toBeVisible();
});
