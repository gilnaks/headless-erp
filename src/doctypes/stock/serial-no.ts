import { defineDoctype } from "../define";

/** ERPNext Serial No. The warehouse is the latest inward that has not gone out. */
export const serialNo = defineDoctype<"serial_no">({
    doctype: "Serial No",
    table: "serial_no",
    module: "stock",
    slug: "serial-no",
    titleField: "serial_no",
    fields: {
        name: { type: "Data", label: "Name", readOnly: true },
        serial_no: { type: "Data", label: "Serial No", required: true },
        item_id: { type: "Link", label: "Item", target: "Item", required: true },
        company_id: { type: "Link", label: "Company", target: "Company", required: true },
        warehouse_id: { type: "Link", label: "Warehouse", target: "Warehouse", readOnly: true },
        batch_id: { type: "Link", label: "Batch", target: "Batch" },
        purchase_rate: { type: "Currency", label: "Purchase Rate", readOnly: true },
        customer_id: { type: "Link", label: "Customer", target: "Customer", readOnly: true },
        warranty_expiry_date: { type: "Date", label: "Warranty Expiry Date" },
    },
    tabs: [
        {
            label: "Details",
            sections: [
                {
                    columns: [
                        ["serial_no", "item_id", "company_id", "warehouse_id"],
                        ["batch_id", "purchase_rate", "customer_id", "warranty_expiry_date", "name"],
                    ],
                },
            ],
        },
    ],
    listView: {
        columns: ["serial_no", "item_id", "warehouse_id", "company_id"],
        searchFields: ["serial_no", "name"],
        defaultSort: { field: "serial_no" },
    },
    errorFields: { serial_no: "serial_no", serial_item: "item_id" },
});
