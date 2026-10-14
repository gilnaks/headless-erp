// Helpers for scripts/gen-coa-templates.mjs, kept separate so Vitest can test them (scripts/lib/coa.test.mjs).

/**
 * Converts the dict literal returned by an ERPNext chart module (`def get(): return {...}`, e.g.
 * standard_chart_of_accounts.py) to JSON text, keeping key order: `_("x")` -> "x", True/False/None -> true/false/null,
 * trailing commas and comments dropped. Only the literal subset those files use is supported.
 */
export function pythonChartToJson(source) {
    const start = source.indexOf("return {");
    if (start < 0) throw new Error("no `return {` in chart module");
    let i = start + "return ".length;
    let out = "";
    let depth = 0;
    const peekNonSpace = (from) => {
        let j = from;
        while (j < source.length && /\s/.test(source[j])) j++;
        return source[j];
    };
    while (i < source.length) {
        const ch = source[i];
        if (ch === '"' || ch === "'") {
            let j = i + 1;
            let text = "";
            while (source[j] !== ch) {
                if (source[j] === "\\") {
                    text += source[j + 1];
                    j += 2;
                } else {
                    text += source[j];
                    j++;
                }
                if (j >= source.length) throw new Error("unterminated string");
            }
            out += JSON.stringify(text);
            i = j + 1;
        } else if (ch === "#") {
            while (i < source.length && source[i] !== "\n") i++;
        } else if (ch === "_" && source[i + 1] === "(") {
            // _("x") -> "x": emit the string, then skip the closing parenthesis.
            i += 2;
            const close = findClosingParen(source, i);
            out += pythonChartToJson(`return {"v": ${source.slice(i, close)}}`).slice(5, -1);
            i = close + 1;
        } else if (/[A-Za-z]/.test(ch)) {
            let j = i;
            while (j < source.length && /\w/.test(source[j])) j++;
            const word = source.slice(i, j);
            const map = { True: "true", False: "false", None: "null" };
            if (!(word in map)) throw new Error(`unexpected identifier ${word}`);
            out += map[word];
            i = j;
        } else if (ch === ",") {
            const next = peekNonSpace(i + 1);
            if (next !== "}" && next !== "]") out += ",";
            i++;
        } else if (/\s/.test(ch)) {
            i++;
        } else {
            if (ch === "{" || ch === "[") depth++;
            if (ch === "}" || ch === "]") depth--;
            out += ch;
            i++;
            if (depth === 0) break;
        }
    }
    JSON.parse(out);
    return out;
}

function findClosingParen(source, from) {
    let i = from;
    let quote = null;
    while (i < source.length) {
        const ch = source[i];
        if (quote) {
            if (ch === "\\") i++;
            else if (ch === quote) quote = null;
        } else if (ch === '"' || ch === "'") quote = ch;
        else if (ch === ")") return i;
        i++;
    }
    throw new Error("unterminated _(");
}

/** Removes insignificant whitespace from JSON text without re-ordering keys (JSON.parse would move numeric keys). */
export function minifyJson(text) {
    let out = "";
    let inString = false;
    for (let i = 0; i < text.length; i++) {
        const ch = text[i];
        if (inString) {
            out += ch;
            if (ch === "\\") {
                out += text[i + 1];
                i++;
            } else if (ch === '"') inString = false;
        } else if (ch === '"') {
            inString = true;
            out += ch;
        } else if (!/\s/.test(ch)) out += ch;
    }
    return out;
}

/** The raw text of the top-level `"tree"` value of a chart JSON document, in source order. */
export function treeText(minified) {
    const key = '"tree":';
    let depth = 0;
    let inString = false;
    let start = -1;
    for (let i = 0; i < minified.length; i++) {
        const ch = minified[i];
        if (inString) {
            if (ch === "\\") i++;
            else if (ch === '"') inString = false;
            continue;
        }
        if (ch === '"') {
            if (depth === 1 && start < 0 && minified.startsWith(key, i)) {
                start = i + key.length;
                i = start - 1;
                continue;
            }
            inString = true;
        } else if (ch === "{" || ch === "[") {
            depth++;
        } else if (ch === "}" || ch === "]") {
            depth--;
            if (start >= 0 && depth === 1) return minified.slice(start, i + 1);
        }
    }
    throw new Error("no top-level tree");
}
