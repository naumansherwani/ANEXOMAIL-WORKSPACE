// J6 — founder phone-alert service worker. Served at /_cc/flare-sw.js. It only does two things: show the notification that arrived in the (encrypted) push, and, for the
// one-time confirm message, hand the token to the page through the Cache API (the page deletes it once used). It never calls the API, so it holds no credential.
self.addEventListener("install", () => self.skipWaiting());
self.addEventListener("activate", (e) => e.waitUntil(self.clients.claim()));
// v2 (7 Nov 2026, "the alert on my phone was empty"): EVERY push shows a notification with a real title and body, whatever the payload looks like. If the payload is not ours the body
// says why in two words (code=...), so an odd alert can be read from the phone itself instead of guessed. The title is never empty, the body is never empty.
const show = (title, body, o) => { const opts = Object.assign({ tag: "anexo", data: { navigate: "/" } }, o || {}); opts.body = String(body || "").trim() || "Open the app to see what changed."; return self.registration.showNotification(String(title || "").trim() || "Anexomail Founder", opts); };
self.addEventListener("push", (event) => {
  let d = null, why = "none";
  try { if (event.data) { d = event.data.json(); why = "shape"; } } catch (_) { d = null; why = "parse"; }
  const n = d && d.notification;
  if (!d || d.web_push !== 8030 || !n || !n.title) {
    event.waitUntil(show("Anexomail Founder", "Open the app to see what changed. (code=" + why + ")", { tag: "anexo-unknown" }));
    return;
  }
  const opts = { body: n.body, tag: n.tag || "anexo", requireInteraction: !!n.requireInteraction, data: { navigate: n.navigate || "/" } };
  const work = [];
  if (d.k === "confirm" && typeof d.t === "string" && /^[A-Za-z0-9_-]{32}$/.test(d.t)) {
    work.push(caches.open("anexo-flare").then((c) => c.put("/__flare/pending-confirm", new Response(d.t))).catch(() => {}));
  }
  work.push(self.clients.matchAll({ type: "window" }).then((cs) => cs.forEach((c) => c.postMessage({ flare: d.k, ref: d.r || null }))).catch(() => {}));
  if (typeof d.a === "string" && /^[A-Za-z0-9_-]{32}$/.test(d.a)) {   // E141 delivery receipt: proves THIS phone received and showed the alert; the token travelled inside the encrypted push
    work.push(show(n.title, n.body, opts)
      .then(() => fetch("/founder/v1/flare/ack", { method: "POST", headers: { "content-type": "application/json" }, body: JSON.stringify({ t: d.a }), keepalive: true, credentials: "omit", cache: "no-store" }))
      .catch(() => {}));
  } else work.push(show(n.title, n.body, opts));
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
