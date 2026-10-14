import type { ModuleId } from "@/config/navigation";
import type { Database } from "@/types/database";

export type TableName = keyof Database["public"]["Tables"];
type Columns<T extends TableName> = keyof Database["public"]["Tables"][T]["Row"] & string;

/** ERPNext fieldtypes implemented so far; add more when a doctype needs them (docs/architecture/05-ui-ux.md). */
export type FieldType =
    | "Data"
    | "Text"
    | "Select"
    | "MultiSelect"
    | "Link"
    | "DynamicLink"
    | "Date"
    | "Check"
    | "Int"
    | "Float"
    | "Currency"
    | "Percent"
    | "Color"
    | "Table";

/**
 * Option lists resolved at runtime instead of being inlined. `Role` is per organization; the others are global.
 * `DocType` lists document types (no child tables); `UserPermissionTarget` those a User Permission can restrict.
 */
export type OptionSource = "Currency" | "Country" | "TimeZone" | "Role" | "DocType" | "UserPermissionTarget";

export type FieldValues = Record<string, unknown>;

export type FieldDef = {
    type: FieldType;
    label: string;
    required?: boolean;
    /** Never editable in the form (computed by the server, e.g. `reporting_currency`). */
    readOnly?: boolean;
    /** Editable on new documents only (ERPNext `set_only_once`). */
    setOnlyOnce?: boolean;
    /** Select / MultiSelect (`text[]` column): fixed labels (ERPNext `options`) or a runtime source. */
    options?: readonly string[] | OptionSource;
    /** Link: target doctype (`User` = organization members). Table: child doctype. */
    target?: string;
    /** DynamicLink: the sibling field holding the target doctype (ERPNext `options`). */
    optionsField?: string;
    default?: string | number | boolean;
    /** ERPNext `depends_on`; hidden fields are still submitted. */
    dependsOn?: (values: FieldValues) => boolean;
    description?: string;
    placeholder?: string;
};

export type FormSection = { label?: string; columns: string[][] };
export type FormTab = { label: string; sections: FormSection[] };

export type ListView = {
    columns: string[];
    /** Columns matched by the list search box (`ilike`). */
    searchFields: string[];
    defaultSort: { field: string; desc?: boolean };
};

/** ERPNext tree doctype (`is_tree`, NestedSet): drives the Tree view (`?view=tree`). */
export type TreeOptions = {
    /** Self Link to the parent node (ERPNext `nsm_parent_field`). */
    parentField: string;
    /** Check field: only groups can have children ("Add child"). */
    groupField: string;
    /** Link fields offered as tree filters (ERPNext treeview `filters`); copied onto new child nodes. */
    filters?: string[];
    /** Check field hiding nodes unless "Include disabled" is on. */
    disabledField?: string;
};

export type FormActionContext = { orgSlug: string };

/**
 * A form button that edits the unsaved document (ERPNext whitelisted controller methods such as
 * `get_weekly_off_dates`). `run` returns the fields it changes; throw an `Error` to show its message. The server
 * still validates on save.
 */
export type FormAction = {
    id: string;
    label: string;
    run: (values: FieldValues, ctx: FormActionContext) => FieldValues | Promise<FieldValues>;
};

/**
 * A field change handler (ERPNext `frappe.ui.form.on(doctype, { <field>(frm) {...} })`): runs when the user edits
 * the field and returns the fields to set.
 */
export type FieldTrigger = (values: FieldValues) => FieldValues;

export type ChildDoctype = {
    doctype: string;
    table: TableName;
    fields: Record<string, FieldDef>;
    /** Grid columns in order. */
    columns: string[];
};

export type Doctype = {
    doctype: string;
    table: TableName;
    module: ModuleId;
    /** URL segment below the module (`/[org]/<module>/<slug>`). */
    slug: string;
    submittable: boolean;
    /** Frappe "Single": one row per org, edited in place (no list, new or delete). */
    single: boolean;
    titleField: string;
    fields: Record<string, FieldDef>;
    children: Record<string, ChildDoctype>;
    tabs: FormTab[];
    listView: ListView;
    /** Maps `code` of a `code: message` database error to the field it belongs to. */
    errorFields: Record<string, string>;
    tree?: TreeOptions;
    /** Form actions, shown in the form header menu while the document is editable. */
    actions: FormAction[];
    triggers: Record<string, FieldTrigger>;
};

type LayoutOf<K extends string> = { label: string; sections: { label?: string; columns: K[][] }[] }[];

type ListViewInput<T extends TableName> = {
    columns: Columns<T>[];
    searchFields: Columns<T>[];
    defaultSort: { field: Columns<T>; desc?: boolean };
};

type DoctypeBase<T extends TableName, C extends string> = {
    doctype: string;
    table: T;
    module: ModuleId;
    slug: string;
    fields: Partial<Record<Columns<T> | C, FieldDef>>;
    children?: Record<C, ChildDoctype>;
    tabs: LayoutOf<Columns<T> | C>;
    errorFields?: Record<string, Columns<T> | C>;
    tree?: { parentField: Columns<T>; groupField: Columns<T>; filters?: Columns<T>[]; disabledField?: Columns<T> };
    actions?: FormAction[];
    triggers?: Partial<Record<Columns<T> | C, FieldTrigger>>;
};

/** `C` = Table field names (child row arrays), which are not columns of the parent table. */
export type DoctypeInput<T extends TableName, C extends string = never> = DoctypeBase<T, C> &
    (
        | { single?: false; submittable?: boolean; titleField: Columns<T>; listView: ListViewInput<T> }
        | { single: true; submittable?: never; titleField?: never; listView?: never }
    );

/**
 * Typed descriptor for a doctype: field keys, layout, list columns and the title field must be real columns of
 * `table` (or declared child tables), checked by `tsc` against the generated database types. Mirrors the ERPNext
 * doctype JSON.
 */
export function defineDoctype<T extends TableName, C extends string = never>(input: DoctypeInput<T, C>): Doctype {
    return {
        doctype: input.doctype,
        table: input.table,
        module: input.module,
        slug: input.slug,
        submittable: input.submittable ?? false,
        single: input.single ?? false,
        titleField: input.titleField ?? "id",
        fields: input.fields as Record<string, FieldDef>,
        children: (input.children ?? {}) as Record<string, ChildDoctype>,
        tabs: input.tabs as FormTab[],
        listView: input.listView ?? { columns: [], searchFields: [], defaultSort: { field: "id" } },
        errorFields: input.errorFields ?? {},
        ...(input.tree ? { tree: input.tree } : {}),
        actions: input.actions ?? [],
        triggers: (input.triggers ?? {}) as Record<string, FieldTrigger>,
    };
}

export function defineChildDoctype<T extends TableName>(input: {
    doctype: string;
    table: T;
    fields: Partial<Record<Columns<T>, FieldDef>>;
    columns: Columns<T>[];
}): ChildDoctype {
    return { ...input, fields: input.fields as Record<string, FieldDef> };
}

/** All field names placed in the form layout, in order. */
export function layoutFields(d: Pick<Doctype, "tabs">): string[] {
    return d.tabs.flatMap((t) => t.sections.flatMap((s) => s.columns.flat()));
}

export function docPath(d: Pick<Doctype, "module" | "slug">): string {
    return `${d.module}/${d.slug}`;
}
