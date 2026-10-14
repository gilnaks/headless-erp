import { describe, expect, it } from "vitest";
import { MIN_PASSWORD_LENGTH, passwordLoginSchema, signupSchema, updatePasswordSchema } from "./auth";
import { createOrganizationSchema, RESERVED_SLUGS, SLUG_PATTERN, slugify } from "./organization";
import { createInvitationSchema, removeMemberSchema, setMemberStatusSchema, updateMemberRolesSchema } from "./users";

describe("auth schemas", () => {
    it("normalises email", () => {
        const parsed = passwordLoginSchema.parse({ email: "  Jane@Example.COM ", password: "x" });
        expect(parsed.email).toBe("jane@example.com");
    });

    it("rejects bad email and empty password", () => {
        const result = passwordLoginSchema.safeParse({ email: "nope", password: "" });
        expect(result.success).toBe(false);
        expect(result.error?.issues.map((i) => i.path[0])).toEqual(["email", "password"]);
    });

    it("enforces the password minimum on signup", () => {
        const base = { first_name: "Jane", last_name: "", email: "jane@example.com" };
        expect(signupSchema.safeParse({ ...base, password: "x".repeat(MIN_PASSWORD_LENGTH - 1) }).success).toBe(false);
        expect(signupSchema.safeParse({ ...base, password: "x".repeat(MIN_PASSWORD_LENGTH) }).success).toBe(true);
        expect(signupSchema.safeParse({ ...base, first_name: " ", password: "x".repeat(MIN_PASSWORD_LENGTH) }).success).toBe(false);
    });

    it("requires matching passwords on update", () => {
        const result = updatePasswordSchema.safeParse({ password: "longenough", confirm: "different" });
        expect(result.success).toBe(false);
        expect(result.error?.issues[0]?.path).toEqual(["confirm"]);
    });
});

describe("organization schema", () => {
    const valid = { name: "Acme", slug: "acme", country: "Netherlands", default_currency: "eur", time_zone: "Europe/Amsterdam" };

    it("accepts and normalises a valid organization", () => {
        expect(createOrganizationSchema.parse(valid)).toMatchObject({ slug: "acme", default_currency: "EUR" });
    });

    it.each(["ab", "Has Space", "a".repeat(41), "under_score"])("rejects slug %s", (slug) => {
        expect(createOrganizationSchema.safeParse({ ...valid, slug }).success).toBe(false);
    });

    it.each(RESERVED_SLUGS)("rejects reserved slug %s", (slug) => {
        expect(createOrganizationSchema.safeParse({ ...valid, slug }).success).toBe(false);
    });

    it.each([
        ["Acme Inc.", "acme-inc"],
        ["  Café Zürich GmbH ", "cafe-zurich-gmbh"],
        ["---", ""],
        ["x".repeat(50), "x".repeat(40)],
    ])("slugify(%s) = %s", (input, expected) => {
        expect(slugify(input)).toBe(expected);
    });

    it("slugify output satisfies the pattern for ordinary names", () => {
        expect(SLUG_PATTERN.test(slugify("Northwind Traders"))).toBe(true);
    });
});

describe("user schemas", () => {
    const member = { orgSlug: "acme", userId: "00000000-0000-0000-0000-0000000011a1" };

    it("trims and dedupes roles and treats a blank profile as none", () => {
        const parsed = updateMemberRolesSchema.parse({ ...member, roleProfile: " ", roles: [" Sales User", "Sales User", "Auditor"] });
        expect(parsed).toMatchObject({ roleProfile: null, roles: ["Sales User", "Auditor"] });
    });

    it("rejects malformed user ids and blank roles", () => {
        expect(updateMemberRolesSchema.safeParse({ ...member, userId: "nope", roleProfile: null, roles: [] }).success).toBe(false);
        expect(updateMemberRolesSchema.safeParse({ ...member, roleProfile: null, roles: [" "] }).success).toBe(false);
    });

    it("only allows active or disabled status", () => {
        expect(setMemberStatusSchema.safeParse({ ...member, status: "disabled" }).success).toBe(true);
        expect(setMemberStatusSchema.safeParse({ ...member, status: "invited" }).success).toBe(false);
    });

    it("needs a user to remove", () => {
        expect(removeMemberSchema.safeParse({ orgSlug: "acme" }).success).toBe(false);
    });
});

describe("invitation schema", () => {
    const base = { orgSlug: "acme", email: " Jane@Example.COM ", roleProfile: null, roles: ["Sales User"] };

    it("normalises the email", () => {
        expect(createInvitationSchema.parse(base).email).toBe("jane@example.com");
    });

    it("needs roles or a profile", () => {
        const result = createInvitationSchema.safeParse({ ...base, roles: [] });
        expect(result.success).toBe(false);
        expect(result.error?.issues[0]?.path).toEqual(["roles"]);
        expect(createInvitationSchema.safeParse({ ...base, roles: [], roleProfile: "Sales" }).success).toBe(true);
    });

    it("rejects a malformed email", () => {
        expect(createInvitationSchema.safeParse({ ...base, email: "jane" }).success).toBe(false);
    });
});
