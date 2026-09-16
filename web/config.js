// A hosted build may set this in runtime-config.js. Same-origin remains the
// safe default for the desktop server and local development.
const runtimeOrigin = String(globalThis.STUDY_ARENA_API_URL || "").trim();
const browserLocation = globalThis.location;
export const IS_GITHUB_PAGES =
  Boolean(browserLocation) && browserLocation.hostname.endsWith("github.io");

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

export const API_URL = validApiOrigin(runtimeOrigin);
export const API_CONFIGURED = !IS_GITHUB_PAGES || Boolean(API_URL);
export const API_UNAVAILABLE_MESSAGE =
  "Account creation and sign-in are not available on this public preview yet. " +
  "Explore as a guest, or use the desktop Study Arena while its secure server is running.";
