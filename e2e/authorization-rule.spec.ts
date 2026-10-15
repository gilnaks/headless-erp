import { expect, test } from "@playwright/test";
import { createOrganization, label, pick, signIn } from "./helpers";

test("authorization rule requires an approver and is named from its series", async ({ page }) => {
    const stamp = Date.now().toString(36);

    await signIn(page, "E2E_AUTH_RULE");
    const org = await createOrganization(page, `Auth Rule Org ${stamp}`);

    await page.goto(`${org}/setup/authorization-rule/new`);
    // Retried: a choice made before the form hydrates is lost.
    await expect(async () => {
        await page.getByRole("button", { name: /Transaction/ }).click();
        await page.getByRole("option", { name: "Sales Order" }).click();
        await expect(page.getByRole("button", { name: /Transaction/ })).toContainText("Sales Order", { timeout: 1_000 });
    }).toPass();
    await page.getByLabel(label("Above Value")).fill("1000");

    await page.getByRole("button", { name: /^Save/ }).click();
    await expect(page.getByText("Please enter Approving Role or Approving User").first()).toBeVisible();
    await expect(page).toHaveURL(new RegExp(`${org}/setup/authorization-rule/new$`));

    await pick(page, "Approving Role", "Sales Man", /^Sales Manager$/);
    await page.getByRole("button", { name: /^Save/ }).click();
    await expect(page).toHaveURL(new RegExp(`${org}/setup/authorization-rule/[0-9a-f-]{36}$`), { timeout: 15_000 });
    await expect(page.getByRole("textbox", { name: label("Name") })).toHaveValue("HR-ARU-00001");

    await page.goto(`${org}/setup/authorization-rule`);
    const row = page.getByRole("row").filter({ hasText: "HR-ARU-00001" });
    await expect(row).toContainText("Sales Order");
    await expect(row).toContainText("Sales Manager");
});
