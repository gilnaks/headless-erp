import type { SupabaseClient } from "@supabase/supabase-js";
import { describe, expect, it, vi } from "vitest";
import { completeAuthCallback } from "./callback";

function client(result: { error: { message: string } | null }) {
    return {
        auth: {
            exchangeCodeForSession: vi.fn(async () => result),
            verifyOtp: vi.fn(async () => result),
        },
    } as unknown as SupabaseClient;
}

describe("auth callback", () => {
    it("exchanges a code and follows a safe next path", async () => {
        const supabase = client({ error: null });
        const next = await completeAuthCallback(new URLSearchParams("code=abc&next=/acme"), supabase);
        expect(next).toBe("/acme");
        expect(supabase.auth.exchangeCodeForSession).toHaveBeenCalledWith("abc");
    });

    it("verifies a token hash", async () => {
        const supabase = client({ error: null });
        const next = await completeAuthCallback(new URLSearchParams("token_hash=t&type=recovery&next=/update-password"), supabase);
        expect(next).toBe("/update-password");
        expect(supabase.auth.verifyOtp).toHaveBeenCalledWith({ token_hash: "t", type: "recovery" });
    });

    it("rejects a missing or failed link and drops an off-site next", async () => {
        expect(await completeAuthCallback(new URLSearchParams("next=https://evil.test"), client({ error: null }))).toBe(
            "/login?error=link_invalid",
        );
        expect(await completeAuthCallback(new URLSearchParams("code=abc&next=//evil.test"), client({ error: { message: "nope" } }))).toBe(
            "/login?error=link_invalid",
        );
    });
});
