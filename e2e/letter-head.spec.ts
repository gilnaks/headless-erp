import { expect, test } from "@playwright/test";
import { createOrganization, label, signIn } from "./helpers";

// 1x1 transparent PNG.
const PNG = Buffer.from("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==", "base64");

test("HTML letter head is sanitized; image letter head uploads and previews", async ({ page }) => {
    const stamp = Date.now().toString(36);

    await signIn(page, "E2E_LETTERHEAD");
    const org = await createOrganization(page, `Letter Head Org ${stamp}`);

    await page.goto(`${org}/setup/letter-head/new`);
    await expect(async () => {
        await page.getByRole("textbox", { name: label("Letter Head Name") }).fill("Standard");
        await expect(page.getByRole("textbox", { name: label("Letter Head Name") })).toHaveValue("Standard", { timeout: 1_000 });
    }).toPass();
    await page
        .getByRole("textbox", { name: label("Header HTML") })
        .fill('<h2>Acme Header</h2><script>window.pwned = 1</script><img src="x.png" onerror="window.pwned = 2">');
    await expect(page.frameLocator('iframe[title="Header preview"]').getByText("Acme Header")).toBeVisible();
    await page.getByRole("button", { name: /^Save/ }).click();
    await expect(page).toHaveURL(new RegExp(`${org}/setup/letter-head/[0-9a-f-]{36}$`));

    await page.reload();
    const header = page.getByRole("textbox", { name: label("Header HTML") });
    await expect(header).toHaveValue(/<h2>Acme Header<\/h2>/);
    await expect(header).not.toHaveValue(/script|onerror|pwned/);
    await expect(page.getByRole("checkbox", { name: "Default Letter Head" })).toBeChecked();

    await page.goto(`${org}/setup/letter-head/new`);
    await expect(async () => {
        await page.getByRole("textbox", { name: label("Letter Head Name") }).fill("Logo");
        await expect(page.getByRole("textbox", { name: label("Letter Head Name") })).toHaveValue("Logo", { timeout: 1_000 });
    }).toPass();
    await page.getByRole("button", { name: /Letter Head Based On/ }).click();
    await page.getByRole("option", { name: "Image" }).click();
    await page.locator('input[type="file"]').first().setInputFiles({ name: "logo.png", mimeType: "image/png", buffer: PNG });
    await expect(page.getByRole("img", { name: "Image" })).toBeVisible({ timeout: 15_000 });
    await expect(page.getByTestId("letter-head-preview").getByRole("img", { name: "Letter head header" })).toBeVisible();
    await page.getByRole("button", { name: /^Save/ }).click();
    await expect(page).toHaveURL(new RegExp(`${org}/setup/letter-head/[0-9a-f-]{36}$`));

    await page.reload();
    await expect(page.getByTestId("letter-head-preview").getByRole("img", { name: "Letter head header" })).toBeVisible({ timeout: 15_000 });

    await page.goto(`${org}/setup/letter-head`);
    await expect(page.getByRole("row").filter({ hasText: "Logo" })).toBeVisible();
    await expect(page.getByRole("row").filter({ hasText: "Standard" })).toBeVisible();
});
