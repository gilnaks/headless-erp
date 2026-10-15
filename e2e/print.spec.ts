import { expect, test } from "@playwright/test";
import { createOrganization, label, signIn } from "./helpers";

test("print a company with the default letter head; another organization gets a 404", async ({ page, browser }) => {
    test.slow();
    const stamp = Date.now().toString(36);
    const orgName = `Print Org ${stamp}`;

    await signIn(page, "E2E_PRINT_A");
    const org = await createOrganization(page, orgName);

    await page.goto(`${org}/setup/letter-head/new`);
    await expect(async () => {
        await page.getByRole("textbox", { name: label("Letter Head Name") }).fill("Main");
        await expect(page.getByRole("textbox", { name: label("Letter Head Name") })).toHaveValue("Main", { timeout: 1_000 });
    }).toPass();
    await page.getByRole("textbox", { name: label("Header HTML") }).fill("<p><b>Print Head Inc.</b></p>");
    await page.getByRole("button", { name: /^Save/ }).click();
    await expect(page).toHaveURL(new RegExp(`${org}/setup/letter-head/[0-9a-f-]{36}$`));

    await page.goto(`${org}/setup/company`);
    await page.getByRole("row").filter({ hasText: orgName }).first().click();
    await expect(page).toHaveURL(new RegExp(`${org}/setup/company/[0-9a-f-]{36}$`));
    const companyId = page.url().split("/").pop() ?? "";

    await page.getByRole("button", { name: "More actions" }).click();
    const [print] = await Promise.all([page.context().waitForEvent("page"), page.getByRole("menuitem", { name: "Print" }).click()]);
    await expect(print).toHaveURL(new RegExp(`/print/company/${companyId}$`));
    const sheet = print.getByRole("article", { name: `Company ${orgName}` });
    await expect(sheet).toBeVisible({ timeout: 15_000 });
    await expect(sheet.getByTestId("letter-head-header")).toHaveText("Print Head Inc.");
    await expect(sheet.getByText("Country", { exact: true })).toBeVisible();
    await expect(sheet.getByText("Philippines", { exact: true }).first()).toBeVisible();
    await expect(print.getByRole("button", { name: "Print", exact: true })).toBeEnabled();
    await print.close();

    const other = await browser.newContext();
    const intruder = await other.newPage();
    await signIn(intruder, "E2E_PRINT_B");
    await createOrganization(intruder, `Print Other ${stamp}`);
    await intruder.goto(`/print/company/${companyId}`);
    await expect(intruder.getByText("404 error")).toBeVisible();
    await expect(intruder.getByText("Print Head Inc.")).toHaveCount(0);
    await other.close();
});
