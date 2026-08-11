import { createFileRoute } from "@tanstack/react-router";
import { useEffect, useState } from "react";
import { Activity, Gauge, KeyboardIcon, Sparkles, Trash2 } from "lucide-react";

import { Section, Stat } from "@/components/app/analytics/AnalyticsBits";
import { Toggle, Verdict } from "@/components/app/premium/PremiumBits";
import { StateBlock } from "@/components/state/StateBlock";
import {
  ACHIEVEMENTS,
  auditFocus,
  celebrate,
  clearMotionLedger,
  measureMotion,
  useExperience,
  useFrameWatch,
  useMotionLedger,
  type Achievement,
  type FocusIssue,
} from "@/lib/experience";
import { notify } from "@/lib/notify";

export const Route = createFileRoute("/app/founder_/motion")({
  head: () => ({
    meta: [
      { title: "Motion contract & focus ledger — ANEXOMAIL" },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: MotionLedgerPage,
});

const ms = (n: number) => `${Math.round(n)}ms`;

/** Founder-only surface (founderworkspace.anexomail.com, IP allowlisted at Caddy). */
function MotionLedgerPage() {
  const ledger = useMotionLedger();
  const frames = useFrameWatch();
  const exp = useExperience();
  const [focus, setFocus] = useState<{ issues: FocusIssue[]; checked: number } | null>(null);

  // Measuring the page's own entrance is the first honest sample in the ledger.
  useEffect(() => {
    const end = measureMotion("founder.motion:mount", "calm");
    end();
  }, []);

  return (
    <div className="mx-auto w-full max-w-3xl px-6 py-8 md:px-8">
      <Section
        eyebrow={<><Gauge className="size-3.5" aria-hidden="true" /> Motion contract</>}
        title="Every animation has a budget, and the budget is measured"
        blurb="Four durations exist in this product: instant 90ms, quick 180ms, calm 380ms, cinematic 700ms. This screen records what the browser actually spent — real samples from this device only, nothing invented."
      >
        <div className="grid gap-ax-3 sm:grid-cols-2 lg:grid-cols-4">
          <Stat label="Samples" value={String(ledger.total)} />
          <Stat label="Over budget" value={String(ledger.failing)} hint="p95 past 1.5× budget" />
          <Stat label="Long frames" value={frames.watching ? String(frames.longFrames) : "—"} hint="browser stalls >50ms" />
          <Stat label="Worst stall" value={frames.worst_ms ? ms(frames.worst_ms) : "—"} />
        </div>

        <div className="mt-ax-4">
          {ledger.rows.length === 0 ? (
            <StateBlock
              icon={<Activity className="size-4" aria-hidden="true" />}
              title="No samples on this device yet"
              body="Open a thread, switch a panel or run the test below — each interaction writes one honest row here."
              action={
                <button
                  type="button"
                  onClick={() => {
                    const end = measureMotion("manual.test:quick", "quick");
                    requestAnimationFrame(() => end());
                  }}
                  className="ax-press rounded-lg border border-border bg-secondary px-3 py-1.5 text-xs font-semibold text-foreground"
                >
                  Record a test interaction
                </button>
              }
            />
          ) : (
            <ul className="space-y-1.5">
              {ledger.rows.map((r) => (
                <li
                  key={`${r.name}-${r.budget}`}
                  className="flex flex-wrap items-center gap-3 rounded-xl border border-border bg-card px-3 py-2 text-sm"
                >
                  <span className="min-w-0 flex-1 truncate font-semibold text-foreground">{r.name}</span>
                  <span className="text-[11px] text-muted-foreground">
                    {r.budget} · budget {ms(r.budget_ms)}
                  </span>
                  <span className="text-[11px] text-steel">
                    p50 {ms(r.p50)} · p95 {ms(r.p95)} · worst {ms(r.worst)}
                  </span>
                  <span className="text-[11px] text-muted-foreground">{r.samples} samples</span>
                  <Verdict verdict={r.verdict}>
                    {r.verdict === "green" ? "within budget" : r.verdict === "watch" ? "watch" : `${r.over} over`}
                  </Verdict>
                </li>
              ))}
            </ul>
          )}
        </div>

        {ledger.rows.length > 0 && (
          <button
            type="button"
            onClick={() => {
              clearMotionLedger();
              notify.done("Motion ledger cleared on this device");
            }}
            className="ax-press mt-ax-4 inline-flex items-center gap-1.5 rounded-lg border border-border bg-card px-2.5 py-1.5 text-xs font-semibold text-foreground"
          >
            <Trash2 className="size-3.5" aria-hidden="true" /> Clear samples
          </button>
        )}
      </Section>

      <Section
        eyebrow={<><KeyboardIcon className="size-3.5" aria-hidden="true" /> Focus ledger</>}
        title="Accessibility with receipts, not claims"
        blurb="Scans everything focusable on the screen you came from and reports what a keyboard or screen-reader user would hit. Zero issues is the only passing score."
      >
        <button
          type="button"
          onClick={() => {
            const end = measureMotion("focus.audit:run", "quick");
            const result = auditFocus();
            setFocus(result);
            end();
            notify.info(
              result.issues.length === 0 ? "Clean — no focus issues found" : `${result.issues.length} focus issues found`,
              `${result.checked} interactive elements checked`,
            );
          }}
          className="ax-press rounded-lg border border-border bg-secondary px-3 py-1.5 text-xs font-semibold text-foreground"
        >
          Run focus audit on this page
        </button>

        {focus && (
          <div className="mt-ax-3">
            <p className="text-sm text-muted-foreground">
              <span className="font-semibold text-foreground">{focus.checked}</span> interactive elements checked ·{" "}
              <span className="font-semibold text-foreground">{focus.issues.length}</span> issues
            </p>
            {focus.issues.length > 0 && (
              <ul className="mt-ax-3 space-y-1.5">
                {focus.issues.slice(0, 20).map((issue, i) => (
                  <li key={`${issue.selector}-${i}`} className="rounded-xl border border-danger/30 bg-danger/5 px-3 py-2">
                    <span className="block text-[12px] font-semibold text-foreground">{issue.selector}</span>
                    <span className="mt-0.5 block text-[11px] text-muted-foreground">{issue.problem}</span>
                    <span className="mt-0.5 block text-[11px] text-steel">Fix: {issue.fix}</span>
                  </li>
                ))}
              </ul>
            )}
          </div>
        )}
      </Section>

      <Section
        eyebrow={<><Sparkles className="size-3.5" aria-hidden="true" /> Earned delight</>}
        title="Celebration only for a proven finish"
        blurb="Public workspaces start quiet — enterprise buyers hate surprise animation. Founder surfaces start with delight on. Nothing fires unless the work is genuinely done."
      >
        <div className="grid gap-ax-2">
          <Toggle
            label="Calm mode"
            hint="Kills motion, celebration and pulsing across the whole workspace."
            checked={exp.calm}
            onChange={(v) => exp.set({ calm: v })}
          />
          <Toggle
            label="Earned delight"
            hint="Celebrate inbox zero, kept promises, green DNS and delivered migrations."
            checked={exp.delight}
            onChange={(v) => exp.set({ delight: v })}
            disabled={exp.calm}
            disabledNote="Calm mode is on — delight stays silent until you switch it off."
          />
          <Toggle
            label="Focus ring audit overlay"
            hint="Paints a high-contrast ring on whatever holds keyboard focus."
            checked={exp.focusAudit}
            onChange={(v) => exp.set({ focusAudit: v })}
          />
        </div>
        <p className="mt-ax-3 text-[11px] text-muted-foreground">
          OS reduced-motion right now: <span className="text-foreground">{exp.osReduced ? "on — motion suppressed" : "off"}</span>
        </p>

        <div className="mt-ax-4 flex flex-wrap gap-2">
          {(Object.keys(ACHIEVEMENTS) as Achievement[]).map((key) => (
            <button
              key={key}
              type="button"
              onClick={() => {
                celebrate(key);
                if (!exp.delight || exp.calm || exp.osReduced) {
                  notify.info("Suppressed — that is correct", "Delight is off, or calm/reduced motion is on.");
                }
              }}
              className="ax-press rounded-lg border border-border bg-card px-2.5 py-1.5 text-[11px] font-semibold text-foreground"
            >
              Preview: {ACHIEVEMENTS[key].title}
            </button>
          ))}
        </div>
      </Section>
    </div>
  );
}
