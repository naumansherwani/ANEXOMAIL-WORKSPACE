/**
 * ANEXOMAIL — Phase 47: TELEMETRY TRUTH (PostHog + glitch reporting)
 *
 * Rules:
 *  - Frontend sirf batata hai ke kya toota. Noise filtering, dedupe aur
 *    WhatsApp alert ka faisla backend + Supabase karta hai (NO DUPLICATE).
 *  - Config sirf publishable: VITE_POSTHOG_KEY + VITE_POSTHOG_HOST.
 *    Key na ho to sab kuch chup-chaap band — koi crash, koi console shor nahi.
 *  - Glitch report backend par jata hai: POST {VITE_API_URL}/api/public/glitch/report
 */

type PostHogLike = {
  init: (key: string, options: Record<string, unknown>) => void;
  capture: (event: string, props?: Record<string, unknown>) => void;
  get_session_replay_url?: (options?: Record<string, unknown>) => string | undefined;
  get_session_id?: () => string | undefined;
};

const KEY = import.meta.env["VITE_POSTHOG_KEY"] as string | undefined;
const HOST = (import.meta.env["VITE_POSTHOG_HOST"] as string | undefined) ?? "https://eu.i.posthog.com";
const API = ((import.meta.env["VITE_API_URL"] as string | undefined) ?? "").replace(/\/$/, "");

let ph: PostHogLike | null = null;
let started = false;

/** PostHog session id — glitch log aur replay ko jodne ke liye. */
function sessionId(): string | undefined {
  try {
    return ph?.get_session_id?.();
  } catch {
    return undefined;
  }
}

/** Session replay link — founder seedha recording khol sake. */
function recordingUrl(): string | undefined {
  try {
    return ph?.get_session_replay_url?.({ withTimestamp: true });
  } catch {
    return undefined;
  }
}

export type GlitchKind =
  | "js_error"
  | "unhandled_rejection"
  | "console_error"
  | "api_error"
  | "checkout_error"
  | "render_error";

export function reportGlitch(
  kind: GlitchKind,
  message: string,
  extra?: {
    severity?: "info" | "warning" | "error" | "critical";
    stack?: string | undefined;
    fingerprint?: string | undefined;
    meta?: Record<string, unknown> | undefined;
  },
) {
  if (typeof window === "undefined") return;
  ph?.capture("glitch", { kind, message, ...extra?.meta });
  if (!API) return;
  const body = JSON.stringify({
    kind,
    message: String(message).slice(0, 1000),
    severity: extra?.severity ?? "error",
    stack: extra?.stack?.slice(0, 4000),
    fingerprint: extra?.fingerprint,
    route: window.location.pathname,
    session_id: sessionId(),
    recording_url: recordingUrl(),
    meta: { ...extra?.meta, url: window.location.href, ua: navigator.userAgent },
  });
  void fetch(`${API}/api/public/glitch/report`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body,
    keepalive: true,
    credentials: "omit",
  }).catch(() => {
    /* alert pipeline khud ek naya glitch na bane */
  });
}

/** Rage / dead clicks — khaas taur par pricing table ke buttons. */
function watchRageClicks() {
  const WINDOW_MS = 1200;
  const THRESHOLD = 3;
  let last: { key: string; count: number; at: number } | null = null;

  window.addEventListener(
    "click",
    (event) => {
      const target = event.target as Element | null;
      const hit = target?.closest?.("a,button,[role='button']") as HTMLElement | null;
      if (!hit) return;

      const inPricing = Boolean(
        hit.closest("[data-ax-pricing]") || hit.hasAttribute("data-ax-price-cta"),
      );
      const label =
        hit.getAttribute("data-ax-price-cta") ||
        hit.getAttribute("aria-label") ||
        hit.textContent?.trim().slice(0, 60) ||
        hit.tagName.toLowerCase();
      const key = `${window.location.pathname}::${label}`;
      const now = Date.now();

      if (last && last.key === key && now - last.at < WINDOW_MS) last.count += 1;
      else last = { key, count: 1, at: now };
      last.at = now;

      if (last.count < THRESHOLD) return;
      const count = last.count;
      last = null;

      ph?.capture("rage_click", {
        target: label,
        clicks: count,
        pricing: inPricing,
        route: window.location.pathname,
      });

      if (!API) return;
      void fetch(`${API}/api/public/glitch/trigger`, {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({
          trigger_type: "rage_click",
          route: window.location.pathname,
          target_label: label,
          hit_count: count,
          session_id: sessionId(),
          recording_url: recordingUrl(),
          meta: { pricing: inPricing },
        }),
        keepalive: true,
        credentials: "omit",
      }).catch(() => {});
    },
    { capture: true },
  );
}

function watchErrors() {
  window.addEventListener("error", (event) => {
    const error = (event as ErrorEvent).error as Error | undefined;
    reportGlitch("js_error", error?.message || (event as ErrorEvent).message || "unknown error", {
      stack: error?.stack,
    });
  });

  window.addEventListener("unhandledrejection", (event) => {
    const reason = (event as PromiseRejectionEvent).reason;
    const error = reason instanceof Error ? reason : undefined;
    reportGlitch("unhandled_rejection", error?.message ?? String(reason), { stack: error?.stack });
  });

  // console.error bhi sach hai — lekin severity warning, taake founder ka
  // WhatsApp sirf asli tootne par bajay.
  const original = console.error.bind(console);
  console.error = (...args: unknown[]) => {
    original(...args);
    const first = args[0];
    const message = first instanceof Error ? first.message : args.map(String).join(" ");
    reportGlitch("console_error", message.slice(0, 500), {
      severity: "warning",
      stack: first instanceof Error ? first.stack : undefined,
    });
  };
}

/** Root se ek hi dafa chalta hai. */
export async function startTelemetry() {
  if (started || typeof window === "undefined") return;
  started = true;

  if (KEY) {
    try {
      const mod = await import("posthog-js");
      ph = mod.default as unknown as PostHogLike;
      ph.init(KEY, {
        api_host: HOST,
        capture_pageview: true,
        capture_pageleave: true,
        autocapture: true,
        disable_session_recording: false,
        session_recording: {
          maskAllInputs: true,
          maskTextSelector: "[data-ax-mask]",
          recordCrossOriginIframes: false,
        },
        enable_recording_console_log: true,
        persistence: "localStorage+cookie",
      });
    } catch {
      ph = null;
    }
  }

  watchErrors();
  watchRageClicks();
}
