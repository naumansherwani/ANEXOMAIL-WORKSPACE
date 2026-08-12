import { ArrowRight, Coins, Download, Gauge, ShieldAlert, Timer } from "lucide-react";

import { Chip } from "@/components/app/crm/CrmBits";
import { Button } from "@/components/ui/button";
import {
  AGENT_LABEL,
  type AiAgentKey,
  type AiCredits,
  type AiGuardrailEvent,
  type AiReceipt,
} from "@/lib/ai-workspace";
import { cn } from "@/lib/utils";

export { Chip };

/**
 * Escalation Chain strip — locked chain: User -> LEO -> Jimmy -> Sherlock.
 * Jimmy kabhi Leo ko replace nahi karta; ye strip sirf live state dikhati hai.
 */
export function EscalationStrip({ active }: { active: AiAgentKey | null }) {
  const chain: AiAgentKey[] = ["leo", "jimmy", "sherlock"];
  return (
    <div className="flex flex-wrap items-center gap-2" aria-label="Escalation chain">
      <span className="ax-caption text-muted-foreground">You</span>
      {chain.map((a) => (
        <span key={a} className="flex items-center gap-2">
          <ArrowRight className="size-3 text-steel" aria-hidden="true" />
          <span
            data-live={active === a ? "true" : "false"}
            className="ax-caption rounded-full border border-border px-2 py-0.5 font-semibold text-muted-foreground data-[live=true]:border-primary/50 data-[live=true]:bg-primary/10 data-[live=true]:text-foreground"
          >
            {AGENT_LABEL[a]}
            {a === "leo" ? " · primary" : a === "sherlock" ? " · validation" : " · escalation only"}
          </span>
        </span>
      ))}
    </div>
  );
}

/** TTFT badge — speed is a feature, so it is always on screen. */
export function TtftBadge({ ms }: { ms: number | null }) {
  if (ms === null) return null;
  return (
    <span
      className={cn(
        "ax-caption inline-flex items-center gap-1 rounded-full border px-2 py-0.5 font-semibold",
        ms < 400
          ? "border-success/40 bg-success/10 text-success"
          : ms < 1200
            ? "border-warning/40 bg-warning/10 text-warning"
            : "border-danger/40 bg-danger/10 text-danger",
      )}
    >
      <Timer className="size-3" aria-hidden="true" /> first token {ms}ms
    </span>
  );
}

/** Answer Receipt — model, tokens, cost, latency, sources. Server truth only. */
export function ReceiptCard({ receipt }: { receipt: AiReceipt }) {
  const money = `${receipt.currency === "GBP" ? "£" : `${receipt.currency} `}${receipt.cost.toFixed(4)}`;
  return (
    <div className="mt-ax-3 rounded-xl border border-border bg-secondary/40 p-ax-3">
      <div className="flex flex-wrap items-center gap-2">
        <Chip>{receipt.model}</Chip>
        <Chip>
          {receipt.input_tokens}+{receipt.output_tokens} tokens
        </Chip>
        <Chip>{money}</Chip>
        {receipt.latency_ms !== null && <Chip>{receipt.latency_ms}ms</Chip>}
        <TtftBadge ms={receipt.ttft_ms} />
        {receipt.escalated_to && (
          <Chip tone="warn">escalated to {AGENT_LABEL[receipt.escalated_to]}</Chip>
        )}
        {receipt.sherlock_verdict && <Chip tone="good">Sherlock: {receipt.sherlock_verdict}</Chip>}
      </div>
      {receipt.sources.length > 0 && (
        <ul className="mt-2 space-y-1">
          {receipt.sources.map((s) => (
            <li key={s.ref} className="ax-caption text-muted-foreground">
              <span className="font-semibold text-foreground">{s.title}</span>
              {s.kind ? ` · ${s.kind}` : ""} · <span className="font-mono">{s.ref}</span>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}

/**
 * Credits meter — founder unlimited hai, phir bhi burn dikhta hai.
 * Charge zero, cost visible: real ledger, zero limit.
 */
export function CreditsMeter({
  credits,
  estimateTokens,
}: {
  credits: AiCredits;
  estimateTokens?: number;
}) {
  const sym = credits.currency === "GBP" ? "£" : `${credits.currency} `;
  const estimate =
    estimateTokens && credits.rate_per_1k !== null
      ? (estimateTokens / 1000) * credits.rate_per_1k
      : null;
  return (
    <div className="ax-plane rounded-2xl p-ax-4">
      <p className="ax-caption flex items-center gap-1.5 text-muted-foreground">
        <Coins className="size-3.5" aria-hidden="true" /> Burn
        {credits.unlimited && <Chip tone="good">founder · not charged</Chip>}
      </p>
      <p className="mt-1 text-2xl font-bold text-foreground">
        {sym}
        {credits.spent_today.toFixed(4)}
        <span className="ax-caption ml-1 font-normal text-muted-foreground">today</span>
      </p>
      <p className="ax-caption mt-1 text-muted-foreground">
        {sym}
        {credits.spent_month.toFixed(4)} this month
        {credits.unlimited
          ? " · cost tracked, never billed"
          : ` · balance ${sym}${credits.balance.toFixed(2)}`}
      </p>
      {estimate !== null && (
        <p className="ax-caption mt-2 flex items-center gap-1.5 text-foreground">
          <Gauge className="size-3.5 text-steel" aria-hidden="true" /> next answer approx {sym}
          {estimate.toFixed(4)}
        </p>
      )}
    </div>
  );
}

/** Guardrail Card — money / legal / cancel = pause with a reason, never silent. */
export function GuardrailCard({
  event,
  onDecide,
  busy,
}: {
  event: AiGuardrailEvent;
  onDecide?: (decision: "release" | "refuse") => void;
  busy?: boolean;
}) {
  return (
    <div className="mt-ax-3 rounded-xl border border-warning/40 bg-warning/5 p-ax-3">
      <p className="flex items-center gap-2 text-[13px] font-bold text-foreground">
        <ShieldAlert className="size-4 text-warning" aria-hidden="true" />
        Paused — {event.keyword}
        <Chip tone={event.state === "paused" ? "warn" : event.state === "released" ? "good" : "bad"}>
          {event.state}
        </Chip>
      </p>
      <p className="ax-caption mt-1 text-muted-foreground">{event.reason}</p>
      {onDecide && event.state === "paused" && (
        <div className="mt-ax-3 flex gap-2">
          <Button size="sm" disabled={busy} onClick={() => onDecide("release")}>
            Release
          </Button>
          <Button size="sm" variant="secondary" disabled={busy} onClick={() => onDecide("refuse")}>
            Refuse
          </Button>
        </div>
      )}
    </div>
  );
}

export function ExportButtons({ onExport }: { onExport: (format: "md" | "json") => void }) {
  return (
    <div className="flex gap-2">
      {(["md", "json"] as const).map((f) => (
        <Button key={f} size="sm" variant="secondary" onClick={() => onExport(f)}>
          <Download className="size-3.5" aria-hidden="true" /> {f.toUpperCase()}
        </Button>
      ))}
    </div>
  );
}