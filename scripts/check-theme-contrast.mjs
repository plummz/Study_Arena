// WCAG 2.1 contrast check for every theme block in web/tokens.css.
// Usage: node scripts/check-theme-contrast.mjs   (exit 1 if any required pair fails)
import { readFile } from "node:fs/promises";

const css = await readFile(new URL("../web/tokens.css", import.meta.url), "utf8");
const themes = {};
for (const [, selector, body] of css.matchAll(/(:root(?:\[data-theme="[^"]+"\])?)\s*\{([^}]*)\}/g)) {
  const name = selector.match(/"([^"]+)"/)?.[1] || "light";
  themes[name] = Object.fromEntries([...body.matchAll(/--([\w-]+):\s*(#[0-9a-f]{6})/gi)].map((m) => [m[1], m[2]]));
}
const luminance = (hex) => {
  const [r, g, b] = [1, 3, 5].map((i) => parseInt(hex.slice(i, i + 2), 16) / 255)
    .map((c) => (c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4));
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
};
const ratio = (a, b) => {
  const [x, y] = [luminance(a), luminance(b)].sort((m, n) => n - m);
  return (x + 0.05) / (y + 0.05);
};
// [foreground, background, minimum]. 4.5 = AA body text; 3 = AA non-text UI (focus ring, field border).
const pairs = [
  ...["bg", "card", "soft", "input", "peach"].map((bg) => ["ink", bg, 4.5]),
  ...["bg", "card", "soft", "input"].map((bg) => ["muted", bg, 4.5]),
  ...["bg", "card", "soft"].map((bg) => ["sage", bg, 4.5]),
  ["on-sage", "sage", 4.5],
  ...["bg", "card", "error-bg"].map((bg) => ["danger", bg, 4.5]),
  ["bg", "ink", 4.5], // toast: --bg text on --ink
  ...["bg", "card"].map((bg) => ["focus", bg, 3]),
  ...["card", "input"].map((bg) => ["field-border", bg, 3]),
];
const only = process.argv.slice(2);
let failed = 0;
for (const [name, t] of Object.entries(themes)) {
  if (only.length && !only.includes(name)) continue;
  console.log(`\n${name}`);
  for (const [fg, bg, min] of pairs) {
    if (!t[fg] || !t[bg]) continue;
    const value = ratio(t[fg], t[bg]), ok = value >= min;
    if (!ok) failed++;
    console.log(`  ${ok ? "pass" : "FAIL"}  ${fg} on ${bg}: ${value.toFixed(2)}:1 (needs ${min})`);
  }
}
process.exitCode = failed ? 1 : 0;
