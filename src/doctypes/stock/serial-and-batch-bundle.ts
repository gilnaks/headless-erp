import { defineChildDoctype, defineDoctype } from "../define";

export const serialAndBatchEntry = defineChildDoctype<"serial_and_batch_entry">({
    doctype: "Serial and Batch Entry",
    table: "serial_and_batch_entry",
    fields: {
        serial_no_id: { type: "Link", label: "Serial No", target: "Serial No" },
        batch_id: { type: "Link", label: "Batch", target: "Batch" },
        qty: { type: "Float", label: "Qty", required: true },
        incoming_rate: { type: "Currency", label: "Incoming Rate" },
    },
    columns: ["serial_no_id", "batch_id", "qty", "incoming_rate"],
});

/** ERPNext Serial and Batch Bundle. Stock Entry and Stock Reconciliation create it on submit. */
export const serialAndBatchBundle = defineDoctype<"serial_and_batch_bundle", "entries">({
    doctype: "Serial and Batch Bundle",
    table: "serial_and_batch_bundle",
    module: "stock",
    slug: "serial-and-batch-bundle",
    titleField: "name",
    submittable: true,
    fields: {
        name: { type: "Data", label: "Name", readOnly: true },
        naming_series: { type: "Data", label: "Series", readOnly: true, default: "SABB-.########" },
        item_id: { type: "Link", label: "Item", target: "Item", required: true },
        company_id: { type: "Link", label: "Company", target: "Company", required: true },
        warehouse_id: { type: "Link", label: "Warehouse", target: "Warehouse", required: true },
        voucher_type: { type: "Data", label: "Voucher Type", required: true },
        voucher_id: { type: "Data", label: "Voucher" },
        type_of_transaction: {
            type: "Select",
            label: "Type of Transaction",
            options: ["Inward", "Outward"],
            required: true,
        },
        posting_datetime: { type: "Data", label: "Posting Datetime", readOnly: true },
        total_qty: { type: "Float", label: "Total Qty", readOnly: true },
    },
    children: { entries: serialAndBatchEntry },
    tabs: [
        {
            label: "Details",
            sections: [
                {
                    columns: [
                        ["item_id", "warehouse_id", "company_id", "type_of_transaction"],
                        ["voucher_type", "voucher_id", "posting_datetime", "total_qty", "naming_series", "name"],
                    ],
                },
                { label: "Entries", columns: [["entries"]] },
            ],
        },
    ],
    listView: {
        columns: ["name", "item_id", "warehouse_id", "type_of_transaction", "total_qty"],
        searchFields: ["name", "voucher_type"],
        defaultSort: { field: "name", desc: true },
    },
    errorFields: {
        sabb_qty: "entries",
        sabb_row: "entries",
        sabb_type: "type_of_transaction",
        sabb_status: "name",
    },
});
