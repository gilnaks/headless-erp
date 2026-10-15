import "server-only";

import sanitize from "sanitize-html";

const SAFE_VALUE = /^(?!.*(?:url|expression|javascript)\s*[(:]).*$/i;

const STYLE_PROPERTIES = [
    "color",
    "background-color",
    "text-align",
    "vertical-align",
    "font-size",
    "font-weight",
    "font-style",
    "font-family",
    "line-height",
    "text-decoration",
    "text-transform",
    "letter-spacing",
    "width",
    "height",
    "max-width",
    "min-width",
    "margin",
    "margin-top",
    "margin-right",
    "margin-bottom",
    "margin-left",
    "padding",
    "padding-top",
    "padding-right",
    "padding-bottom",
    "padding-left",
    "border",
    "border-top",
    "border-right",
    "border-bottom",
    "border-left",
    "border-collapse",
    "display",
    "float",
];

const OPTIONS: sanitize.IOptions = {
    allowedTags: [
        "div",
        "span",
        "p",
        "br",
        "hr",
        "h1",
        "h2",
        "h3",
        "h4",
        "h5",
        "h6",
        "b",
        "strong",
        "i",
        "em",
        "u",
        "s",
        "small",
        "sub",
        "sup",
        "blockquote",
        "ul",
        "ol",
        "li",
        "a",
        "img",
        "table",
        "thead",
        "tbody",
        "tfoot",
        "tr",
        "th",
        "td",
        "colgroup",
        "col",
    ],
    allowedAttributes: {
        "*": ["style", "class", "align", "width", "height"],
        a: ["href", "title", "target", "rel"],
        img: ["src", "alt", "title"],
        td: ["colspan", "rowspan", "valign"],
        th: ["colspan", "rowspan", "valign", "scope"],
        col: ["span"],
    },
    allowedStyles: { "*": Object.fromEntries(STYLE_PROPERTIES.map((p) => [p, [SAFE_VALUE]])) },
    allowedSchemes: ["http", "https", "mailto", "tel"],
    allowedSchemesByTag: { img: ["http", "https", "data"] },
    allowProtocolRelative: false,
    disallowedTagsMode: "discard",
};

/**
 * Allow-list sanitizer for user-authored HTML (Letter Head content/footer, `html: true` Text fields): formatting,
 * tables and images survive; scripts, event handlers, iframes, forms and `javascript:` URLs are removed.
 */
export function sanitizeHtml(html: string): string {
    return sanitize(html, OPTIONS);
}
