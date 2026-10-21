import { useEffect, useMemo, useRef, useState } from "react";

import { useCalendarEvents } from "@/lib/calendar";
import { reminderText } from "@/lib/calprefs";
import { notify } from "@/lib/notify";
import { fmtTime } from "@/lib/timeFormat";

const FIRED_KEY = "ax.rem.fired";

function readFired(): Set<string> {
  try {
    return new Set(JSON.parse(window.sessionStorage.getItem(FIRED_KEY) ?? "[]") as string[]);
  } catch {
    return new Set();
  }
}

function writeFired(s: Set<string>) {
  try {
    window.sessionStorage.setItem(FIRED_KEY, JSON.stringify([...s].slice(-200)));
  } catch {
    /* private window: the in-memory set below still stops repeats for this page */
  }
}

/**
 * Meeting reminders while ANEXOMAIL is open in any tab/page ("starts in 10 minutes").
 * Mounted once in the app shell; renders nothing. A reminder shows once per meeting+lead time, also when the person
 * opens the app a little late (as long as the meeting has not started). Mail reminders need a server timer and are a
 * separate step — this is the in-app one, and the setting says so.
 */
export function ReminderWatcher() {
  const [tick, setTick] = useState(() => Date.now());
  const hour = Math.floor(tick / 3_600_000) * 3_600_000;
  const range = useMemo(
    () => ({ from: new Date(hour).toISOString(), to: new Date(hour + 36 * 3_600_000).toISOString() }),
    [hour],
  );
  const events = useCalendarEvents(range);
  const refetch = events.refetch;
  const fired = useRef<Set<string> | null>(null);

  useEffect(() => {
    const t = setInterval(() => setTick(Date.now()), 20_000);
    const r = setInterval(() => void refetch(), 5 * 60_000);
    return () => {
      clearInterval(t);
      clearInterval(r);
    };
  }, [refetch]);

  useEffect(() => {
    const rows = events.data?.events;
    if (!rows) return;
    if (!fired.current) fired.current = readFired();
    const seen = fired.current;
    let changed = false;
    for (const ev of rows) {
      if (ev.status === "cancelled" || !ev.remind_min?.length) continue;
      const start = new Date(ev.starts_at).getTime();
      if (!(start > tick)) continue; // already started
      for (const m of ev.remind_min) {
        const key = `${ev.id}:${m}`;
        if (seen.has(key) || tick < start - m * 60_000) continue;
        seen.add(key);
        changed = true;
        notify.info(
          m === 0 ? `${ev.title} starts now` : `${ev.title} starts in ${reminderText(m)}`,
          `${fmtTime(ev.starts_at)}${ev.location ? ` · ${ev.location}` : ""}`,
        );
      }
    }
    if (changed) writeFired(seen);
  }, [events.data, tick]);

  return null;
}
