import { expect, type Page, test } from "@playwright/test";
import { createOrganization, label, pick, signIn } from "./helpers";

async function runAction(page: Page, name: string) {
    await page.getByRole("button", { name: "Actions", exact: true }).click();
    await page.getByRole("menuitem", { name }).click();
}

/** Visible cells only: the previous route (e.g. `/new`) stays mounted but hidden after navigating. */
const holidayRows = (page: Page) => page.locator('[data-grid="holidays"][data-col="holiday_date"] input:visible');

test("weekly offs and local holidays fill the list and the total is saved", async ({ page }) => {
    test.slow();
    const stamp = Date.now().toString(36);
    const name = `Holidays ${stamp}`;

    await signIn(page, "E2E_HOLIDAYS");
    const org = await createOrganization(page, `Holidays Org ${stamp}`);

    await page.goto(`${org}/setup/holiday-list/new`);
    await page.getByRole("textbox", { name: label("Holiday List Name") }).fill(name);
    await page.getByLabel(label("From Date")).fill("2026-01-01");
    await page.getByLabel(label("To Date")).fill("2026-03-31");

    await runAction(page, "Add Weekly Holidays");
    await expect(page.getByText("Please select weekly off day.")).toBeVisible();

    await page.getByRole("button", { name: /Weekly Off/ }).click();
    await page.getByRole("option", { name: "Sunday" }).click();
    await runAction(page, "Add Weekly Holidays");
    await expect(holidayRows(page)).toHaveCount(13);

    await pick(page, "Country", "Philippines", /^Philippines/);
    await runAction(page, "Add Local Holidays");
    await expect.poll(() => holidayRows(page).count()).toBeGreaterThan(13);
    const descriptions = await page
        .locator('[data-grid="holidays"][data-col="description"] input:visible')
        .evaluateAll((inputs) => inputs.map((i) => (i as HTMLInputElement).value));
    expect(descriptions).toContain("New Year's Day");
    const rows = descriptions.length;

    await page.getByRole("button", { name: /^Save/ }).click();
    await expect(page).toHaveURL(new RegExp(`${org}/setup/holiday-list/[0-9a-f-]{36}$`));
    await expect(page.getByRole("textbox", { name: label("Total Holidays") })).toHaveValue(String(rows));
    await expect(holidayRows(page).first()).toHaveValue("2026-01-01");
    await runAction(page, "Clear Table");
    await expect(holidayRows(page)).toHaveCount(0);
    await expect(page.getByRole("textbox", { name: label("Total Holidays") })).toHaveValue("0");
});
