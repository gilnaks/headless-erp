import { expect, type Page, test } from "@playwright/test";
import { createOrganization, credentials, label, signIn } from "./helpers";

async function switchUser(page: Page, prefix: string) {
    await page.context().clearCookies();
    await signIn(page, prefix);
    await expect(page).not.toHaveURL(/\/login/);
}

test("home onboarding checklist: skip, invite completes a step, managers only, dismiss", async ({ page }) => {
    test.slow();
    const stamp = Date.now().toString(36);
    const member = credentials("E2E_HOME_MEMBER").email;

    await signIn(page, "E2E_HOME");
    const org = await createOrganization(page, `Home Org ${stamp}`);

    const card = page.getByRole("region", { name: "Get started" });
    await expect(card).toBeVisible();
    await expect(page.getByRole("region", { name: "Profit and Loss" })).toBeVisible();
    await expect(page.getByRole("region", { name: "Annual Sales" })).toBeVisible();
    await expect(card.getByRole("listitem", { name: "Invite your team" })).not.toContainText("Done");

    const stock = card.getByRole("listitem", { name: "Keep track of your stock" });
    await expect(async () => {
        await stock.getByRole("button", { name: "Skip" }).click();
        await expect(stock).toContainText("Skipped", { timeout: 2_000 });
    }).toPass();

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

    await switchUser(page, "E2E_HOME_MEMBER");
    await page.goto(new URL(link).pathname);
    await page.getByRole("button", { name: "Accept invitation" }).click();
    await expect(page).toHaveURL(new RegExp(`${org}$`));
    await expect(page.getByRole("region", { name: "Profit and Loss" })).toBeVisible();
    await expect(page.getByRole("region", { name: "Get started" })).toHaveCount(0);

    await switchUser(page, "E2E_HOME");
    await page.goto(org);
    await expect(card.getByRole("listitem", { name: "Invite your team" })).toContainText("Done");
    await card.getByRole("button", { name: "Dismiss" }).click();
    await expect(card).toHaveCount(0);
    await page.reload();
    await expect(page.getByRole("region", { name: "Profit and Loss" })).toBeVisible();
    await expect(card).toHaveCount(0);
});
