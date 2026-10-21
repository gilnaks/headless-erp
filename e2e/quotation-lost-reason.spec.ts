import { expect, test } from "@playwright/test";
import { createOrganization, credentials, label, signIn } from "./helpers";

test("a new quotation lost reason is saved and listed", async ({ page }) => {
    const stamp = Date.now().toString(36);
    const name = `Price ${stamp}`;
    const { email } = credentials("E2E_QUOTATION_LOST_REASON");

    await signIn(page, "E2E_QUOTATION_LOST_REASON");
    const org = await createOrganization(page, `Lost Reason Org ${stamp}`);

    await page.goto(`${org}/setup/users`);
    await page.getByRole("row").filter({ hasText: email }).click();
    await expect(page).toHaveURL(new RegExp(`${org}/setup/users/[0-9a-f-]{36}$`));
    await page.getByRole("button", { name: /System Manager/ }).click();
    const search = page.getByPlaceholder("Search").last();
    await search.fill("");
    await search.pressSequentially("Sales Manager");
    await page.getByRole("option", { name: "Sales Manager", exact: true }).click();
    await page.keyboard.press("Escape");
    await page.keyboard.press("Escape");
    await page.getByRole("button", { name: /^Save/ }).click();
    await expect(page.getByText("Not Saved")).toBeHidden();

    await page.goto(`${org}/selling/quotation-lost-reason/new`);
    await page.getByRole("textbox", { name: label("Quotation Lost Reason") }).fill(name);
    await page.getByRole("button", { name: /^Save/ }).click();
    await expect(page).toHaveURL(new RegExp(`${org}/selling/quotation-lost-reason/[0-9a-f-]{36}$`), { timeout: 15_000 });

    await page.goto(`${org}/selling/quotation-lost-reason`);
    await page.getByRole("textbox", { name: "Search Quotation Lost Reason" }).fill(name);
    await expect(page.getByRole("row", { name: new RegExp(name) })).toBeVisible();
});
