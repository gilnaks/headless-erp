import {
    Archive,
    Bank,
    BankNote01,
    BarChart10,
    BookOpen01,
    Building02,
    Building07,
    Calculator,
    CalendarCheck01,
    CheckSquare,
    ClipboardCheck,
    Clock,
    Database01,
    Dataflow03,
    File06,
    Folder,
    Home03,
    LayersThree01,
    Mail01,
    Move,
    Package,
    PackageCheck,
    Percent03,
    PiggyBank01,
    Printer,
    Receipt,
    Scales01,
    Settings01,
    ShieldTick,
    ShoppingBag01,
    ShoppingCart01,
    SwitchHorizontal01,
    Table,
    Tool01,
    TrendDown01,
    Truck01,
    Users01,
} from "@untitledui/icons";
import type { FC } from "react";

/**
 * Typed transcription of `erpnext/<module>/sidebar/<module>/<module>.json`, limited to in-scope items (PLAN §1).
 * Items dropped as out of scope: Accounting Dimension, Account Category, Financial Report Template, Pricing Rule, POS,
 * Quality Inspection, Item Attribute (variants), Inventory Dimension, Subcontracting BOM/Inward Order, BOM Creator,
 * BOM Comparison Tool, Downtime Entry, Plant Floor, and Setup › Data / Integrations / out-of-scope Settings.
 */

export type ModuleId = "setup" | "accounts" | "selling" | "buying" | "stock" | "manufacturing" | "projects" | "assets";

export type Phase = "P0" | "P1" | "P2" | "P3" | "P4" | "P5" | "P6" | "P7" | "P8" | "P9" | "P10";

export type NavTarget =
    | { kind: "workspace" }
    | { kind: "dashboard" }
    | { kind: "doctype"; doctype: string }
    | { kind: "report"; report: string }
    | { kind: "page"; page: string };

export type NavLink = {
    label: string;
    /** Path below `/[org]` (no leading slash). `""` is the org home. */
    path: string;
    target: NavTarget;
    /** Delivery phase (PLAN §7); everything renders a placeholder until then. */
    phase: Phase;
    icon?: FC<{ className?: string }>;
};

export type NavSection = {
    label: string;
    icon: FC<{ className?: string }>;
    items: NavLink[];
};

export type ModuleNav = {
    id: ModuleId;
    label: string;
    icon: FC<{ className?: string }>;
    /** Top-level links (ERPNext items without `child: 1`). */
    items: NavLink[];
    sections: NavSection[];
};

const doctype = (label: string, path: string, phase: Phase, doctypeName = label, icon?: NavLink["icon"]): NavLink => ({
    label,
    path,
    phase,
    icon,
    target: { kind: "doctype", doctype: doctypeName },
});

const report = (label: string, module: ModuleId, phase: Phase, reportName = label, icon?: NavLink["icon"]): NavLink => ({
    label,
    path: `${module}/reports/${slugify(reportName)}`,
    phase,
    icon,
    target: { kind: "report", report: reportName },
});

const home = (module: ModuleId, phase: Phase): NavLink => ({
    label: "Home",
    path: module,
    phase,
    icon: Home03,
    target: { kind: "workspace" },
});

const dashboard = (module: ModuleId, phase: Phase): NavLink => ({
    label: "Dashboard",
    path: `${module}/dashboard`,
    phase,
    icon: BarChart10,
    target: { kind: "dashboard" },
});

export function slugify(name: string): string {
    return name
        .toLowerCase()
        .replace(/[^a-z0-9]+/g, "-")
        .replace(/^-|-$/g, "");
}

export const MODULES: ModuleNav[] = [
    {
        id: "accounts",
        label: "Accounting",
        icon: Calculator,
        items: [
            home("accounts", "P3"),
            dashboard("accounts", "P3"),
            doctype("Chart of Accounts", "accounts/account", "P2", "Account", BookOpen01),
            doctype("Sales Invoice", "accounts/sales-invoice", "P5", "Sales Invoice", Receipt),
            doctype("Purchase Invoice", "accounts/purchase-invoice", "P6", "Purchase Invoice", Receipt),
            doctype("Payment Entry", "accounts/payment-entry", "P3", "Payment Entry", BankNote01),
            doctype("Journal Entry", "accounts/journal-entry", "P3", "Journal Entry", File06),
        ],
        sections: [
            {
                label: "Reports",
                icon: Table,
                items: [
                    report("General Ledger", "accounts", "P3"),
                    report("Trial Balance", "accounts", "P3"),
                    report("Trial Balance for Party", "accounts", "P3"),
                    report("Profit and Loss", "accounts", "P3", "Profit and Loss Statement"),
                    report("Balance Sheet", "accounts", "P3"),
                    report("Cash Flow", "accounts", "P3"),
                    report("Consolidated Report", "accounts", "P3", "Consolidated Financial Statement"),
                    report("Profitability Analysis", "accounts", "P3"),
                    report("Accounts Receivable", "accounts", "P7"),
                    report("Accounts Payable", "accounts", "P7"),
                ],
            },
            {
                label: "Banking",
                icon: Bank,
                items: [
                    {
                        label: "Banking",
                        path: "accounts/bank-reconciliation",
                        phase: "P7",
                        target: { kind: "page", page: "bank-reconciliation" },
                    },
                    doctype("Bank Account", "accounts/bank-account", "P7"),
                    doctype("Bank Clearance", "accounts/bank-clearance", "P7"),
                ],
            },
            {
                label: "Taxes",
                icon: Percent03,
                items: [
                    doctype("Sales Tax Template", "accounts/sales-taxes-and-charges-template", "P2", "Sales Taxes and Charges Template"),
                    doctype(
                        "Purchase Tax Template",
                        "accounts/purchase-taxes-and-charges-template",
                        "P2",
                        "Purchase Taxes and Charges Template",
                    ),
                    doctype("Item Tax Template", "accounts/item-tax-template", "P2"),
                    doctype("Tax Rule", "accounts/tax-rule", "P2"),
                    doctype("Tax Withholding Category", "accounts/tax-withholding-category", "P7"),
                ],
            },
            {
                label: "Budgeting",
                icon: PiggyBank01,
                items: [
                    doctype("Budget", "accounts/budget", "P7"),
                    doctype("Cost Center Allocation", "accounts/cost-center-allocation", "P7"),
                    doctype("Monthly Distribution", "accounts/monthly-distribution", "P7"),
                    report("Budget Variance", "accounts", "P7", "Budget Variance Report"),
                ],
            },
            {
                label: "Setup",
                icon: Database01,
                items: [
                    doctype("Company", "setup/company", "P1"),
                    doctype("Fiscal Year", "accounts/fiscal-year", "P2"),
                    doctype("Chart of Cost Centers", "accounts/cost-center", "P2", "Cost Center"),
                    doctype("Mode of Payment", "accounts/mode-of-payment", "P2"),
                    doctype("Payment Terms Template", "accounts/payment-terms-template", "P2"),
                    doctype("Currency Exchange", "accounts/currency-exchange", "P2"),
                    doctype("Settings", "accounts/settings", "P3", "Accounts Settings"),
                ],
            },
        ],
    },
    {
        id: "selling",
        label: "Selling",
        icon: ShoppingBag01,
        items: [
            home("selling", "P5"),
            dashboard("selling", "P5"),
            doctype("Customer", "selling/customer", "P2", "Customer", Users01),
            doctype("Quotation", "selling/quotation", "P5", "Quotation", File06),
            doctype("Sales Order", "selling/sales-order", "P5", "Sales Order", ShoppingCart01),
            doctype("Delivery Note", "selling/delivery-note", "P5", "Delivery Note", Truck01),
            doctype("Sales Invoice", "selling/sales-invoice", "P5", "Sales Invoice", Receipt),
        ],
        sections: [
            {
                label: "Reports",
                icon: Table,
                items: [
                    report("Sales Analytics", "selling", "P5"),
                    report("Sales Register", "selling", "P5"),
                    report("Accounts Receivable", "selling", "P7"),
                    report("Accounts Receivable Summary", "selling", "P7"),
                    report("Gross Profit", "selling", "P5"),
                ],
            },
            {
                label: "Items",
                icon: Package,
                items: [doctype("Item", "selling/item", "P2"), doctype("Price List", "selling/price-list", "P2")],
            },
            {
                label: "Setup",
                icon: Database01,
                items: [
                    doctype("Customer Group", "selling/customer-group", "P2"),
                    doctype("Territory", "selling/territory", "P2"),
                    doctype("Sales Person", "selling/sales-person", "P2"),
                    doctype("Settings", "selling/settings", "P5", "Selling Settings"),
                ],
            },
        ],
    },
    {
        id: "buying",
        label: "Buying",
        icon: ShoppingCart01,
        items: [
            home("buying", "P6"),
            dashboard("buying", "P6"),
            doctype("Supplier", "buying/supplier", "P2", "Supplier", Truck01),
            doctype("Material Request", "buying/material-request", "P4", "Material Request", ClipboardCheck),
            doctype("Request for Quotation", "buying/request-for-quotation", "P6", "Request for Quotation", File06),
            doctype("Supplier Quotation", "buying/supplier-quotation", "P6", "Supplier Quotation", File06),
            doctype("Purchase Order", "buying/purchase-order", "P6", "Purchase Order", ShoppingCart01),
            doctype("Purchase Receipt", "buying/purchase-receipt", "P6", "Purchase Receipt", PackageCheck),
            doctype("Purchase Invoice", "buying/purchase-invoice", "P6", "Purchase Invoice", Receipt),
        ],
        sections: [
            {
                label: "Reports",
                icon: Table,
                items: [
                    report("Purchase Analytics", "buying", "P6"),
                    report("Purchase Order Analysis", "buying", "P6"),
                    report("Purchase Register", "buying", "P6"),
                    report("Supplier Quotation Comparison", "buying", "P6"),
                    report("Accounts Payable", "buying", "P7"),
                    report("Accounts Payable Summary", "buying", "P7"),
                ],
            },
            {
                label: "Items",
                icon: Package,
                items: [
                    doctype("Item", "buying/item", "P2"),
                    doctype("Item Group", "buying/item-group", "P2"),
                    doctype("Price List", "buying/price-list", "P2"),
                ],
            },
            {
                label: "Setup",
                icon: Database01,
                items: [
                    doctype("Supplier Group", "buying/supplier-group", "P2"),
                    doctype("Supplier Scorecard", "buying/supplier-scorecard", "P6"),
                    doctype("Settings", "buying/settings", "P6", "Buying Settings"),
                ],
            },
        ],
    },
    {
        id: "stock",
        label: "Stock",
        icon: Package,
        items: [
            home("stock", "P4"),
            dashboard("stock", "P4"),
            doctype("Item", "stock/item", "P2", "Item", Package),
            doctype("Warehouse", "stock/warehouse", "P2", "Warehouse", Building02),
            doctype("Material Request", "stock/material-request", "P4", "Material Request", ClipboardCheck),
            doctype("Stock Entry", "stock/stock-entry", "P4", "Stock Entry", SwitchHorizontal01),
            doctype("Stock Reconciliation", "stock/stock-reconciliation", "P4", "Stock Reconciliation", Scales01),
            doctype("Purchase Receipt", "stock/purchase-receipt", "P6", "Purchase Receipt", PackageCheck),
            doctype("Delivery Note", "stock/delivery-note", "P5", "Delivery Note", Truck01),
        ],
        sections: [
            {
                label: "Reports",
                icon: Table,
                items: [
                    report("Stock Ledger", "stock", "P4"),
                    report("Stock Balance", "stock", "P4"),
                    report("Stock Projected Qty", "stock", "P4"),
                    report("Stock Ageing", "stock", "P4"),
                    report("Stock Analytics", "stock", "P4"),
                ],
            },
            {
                label: "Tools",
                icon: Tool01,
                items: [
                    doctype("Pick List", "stock/pick-list", "P5"),
                    doctype("Landed Cost Voucher", "stock/landed-cost-voucher", "P6"),
                    doctype("Packing Slip", "stock/packing-slip", "P5"),
                ],
            },
            {
                label: "Serial & Batch",
                icon: LayersThree01,
                items: [
                    doctype("Serial No", "stock/serial-no", "P4"),
                    doctype("Batch No", "stock/batch", "P4", "Batch"),
                    doctype("Serial and Batch Bundle", "stock/serial-and-batch-bundle", "P4"),
                ],
            },
            {
                label: "Setup",
                icon: Database01,
                items: [
                    doctype("Item Group", "stock/item-group", "P2"),
                    doctype("Brand", "stock/brand", "P2"),
                    doctype("Unit of Measure (UOM)", "stock/uom", "P2", "UOM"),
                    doctype("Settings", "stock/settings", "P4", "Stock Settings"),
                ],
            },
        ],
    },
    {
        id: "manufacturing",
        label: "Manufacturing",
        icon: Building07,
        items: [
            home("manufacturing", "P8"),
            dashboard("manufacturing", "P8"),
            doctype("BOM", "manufacturing/bom", "P8", "BOM", Dataflow03),
            doctype("Production Plan", "manufacturing/production-plan", "P8", "Production Plan", CalendarCheck01),
            doctype("Work Order", "manufacturing/work-order", "P8", "Work Order", Building07),
            doctype("Job Card", "manufacturing/job-card", "P8", "Job Card", ClipboardCheck),
            doctype("Stock Entry", "manufacturing/stock-entry", "P4", "Stock Entry", SwitchHorizontal01),
        ],
        sections: [
            {
                label: "Reports",
                icon: Table,
                items: [
                    report("Production Analytics", "manufacturing", "P8"),
                    report("Work Order Summary", "manufacturing", "P8"),
                    report("Job Card Summary", "manufacturing", "P8"),
                    report("Production Planning Report", "manufacturing", "P8"),
                    report("Material Requirements Planning Report", "manufacturing", "P8"),
                ],
            },
            {
                label: "Subcontracting",
                icon: ShoppingBag01,
                items: [
                    doctype("Subcontracting Order", "manufacturing/subcontracting-order", "P8"),
                    doctype("Subcontracting Receipt", "manufacturing/subcontracting-receipt", "P8"),
                ],
            },
            {
                label: "Tools",
                icon: Tool01,
                items: [doctype("BOM Update Tool", "manufacturing/bom-update-tool", "P8")],
            },
            {
                label: "Setup",
                icon: Database01,
                items: [
                    doctype("Workstation", "manufacturing/workstation", "P8"),
                    doctype("Operation", "manufacturing/operation", "P8"),
                    doctype("Routing", "manufacturing/routing", "P8"),
                    doctype("Settings", "manufacturing/settings", "P8", "Manufacturing Settings"),
                ],
            },
        ],
    },
    {
        id: "projects",
        label: "Projects",
        icon: Folder,
        items: [
            home("projects", "P9"),
            dashboard("projects", "P9"),
            doctype("Project", "projects/project", "P9", "Project", Folder),
            doctype("Task", "projects/task", "P9", "Task", CheckSquare),
            doctype("Timesheet", "projects/timesheet", "P9", "Timesheet", Clock),
        ],
        sections: [
            {
                label: "Reports",
                icon: Table,
                items: [
                    report("Project Summary", "projects", "P9"),
                    report("Timesheet Billing Summary", "projects", "P9"),
                    report("Daily Timesheet Summary", "projects", "P9"),
                    report("Delayed Tasks Summary", "projects", "P9"),
                    report("Project wise Stock Tracking", "projects", "P9"),
                ],
            },
            {
                label: "Setup",
                icon: Database01,
                items: [
                    doctype("Activity Type", "projects/activity-type", "P9"),
                    doctype("Activity Cost", "projects/activity-cost", "P9"),
                    doctype("Project Type", "projects/project-type", "P9"),
                    doctype("Task Type", "projects/task-type", "P9"),
                    doctype("Project Template", "projects/project-template", "P9"),
                    doctype("Project Update", "projects/project-update", "P9"),
                    doctype("Settings", "projects/settings", "P9", "Projects Settings"),
                ],
            },
        ],
    },
    {
        id: "assets",
        label: "Assets",
        icon: Archive,
        items: [
            home("assets", "P10"),
            dashboard("assets", "P10"),
            doctype("Asset", "assets/asset", "P10", "Asset", Archive),
            doctype("Depreciation Schedule", "assets/asset-depreciation-schedule", "P10", "Asset Depreciation Schedule", TrendDown01),
            doctype("Asset Movement", "assets/asset-movement", "P10", "Asset Movement", Move),
            report("Fixed Asset Register", "assets", "P10", "Fixed Asset Register", Table),
        ],
        sections: [
            {
                label: "Reports",
                icon: Table,
                items: [
                    report("Asset Depreciation Ledger", "assets", "P10"),
                    report("Asset Depreciations and Balances", "assets", "P10"),
                    report("Asset Activity", "assets", "P10"),
                ],
            },
            {
                label: "Value Changes",
                icon: TrendDown01,
                items: [
                    doctype("Asset Capitalization", "assets/asset-capitalization", "P10"),
                    doctype("Asset Value Adjustment", "assets/asset-value-adjustment", "P10"),
                ],
            },
            {
                label: "Maintenance",
                icon: Tool01,
                items: [
                    doctype("Asset Maintenance", "assets/asset-maintenance", "P10"),
                    doctype("Asset Maintenance Log", "assets/asset-maintenance-log", "P10"),
                    doctype("Asset Repair", "assets/asset-repair", "P10"),
                    doctype("Asset Maintenance Team", "assets/asset-maintenance-team", "P10"),
                ],
            },
            {
                label: "Setup",
                icon: Database01,
                items: [
                    doctype("Asset Category", "assets/asset-category", "P10"),
                    doctype("Location", "assets/location", "P10"),
                    doctype("Settings", "accounts/settings", "P3", "Accounts Settings"),
                ],
            },
        ],
    },
    {
        id: "setup",
        label: "Setup",
        icon: Settings01,
        items: [
            { label: "Home", path: "", phase: "P1", icon: Home03, target: { kind: "workspace" } },
            doctype("Company", "setup/company", "P1", "Company", Building02),
            doctype("Users", "setup/users", "P1", "User", Users01),
        ],
        sections: [
            {
                label: "Organization",
                icon: Building02,
                items: [
                    doctype("Branch", "setup/branch", "P1"),
                    doctype("Department", "setup/department", "P1"),
                    doctype("Designation", "setup/designation", "P1"),
                    doctype("Holiday List", "setup/holiday-list", "P1"),
                ],
            },
            {
                label: "Access",
                icon: ShieldTick,
                items: [
                    doctype("Role", "setup/roles", "P1"),
                    doctype("Role Profile", "setup/role-profile", "P1"),
                    {
                        label: "Role Permissions",
                        path: "setup/role-permissions",
                        phase: "P1",
                        target: { kind: "page", page: "permission-manager" },
                    },
                    doctype("User Permissions", "setup/user-permissions", "P1", "User Permission"),
                    doctype("Authorization Rule", "setup/authorization-rule", "P1"),
                ],
            },
            {
                label: "Printing",
                icon: Printer,
                items: [
                    doctype("Letter Head", "setup/letter-head", "P1"),
                    doctype("Print Format", "setup/print-format", "P1"),
                    doctype("Print Settings", "setup/print-settings", "P1"),
                ],
            },
            {
                label: "Email",
                icon: Mail01,
                items: [
                    doctype("Email Account", "setup/email-account", "P1"),
                    doctype("Email Template", "setup/email-template", "P1"),
                    doctype("Email Digest", "setup/email-digest", "P1"),
                ],
            },
            {
                label: "Settings",
                icon: Settings01,
                items: [
                    doctype("Global Defaults", "setup/global-defaults", "P0"),
                    doctype("System", "setup/system-settings", "P0", "System Settings"),
                    doctype("Accounts", "accounts/settings", "P3", "Accounts Settings"),
                    doctype("Selling", "selling/settings", "P5", "Selling Settings"),
                    doctype("Buying", "buying/settings", "P6", "Buying Settings"),
                    doctype("Stock", "stock/settings", "P4", "Stock Settings"),
                    doctype("Manufacturing", "manufacturing/settings", "P8", "Manufacturing Settings"),
                    doctype("Projects", "projects/settings", "P9", "Projects Settings"),
                ],
            },
        ],
    },
];

export const MODULE_IDS = MODULES.map((m) => m.id);

export function getModule(id: string): ModuleNav | undefined {
    return MODULES.find((m) => m.id === id);
}

export function moduleLinks(module: ModuleNav): NavLink[] {
    return [...module.items, ...module.sections.flatMap((s) => s.items)];
}

/** The nav entry for a path below `/[org]` (first match wins; Settings pointers may appear in several modules). */
export function findLink(path: string): NavLink | undefined {
    for (const module of MODULES) {
        const link = moduleLinks(module).find((l) => l.path === path);
        if (link) return link;
    }
    return undefined;
}

/** Exact nav entry, or the doctype entry whose list path prefixes `path` (`<doctype>/new`, `<doctype>/<id>`). */
export function findLinkForPath(path: string): NavLink | undefined {
    const exact = findLink(path);
    if (exact) return exact;
    const parent = path.split("/").slice(0, -1).join("/");
    const link = parent ? findLink(parent) : undefined;
    return link?.target.kind === "doctype" ? link : undefined;
}

/** The module owning a path below `/[org]`: its first segment, or Setup for the org home. */
export function moduleForPath(path: string): ModuleNav | undefined {
    const first = path.split("/")[0];
    return first === "" ? getModule("setup") : getModule(first);
}

/** Bespoke routes under `src/app/(app)/[org]` (not descriptors); see docs/modules/00-setup.md §8 for why each exists. */
export const BUILT_PAGES: ReadonlySet<string> = new Set(["setup/users", "setup/role-permissions"]);

export function orgHref(orgSlug: string, path: string): string {
    return path ? `/${orgSlug}/${path}` : `/${orgSlug}`;
}
