import { expect, test } from "@playwright/test";
import { createOrganization, signIn } from "./helpers";

test("turning off Company create hides New Company, and resetting the doctype brings it back", async ({ page }) => {
    const stamp = Date.now().toString(36);

    await signIn(page, "E2E_PERMS");
    const org = await createOrganization(page, `Perms Org ${stamp}`);

    await page.goto(`${org}/setup/role-permissions`);
    await expect(page.getByText("Select a document type or a role to see its rules.")).toBeVisible();
    await page.getByRole("button", { name: /Document type/ }).click();
    await page.getByRole("option", { name: "Company", exact: true }).click();
    await expect(page).toHaveURL(/doctype=Company/);

    const create = page.getByRole("checkbox", { name: "Create: System Manager on Company" });
    await expect(create).toBeChecked();
    await create.click({ force: true });
    await expect(create).not.toBeChecked();

    await page.goto(`${org}/setup/company`);
    await expect(page.getByRole("heading", { name: "Company" }).first()).toBeVisible();
    await expect(page.getByRole("link", { name: "New Company" })).toHaveCount(0);

    await page.goto(`${org}/setup/role-permissions?doctype=Company`);
    await page.getByRole("button", { name: "Reset to defaults" }).click();
    await page.getByRole("dialog").getByRole("button", { name: "Reset" }).click();
    await expect(page.getByRole("dialog")).toBeHidden();
    await expect(page.getByRole("checkbox", { name: "Create: System Manager on Company" })).toBeChecked();

    await page.goto(`${org}/setup/company`);
    await expect(page.getByRole("link", { name: "New Company" }).first()).toBeVisible();
});
