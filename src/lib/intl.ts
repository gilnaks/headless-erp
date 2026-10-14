/** IANA time zones known to the runtime (ERPNext stores IANA names), always including UTC. */
export function timeZoneOptions(): { id: string; label: string }[] {
    const zones = Intl.supportedValuesOf("timeZone");
    return (zones.includes("UTC") ? zones : ["UTC", ...zones]).map((zone) => ({ id: zone, label: zone }));
}

export function browserTimeZone(): string {
    return Intl.DateTimeFormat().resolvedOptions().timeZone || "UTC";
}
