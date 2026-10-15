"use server";

import { LINK_DOCTYPES } from "@/doctypes/setup/address";
import { requireUser } from "@/lib/auth/claims";
import { type ActionResult, fail } from "@/lib/errors";
import { formatAddress } from "@/lib/format/address";
import { createClient } from "@/lib/supabase/server";

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export type PartyAddress = {
    id: string;
    name: string;
    addressType: string;
    lines: string[];
    isPrimary: boolean;
    isShipping: boolean;
    disabled: boolean;
};

export type PartyContact = {
    id: string;
    name: string;
    fullName: string;
    email: string | null;
    phone: string | null;
    mobile: string | null;
    isPrimary: boolean;
};

/**
 * ERPNext `load_address_and_contact`: the addresses and contacts linked to a party, primary first
 * (`app.party_addresses` / `app.party_contacts`; RLS decides what the caller sees).
 */
export async function getAddressesAndContacts(input: {
    orgSlug: string;
    doctype: string;
    id: string;
}): Promise<ActionResult<{ addresses: PartyAddress[]; contacts: PartyContact[] }>> {
    await requireUser(`/${input.orgSlug}`);
    if (!(LINK_DOCTYPES as readonly string[]).includes(input.doctype) || !UUID.test(input.id)) return fail("Not a party.");

    const supabase = await createClient();
    const args = { p_doctype: input.doctype, p_id: input.id };
    const [addresses, contacts] = await Promise.all([supabase.rpc("party_addresses", args), supabase.rpc("party_contacts", args)]);
    if (addresses.error || contacts.error) return fail("Could not load addresses and contacts.");

    return {
        ok: true,
        data: {
            addresses: (addresses.data ?? []).map((a) => ({
                id: a.id,
                name: a.name ?? a.address_title ?? "",
                addressType: a.address_type,
                lines: formatAddress(a),
                isPrimary: a.is_primary_address,
                isShipping: a.is_shipping_address,
                disabled: a.disabled,
            })),
            contacts: (contacts.data ?? []).map((c) => ({
                id: c.id,
                name: c.name ?? c.full_name ?? c.first_name,
                fullName: c.full_name ?? c.first_name,
                email: c.email_id,
                phone: c.phone,
                mobile: c.mobile_no,
                isPrimary: c.is_primary_contact,
            })),
        },
    };
}
