import { expect, test } from "@playwright/test";
import { createOrganization, label, signIn } from "./helpers";

// Runs with EMAIL_DRY_RUN=1: messages are logged to email_log but never leave the server.
test("invitations are emailed and a record can be emailed from its form", async ({ page }) => {
    const stamp = Date.now().toString(36);
    const invitee = `invitee-${stamp}@example.com`;
    const orgName = `Email Send Org ${stamp}`;

    await signIn(page, "E2E_EMAIL_SEND");
    const org = await createOrganization(page, orgName);

    await page.goto(`${org}/setup/users`);
    await page.getByRole("button", { name: "Invite user" }).click();
    const drawer = page.getByRole("dialog");
    await drawer.getByRole("textbox", { name: label("Email") }).fill(invitee);
    await drawer.getByRole("button", { name: /Role Profile/ }).click();
    await page.getByRole("option", { name: "Sales" }).click();
    await drawer.getByRole("button", { name: "Create invitation" }).click();
    await expect(drawer.getByText(`Invitation emailed to ${invitee}`)).toBeVisible();
    await expect(drawer.getByRole("textbox", { name: "Invitation link" })).toHaveValue(/\/invite\/[0-9a-f]{48}$/);
    await drawer.getByRole("button", { name: "Done" }).click();

    await page.goto(`${org}/setup/company`);
    await page
        .getByRole("row", { name: new RegExp(`^${orgName}`) })
        .first()
        .click();
    await expect(page).toHaveURL(new RegExp(`${org}/setup/company/[0-9a-f-]{36}$`));
    await expect(async () => {
        await page.getByRole("button", { name: "More actions" }).click();
        await page.getByRole("menuitem", { name: "Email" }).click({ timeout: 1_000 });
    }).toPass();

    const dialog = page.getByRole("dialog", { name: "Email Company" });
    await expect(dialog.getByRole("textbox", { name: label("Subject") })).toHaveValue(`Company ${orgName}`);
    await expect(dialog.getByRole("textbox", { name: label("Message") })).toHaveValue(/\/print\/company\/[0-9a-f-]{36}/);

    await dialog.getByRole("textbox", { name: label("To") }).fill("not an email");
    await dialog.getByRole("button", { name: "Send", exact: true }).click();
    await expect(dialog.getByText("Enter at least one valid recipient.")).toBeVisible();

    await dialog.getByRole("textbox", { name: label("To") }).fill("client@example.com");
    await dialog.getByRole("textbox", { name: label("CC") }).fill("accounts@example.com");
    await dialog.getByRole("button", { name: "Send", exact: true }).click();
    await expect(dialog).toBeHidden();
    await expect(page.getByText("Email sent to client@example.com, accounts@example.com.")).toBeVisible();
});
