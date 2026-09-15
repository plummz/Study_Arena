import { writeFile } from "node:fs/promises";
const value = process.argv[2];
let url;
try {
  url = new URL(value);
} catch {
  throw new Error("Provide the institution HTTPS API origin.");
}
if (
  url.protocol !== "https:" ||
  url.username ||
  url.password ||
  url.pathname !== "/" ||
  url.search ||
  url.hash
)
  throw new Error(
    "Use an HTTPS origin with no path, credentials, query or fragment.",
  );
await writeFile(
  "web/config.js",
  `// Public API origin; never store credentials here.\nexport const API_URL = ${JSON.stringify(url.origin)};\n`,
);
console.log("Android API origin configured. Run npx cap sync android.");
