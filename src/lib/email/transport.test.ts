import { afterEach, describe, expect, it, vi } from "vitest";

const { sendViaResend } = await import("./transport");

const message = { from: '"Acme" <hello@acme.test>', to: ["jane@x.test"], subject: "Hi", html: "<p>Hi</p>" };

function fakeFetch(status: number, body: unknown) {
    return vi.fn(async () => new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } }));
}

afterEach(() => {
    vi.unstubAllEnvs();
});

describe("sendViaResend", () => {
    it("posts the message to Resend with the account key", async () => {
        const fetchImpl = fakeFetch(200, { id: "msg_1" });
        const result = await sendViaResend("re_key", { ...message, cc: ["cc@x.test"], replyTo: "me@x.test" }, fetchImpl);
        expect(result).toEqual({ ok: true, id: "msg_1" });
        const [url, init] = fetchImpl.mock.calls[0] as unknown as [string, RequestInit];
        expect(url).toBe("https://api.resend.com/emails");
        expect((init.headers as Record<string, string>).Authorization).toBe("Bearer re_key");
        expect(JSON.parse(String(init.body))).toEqual({
            from: '"Acme" <hello@acme.test>',
            to: ["jane@x.test"],
            cc: ["cc@x.test"],
            subject: "Hi",
            html: "<p>Hi</p>",
            reply_to: "me@x.test",
        });
    });

    it("returns the provider's error message", async () => {
        const result = await sendViaResend("re_key", message, fakeFetch(403, { message: "The domain is not verified." }));
        expect(result).toEqual({ ok: false, error: "The domain is not verified." });
    });

    it("reports network failures", async () => {
        const fetchImpl = vi.fn(async () => {
            throw new Error("offline");
        });
        const result = await sendViaResend("re_key", message, fetchImpl);
        expect(result).toEqual({ ok: false, error: "Could not reach the email provider: offline" });
    });

    it("sends nothing in dry-run mode", async () => {
        vi.stubEnv("EMAIL_DRY_RUN", "1");
        const fetchImpl = fakeFetch(200, { id: "msg_1" });
        const result = await sendViaResend("re_key", message, fetchImpl);
        expect(result.ok && result.id.startsWith("dry-run-")).toBe(true);
        expect(fetchImpl).not.toHaveBeenCalled();
    });
});
