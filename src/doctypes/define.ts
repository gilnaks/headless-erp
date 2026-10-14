import type { ModuleId } from "@/config/navigation";
import type { Database } from "@/types/database";

export type TableName = keyof Database["public"]["Tables"];
type Columns<T extends TableName> = keyof Database["public"]["Tables"][T]["Row"] & string;

/** ERPNext fieldtypes implemented so far; add more when a doctype needs them (docs/architecture/05-ui-ux.md). */
export type FieldType = "Data" | "Text" | "Select" | "Link" | "Date" | "Check" | "Int" | "Float" | "Currency" | "Percent" | "Table";

/** Option lists resolved at runtime instead of being inlined (no reference tables yet). */
export type OptionSource = "Currency" | "Country" | "TimeZone";

export type FieldValues = Record<string, unknown>;

export type FieldDef = {
    type: FieldType;
    label: string;
    required?: boolean;
    /** Never editable in the form (computed by the server, e.g. `reporting_currency`). */
    readOnly?: boolean;
    /** Editable on new documents only (ERPNext `set_only_once`). */
    setOnlyOnce?: boolean;
    /** Select: fixed labels (ERPNext `options`) or a runtime source. */
    options?: readonly string[] | OptionSource;
    /** Link: target doctype. Table: child doctype. */
    target?: string;
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
    errorFields?: Record<string, Columns<T>>;
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
