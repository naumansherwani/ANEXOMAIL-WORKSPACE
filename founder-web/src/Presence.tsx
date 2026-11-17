import { useEffect, useState } from "react";
import { presence, PRESENCE_TEXT, type Presence as P } from "./presence_pure";

// Top-bar pill: Live / Idle / Offline. Activity = pointer, key, touch, scroll, or the tab coming back to the front.
export default function PresencePill() {
  const [last, setLast] = useState(() => Date.now()), [online, setOnline] = useState(() => (typeof navigator === "undefined" ? true : navigator.onLine)), [tick, setTick] = useState(0);
  useEffect(() => {
    let t = 0;
    const touch = () => { const n = Date.now(); if (n - t > 1000) { t = n; setLast(n); } };
    const vis = () => { if (!document.hidden) touch(); };
    const on = () => setOnline(true), off = () => setOnline(false);
    const ev = ["pointerdown", "keydown", "touchstart", "scroll", "wheel"] as const;
    ev.forEach((e) => window.addEventListener(e, touch, { passive: true, capture: true }));
    document.addEventListener("visibilitychange", vis); window.addEventListener("online", on); window.addEventListener("offline", off);
    const id = window.setInterval(() => setTick((x) => x + 1), 30_000);
    return () => { ev.forEach((e) => window.removeEventListener(e, touch, true)); document.removeEventListener("visibilitychange", vis); window.removeEventListener("online", on); window.removeEventListener("offline", off); window.clearInterval(id); };
  }, []);
  void tick;
  const s: P = presence(Date.now(), last, online);
  const x = PRESENCE_TEXT[s];
  return <span className={`prs ${s}`} role="status" title={x.tip} aria-label={`${x.label}. ${x.tip}`}><i aria-hidden="true" />{x.label}</span>;
}
