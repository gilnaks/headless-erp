import { expect, test } from "@playwright/test";
import { createOrganization, label, pick, signIn } from "./helpers";

test("sign in, create an organization and a company, see it in the list", async ({ page }) => {
    const stamp = Date.now().toString(36);
    const companyName = `Smoke Company ${stamp}`;

    await signIn(page, "E2E");
    const org = await createOrganization(page, `Smoke Org ${stamp}`);

    await page.goto(`${org}/setup/company`);
    await page.getByRole("link", { name: "New Company" }).first().click();
    await expect(page.getByRole("heading", { name: "New Company" })).toBeVisible();

    await page.getByRole("textbox", { name: label("Company") }).fill(companyName);
    await page.getByRole("textbox", { name: label("Abbr") }).fill(`S${stamp.slice(-3).toUpperCase()}`);
    await pick(page, "Default Currency", "PHP", /^PHP/);
    await pick(page, "Country", "Philippines", /^Philippines/);
    // Chart templates follow the country: its chart plus the standard ones.
    const chart = page.getByRole("combobox", { name: label("Chart Of Accounts Template") });
    await chart.click();
    await chart.fill("");
    await expect(page.getByRole("option", { name: "Philippines" })).toBeVisible();
    await expect(page.getByRole("option", { name: /^SKR04/ })).toHaveCount(0);
    await page.getByRole("option", { name: "Philippines" }).click();
    await page.getByRole("button", { name: /^Save/ }).click();

    await expect(page).toHaveURL(new RegExp(`${org}/setup/company/[0-9a-f-]{36}$`), { timeout: 15_000 });
    await expect(chart).toHaveValue("Philippines");

    await page.goto(`${org}/setup/company`);
    await expect(page.getByRole("row", { name: new RegExp(companyName) })).toBeVisible();

    const palette = page.getByRole("dialog", { name: "Command palette" });
    const search = palette.getByPlaceholder("Search pages, actions and records…");

    // The shortcut is bound after hydration; retry until the dialog shows.
    await expect(async () => {
        if (!(await palette.isVisible())) await page.keyboard.press("ControlOrMeta+k");
        await expect(palette).toBeVisible({ timeout: 1000 });
    }).toPass();
    await search.pressSequentially(`Smoke Company ${stamp}`);
    await expect(palette.getByRole("menuitem", { name: new RegExp(companyName) })).toBeVisible();

    await search.fill("");
    await search.pressSequentially("Global Defaults");
    await palette.getByRole("menuitem", { name: /^Global Defaults/ }).click();
    await expect(page).toHaveURL(new RegExp(`${org}/setup/global-defaults$`));
    await expect(page.getByRole("combobox", { name: label("Default Company") })).toHaveValue(companyName);
});
