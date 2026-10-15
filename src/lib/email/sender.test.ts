import { describe, expect, it, vi } from "vitest";

vi.mock("server-only", () => ({}));

const { accountSender, formatAddress, platformSender, withSignature } = await import("./sender");

const account = {
    email_account_id: "a1",
    email_account_name: "Acme Sales",
    email_id: "sales@acme.test",
    api_key: "re_company",
    always_use_account_email_id_as_sender: false,
    always_use_account_name_as_sender_name: false,
    add_signature: true,
    signature: "<p>Acme</p>",
    footer: "<small>Footer</small>",
};

describe("accountSender", () => {
    it("sends from the account's address under the user's name, replying to the user", () => {
        expect(accountSender(account, { name: "Jane Doe", email: "jane@acme.test" })).toEqual({
            accountId: "a1",
            apiKey: "re_company",
            from: '"Jane Doe" <sales@acme.test>',
            replyTo: "jane@acme.test",
            signature: "<p>Acme</p>",
            footer: "<small>Footer</small>",
        });
    });

    it("honours always_use_account_email_id_as_sender / _name_as_sender_name and add_signature", () => {
        const sender = accountSender(
            { ...account, always_use_account_email_id_as_sender: true, always_use_account_name_as_sender_name: true, add_signature: false },
            { name: "Jane Doe", email: "jane@acme.test" },
        );
        expect(sender.from).toBe('"Acme Sales" <sales@acme.test>');
        expect(sender.replyTo).toBeUndefined();
        expect(sender.signature).toBeNull();
    });
});

describe("platformSender", () => {
    it("uses RESEND_API_KEY and EMAIL_FROM", () => {
        expect(platformSender({ RESEND_API_KEY: "re_platform", EMAIL_FROM: "ERP <no-reply@erp.test>" })).toMatchObject({
            accountId: null,
            apiKey: "re_platform",
            from: "ERP <no-reply@erp.test>",
        });
    });

    it("is unavailable without configuration, except in dry-run mode", () => {
        expect(platformSender({})).toBeNull();
        expect(platformSender({ EMAIL_DRY_RUN: "1" })?.from).toBe("no-reply@example.invalid");
    });
});

describe("formatting", () => {
    it("quotes display names and strips header-breaking characters", () => {
        expect(formatAddress('Jane "JD" <Doe>\r\n', "jane@x.test")).toBe('"Jane JD Doe" <jane@x.test>');
        expect(formatAddress(null, "jane@x.test")).toBe("jane@x.test");
    });

    it("appends the signature and footer", () => {
        expect(withSignature("<p>Body</p>", { signature: "<p>Sig</p>", footer: "<small>F</small>" })).toBe(
            '<p>Body</p>\n<div class="signature"><p>Sig</p></div>\n<small>F</small>',
        );
        expect(withSignature("<p>Body</p>", { signature: null, footer: null })).toBe("<p>Body</p>");
    });
});
