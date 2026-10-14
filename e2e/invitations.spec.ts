import { expect, type Page, test } from "@playwright/test";
import { createOrganization, credentials, label, signIn } from "./helpers";

async function switchUser(page: Page, prefix: string) {
    await page.context().clearCookies();
    await signIn(page, prefix);
    await expect(page).not.toHaveURL(/\/login/);
}

test("owner invites with a role profile, the invitee accepts the copied link and joins with the profile roles", async ({ page }) => {
    const stamp = Date.now().toString(36);
    const invitee = credentials("E2E_INVITEE").email;

    await signIn(page, "E2E_INVITER");
    const org = await createOrganization(page, `Invite Org ${stamp}`);

    await page.goto(`${org}/setup/users`);
    await page.getByRole("button", { name: "Invite user" }).click();
    const drawer = page.getByRole("dialog");
    await drawer.getByRole("textbox", { name: label("Email") }).fill(invitee);
    await drawer.getByRole("button", { name: /Role Profile/ }).click();
    await page.getByRole("option", { name: "Accounts" }).click();
    await expect(drawer.getByRole("button", { name: /Accounts User, Accounts Manager/ })).toBeVisible();
    await drawer.getByRole("button", { name: "Create invitation" }).click();

    const link = await drawer.getByRole("textbox", { name: "Invitation link" }).inputValue();
    expect(link).toMatch(/\/invite\/[0-9a-f]{48}$/);
    await drawer.getByRole("button", { name: "Done" }).click();
    const invitationRow = page.getByRole("row").filter({ hasText: invitee });
    await expect(invitationRow).toContainText("Pending");

    await page.getByRole("button", { name: "Invite user" }).click();
    await drawer.getByRole("textbox", { name: label("Email") }).fill(invitee);
    await drawer.getByRole("button", { name: /^Select/ }).click();
    await page.getByRole("option", { name: "Sales User" }).click();
    await page.keyboard.press("Escape");
    await page.keyboard.press("Escape");
    await drawer.getByRole("button", { name: "Create invitation" }).click();
    await expect(drawer.getByText(/already open/).first()).toBeVisible();
    await drawer.getByRole("button", { name: "Cancel" }).click();

    await switchUser(page, "E2E_INVITEE");
    await page.goto(new URL(link).pathname);
    await expect(page.getByText(`Invite Org ${stamp}`)).toBeVisible();
    await page.getByRole("button", { name: "Accept invitation" }).click();
    await expect(page).toHaveURL(new RegExp(`${org}$`));

    await switchUser(page, "E2E_INVITER");
    await page.goto(`${org}/setup/users`);
    const memberRow = page.getByRole("grid", { name: "Users" }).getByRole("row").filter({ hasText: invitee });
    await expect(memberRow).toContainText("Accounts User");
    await expect(memberRow).toContainText("Accounts Manager");
    await expect(page.getByRole("grid", { name: "Invitations" }).getByRole("row").filter({ hasText: invitee })).toContainText("Accepted");
});
