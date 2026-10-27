/**
 * COMPOSE "BUSINESS OUTCOMES" (Pro) — email likhte waqt KAAM aur PAISA.
 * Sab hisaab browser mein WASM kernel (intent@1) karta hai: wada + deadline (deterministic), padhne ka waqt/paisa. Server ko typing ke dauraan kuch nahi jata.
 * Send ke BAAD hi server ko: commit.record (wada -> task + calendar hold, HMAC-sealed ledger) aur commit.economics (kharcha ka log).
 * Kernel tayyar na ho => bina badge ke compose normal chalta hai (kabhi rukawat nahi).
 */
import { useQuery } from "@tanstack/react-query";
import { useDeferredValue, useEffect, useMemo, useState } from "react";

import type { IntentCost, IntentPromise } from "@/lib/kernel/kernel";
import { getKernel, kernelIfReady } from "@/lib/kernel/boot";
import { rpc } from "@/lib/rpc";

export type AttentionRate = { currency: string; rate_minor_per_hour: number; wpm: number };
export const DEFAULT_RATE: AttentionRate = { currency: "GBP", rate_minor_per_hour: 6000, wpm: 220 };

/** Quoted purani mail ("> ...") aur khali lines nikal kar sirf naya likha hua. */
export function ownText(body: string): string {
  return body
    .split("\n")
    .filter((l) => !l.trimStart().startsWith(">"))
    .join("\n");
}

export function countWords(body: string): number {
  const t = ownText(body).trim();
  return t ? t.split(/\s+/).length : 0;
}

/** to/cc/bcc ke comma / semicolon / space se alag pate => ginti (dedupe, lowercase). */
export function recipientList(...fields: string[]): string[] {
  const seen = new Set<string>();
  for (const f of fields)
    for (const part of f.split(/[,;\s]+/)) {
      const m = part.match(/<?([^<>\s]+@[^<>\s]+)>?/);
      if (m) seen.add(m[1]!.toLowerCase());
    }
  return [...seen];
}

export function money(minor: number, currency: string): string {
  try {
    return new Intl.NumberFormat("en-GB", {
      style: "currency",
      currency,
      minimumFractionDigits: minor % 100 === 0 ? 0 : 2,
    }).format(minor / 100);
  } catch {
    return `${(minor / 100).toFixed(2)} ${currency}`;
  }
}

export function duration(seconds: number): string {
  if (seconds < 90) return `${seconds}s`;
  const m = Math.round(seconds / 60);
  if (m < 90) return `${m} min`;
  const h = Math.floor(m / 60);
  return `${h} h ${m % 60} min`;
}

export function useAttentionRate(enabled: boolean) {
  return useQuery<AttentionRate>({
    queryKey: ["commit", "rate"],
    queryFn: () => rpc<AttentionRate>("commit.rate", {}).catch(() => DEFAULT_RATE),
    enabled,
    staleTime: 10 * 60_000,
    retry: false,
  });
}

export type Outcomes = {
  promises: IntentPromise[];
  cost: IntentCost | null;
  words: number;
  recipients: string[];
  ready: boolean;
};

/** Debounced (deferred) kernel scan. Har akshar par nahi — typing kabhi nahi atakti. */
export function useOutcomes(
  body: string,
  recipientFields: string[],
  rate: AttentionRate,
  enabled: boolean,
): Outcomes {
  const deferred = useDeferredValue(body);
  const [stable, setStable] = useState(deferred);
  const [ready, setReady] = useState(() => kernelIfReady() !== null);
  const rcpt = recipientFields.join("\n");

  useEffect(() => {
    if (!enabled) return;
    const t = setTimeout(() => setStable(deferred), 350);
    return () => clearTimeout(t);
  }, [deferred, enabled]);

  useEffect(() => {
    if (!enabled || ready) return;
    let live = true;
    void getKernel().then((k) => live && k && setReady(true));
    return () => {
      live = false;
    };
  }, [enabled, ready]);

  return useMemo<Outcomes>(() => {
    const recipients = recipientList(...rcpt.split("\n"));
    const words = countWords(stable);
    const k = enabled ? kernelIfReady() : null;
    if (!k) return { promises: [], cost: null, words, recipients, ready: false };
    const now = Date.now() / 1000;
    const tz = -new Date().getTimezoneOffset();
    let promises: IntentPromise[] = [];
    try {
      promises = k.intentScan(ownText(stable), now, tz).promises;
    } catch {
      promises = [];
    }
    let cost: IntentCost | null = null;
    if (recipients.length > 0 && words > 0) {
      try {
        cost = k.intentCost(words, recipients.length, rate.rate_minor_per_hour, rate.wpm);
      } catch {
        cost = null;
      }
    }
    return { promises, cost, words, recipients, ready: true };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [stable, rcpt, rate.rate_minor_per_hour, rate.wpm, enabled, ready]);
}

export type RecordResult = {
  ok: boolean;
  duplicate: boolean;
  promise_id: string;
  task_id: string | null;
  event_id: string | null;
  seq?: number;
};

/** Send ke baad: chuney hue wade. Har ek alag (ek fail baaqi ko nahi rokta). Kernel hi request par HMAC tag lagata hai (rpc). */
export async function recordPromises(
  chosen: { promise: IntentPromise; withEvent: boolean }[],
  ctx: { threadId?: string | undefined; subject: string; to: string[] },
): Promise<{ saved: number; failed: number; events: number }> {
  let saved = 0;
  let failed = 0;
  let events = 0;
  for (const { promise, withEvent } of chosen) {
    try {
      const r = await rpc<RecordResult>("commit.record", {
        phrase: promise.phrase,
        action: promise.action,
        due: promise.due_date ?? "",
        ...(ctx.threadId ? { thread_id: ctx.threadId } : {}),
        subject: ctx.subject,
        exact: promise.due_exact,
        confidence: promise.confidence,
        lang: promise.lang,
        to: ctx.to,
        with_event: withEvent && !!promise.due_date,
      });
      if (r.ok) {
        saved++;
        if (r.event_id) events++;
      } else failed++;
    } catch {
      failed++;
    }
  }
  return { saved, failed, events };
}

export async function recordEconomics(input: {
  words: number;
  recipients: number;
  threadId?: string | undefined;
  callAccepted?: boolean;
}): Promise<void> {
  try {
    await rpc("commit.economics", {
      words: input.words,
      recipients: input.recipients,
      ...(input.threadId ? { thread_id: input.threadId } : {}),
      call_accepted: !!input.callAccepted,
    });
  } catch {
    /* log hai, send ko kabhi nahi rokta */
  }
}
