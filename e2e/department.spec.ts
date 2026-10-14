import { expect, test } from "@playwright/test";
import { createCompany, createOrganization, label, signIn } from "./helpers";

test("the department tree seeds a company and adds a child under a group", async ({ page }) => {
    test.slow();
    const stamp = Date.now().toString(36);
    const abbr = `D${stamp.slice(-3).toUpperCase()}`;

    await signIn(page, "E2E_DEPARTMENT");
    const org = await createOrganization(page, `Department Org ${stamp}`);
    await createCompany(page, org, `Dept Co ${stamp}`, abbr);

    await page.goto(`${org}/setup/department`);
    await expect(page.getByRole("row", { name: new RegExp(`^Accounts - ${abbr}`) })).toBeVisible();
    await page
        .getByRole("radio", { name: "Tree" })
        .or(page.getByRole("button", { name: "Tree" }))
        .click();
    await expect(page).toHaveURL(/view=tree/);

    const tree = page.getByRole("treegrid", { name: "Department tree" });
    await expect(tree.getByRole("row", { name: /^All Departments/ })).toBeVisible();
    await expect(tree.getByRole("row", { name: new RegExp(`^Legal - ${abbr}`) })).toBeVisible();

    await page.getByRole("combobox", { name: "Company" }).selectOption({ label: `Dept Co ${stamp}` });
    await expect(page).toHaveURL(/company_id=/);
    await tree.getByRole("row", { name: /^All Departments/ }).hover();
    await tree.getByRole("link", { name: "Add child to All Departments" }).click();
    await expect(page).toHaveURL(/\/setup\/department\/new\?parent_id=/);
    await page.getByRole("textbox", { name: label("Department") }).fill("Engineering");
    await page.getByRole("checkbox", { name: "Is Group" }).check({ force: true });
    await page.getByRole("button", { name: /^Save/ }).click();
    await expect(page).toHaveURL(new RegExp(`${org}/setup/department/[0-9a-f-]{36}$`));
    await expect(page.getByRole("textbox", { name: label("Name") })).toHaveValue(`Engineering - ${abbr}`);
});
