/** ISO 4217 currency codes known to the runtime, with English display names. */
export function currencyOptions(): { id: string; label: string; supportingText: string }[] {
    const names = new Intl.DisplayNames(["en"], { type: "currency" });
    return Intl.supportedValuesOf("currency").map((code) => ({ id: code, label: code, supportingText: names.of(code) ?? "" }));
}

/** IANA time zones known to the runtime (ERPNext stores IANA names), always including UTC. */
export function timeZoneOptions(): { id: string; label: string }[] {
    const zones = Intl.supportedValuesOf("timeZone");
    return (zones.includes("UTC") ? zones : ["UTC", ...zones]).map((zone) => ({ id: zone, label: zone }));
}

export function browserTimeZone(): string {
    return Intl.DateTimeFormat().resolvedOptions().timeZone || "UTC";
}
