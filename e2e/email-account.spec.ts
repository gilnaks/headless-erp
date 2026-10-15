import { expect, test } from "@playwright/test";
import { createOrganization, label, signIn } from "./helpers";

// Runs with EMAIL_DRY_RUN=1: the test email is logged but never leaves the server.
test("email account stores its API key write-only and sends a test email", async ({ page }) => {
    const stamp = Date.now().toString(36);

    await signIn(page, "E2E_EMAIL_ACCOUNT");
    const org = await createOrganization(page, `Email Org ${stamp}`);

    await page.goto(`${org}/setup/email-account/new`);
    await expect(async () => {
        await page.getByRole("textbox", { name: label("Email Account Name") }).fill("Notifications");
        await expect(page.getByRole("textbox", { name: label("Email Account Name") })).toHaveValue("Notifications", { timeout: 1_000 });
    }).toPass();
    await page.getByRole("textbox", { name: label("Email Address") }).fill("not-an-email");
    await page.getByLabel(label("API Key")).fill("re_e2e_secret");
    await page.getByRole("checkbox", { name: "Default Outgoing" }).check({ force: true });
    await page.getByRole("button", { name: /^Save/ }).click();
    await expect(page.getByText("Enter a valid email address").first()).toBeVisible();

    await page.getByRole("textbox", { name: label("Email Address") }).fill("Notify@Example.com");
    await page.getByRole("button", { name: /^Save/ }).click();
    await expect(page).toHaveURL(new RegExp(`${org}/setup/email-account/[0-9a-f-]{36}$`));

    await page.reload();
    await expect(page.getByRole("textbox", { name: label("Email Address") })).toHaveValue("notify@example.com");
    await expect(page.getByRole("checkbox", { name: "API Key Saved" })).toBeChecked();
    await expect(page.getByLabel(label("API Key"))).toHaveValue("");
    await expect(page.locator("body")).not.toContainText("re_e2e_secret");

    await page.getByRole("button", { name: "Actions", exact: true }).click();
    await page.getByRole("menuitem", { name: "Send Test Email" }).click();
    await expect(page.getByText(/^Test email sent to .+@.+\.$/)).toBeVisible({ timeout: 15_000 });

    await page.goto(`${org}/setup/email-account`);
    await expect(page.getByRole("row").filter({ hasText: "notify@example.com" })).toBeVisible();
});
