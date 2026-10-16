import { defineDoctype } from "../define";

/** ERPNext Warehouse. Names are "<warehouse name> - <abbr>". Stores is the company default. */
export const warehouse = defineDoctype({
    doctype: "Warehouse",
    table: "warehouse",
    module: "stock",
    slug: "warehouse",
    titleField: "name",
    fields: {
        name: { type: "Data", label: "Name", readOnly: true },
        warehouse_name: { type: "Data", label: "Warehouse Name", required: true },
        is_group: { type: "Check", label: "Is Group" },
        company_id: { type: "Link", label: "Company", target: "Company", required: true },
        parent_id: { type: "Link", label: "Parent Warehouse", target: "Warehouse" },
        account_id: { type: "Link", label: "Account", target: "Account" },
        warehouse_type_id: { type: "Link", label: "Warehouse Type", target: "Warehouse Type" },
        is_rejected_warehouse: { type: "Check", label: "Is Rejected Warehouse" },
        disabled: { type: "Check", label: "Disabled" },
        email_id: { type: "Data", label: "Email" },
        phone_no: { type: "Data", label: "Phone" },
        mobile_no: { type: "Data", label: "Mobile" },
        address_line_1: { type: "Data", label: "Address Line 1" },
        address_line_2: { type: "Data", label: "Address Line 2" },
        city: { type: "Data", label: "City" },
        state: { type: "Data", label: "State" },
        pin: { type: "Data", label: "Pin" },
    },
    tabs: [
        {
            label: "Details",
            sections: [
                {
                    columns: [
                        ["warehouse_name", "is_group", "company_id", "parent_id", "name"],
                        ["account_id", "warehouse_type_id", "is_rejected_warehouse", "disabled"],
                    ],
                },
                {
                    label: "Address",
                    columns: [
                        ["address_line_1", "address_line_2", "city", "state", "pin"],
                        ["email_id", "phone_no", "mobile_no"],
                    ],
                },
            ],
        },
    ],
    listView: {
        columns: ["name", "company_id", "parent_id", "warehouse_type_id", "is_group", "disabled"],
        searchFields: ["name", "warehouse_name"],
        defaultSort: { field: "name" },
    },
    tree: { parentField: "parent_id", groupField: "is_group", filters: ["company_id"], disabledField: "disabled" },
    errorFields: {
        duplicate: "warehouse_name",
        warehouse_parent: "parent_id",
        warehouse_account: "account_id",
        invalid_parent: "parent_id",
        has_children: "is_group",
    },
});
