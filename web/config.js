// A hosted build may set this in runtime-config.js. Same-origin remains the
// safe default for the desktop server and local development.
const runtimeOrigin = String(
  globalThis.document
    ?.querySelector('meta[name="study-arena-api"]')
    ?.getAttribute("content") || "",
).trim();
const browserLocation = globalThis.location;
export const IS_GITHUB_PAGES =
  Boolean(browserLocation) && browserLocation.hostname.endsWith("github.io");
const IS_NATIVE = Boolean(
  globalThis.window?.Capacitor?.isNativePlatform?.(),
);
const IS_LOCAL_SERVER =
  Boolean(browserLocation) &&
  ["localhost", "127.0.0.1", "::1"].includes(browserLocation.hostname) &&
  !IS_NATIVE;

function validApiOrigin(value) {
  if (!value) return "";
  try {
    const url = new URL(value);
    if (url.protocol !== "https:" && url.hostname !== "localhost") return "";
    return url.origin;
  } catch {
    return "";
  }
}

// The desktop/local Java server is same-origin even though the public build's
// HTML carries a Railway endpoint. GitHub Pages and native builds use that
// configured HTTPS endpoint.
export const API_URL = IS_LOCAL_SERVER ? "" : validApiOrigin(runtimeOrigin);
export const API_CONFIGURED = !IS_GITHUB_PAGES || Boolean(API_URL);
export const API_UNAVAILABLE_MESSAGE =
  "Account creation and sign-in are not available on this public preview yet. " +
  "Explore as a guest, or use the desktop Study Arena while its secure server is running.";
