/**
 * ANEXOMAIL — PHASE 12A: ADVANCED EMAIL WORD PREDICTION.
 *
 * Architecture (locked):
 *   Email Composer -> Prediction Controller (usePrediction)
 *                  -> Context Builder (buildPredictionContext)
 *                  -> Prediction Engine (Rust /rpc/mail.predict PRIMARY,
 *                     Bun /api/mail/predict FALLBACK)
 *                  -> Candidate -> Ghost text -> TAB / -> accept
 *
 * LOCKS:
 *  - Assistive only. Prediction NEVER becomes part of the email until accepted,
 *    and it never sends anything.
 *  - Truth is Supabase #4 (global business phrase book + SIRF user ke apne
 *    seekhe hue n-grams). Koi doosre user/conversation ka text nahi, koi
 *    credential/token nahi, koi fabricated fact nahi.
 *  - Engine unavailable = feature chup-chaap OFF. Composer poora usable rehta hai.
 *  - Debounced, cancelable, non-blocking.
 */

import { useCallback, useEffect, useMemo, useRef, useState } from "react";

import { rpcOrRest } from "@/lib/rpc";

export type PredictionCandidate = {
  text: string;
  source?: "you" | "business";
  confidence?: number;
};

export type PredictionContext = {
  /** Lowercased tail (last 1–3 complete words) the engine matches on. */
  prefix: string;
  /** Half-typed word right at the caret ("prop" in "the prop"). */
  partial: string;
  formality: "any" | "formal" | "casual";
  /** True only when a prediction makes sense at this caret. */
  ready: boolean;
};

const MAX_PREFIX_WORDS = 3;

/** Context Builder — sentence/paragraph tail, partial word, formality. */
export function buildPredictionContext(
  text: string,
  caret: number,
  opts: { subject?: string; to?: string; thread?: boolean } = {},
): PredictionContext {
  const before = text.slice(0, Math.max(0, caret));
  // Sirf current sentence/paragraph ka tail — puri email nahi.
  const sentence = before.split(/(?<=[.!?])\s+|\n{2,}/).pop() ?? before;
  const endsWithSpace = /\s$/.test(before);
  const tokens = sentence.trim().split(/\s+/).filter(Boolean);
  const partial = endsWithSpace ? "" : (tokens[tokens.length - 1] ?? "");
  const complete = endsWithSpace ? tokens : tokens.slice(0, -1);
  const prefix = complete
    .slice(-MAX_PREFIX_WORDS)
    .join(" ")
    .toLowerCase()
    .replace(/[^\p{L}\p{N}'\s]/gu, "")
    .trim();

  const blob = `${opts.subject ?? ""} ${before}`.toLowerCase();
  const formality: PredictionContext["formality"] = /\b(dear|kind regards|yours sincerely|i am writing)\b/.test(
    blob,
  )
    ? "formal"
    : /\b(hey|hiya|thanks!|cheers)\b/.test(blob)
      ? "casual"
      : "any";

  return {
    prefix,
    partial: partial.toLowerCase(),
    formality,
    // caret text ke end par ho aur kam se kam 2 mukammal words likhe hon.
    ready: prefix.split(" ").filter(Boolean).length >= 2 && caret >= text.length,
  };
}

/** Prediction Engine call — Rust primary, Bun fallback. */
export async function predictNext(input: {
  prefix: string;
  formality?: string;
  subject?: string;
  to?: string;
  thread_id?: string;
  limit?: number;
}): Promise<PredictionCandidate[]> {
  const body = { limit: 3, ...input };
  const out = await rpcOrRest<{ candidates?: PredictionCandidate[] }>(
    "mail.predict",
    { path: "/api/mail/predict", method: "POST", body },
    body,
  );
  return (out?.candidates ?? []).filter((c) => typeof c?.text === "string" && c.text.trim());
}

/** After a real send: user ke apne likhe se pattern seekho (server side filters). */
export async function learnWritingPattern(text: string) {
  if (text.trim().length < 12) return;
  const body = { text: text.slice(0, 4000) };
  await rpcOrRest("mail.predict.learn", { path: "/api/mail/predict/learn", method: "POST", body }, body);
}

async function logPredictionEvent(action: "accept" | "dismiss" | "conflict", prefix: string) {
  const body = { action, prefix };
  try {
    await rpcOrRest("mail.predict.event", { path: "/api/mail/predict/event", method: "POST", body }, body);
  } catch {
    /* telemetry never blocks writing */
  }
}

type ControllerArgs = {
  text: string;
  caret: number;
  subject?: string;
  to?: string;
  threadId?: string;
  enabled?: boolean;
};

/**
 * Prediction Controller — debounced, cancelable, self-disabling.
 * `ghost` = woh text jo cursor ke aage halka dikhega (typed text ka hissa nahi).
 */
export function usePredictionController({
  text,
  caret,
  subject,
  to,
  threadId,
  enabled = true,
}: ControllerArgs) {
  const [candidate, setCandidate] = useState<PredictionCandidate | null>(null);
  const [available, setAvailable] = useState(true);
  const dismissed = useRef<string | null>(null);
  const seq = useRef(0);

  const ctx = useMemo(
    () => buildPredictionContext(text, caret, { subject, to, thread: Boolean(threadId) }),
    [text, caret, subject, to, threadId],
  );

  useEffect(() => {
    if (!enabled || !available || !ctx.ready) {
      setCandidate(null);
      return;
    }
    if (dismissed.current === ctx.prefix) {
      setCandidate(null);
      return;
    }

    const mine = ++seq.current;
    const timer = setTimeout(() => {
      void predictNext({
        prefix: ctx.prefix,
        formality: ctx.formality,
        ...(subject ? { subject } : {}),
        ...(to ? { to } : {}),
        ...(threadId ? { thread_id: threadId } : {}),
      })
        .then((list) => {
          if (mine !== seq.current) return; // user ne likhna jari rakha — cancel
          // partial word ke saath sirf woh candidate jo us word ko jari rakhe
          const picked = ctx.partial
            ? list.find((c) => c.text.toLowerCase().startsWith(ctx.partial))
            : list[0];
          if (!picked) {
            setCandidate(null);
            return;
          }
          const remainder = ctx.partial ? picked.text.slice(ctx.partial.length) : picked.text;
          if (!remainder.trim()) {
            setCandidate(null);
            return;
          }
          setCandidate({ ...picked, text: remainder });
        })
        .catch(() => {
          if (mine !== seq.current) return;
          setCandidate(null);
          setAvailable(false); // engine offline — feature gracefully band
        });
    }, 220);

    return () => clearTimeout(timer);
  }, [enabled, available, ctx, subject, to, threadId]);

  const dismiss = useCallback(() => {
    dismissed.current = ctx.prefix;
    setCandidate(null);
    if (ctx.prefix) void logPredictionEvent("dismiss", ctx.prefix);
  }, [ctx.prefix]);

  const accepted = useCallback(() => {
    dismissed.current = null;
    if (ctx.prefix) void logPredictionEvent("accept", ctx.prefix);
  }, [ctx.prefix]);

  /** Ghost text ko typed text se alag rakhna zaroori hai — sirf presentation. */
  const ghost = candidate?.text ?? "";
  const needsSpace = ghost ? !/^\s|^[.,!?;:]/.test(ghost) && !/\s$/.test(text.slice(0, caret)) && !ctx.partial : false;

  return {
    ghost,
    /** Jo string accept par insert hogi (spacing samet). */
    insertion: ghost ? `${needsSpace ? " " : ""}${ghost}` : "",
    source: candidate?.source ?? null,
    available,
    dismiss,
    accepted,
  };
}
