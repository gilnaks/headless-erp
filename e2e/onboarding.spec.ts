import { expect, test } from "@playwright/test";
import { defaultFiscalYear, fiscalYearName } from "../src/lib/fiscal-year";
import { label, pick, signIn } from "./helpers";

test("the setup wizard creates the organization, its first company, fiscal year and invitations", async ({ page }) => {
    test.slow();
    const stamp = Date.now().toString(36);
    const orgName = `Onboard Org ${stamp}`;
    const slug = orgName.toLowerCase().replaceAll(" ", "-");
    const companyName = `Onboard Trading ${stamp}`;
    const invitee = `teammate-${stamp}@example.com`;

    await signIn(page, "E2E_ONBOARDING");
    await expect(page).toHaveURL(/\/setup$/);
    const steps = page.getByRole("list", { name: "Setup steps" });
    await expect(steps.locator('[aria-current="step"]')).toContainText("Organization");

    // Step 1: the URL follows the name (retried: a value typed before the form hydrates is lost); the step is
    // validated before moving on.
    const orgInput = page.getByRole("textbox", { name: label("Organization name") });
    await expect(async () => {
        await orgInput.fill(orgName);
        await expect(page.getByRole("textbox", { name: label("URL") })).toHaveValue(slug, { timeout: 1_000 });
    }).toPass();
    await orgInput.fill("");
    await page.getByRole("button", { name: "Next" }).click();
    await expect(page.getByText("Enter the organization name")).toBeVisible();
    await orgInput.fill(orgName);
    await expect(page.getByRole("textbox", { name: label("URL") })).toHaveValue(slug);
    await pick(page, "Country", "India", /^India$/);
    await pick(page, "Default currency", "INR", /^INR/);
    await page.getByRole("button", { name: "Next" }).click();

    // Step 2: name and abbreviation prefilled, India's fiscal year (April) and a chart with its preview.
    await expect(steps.locator('[aria-current="step"]')).toContainText("Company");
    const name = page.getByRole("textbox", { name: label("Company name") });
    await expect(name).toHaveValue(orgName);
    await name.fill(companyName);
    await expect(page.getByRole("textbox", { name: label("Company abbreviation") })).toHaveValue(`OT${stamp[0].toUpperCase()}`);

    const timeZone = await page.evaluate(() => Intl.DateTimeFormat().resolvedOptions().timeZone);
    const today = new Intl.DateTimeFormat("en-CA", { timeZone }).format(new Date());
    const fy = defaultFiscalYear("India", today);
    expect(fy?.start.slice(5)).toBe("04-01");
    await expect(page.getByLabel(label("Financial year begins on"))).toHaveValue(fy?.start ?? "");
    await expect(page.getByText(`Ends on ${fy?.end}.`)).toBeVisible();

    const chart = page.getByRole("combobox", { name: label("Chart of accounts") });
    await expect(chart).not.toHaveValue("", { timeout: 15_000 });
    await pick(page, "Chart of accounts", "Standard", /^Standard$/);
    const preview = page.getByRole("list", { name: "Standard accounts" });
    await expect(preview.getByText("Application of Funds (Assets)")).toBeVisible();
    await expect(preview.getByText("Cash", { exact: true })).toBeVisible();

    // Back keeps the values.
    await page.getByRole("button", { name: "Back" }).click();
    await expect(page.getByRole("textbox", { name: label("URL") })).toHaveValue(slug);
    await page.getByRole("button", { name: "Next" }).click();
    await expect(name).toHaveValue(companyName);
    await expect(chart).toHaveValue("Standard");
    await page.getByRole("button", { name: "Next" }).click();

    // Step 3: one teammate with a role profile.
    await expect(steps.locator('[aria-current="step"]')).toContainText("Invite");
    await page.getByRole("button", { name: "Add teammate" }).click();
    await page.getByRole("textbox", { name: label("Email") }).fill(invitee);
    await pick(page, "Role profile", "Accounts", /^Accounts/);
    await page.getByRole("button", { name: "Create organization" }).click();
    await expect(page.getByText("Setting up the basics")).toBeVisible();
    await expect(page).toHaveURL(new RegExp(`/${slug}$`), { timeout: 30_000 });

    await page.goto(`/${slug}/setup/company`);
    await expect(page.getByRole("row", { name: new RegExp(companyName) })).toBeVisible();

    await page.goto(`/${slug}/accounts/fiscal-year`);
    await expect(page.getByRole("row", { name: new RegExp(`^${fiscalYearName(fy?.start ?? "", fy?.end ?? "")}`) })).toBeVisible();

    await page.goto(`/${slug}/setup/global-defaults`);
    await expect(page.getByRole("combobox", { name: label("Default Company") })).toHaveValue(companyName);

    await page.goto(`/${slug}/setup/users`);
    await expect(page.getByRole("grid", { name: "Invitations" }).getByRole("row").filter({ hasText: invitee })).toBeVisible();
});
