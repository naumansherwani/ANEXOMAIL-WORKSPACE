// J6 — founder phone-alert service worker. Served at /_cc/flare-sw.js. It only does two things: show the notification that arrived in the (encrypted) push, and, for the
// one-time confirm message, hand the token to the page through the Cache API (the page deletes it once used). It never calls the API, so it holds no credential.
self.addEventListener("install", () => self.skipWaiting());
self.addEventListener("activate", (e) => e.waitUntil(self.clients.claim()));
self.addEventListener("push", (event) => {
  let d = null;
  try { d = event.data ? event.data.json() : null; } catch (_) { d = null; }
  const n = d && d.notification;
  if (!d || d.web_push !== 8030 || !n || !n.title) {   // a push that is not ours: say nothing private, but a push must show something (userVisibleOnly)
    event.waitUntil(self.registration.showNotification("Anexomail Founder", { body: "Open the app to see what changed.", tag: "anexo-unknown" }));
    return;
  }
  const work = [];
  if (d.k === "confirm" && typeof d.t === "string" && /^[A-Za-z0-9_-]{32}$/.test(d.t)) {
    work.push(caches.open("anexo-flare").then((c) => c.put("/__flare/pending-confirm", new Response(d.t))));
  }
  work.push(self.clients.matchAll({ type: "window" }).then((cs) => cs.forEach((c) => c.postMessage({ flare: d.k, ref: d.r || null }))));
  work.push(self.registration.showNotification(n.title, { body: n.body || "", tag: n.tag || "anexo", requireInteraction: !!n.requireInteraction, data: { navigate: n.navigate || "/" } }));
  event.waitUntil(Promise.all(work));
});
self.addEventListener("notificationclick", (event) => {
  event.notification.close();
  const url = (event.notification.data && event.notification.data.navigate) || "/";
  let ok = false; try { ok = new URL(url, self.location.origin).origin === self.location.origin; } catch (_) { ok = false; }
  const target = ok ? url : "/";                       // never navigate off the founder site
  event.waitUntil(self.clients.matchAll({ type: "window", includeUncontrolled: true }).then((cs) => {
    for (const c of cs) { if ("focus" in c) { c.navigate(target).catch(() => {}); return c.focus(); } }
    return self.clients.openWindow(target);
  }));
});
