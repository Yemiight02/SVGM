import type { ValidateSVGResult } from "./lib/types";

/**
 * Lightweight, dependency-free SVG validator. Checks for:
 *  - non-empty body
 *  - presence of the `<svg ... xmlns="http://www.w3.org/2000/svg">` root
 *  - balanced angle brackets and double quotes
 *  - rejection of any `<script>` tags, `javascript:` URIs, or `on*=`
 *    event-handler attributes (defense in depth)
 */
export function validateSVG(input: string): ValidateSVGResult {
    const errors: string[] = [];
    const svg = (input ?? "").trim();
    const sizeBytes = Buffer.byteLength(svg, "utf-8");

    if (svg.length === 0) {
        errors.push("SVG is empty");
        return { ok: false, errors, sizeBytes };
    }

    if (!/^<\?xml[^>]*\?>\s*<svg[\s>]/i.test(svg) && !/^<svg[\s>]/i.test(svg)) {
        errors.push("Missing <svg> root element or XML declaration");
    }

    if (!/xmlns\s*=\s*"http:\/\/www\.w3\.org\/2000\/svg"/.test(svg)) {
        errors.push('Missing required xmlns="http://www.w3.org/2000/svg" attribute');
    }

    if (!hasBalanced(svg, "<", ">")) {
        errors.push("Unbalanced angle brackets");
    }

    if (!quoteBalanceOk(svg)) {
        errors.push("Unbalanced or mismatched quotes in attribute values");
    }

    const lower = svg.toLowerCase();
    if (lower.includes("<script")) errors.push("Contains forbidden <script> tag");
    if (lower.includes("javascript:")) errors.push("Contains forbidden javascript: URI");
    if (/\son[a-z]+\s*=/i.test(svg)) errors.push("Contains forbidden event-handler attribute (on*=)");

    const max = Number(process.env.SVG_MAX_BYTES ?? 24576);
    if (sizeBytes > max) {
        errors.push(`SVG too large: ${sizeBytes} bytes (max ${max})`);
    }

    return { ok: errors.length === 0, errors, sizeBytes };
}

function hasBalanced(s: string, open: string, close: string): boolean {
    let count = 0;
    for (const c of s) {
        if (c === open) count++;
        else if (c === close) count--;
        if (count < 0) return false;
    }
    return count === 0;
}

/**
 * State-machine quote balance: tracks whether we're inside a `"..."` or
 * `'...'` attribute value, with `\` as the escape character. Returns true
 * if every quote in the document is part of a properly closed pair.
 */
function quoteBalanceOk(s: string): boolean {
    let inDouble = false;
    let inSingle = false;
    for (let i = 0; i < s.length; i++) {
        const c = s[i];
        if (c === "\\") {
            i++; // skip next char (escape)
            continue;
        }
        if (inDouble) {
            if (c === '"') inDouble = false;
        } else if (inSingle) {
            if (c === "'") inSingle = false;
        } else {
            if (c === '"') inDouble = true;
            else if (c === "'") inSingle = true;
        }
    }
    return !inDouble && !inSingle;
}

if (require.main === module) {
    const fs = require("fs");
    const path = require("path");
    const file = process.argv[2];
    if (!file) {
        console.error("usage: validate-svg <file.svg>");
        process.exit(2);
    }
    const data = fs.readFileSync(path.resolve(file), "utf-8");
    const r = validateSVG(data);
    if (r.ok) {
        console.log(`OK — ${r.sizeBytes} bytes`);
        process.exit(0);
    } else {
        console.error(`INVALID — ${r.sizeBytes} bytes`);
        for (const e of r.errors) console.error(`  - ${e}`);
        process.exit(1);
    }
}
