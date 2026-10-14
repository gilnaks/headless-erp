import { describe, expect, it } from "vitest";
import { authErrorMessage, dbError } from "./errors";

describe("dbError", () => {
    it("splits app exceptions into code and message", () => {
        expect(dbError({ code: "P0001", message: "slug_taken: this URL is already in use" })).toEqual({
            code: "slug_taken",
            message: "this URL is already in use",
        });
    });

    it("maps permission errors", () => {
        expect(dbError({ code: "42501", message: "permission denied for table x" }).code).toBe("permission_denied");
    });

    it("maps unique and foreign key violations without leaking constraint names", () => {
        expect(dbError({ code: "23505", message: 'duplicate key value violates unique constraint "x"' })).toEqual({
            code: "duplicate",
            message: "A record with this name already exists.",
        });
        expect(dbError({ code: "23503", message: 'update or delete on table "companies" violates foreign key' }).code).toBe("linked");
    });

    it("hides other raw database errors", () => {
        expect(dbError({ code: "22P02", message: 'invalid input syntax for type uuid: "x"' })).toEqual({
            code: "unknown",
            message: "Something went wrong. Try again.",
        });
    });
});

describe("authErrorMessage", () => {
    it("maps known codes and falls back to the message", () => {
        expect(authErrorMessage({ code: "invalid_credentials", message: "Invalid login credentials" })).toBe(
            "Incorrect email or password.",
        );
        expect(authErrorMessage({ code: "something_new", message: "Raw" })).toBe("Raw");
        expect(authErrorMessage(null)).toBe("Something went wrong. Try again.");
    });
});
