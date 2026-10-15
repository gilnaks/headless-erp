import { expect, test } from "@playwright/test";
import { createOrganization, label, signIn } from "./helpers";

test("email template previews placeholders and rejects unknown helpers", async ({ page }) => {
    const stamp = Date.now().toString(36);

    await signIn(page, "E2E_EMAIL_TEMPLATE");
    const org = await createOrganization(page, `Template Org ${stamp}`);

    await page.goto(`${org}/setup/email-template/new`);
    await expect(async () => {
        await page.getByRole("textbox", { name: label("Name") }).fill("Payment Reminder");
        await expect(page.getByRole("textbox", { name: label("Name") })).toHaveValue("Payment Reminder", { timeout: 1_000 });
    }).toPass();
    await page.getByRole("textbox", { name: label("Subject") }).fill("Reminder: {{doc.name}}");
    await page.getByRole("textbox", { name: label("Response") }).fill("<p>Dear {{doc.customer_name}}, please pay {{shout doc.grand_total}}.</p>");

    const preview = page.getByTestId("email-template-preview");
    await expect(preview).toContainText("Subject: Reminder: ACC-SINV-2026-00001");
    await expect(preview).toContainText('Unknown helper "shout"');

    await page.getByRole("button", { name: /^Save/ }).click();
    await expect(page.getByText(/Unknown helper "shout"/).first()).toBeVisible();
    await expect(page).toHaveURL(new RegExp(`${org}/setup/email-template/new$`));

    await page
        .getByRole("textbox", { name: label("Response") })
        .fill("<p>Dear {{doc.customer_name}}, please pay {{money doc.grand_total}}.</p><script>alert(1)</script>");
    await expect(preview.frameLocator('iframe[title="Email body preview"]').getByText("Dear Sample Customer, please pay $1,250.00.")).toBeVisible();
    await page.getByRole("button", { name: /^Save/ }).click();
    await expect(page).toHaveURL(new RegExp(`${org}/setup/email-template/[0-9a-f-]{36}$`));

    await page.reload();
    const body = page.getByRole("textbox", { name: label("Response") });
    await expect(body).toHaveValue(/\{\{money doc\.grand_total\}\}/);
    await expect(body).not.toHaveValue(/script/);

    await page.goto(`${org}/setup/email-template`);
    await expect(page.getByRole("row").filter({ hasText: "Payment Reminder" })).toBeVisible();
});
