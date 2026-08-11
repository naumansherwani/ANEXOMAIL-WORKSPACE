/**
 * Phase 29 — Premium Experience (client-only, zero backend).
 *
 * Locked rules:
 * - Motion Contract: every transition has a named budget (instant/quick/calm/
 *   cinematic). Real frame cost is measured, not felt. Over budget = a row in
 *   the ledger, never a silent regression.
 * - Calm Mode: one switch kills motion, celebration and pulsing. OS
 *   prefers-reduced-motion is always respected on top of it.
 * - Earned Delight: celebration only fires on a proven finish (inbox zero,
 *   promise kept, DNS green). Awam ke liye default OFF, founder ke liye ON.
 * - Focus Ledger: accessibility shipped with proof — we audit the live DOM.
 */

import { useCallback, useEffect, useState } from "react";

import { founderPreviewEnabled } from "@/lib/founder-preview";

/* ----------------------------- preferences ------------------------------ */

export type Experience = {
  /** Kills motion, celebration, breathing dots and sound. */
  calm: boolean;
  /** Earned celebration on proven completion. */
  delight: boolean;
  /** Focus ring + focus ledger overlay for keyboard auditing. */
  focusAudit: boolean;
};

const KEY = "ax.experience.v1";

export function defaultExperience(): Experience {
  // Founder surfaces get delight ON; every other visitor starts enterprise-quiet.
  const founder = typeof window !== "undefined" && founderPreviewEnabled();
  return { calm: false, delight: founder, focusAudit: false };
}

export function readExperience(): Experience {
  const base = defaultExperience();
  if (typeof window === "undefined") return base;
  try {
    const raw = window.localStorage.getItem(KEY);
    if (!raw) return base;
    const parsed = JSON.parse(raw) as Partial<Experience>;
    return {
      calm: typeof parsed.calm === "boolean" ? parsed.calm : base.calm,
      delight: typeof parsed.delight === "boolean" ? parsed.delight : base.delight,
      focusAudit: typeof parsed.focusAudit === "boolean" ? parsed.focusAudit : base.focusAudit,
    };
  } catch {
    return base;
  }
}

function writeExperience(next: Experience) {
  try {
    window.localStorage.setItem(KEY, JSON.stringify(next));
  } catch {
    /* private mode — preference stays for this tab only */
  }
  window.dispatchEvent(new CustomEvent("ax:experience", { detail: next }));
}

/** True when the OS itself asks for less movement. */
export function osReducedMotion(): boolean {
  if (typeof window === "undefined" || !window.matchMedia) return false;
  return window.matchMedia("(prefers-reduced-motion: reduce)").matches;
}

/** Paints the current preferences onto <html> so CSS can obey them globally. */
function paint(exp: Experience) {
  const el = document.documentElement;
  el.toggleAttribute("data-ax-calm", exp.calm);
  el.toggleAttribute("data-ax-delight", exp.delight && !exp.calm);
  el.toggleAttribute("data-ax-focus-audit", exp.focusAudit);
}

export function useExperience() {
  const [exp, setExp] = useState<Experience>(() =>
    typeof window === "undefined" ? { calm: false, delight: false, focusAudit: false } : readExperience(),
  );

  useEffect(() => {
    const sync = () => setExp(readExperience());
    sync();
    window.addEventListener("ax:experience", sync as EventListener);
    window.addEventListener("storage", sync);
    return () => {
      window.removeEventListener("ax:experience", sync as EventListener);
      window.removeEventListener("storage", sync);
    };
  }, []);

  useEffect(() => {
    paint(exp);
  }, [exp]);

  const set = useCallback((patch: Partial<Experience>) => {
    const next = { ...readExperience(), ...patch };
    writeExperience(next);
    setExp(next);
  }, []);

  return {
    ...exp,
    /** Motion is only allowed when neither the user nor the OS asked for calm. */
    motionAllowed: !exp.calm && !osReducedMotion(),
    osReduced: osReducedMotion(),
    set,
  };
}

/* --------------------------- motion contract ---------------------------- */

export type MotionBudget = "instant" | "quick" | "calm" | "cinematic";

/** The only four durations in the product. Anything else is a bug. */
export const BUDGET_MS: Record<MotionBudget, number> = {
  instant: 90,
  quick: 180,
  calm: 380,
  cinematic: 700,
};

export type MotionSample = { name: string; budget: MotionBudget; actual: number; at: number };

const LEDGER_KEY = "ax.motion.ledger.v1";
const MAX_SAMPLES = 240;

function loadSamples(): MotionSample[] {
  if (typeof window === "undefined") return [];
  try {
    const raw = window.localStorage.getItem(LEDGER_KEY);
    const parsed = raw ? (JSON.parse(raw) as MotionSample[]) : [];
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

function saveSamples(samples: MotionSample[]) {
  try {
    window.localStorage.setItem(LEDGER_KEY, JSON.stringify(samples.slice(-MAX_SAMPLES)));
  } catch {
    /* ledger is diagnostics, never critical */
  }
}

export function recordMotion(name: string, budget: MotionBudget, actual: number) {
  if (typeof window === "undefined") return;
  const samples = loadSamples();
  samples.push({ name, budget, actual: Math.round(actual), at: Date.now() });
  saveSamples(samples);
  window.dispatchEvent(new Event("ax:motion"));
}

/**
 * Measures a real interaction: call it when the user acts, call the returned
 * function when the new frame is on screen. Cost = wall clock, not a guess.
 */
export function measureMotion(name: string, budget: MotionBudget) {
  const start = typeof performance === "undefined" ? Date.now() : performance.now();
  let done = false;
  return () => {
    if (done) return;
    done = true;
    const finish = () => {
      const end = typeof performance === "undefined" ? Date.now() : performance.now();
      recordMotion(name, budget, end - start);
    };
    if (typeof requestAnimationFrame === "function") {
      requestAnimationFrame(() => requestAnimationFrame(finish));
    } else {
      finish();
    }
  };
}

export function clearMotionLedger() {
  try {
    window.localStorage.removeItem(LEDGER_KEY);
  } catch {
    /* nothing to clear */
  }
  window.dispatchEvent(new Event("ax:motion"));
}

export type MotionRow = {
  name: string;
  budget: MotionBudget;
  budget_ms: number;
  samples: number;
  p50: number;
  p95: number;
  worst: number;
  over: number;
  verdict: "green" | "watch" | "fail";
};

function pct(sorted: number[], p: number) {
  if (sorted.length === 0) return 0;
  const i = Math.min(sorted.length - 1, Math.max(0, Math.ceil((p / 100) * sorted.length) - 1));
  return sorted[i] ?? 0;
}

export function motionLedger(): { rows: MotionRow[]; total: number; failing: number } {
  const grouped = new Map<string, MotionSample[]>();
  for (const s of loadSamples()) {
    const k = `${s.name}::${s.budget}`;
    const list = grouped.get(k) ?? [];
    list.push(s);
    grouped.set(k, list);
  }

  const rows: MotionRow[] = [...grouped.entries()].map(([k, list]) => {
    const [name, budget] = k.split("::") as [string, MotionBudget];
    const nums = list.map((s) => s.actual).sort((a, b) => a - b);
    const budget_ms = BUDGET_MS[budget];
    const p95 = pct(nums, 95);
    const over = list.filter((s) => s.actual > budget_ms).length;
    return {
      name,
      budget,
      budget_ms,
      samples: list.length,
      p50: pct(nums, 50),
      p95,
      worst: nums[nums.length - 1] ?? 0,
      over,
      verdict: p95 > budget_ms * 1.5 ? "fail" : p95 > budget_ms ? "watch" : "green",
    };
  });

  rows.sort((a, b) => b.p95 / b.budget_ms - a.p95 / a.budget_ms);
  return {
    rows,
    total: rows.reduce((s, r) => s + r.samples, 0),
    failing: rows.filter((r) => r.verdict === "fail").length,
  };
}

/** Live view of the ledger — re-reads whenever a new sample lands. */
export function useMotionLedger() {
  const [state, setState] = useState(() => ({ rows: [] as MotionRow[], total: 0, failing: 0 }));
  useEffect(() => {
    const sync = () => setState(motionLedger());
    sync();
    window.addEventListener("ax:motion", sync);
    return () => window.removeEventListener("ax:motion", sync);
  }, []);
  return state;
}

/* ------------------------- dropped-frame watcher ------------------------- */

export type FrameWatch = { longFrames: number; worst_ms: number; watching: boolean };

/**
 * Counts frames the browser actually blew past 50ms. Uses the long-animation-frame
 * timeline where available and falls back to long tasks.
 */
export function useFrameWatch() {
  const [state, setState] = useState<FrameWatch>({ longFrames: 0, worst_ms: 0, watching: false });

  useEffect(() => {
    if (typeof PerformanceObserver === "undefined") return;
    const supported = (PerformanceObserver as unknown as { supportedEntryTypes?: string[] })
      .supportedEntryTypes ?? [];
    const type = supported.includes("long-animation-frame")
      ? "long-animation-frame"
      : supported.includes("longtask")
        ? "longtask"
        : null;
    if (!type) return;

    const obs = new PerformanceObserver((list) => {
      let count = 0;
      let worst = 0;
      for (const entry of list.getEntries()) {
        count += 1;
        worst = Math.max(worst, Math.round(entry.duration));
      }
      setState((prev) => ({
        longFrames: prev.longFrames + count,
        worst_ms: Math.max(prev.worst_ms, worst),
        watching: true,
      }));
    });
    try {
      obs.observe({ type, buffered: true } as PerformanceObserverInit);
      setState((prev) => ({ ...prev, watching: true }));
    } catch {
      return;
    }
    return () => obs.disconnect();
  }, []);

  return state;
}

/* ---------------------------- focus ledger ------------------------------ */

export type FocusIssue = { selector: string; problem: string; fix: string };

const INTERACTIVE = 'a[href], button, input, select, textarea, [role="button"], [tabindex]';

function describe(el: Element) {
  const tag = el.tagName.toLowerCase();
  const id = el.id ? `#${el.id}` : "";
  const cls = (el.getAttribute("class") ?? "").split(/\s+/).filter(Boolean).slice(0, 2).join(".");
  return `${tag}${id}${cls ? `.${cls}` : ""}`;
}

function accessibleName(el: Element) {
  const aria = el.getAttribute("aria-label")?.trim();
  if (aria) return aria;
  const labelled = el.getAttribute("aria-labelledby");
  if (labelled) return labelled;
  const title = el.getAttribute("title")?.trim();
  if (title) return title;
  const text = (el as HTMLElement).innerText?.trim();
  if (text) return text;
  const alt = el.querySelector("img[alt]")?.getAttribute("alt")?.trim();
  return alt ?? "";
}

/** Walks the rendered page and reports every keyboard/naming failure it finds. */
export function auditFocus(): { issues: FocusIssue[]; checked: number } {
  if (typeof document === "undefined") return { issues: [], checked: 0 };
  const nodes = [...document.querySelectorAll(INTERACTIVE)].filter((el) => {
    const style = window.getComputedStyle(el);
    if (style.display === "none" || style.visibility === "hidden") return false;
    return (el as HTMLElement).offsetParent !== null || style.position === "fixed";
  });

  const issues: FocusIssue[] = [];
  for (const el of nodes) {
    const selector = describe(el);
    if (!accessibleName(el)) {
      issues.push({
        selector,
        problem: "No accessible name — a screen reader announces nothing.",
        fix: "Add visible text or aria-label describing the single action.",
      });
    }
    const ti = el.getAttribute("tabindex");
    if (ti && Number(ti) > 0) {
      issues.push({
        selector,
        problem: `tabindex="${ti}" forces an unnatural tab order.`,
        fix: "Use 0 (or none) and let DOM order decide the journey.",
      });
    }
    if (el.tagName === "DIV" && el.getAttribute("role") === "button" && ti === null) {
      issues.push({
        selector,
        problem: "Acts like a button but cannot be reached by keyboard.",
        fix: "Use a real <button>, or add tabindex=0 plus key handlers.",
      });
    }
  }

  return { issues, checked: nodes.length };
}

/* --------------------------- earned delight ----------------------------- */

export type Achievement =
  | "inbox-zero"
  | "promise-kept"
  | "dns-green"
  | "migration-delivered"
  | "first-paying-seat";

export const ACHIEVEMENTS: Record<Achievement, { title: string; body: string }> = {
  "inbox-zero": { title: "Inbox zero", body: "Every thread answered, archived or scheduled. Nothing owes you." },
  "promise-kept": { title: "Promise kept", body: "You said you would, and the thread proves you did." },
  "dns-green": { title: "Ownership proven", body: "MX, SPF, DKIM and DMARC are all green on your own domain." },
  "migration-delivered": { title: "Migration delivered", body: "Message-for-message verified. The old provider can be switched off." },
  "first-paying-seat": { title: "First paying seat", body: "Real money, real recurring. The road to £500/month is open." },
};

/** Fires a celebration only when the work is genuinely finished. */
export function celebrate(achievement: Achievement) {
  if (typeof window === "undefined") return;
  const exp = readExperience();
  if (!exp.delight || exp.calm || osReducedMotion()) return;
  window.dispatchEvent(new CustomEvent("ax:celebrate", { detail: achievement }));
}
