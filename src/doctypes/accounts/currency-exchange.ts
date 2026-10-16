import { defineDoctype } from "../define";

/** ERPNext Currency Exchange. A missing rate returns 0; there is no network lookup. */
export const currencyExchange = defineDoctype({
    doctype: "Currency Exchange",
    table: "currency_exchange",
    module: "accounts",
    slug: "currency-exchange",
    titleField: "name",
    fields: {
        name: { type: "Data", label: "Name", readOnly: true },
        date: { type: "Date", label: "Date", required: true },
        from_currency: { type: "Select", label: "From Currency", options: "Currency", required: true },
        to_currency: { type: "Select", label: "To Currency", options: "Currency", required: true },
        exchange_rate: { type: "Float", label: "Exchange Rate", required: true },
        for_buying: { type: "Check", label: "For Buying", default: true },
        for_selling: { type: "Check", label: "For Selling", default: true },
    },
    tabs: [
        {
            label: "Details",
            sections: [
                {
                    columns: [
                        ["date", "from_currency", "to_currency", "exchange_rate"],
                        ["name", "for_buying", "for_selling"],
                    ],
                },
            ],
        },
    ],
    listView: {
        columns: ["name", "date", "from_currency", "to_currency", "exchange_rate"],
        searchFields: ["name", "from_currency", "to_currency"],
        defaultSort: { field: "date", desc: true },
    },
    errorFields: {
        duplicate: "date",
        currency_exchange_same: "to_currency",
        currency_exchange_rate: "exchange_rate",
        currency_exchange_side: "for_buying",
    },
});
