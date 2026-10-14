import { expect, type Page, test } from "@playwright/test";
import { createOrganization, label, signIn } from "./helpers";

async function save(page: Page, url: RegExp) {
    await page.getByRole("button", { name: /^Save/ }).click();
    await expect(page).toHaveURL(url);
}

test("custom role, role profile, and renaming the role updates the profile", async ({ page }) => {
    const stamp = Date.now().toString(36);
    const reviewer = `Reviewer ${stamp}`;
    const approver = `Approver ${stamp}`;
    const profile = `Review ${stamp}`;

    await signIn(page, "E2E_ACCESS");
    const org = await createOrganization(page, `Access Org ${stamp}`);

    await page.goto(`${org}/setup/roles`);
    await expect(page.getByRole("row", { name: /System Manager/ })).toBeVisible();
    await page.getByRole("link", { name: "New Role" }).first().click();
    await page.getByRole("textbox", { name: label("Role Name") }).fill(reviewer);
    await save(page, new RegExp(`${org}/setup/roles/[0-9a-f-]{36}$`));
    const roleUrl = page.url();

    await page.goto(`${org}/setup/role-profile/new`);
    await page.getByRole("textbox", { name: label("Role Profile") }).fill(profile);
    await page.getByRole("button", { name: /^Select/ }).click();
    await page.getByPlaceholder("Search").last().pressSequentially(stamp);
    const option = page.getByRole("option", { name: reviewer });
    await option.click();
    await expect(option).toHaveAttribute("aria-selected", "true");
    // The first Escape clears the search text, the second closes the popover; the selection survives both.
    await page.keyboard.press("Escape");
    await page.keyboard.press("Escape");
    await expect(page.getByRole("dialog")).toBeHidden();
    await expect(page.getByRole("button", { name: reviewer })).toBeVisible();
    await save(page, new RegExp(`${org}/setup/role-profile/[0-9a-f-]{36}$`));

    await page.goto(roleUrl);
    const name = page.getByRole("textbox", { name: label("Role Name") });
    await name.fill(approver);
    await page.getByRole("button", { name: /^Save/ }).click();
    await expect(page.getByText("Not Saved")).toBeHidden();

    await page.goto(`${org}/setup/role-profile`);
    await expect(page.getByRole("row").filter({ hasText: profile })).toContainText(approver);

    await page.goto(`${org}/setup/roles`);
    await page.getByRole("row", { name: /^Sales User/ }).click();
    await page.getByRole("textbox", { name: label("Role Name") }).fill("Sales Person");
    await page.getByRole("button", { name: /^Save/ }).click();
    await expect(page.getByText(/Standard role Sales User cannot be renamed/).first()).toBeVisible();
});
