import type { ComponentType } from "react";
import type { TemplateKey } from "./template-keys";
import { type PrintTemplateProps, RecordTemplate } from "./templates/record";

/** `print_format.template_key` → server-rendered template. Add a key to `TEMPLATE_KEYS` with each new template. */
export const PRINT_TEMPLATES: Record<TemplateKey, ComponentType<PrintTemplateProps>> = {
    record: RecordTemplate,
};

export function printTemplate(key: string): ComponentType<PrintTemplateProps> {
    return PRINT_TEMPLATES[key as TemplateKey] ?? RecordTemplate;
}

export type { PrintTemplateProps };
