/* SyncBridge PWA — network-first shell; __BUILD_ID__ replaced at build time. */
const VERSION = "__BUILD_ID__";

self.addEventListener("install", () => {
  self.skipWaiting();
});

self.addEventListener("activate", (event) => {
  event.waitUntil(self.clients.claim());
});

self.addEventListener("fetch", (event) => {
  const url = new URL(event.request.url);
  if (url.origin !== self.location.origin) return;

  const path = url.pathname;
  const noStore =
    event.request.mode === "navigate" ||
    path === "/" ||
    path === "/index.html" ||
    path === "/version.json" ||
    path === "/sw.js" ||
    path === "/site.webmanifest";

  if (noStore) {
    event.respondWith(fetch(event.request, { cache: "no-store" }));
  }
});
