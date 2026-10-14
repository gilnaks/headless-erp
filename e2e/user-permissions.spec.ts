import { expect, type Page, test } from "@playwright/test";
import { createCompany, createOrganization, credentials, label, pick, signIn } from "./helpers";

async function switchUser(page: Page, prefix: string) {
    await page.context().clearCookies();
    await signIn(page, prefix);
    await expect(page).not.toHaveURL(/\/login/);
}

test("a Company user permission shows names in the list and limits the member to that company", async ({ page }) => {
    test.slow();
    const stamp = Date.now().toString(36);
    const member = credentials("E2E_RESTRICTED").email;
    const allowed = `Allowed Co ${stamp}`;
    const other = `Other Co ${stamp}`;

    await signIn(page, "E2E_RESTRICTOR");
    const org = await createOrganization(page, `Restrict Org ${stamp}`);
    await createCompany(page, org, allowed, `A${stamp.slice(-3).toUpperCase()}`);
    await createCompany(page, org, other, `O${stamp.slice(-3).toUpperCase()}`);

    await page.goto(`${org}/setup/users`);
    await page.getByRole("button", { name: "Invite user" }).click();
    const drawer = page.getByRole("dialog");
    await drawer.getByRole("textbox", { name: label("Email") }).fill(member);
    await drawer.getByRole("button", { name: /^Select/ }).click();
    await page.getByRole("option", { name: "Sales User" }).click();
    await page.keyboard.press("Escape");
    await page.keyboard.press("Escape");
    await drawer.getByRole("button", { name: "Create invitation" }).click();
    const link = await drawer.getByRole("textbox", { name: "Invitation link" }).inputValue();

    await switchUser(page, "E2E_RESTRICTED");
    await page.goto(new URL(link).pathname);
    await page.getByRole("button", { name: "Accept invitation" }).click();
    await expect(page).toHaveURL(new RegExp(`${org}$`));

    await switchUser(page, "E2E_RESTRICTOR");
    await page.goto(`${org}/setup/users`);
    const memberRow = page.getByRole("grid", { name: "Users" }).getByRole("row").filter({ hasText: member });
    await expect(async () => {
        await memberRow.click();
        await expect(page).toHaveURL(new RegExp(`${org}/setup/users/[0-9a-f-]{36}$`), { timeout: 2000 });
    }).toPass();
    await expect(page.getByText("No restrictions")).toBeVisible();
    await page.getByRole("link", { name: "Add user permission" }).click();

    await expect(page.getByRole("heading", { name: "New User Permission" })).toBeVisible();
    await expect(page.getByRole("combobox", { name: label("User") })).toHaveValue(new RegExp(member));
    await pick(page, "Allow", "Company", /^Company$/);
    await pick(page, "For Value", "Allowed", new RegExp(allowed));
    await page.getByRole("checkbox", { name: "Is Default" }).check({ force: true });
    await page.getByRole("button", { name: /^Save/ }).click();
    await expect(page).toHaveURL(new RegExp(`${org}/setup/user-permissions/[0-9a-f-]{36}$`));

    await page.goto(`${org}/setup/user-permissions`);
    const row = page.getByRole("row").filter({ hasText: member });
    await expect(row).toContainText(allowed);
    await expect(row).toContainText("Company");
    await expect(row).not.toContainText(/[0-9a-f]{8}-[0-9a-f]{4}-/);

    await switchUser(page, "E2E_RESTRICTED");
    await page.goto(`${org}/setup/company`);
    await expect(page.getByRole("row", { name: new RegExp(allowed) })).toBeVisible();
    await expect(page.getByRole("row", { name: new RegExp(other) })).toHaveCount(0);
});
