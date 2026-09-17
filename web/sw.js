const VERSION = "study-arena-shell-v12-lean-install";
const SHELL = [
  "./", "./index.html", "./style.css", "./tokens.css", "./app.js",
  "./studio.js", "./import.js", "./vault.js", "./api.js", "./config.js",
  "./native.js", "./icon.svg", "./manifest.webmanifest", "./starter.json",
].map((path) => new URL(path, self.location.href).href);
const COMPANION_ASSETS = ["moss", "lumi", "coral", "sky", "plum", "sunny", "mint", "nova", "ember", "bubbles", "byte", "clover", "mochi", "comet", "pebble", "melody", "taro", "sol"]
  .map((id) => new URL(`./assets/companions/${id}.png`, self.location.href).href);
const SHELL_PATHS = new Set([...SHELL, ...COMPANION_ASSETS].map((url) => new URL(url).pathname));
self.addEventListener("install", (event) => {
  event.waitUntil(caches.open(VERSION).then((cache) => cache.addAll(SHELL)));
  self.skipWaiting();
});
self.addEventListener("activate", (event) =>
  event.waitUntil(
    caches
      .keys()
      .then((keys) =>
        Promise.all(
          keys.filter((k) => k !== VERSION).map((k) => caches.delete(k)),
        ),
      )
      .then(() => self.clients.claim()),
  ),
);
self.addEventListener("fetch", (event) => {
  const url = new URL(event.request.url);
  // Never cache API responses, bearer tokens, private notes, admin screens or third-party origins.
  if (
    event.request.method !== "GET" ||
    url.origin !== location.origin ||
    url.pathname.startsWith("/api/")
  )
    return;
  if (!SHELL_PATHS.has(url.pathname)) return;
  event.respondWith(
    fetch(event.request)
      .then((response) => {
        if (response.ok) caches.open(VERSION).then((cache) => cache.put(event.request, response.clone()));
        return response;
      })
      .catch(() => caches.match(event.request)),
  );
});
