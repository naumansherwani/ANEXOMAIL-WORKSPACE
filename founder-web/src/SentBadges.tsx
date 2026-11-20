// QC3 gap close: Sent-list badges. Calm list: only mail that needs a glance gets a word (Sending, Delayed, Failed ...).
// One batch call (max 100 ids) through the Rust WASM kernel RPC (mail_api.badges), never one call per row.
// Polls only while some mail is still moving; stops when everything is final. The door being off or slow = no badges, list unchanged.
import { useEffect, useRef, useState } from "react";
import * as api from "./mail_api";
import { badgeOf } from "./presend_pure";
import "./presend.css";

export function useSentBadges(box: string, view: string, ids: string[]): Record<string, api.Badge> {
  const [map, setMap] = useState<Record<string, api.Badge>>({});
  const key = view === "sent" ? ids.slice(0, 100).join(",") : "";
  const alive = useRef(0);
  useEffect(() => {
    const my = ++alive.current; let timer = 0;
    if (!key) { setMap({}); return; }
    const run = async () => {
      let m: Record<string, api.Badge> | null | undefined = null;
      try { m = await api.badges(box, key.split(",")); } catch { m = null; }
      if (my !== alive.current) return;
      if (m) setMap(m);
      const moving = m ? Object.values(m).some((b) => !b.final) : false;
      if (moving) timer = window.setTimeout(() => void run(), 30_000);
    };
    void run();
    return () => { alive.current++; window.clearTimeout(timer); };
  }, [box, key]);
  return map;
}

export function SentBadge({ b }: { b: api.Badge | undefined }) {
  const v = b ? badgeOf(b.phase) : null;
  if (!v) return null;
  return <span className={`mx-chip sb ${v.tone === "bad" ? "bad" : v.tone === "warn" ? "warn" : "off"}`} title={v.text}>{v.text}</span>;
}
