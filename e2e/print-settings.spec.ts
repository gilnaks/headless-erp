import { expect, test } from "@playwright/test";
import { createOrganization, label, signIn } from "./helpers";

test("print settings are seeded and saved in place", async ({ page }) => {
    const stamp = Date.now().toString(36);

    await signIn(page, "E2E_PRINTSETTINGS");
    const org = await createOrganization(page, `Print Settings Org ${stamp}`);

    await page.goto(`${org}/setup/print-settings`);
    const compact = page.getByRole("checkbox", { name: "Compact Item Print" });
    const fontSize = page.getByRole("textbox", { name: label("Font Size") });
    await expect(compact).toBeChecked();
    await expect(fontSize).toHaveValue("9");

    await expect(async () => {
        await fontSize.fill("11");
        await expect(fontSize).toHaveValue("11", { timeout: 1_000 });
    }).toPass();
    await compact.click({ force: true });
    await expect(compact).not.toBeChecked();
    await page.getByRole("button", { name: /^Save/ }).click();
    await expect(page.getByText("Saved.")).toBeVisible();

    await page.reload();
    await expect(page.getByRole("checkbox", { name: "Compact Item Print" })).not.toBeChecked();
    await expect(page.getByRole("textbox", { name: label("Font Size") })).toHaveValue("11");
});
