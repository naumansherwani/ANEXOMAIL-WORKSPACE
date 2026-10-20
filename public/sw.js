/* ANEXOMAIL service worker — app shell offline + no broken deploys (20 Oct 2026).
 *
 * Kyun: src/lib/pwa.ts saalon se "/sw.js" register karta tha, lekin file kabhi bani hi nahi thi (live 404, har page par
 * console error, mobile par offline kuch nahi). Ab:
 *   1. /assets/* (hash wale, kabhi nahi badalte) => cache-first. Naya deploy aaye to purana khula tab bhi apne purane
 *      chunks yahin se le leta hai — "chunk 404, page safed" wala masla khatam.
 *   2. Page kholna (navigation) => hamesha pehle network. Internet na ho to us page ka khali "shell" (bina login ke
 *      maanga gaya: credentials "omit" — is liye is mein kisi user ka koi data NAHI hota). Mail khud IndexedDB
 *      (src/lib/offline.ts) se dikhti hai, jo pehle se bana hua hai.
 *   3. /rpc, /api, /auth, /wt, bahar ke domain, POST — kabhi cache nahi. Mail/token kabhi Cache Storage mein nahi jata.
 *   4. Logout / "clear offline" => message {type:"anexo-clear"} => sab cache saaf.
 */
const VERSION = "v1";
const SHELL = `anexo-shell-${VERSION}`;
const ASSETS = `anexo-assets-${VERSION}`;
const ASSET_LIMIT = 400;
const SHELL_LIMIT = 40;
const FALLBACK = "/app/mail/inbox";
const PRECACHE = [FALLBACK, "/manifest.webmanifest", "/favicon.svg", "/icon-192.png"];
const NEVER = /^\/(rpc|api|auth|wt|realtime|functions|rest|storage)(\/|$)/;

self.addEventListener("install", (event) => {
  event.waitUntil(
    (async () => {
      const cache = await caches.open(SHELL);
      await Promise.allSettled(
        PRECACHE.map(async (path) => {
          const res = await fetch(path, { credentials: "omit", cache: "no-store" });
          if (res.ok) await cache.put(path, res);
        }),
      );
      await self.skipWaiting();
    })(),
  );
});

self.addEventListener("activate", (event) => {
  event.waitUntil(
    (async () => {
      const keep = new Set([SHELL, ASSETS]);
      for (const key of await caches.keys()) if (key.startsWith("anexo-") && !keep.has(key)) await caches.delete(key);
      if (self.registration.navigationPreload) await self.registration.navigationPreload.enable().catch(() => {});
      await self.clients.claim();
    })(),
  );
});

self.addEventListener("message", (event) => {
  if (event.data && event.data.type === "anexo-clear") {
    event.waitUntil(
      (async () => {
        for (const key of await caches.keys()) if (key.startsWith("anexo-")) await caches.delete(key);
      })(),
    );
  }
});

async function trim(cacheName, max) {
  const cache = await caches.open(cacheName);
  const keys = await cache.keys();
  for (let i = 0; i < keys.length - max; i++) await cache.delete(keys[i]);
}

async function assetFirst(request) {
  const cache = await caches.open(ASSETS);
  const hit = await cache.match(request);
  if (hit) return hit;
  const res = await fetch(request);
  if (res.ok && res.type === "basic") {
    await cache.put(request, res.clone());
    trim(ASSETS, ASSET_LIMIT).catch(() => {});
  }
  return res;
}

// Login ke bina usi page ka shell (koi user data nahi) — agli dafa offline ke liye.
async function refreshShell(path) {
  try {
    const res = await fetch(path, { credentials: "omit", cache: "no-store", redirect: "follow" });
    if (res.ok && res.type === "basic" && (res.headers.get("content-type") || "").includes("text/html")) {
      const cache = await caches.open(SHELL);
      await cache.put(path, res);
      await trim(SHELL, SHELL_LIMIT);
    }
  } catch {
    /* offline — kuch nahi */
  }
}

async function navigate(event) {
  const url = new URL(event.request.url);
  try {
    const res = (await event.preloadResponse) || (await fetch(event.request));
    if (res.ok && url.pathname.startsWith("/app")) event.waitUntil(refreshShell(url.pathname));
    return res;
  } catch (e) {
    if (!url.pathname.startsWith("/app")) throw e;
    const cache = await caches.open(SHELL);
    const hit = (await cache.match(url.pathname)) || (await cache.match(FALLBACK));
    if (hit) return hit;
    throw e;
  }
}

self.addEventListener("fetch", (event) => {
  const req = event.request;
  if (req.method !== "GET") return;
  const url = new URL(req.url);
  if (url.origin !== self.location.origin) return;
  if (NEVER.test(url.pathname)) return;
  if (req.mode === "navigate") {
    event.respondWith(navigate(event));
    return;
  }
  if (url.pathname.startsWith("/assets/")) {
    event.respondWith(assetFirst(req));
    return;
  }
  if (PRECACHE.includes(url.pathname)) {
    event.respondWith(
      fetch(req).catch(async () => (await caches.open(SHELL)).match(url.pathname) || Response.error()),
    );
  }
});
