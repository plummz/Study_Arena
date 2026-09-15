const VERSION = "study-arena-shell-v7-eighteen-companions";
const SHELL = [
  "/",
  "/index.html",
  "/style.css",
  "/tokens.css",
  "/app.js",
  "/studio.js",
  "/import.js",
  "/vault.js",
  "/api.js",
  "/config.js",
  "/native.js",
  "/icon.svg",
  "/manifest.webmanifest",
  "/starter.json",
  "/assets/companions/moss.png",
  "/assets/companions/lumi.png",
  "/assets/companions/coral.png",
  "/assets/companions/sky.png",
  "/assets/companions/plum.png",
  "/assets/companions/sunny.png",
  "/assets/companions/mint.png",
  "/assets/companions/nova.png",
  "/assets/companions/ember.png",
  "/assets/companions/bubbles.png",
  "/assets/companions/byte.png",
  "/assets/companions/clover.png",
  "/assets/companions/mochi.png",
  "/assets/companions/comet.png",
  "/assets/companions/pebble.png",
  "/assets/companions/melody.png",
  "/assets/companions/taro.png",
  "/assets/companions/sol.png",
];
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
  if (!SHELL.includes(url.pathname)) return;
  event.respondWith(
    fetch(event.request)
      .then((response) => {
        if (response.ok) caches.open(VERSION).then((cache) => cache.put(event.request, response.clone()));
        return response;
      })
      .catch(() => caches.match(event.request)),
  );
});
