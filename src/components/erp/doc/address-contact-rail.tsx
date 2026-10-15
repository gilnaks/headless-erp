"use client";

import { Plus } from "@untitledui/icons";
import Link from "next/link";
import { type ReactNode, useEffect, useState } from "react";
import { Badge } from "@/components/base/badges/badges";
import { getAddressesAndContacts, type PartyAddress, type PartyContact } from "@/lib/actions/party";

type RailProps = { orgSlug: string; doctype: string; id: string };

type RailState =
    | { status: "loading" }
    | { status: "error"; message: string }
    | { status: "ready"; addresses: PartyAddress[]; contacts: PartyContact[] };

/** `/setup/<slug>/new` pre-filled with one link row to this party (`prefillValues` table-row keys). */
function newHref(orgSlug: string, slug: string, doctype: string, id: string) {
    const query = new URLSearchParams({ "links.link_doctype": doctype, "links.link_id": id });
    return `/${orgSlug}/setup/${slug}/new?${query}`;
}

function Card({ title, item, href, children }: { title: string; item: string; href: string; children: ReactNode }) {
    return (
        <section aria-label={title} className="flex flex-col gap-3 rounded-xl bg-primary p-4 ring-1 ring-secondary">
            <div className="flex items-center justify-between gap-2">
                <h2 className="text-sm font-semibold text-primary">{title}</h2>
                <Link
                    href={href}
                    className="flex items-center gap-1 rounded-md px-1.5 py-0.5 text-xs font-semibold text-brand-secondary outline-focus-ring hover:text-brand-secondary_hover focus-visible:outline-2"
                >
                    <Plus aria-hidden="true" className="size-3.5" />
                    New<span className="sr-only"> {item}</span>
                </Link>
            </div>
            {children}
        </section>
    );
}

function Empty({ children }: { children: ReactNode }) {
    return <p className="text-sm text-tertiary">{children}</p>;
}

/**
 * ERPNext party forms' Address & Contact section (`load_address_and_contact` + `frappe.contacts.render_address_and_contact`):
 * cards for the saved party's addresses and contacts, primary first, with "+ New" pre-linked to the party.
 */
export function AddressContactRail({ orgSlug, doctype, id }: RailProps) {
    const [state, setState] = useState<RailState>({ status: "loading" });

    useEffect(() => {
        let active = true;
        setState({ status: "loading" });
        void getAddressesAndContacts({ orgSlug, doctype, id }).then((result) => {
            if (!active) return;
            if (!result.ok) setState({ status: "error", message: result.error });
            else setState({ status: "ready", addresses: result.data?.addresses ?? [], contacts: result.data?.contacts ?? [] });
        });
        return () => {
            active = false;
        };
    }, [orgSlug, doctype, id]);

    const body = (render: (s: Extract<RailState, { status: "ready" }>) => ReactNode) => {
        if (state.status === "loading") {
            return (
                <div className="flex flex-col gap-2" aria-busy="true">
                    <span className="sr-only">Loading</span>
                    <div className="h-3 w-2/3 animate-pulse rounded bg-secondary" />
                    <div className="h-3 w-1/2 animate-pulse rounded bg-secondary" />
                </div>
            );
        }
        if (state.status === "error") return <p className="text-sm text-error-primary">{state.message}</p>;
        return render(state);
    };

    return (
        <aside aria-label="Address and contacts" className="flex flex-col gap-4">
            <Card title="Addresses" item="Address" href={newHref(orgSlug, "address", doctype, id)}>
                {body(({ addresses }) =>
                    addresses.length === 0 ? (
                        <Empty>No address yet.</Empty>
                    ) : (
                        <ul className="flex flex-col divide-y divide-secondary">
                            {addresses.map((a) => (
                                <li key={a.id} className="flex flex-col gap-1 py-2 first:pt-0 last:pb-0">
                                    <div className="flex flex-wrap items-center gap-1.5">
                                        <Link
                                            href={`/${orgSlug}/setup/address/${a.id}`}
                                            className="text-sm font-medium text-primary hover:underline"
                                        >
                                            {a.name}
                                        </Link>
                                        {a.isPrimary && (
                                            <Badge size="sm" color="brand">
                                                Preferred Billing
                                            </Badge>
                                        )}
                                        {a.isShipping && (
                                            <Badge size="sm" color="gray">
                                                Preferred Shipping
                                            </Badge>
                                        )}
                                        {a.disabled && (
                                            <Badge size="sm" color="warning">
                                                Disabled
                                            </Badge>
                                        )}
                                    </div>
                                    <address className="text-sm text-tertiary not-italic">
                                        {a.lines.map((line, i) => (
                                            // biome-ignore lint/suspicious/noArrayIndexKey: address lines can repeat and never reorder
                                            <span key={i} className="block">
                                                {line}
                                            </span>
                                        ))}
                                    </address>
                                </li>
                            ))}
                        </ul>
                    ),
                )}
            </Card>
            <Card title="Contacts" item="Contact" href={newHref(orgSlug, "contact", doctype, id)}>
                {body(({ contacts }) =>
                    contacts.length === 0 ? (
                        <Empty>No contact yet.</Empty>
                    ) : (
                        <ul className="flex flex-col divide-y divide-secondary">
                            {contacts.map((c) => (
                                <li key={c.id} className="flex flex-col gap-1 py-2 first:pt-0 last:pb-0">
                                    <div className="flex flex-wrap items-center gap-1.5">
                                        <Link
                                            href={`/${orgSlug}/setup/contact/${c.id}`}
                                            className="text-sm font-medium text-primary hover:underline"
                                        >
                                            {c.fullName}
                                        </Link>
                                        {c.isPrimary && (
                                            <Badge size="sm" color="brand">
                                                Primary
                                            </Badge>
                                        )}
                                    </div>
                                    <div className="flex flex-col text-sm text-tertiary">
                                        {c.email && <span className="break-all">{c.email}</span>}
                                        {c.phone && <span className="tabular-nums">{c.phone}</span>}
                                        {c.mobile && c.mobile !== c.phone && <span className="tabular-nums">{c.mobile}</span>}
                                    </div>
                                </li>
                            ))}
                        </ul>
                    ),
                )}
            </Card>
        </aside>
    );
}
