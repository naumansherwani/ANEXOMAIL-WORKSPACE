// LA-1 / LA-5 (Look, additive): "why is the orb this colour". PURE: no DOM, no network. It only READS the answers the page already has
// (the trouble checks that colour the orb + the kernel's verified/unverified state + the endpoint probe count). It never invents a reason:
// unverified = grey with that sentence, nothing known = grey with that sentence. The orb itself (Scene3D.tsx) is not touched.
export type OrbTone = "ok" | "warn" | "fail" | "unknown";
export type WhyItem = { name: string; state: string; detail?: string };
export type WhyIn = { tone: OrbTone; ks: string; items: WhyItem[] | null; endpointsOk: number | null; endpointsAll: number | null };
export type WhyLine = { name: string; state: string; detail: string };
export type Why = { colour: string; headline: string; lines: WhyLine[]; summary: string; sr: string };

const COLOUR: Record<OrbTone, string> = { ok: "Green", warn: "Amber", fail: "Red", unknown: "Grey" };
/** snake_case id -> "Snake case" (the checks arrive as ids like mail_outbox). */
export const niceName = (s: string): string => { const t = String(s || "").replace(/[_-]+/g, " ").trim(); return t ? t[0]!.toUpperCase() + t.slice(1) : "Check"; };
const clip = (s: unknown, n = 120): string => { const t = String(s ?? "").replace(/\s+/g, " ").trim(); return t.length > n ? t.slice(0, n - 1) + "…" : t; };
const RANK: Record<string, number> = { fail: 0, warn: 1 };

export function orbWhy(i: WhyIn): Why {
  const colour = COLOUR[i.tone];
  if (i.ks !== "verified") return done(colour, `${colour}: answers are not verified yet`, [], "This browser has not verified the server's answers yet. A grey orb means unknown, never a guess.");
  if (!i.items) return done(colour, `${colour}: waiting for the first health answer`, [], "Nothing has been measured yet.");
  const bad = i.items.filter((x) => x.state !== "ok").sort((a, b) => (RANK[a.state] ?? 2) - (RANK[b.state] ?? 2));
  const tot = i.items.length;
  const lines = bad.map((x) => ({ name: niceName(x.name), state: x.state, detail: clip(x.detail) }));
  const ep = i.endpointsAll != null && i.endpointsAll > 0 && i.endpointsOk != null ? ` ${i.endpointsOk} of ${i.endpointsAll} endpoints answering.` : "";
  const headline = bad.length === 0 ? `${colour}: all ${tot} checks fine` : `${colour}: ${bad.length} of ${tot} ${bad.length === 1 ? "check needs" : "checks need"} a look`;
  const summary = `${tot - bad.length} of ${tot} checks fine.${ep}`;
  return done(colour, headline, lines, summary);
}
function done(colour: string, headline: string, lines: WhyLine[], summary: string): Why {
  return { colour, headline, lines, summary, sr: [headline + ".", ...lines.map((l) => `${l.name}: ${l.state}${l.detail ? ", " + l.detail : ""}.`), summary].join(" ") };
}
