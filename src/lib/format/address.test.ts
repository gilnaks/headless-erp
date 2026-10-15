import { describe, expect, it } from "vitest";
import { formatAddress } from "./address";

const base = { address_line1: "1 Main St", address_line2: "Suite 2", city: "Springfield", pincode: "12345" };

describe("formatAddress", () => {
    it("uses the default template for countries without one", () => {
        expect(formatAddress({ ...base, state: "Metro", country: "Philippines", phone: "123", fax: "", email_id: "a@b.co" })).toEqual([
            "1 Main St",
            "Suite 2",
            "Springfield",
            "Metro",
            "12345",
            "Philippines",
            "Phone: 123",
            "Email: a@b.co",
        ]);
    });

    it("drops empty optional lines and trims values", () => {
        expect(formatAddress({ address_line1: " 1 Main St ", city: "Manila", country: "Philippines", state: null })).toEqual([
            "1 Main St",
            "Manila",
            "Philippines",
        ]);
    });

    it.each(["Germany", "Bosnia and Herzegovina", "Croatia", "Denmark", "Sweden", "Switzerland"])(
        "puts the postcode before the upper-cased city for %s",
        (country) => {
            expect(formatAddress({ ...base, country, phone: "123" })).toEqual([
                "1 Main St",
                "Suite 2",
                "12345 SPRINGFIELD",
                country.toUpperCase(),
            ]);
        },
    );

    it("prefixes Luxembourg postcodes with L-", () => {
        expect(formatAddress({ address_line1: "2 Rue", city: "Luxembourg", pincode: "1234", country: "Luxembourg" })).toEqual([
            "2 Rue",
            "L-1234 Luxembourg",
            "LUXEMBOURG",
        ]);
    });

    it("writes Taiwan addresses country first, largest unit first", () => {
        expect(
            formatAddress({ address_line1: "Road 1", city: "Taipei", county: "Da'an", pincode: "106", country: "Taiwan", fax: "9" }),
        ).toEqual(["Taiwan", "106", "Da'anTaipeiRoad 1", "Fax: 9"]);
    });

    it("writes United States addresses as City, State ZIP and omits the country", () => {
        expect(formatAddress({ ...base, state: "IL", country: "United States" })).toEqual([
            "1 Main St",
            "Suite 2",
            "Springfield, IL 12345",
        ]);
    });
});
