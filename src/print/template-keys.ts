/** `print_format.template_key` values with a template in `src/print/registry.tsx` (kept apart so descriptors stay light). */
export const TEMPLATE_KEYS = ["record"] as const;

export type TemplateKey = (typeof TEMPLATE_KEYS)[number];
