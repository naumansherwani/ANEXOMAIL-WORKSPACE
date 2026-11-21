// J6 — founder phone-alert service worker. Served at /_cc/flare-sw.js. It only does two things: show the notification that arrived in the (encrypted) push, and, for the
// one-time confirm message, hand the token to the page through the Cache API (the page deletes it once used). It never calls the API, so it holds no credential.
self.addEventListener("install", () => self.skipWaiting());
self.addEventListener("activate", (e) => e.waitUntil(self.clients.claim()));
// v2 (7 Nov 2026, "the alert on my phone was empty"): EVERY push shows a notification with a real title and body, whatever the payload looks like. If the payload is not ours the body
// says why in two words (code=...), so an odd alert can be read from the phone itself instead of guessed. The title is never empty, the body is never empty.
const show = (title, body, o) => { const opts = Object.assign({ tag: "anexo", data: { navigate: "/" } }, o || {}); opts.body = String(body || "").trim() || "Open the app to see what changed."; return self.registration.showNotification(String(title || "").trim() || "Anexomail Founder", opts); };
// what THIS phone actually received, kept in the page-readable cache so the Phone alerts card can print it ("last alert on this device"). Lengths only, never the secret tokens.
const note = (k, title, body, why) => caches.open("anexo-flare").then((c) => c.put("/__flare/last", new Response(JSON.stringify({ ts: Date.now(), k: k || "?", tl: String(title || "").length, bl: String(body || "").length, why: why || "ok", t: String(title || "").slice(0, 60), b: String(body || "").slice(0, 90) })))).catch(() => {});
self.addEventListener("push", (event) => {
  let d = null, why = "none";
  try { if (event.data) { d = event.data.json(); why = "shape"; } } catch (_) { d = null; why = "parse"; }
  const n = d && d.notification;
  if (!d || d.web_push !== 8030 || !n || !n.title) {
    event.waitUntil(Promise.all([show("Anexomail Founder", "Open the app to see what changed. (code=" + why + ")", { tag: "anexo-unknown" }), note("?", "", "", why)]));
    return;
  }
  const opts = { body: n.body, tag: n.tag || "anexo", requireInteraction: !!n.requireInteraction, data: { navigate: n.navigate || "/", k: d.k || "" } };
  const work = [note(d.k, n.title, n.body, "ok")];
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
// v3 (7 Nov 2026, "tapping the alert on my phone does nothing"): the tap ALWAYS ends with the app in front. Order: focus a window of this site and tell it which alert was tapped; if there is none or focus is
// refused (Android can refuse), open a new window. The tap is also written to the cache ("/__flare/clicked"), so a page that opens fresh can show "you opened this alert" and scroll to the Phone alerts card.
self.addEventListener("notificationclick", (event) => {
  event.notification.close();
  const d = event.notification.data || {};
  let target = "/"; try { const u = new URL(d.navigate || "/", self.location.origin); if (u.origin === self.location.origin) target = u.href; } catch (_) { target = "/"; }   // never navigate off the founder site
  const k = typeof d.k === "string" ? d.k.slice(0, 24) : "";
  const mark = caches.open("anexo-flare").then((c) => c.put("/__flare/clicked", new Response(JSON.stringify({ ts: Date.now(), k, t: String(event.notification.title || "").slice(0, 60) })))).catch(() => {});
  const open = async () => {
    const cs = await self.clients.matchAll({ type: "window", includeUncontrolled: true });
    for (const c of cs) {
      let same = false; try { same = new URL(c.url).origin === self.location.origin; } catch (_) { same = false; }
      if (!same) continue;
      try { const f = (await c.focus()) || c; try { f.postMessage({ flare_click: k }); } catch (_) {} try { await f.navigate(target); } catch (_) {} return; } catch (_) { /* focus refused: open a new window below */ }
    }
    await self.clients.openWindow(target);
  };
  event.waitUntil(Promise.all([mark, open()]));
});
