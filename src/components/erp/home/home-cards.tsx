import { BarChart03 } from "@untitledui/icons";

/**
 * Home number cards (Annual Sales, Annual Purchase, Total Stock Value; erpnext/setup/workspace/home/home.json). They
 * show as placeholders until the phase that owns their data wires them to `app.home_number_cards()`.
 */
const NUMBER_CARDS = [
    { label: "Annual Sales", hint: "Submitted Sales Orders this year", phase: "P5" },
    { label: "Annual Purchase", hint: "Submitted Purchase Orders this year", phase: "P6" },
    { label: "Total Stock Value", hint: "Value of the stock in all warehouses", phase: "P4" },
] as const;

export function NumberCards() {
    return (
        <div className="grid grid-cols-1 gap-4 md:grid-cols-3">
            {NUMBER_CARDS.map((card) => (
                <section
                    key={card.label}
                    aria-label={card.label}
                    className="flex flex-col gap-2 rounded-xl bg-primary p-5 ring-1 ring-secondary"
                >
                    <h2 className="text-sm font-medium text-tertiary">{card.label}</h2>
                    <p className="text-display-xs font-semibold text-quaternary tabular-nums">—</p>
                    <p className="text-xs text-tertiary">
                        {card.hint}. Available in phase {card.phase}.
                    </p>
                </section>
            ))}
        </div>
    );
}

/** "Profit and Loss" dashboard chart (erpnext/accounts/dashboard_chart/profit_and_loss): empty until P3. */
export function ProfitAndLossChart() {
    return (
        <section aria-label="Profit and Loss" className="flex flex-col gap-4 rounded-xl bg-primary p-5 ring-1 ring-secondary">
            <h2 className="text-md font-semibold text-primary">Profit and Loss</h2>
            <div className="flex flex-col items-center justify-center gap-2 rounded-lg bg-secondary py-12 text-center">
                <BarChart03 aria-hidden="true" className="size-6 text-fg-quaternary" />
                <p className="text-sm text-tertiary">Your income and expenses over the year, and what's left as profit.</p>
                <p className="text-xs text-quaternary">Available in phase P3.</p>
            </div>
        </section>
    );
}
