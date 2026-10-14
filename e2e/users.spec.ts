import { expect, test } from "@playwright/test";
import { createOrganization, credentials, signIn } from "./helpers";

test("users page lists the owner, and the owner's roles can be extended but System Manager stays", async ({ page }) => {
    const stamp = Date.now().toString(36);
    const { email } = credentials("E2E_USERS");

    await signIn(page, "E2E_USERS");
    const org = await createOrganization(page, `Users Org ${stamp}`);

    await page.goto(`${org}/setup/users`);
    const ownerRow = page.getByRole("row").filter({ hasText: email });
    await expect(ownerRow).toContainText("Users Admin");
    await expect(ownerRow).toContainText("Owner");
    await expect(ownerRow).toContainText("System Manager");
    await expect(ownerRow).toContainText("Active");

    await page.getByPlaceholder("Search name, email or role").fill("nobody-matches-this");
    await expect(page.getByText(/No user matches/)).toBeVisible();
    await page.getByRole("button", { name: "Clear search" }).click();

    await ownerRow.click();
    await expect(page).toHaveURL(new RegExp(`${org}/setup/users/[0-9a-f-]{36}$`));
    await expect(page.getByRole("heading", { name: "Users Admin" })).toBeVisible();
    await expect(page.getByRole("switch", { name: "Active" })).toBeDisabled();
    await expect(page.getByRole("button", { name: "Remove user" })).toHaveCount(0);

    await page.getByRole("button", { name: /System Manager/ }).click();
    await page.getByPlaceholder("Search").last().pressSequentially("Accounts User");
    await page.getByRole("option", { name: "Accounts User" }).click();
    await page.keyboard.press("Escape");
    await page.keyboard.press("Escape");
    await page.getByRole("button", { name: /^Save/ }).click();
    await expect(page.getByText("Not Saved")).toBeHidden();

    await page.goto(`${org}/setup/users`);
    await expect(ownerRow).toContainText("Accounts User");
    await expect(ownerRow).toContainText("System Manager");
});
