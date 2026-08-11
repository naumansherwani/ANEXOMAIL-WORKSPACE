import { GitCommitHorizontal } from "lucide-react";
import type { ReactNode } from "react";

import { Verdict } from "@/components/app/premium/PremiumBits";
import { GATE_COPY, ms, verdictOf, type CheckStatus, type Deployment, type Gate } from "@/lib/release";
import { cn } from "@/lib/utils";

/** Phase 30 — launch primitives. Presentation only; every value comes from the server. */

export function GateBadge({ gate }: { gate: Gate }) {
  const copy = GATE_COPY[gate];
  const tone =
    gate === "locked"
      ? "border-ring/50 bg-secondary text-foreground"
      : gate === "ready"
        ? "border-success/40 bg-success/10 text-success"
        : gate === "blocked"
          ? "border-danger/40 bg-danger/10 text-danger"
          : "border-border bg-card text-muted-foreground";

  return (
    <div className={cn("rounded-2xl border px-ax-4 py-ax-3", tone)}>
      <p className="text-[13px] font-bold tracking-[0.08em] uppercase">{copy.label}</p>
      <p className="ax-caption mt-1 opacity-90">{copy.body}</p>
    </div>
  );
}

/** Ek check + uska proof: code, latency, detail. Sirf tick nahi. */
export function CheckRow({
  suite,
  name,
  status,
  latency,
  code,
  detail,
}: {
  suite: string;
  name: string;
  status: CheckStatus;
  latency: number | null;
  code: number | null;
  detail: string | null;
}) {
  return (
    <li className="ax-plane flex flex-wrap items-center gap-ax-3 rounded-xl px-ax-4 py-ax-3 text-[12px]">
      <Verdict verdict={verdictOf(status)}>{status}</Verdict>
      <span className="min-w-0 flex-1">
        <span className="block font-semibold text-foreground">{name}</span>
        <span className="block truncate text-steel">
          {suite}
          {detail ? ` · ${detail}` : ""}
        </span>
      </span>
      <span className="text-steel">{code == null ? "—" : `HTTP ${code}`}</span>
      <span className="ml-auto text-muted-foreground">{ms(latency)}</span>
    </li>
  );
}

/** Deploy receipt — kaunsa commit, kis ne, kitni der, aur uske baad kya badla. */
export function ReceiptCard({ deployment }: { deployment: Deployment }) {
  const d = deployment;
  return (
    <li className="ax-plane rounded-2xl p-ax-4">
      <div className="flex flex-wrap items-center gap-ax-3">
        <Verdict verdict={d.state === "live" ? "green" : d.state === "failed" ? "fail" : "watch"}>
          {d.state.replace("_", " ")}
        </Verdict>
        <span className="inline-flex items-center gap-1.5 font-mono text-[12px] text-foreground">
          <GitCommitHorizontal className="size-3.5 text-steel" aria-hidden="true" />
          {d.commit_sha.slice(0, 10)}
        </span>
        <span className="ax-caption text-muted-foreground">{d.target}</span>
        <span className="ax-caption ml-auto text-steel">
          {new Date(d.started_at).toLocaleString("en-GB")} · {ms(d.ms)}
        </span>
      </div>
      {d.commit_subject && <p className="mt-1.5 text-[13px] text-foreground">{d.commit_subject}</p>}
      <p className="ax-caption mt-1 text-muted-foreground">
        {d.actor ? `Deployed by ${d.actor}` : "Actor not recorded"}
        {d.rollback_of ? ` · rollback of ${d.rollback_of.slice(0, 8)}` : ""}
      </p>
      {d.changed_since_green.length > 0 && (
        <ul className="mt-ax-3 space-y-1">
          {d.changed_since_green.map((line) => (
            <li key={line} className="ax-caption text-steel">
              · {line}
            </li>
          ))}
        </ul>
      )}
    </li>
  );
}

export function Bar({ label, value, max, tone }: { label: string; value: number; max: number; tone: string }) {
  const pct = max <= 0 ? 0 : Math.min(100, Math.round((value / max) * 100));
  return (
    <div>
      <div className="flex items-baseline justify-between">
        <span className="ax-caption text-muted-foreground">{label}</span>
        <span className="text-[13px] font-bold text-foreground">{pct}%</span>
      </div>
      <span className="mt-1 flex h-2.5 overflow-hidden rounded-full bg-secondary">
        <span className={tone} style={{ width: `${pct}%` }} aria-hidden="true" />
      </span>
    </div>
  );
}

export function Note({ children }: { children: ReactNode }) {
  return <p className="ax-caption mt-ax-3 text-muted-foreground">{children}</p>;
}
