import { Link } from "@tanstack/react-router";
import { AlertOctagon, AlertTriangle, CheckCircle2, ChevronRight, Info, RefreshCw } from "lucide-react";
import type { ReactNode } from "react";

import { StateBlock } from "@/components/state/StateBlock";
import { Button } from "@/components/ui/button";
import {
  useFounderCommand,
  type BrainItem,
  type BrainLevel,
  type BrainLight,
  type FounderCommand,
} from "@/lib/founder-brain";
import { cn } from "@/lib/utils";

/**
 * Founder Command Center — the first thing on the founder host.
 *
 * Reads ONE server verdict (`founder.brain.command`): what needs the founder right now, ranked, with a link that
 * lands on the page where it is fixed. Nothing here is computed in the browser, and a signal the server could not
 * read is shown as "not measured" — never as a calm green.
 */

const LIGHT: Record<BrainLight, { label: string; chip: string; Icon: typeof Info }> = {
  green: { label: "All clear", chip: "border-success/40 bg-success/10 text-success", Icon: CheckCircle2 },
  amber: { label: "Needs you", chip: "border-warning/40 bg-warning/10 text-warning", Icon: AlertTriangle },
  red: { label: "Critical", chip: "border-danger/40 bg-danger/10 text-danger", Icon: AlertOctagon },
};

const LEVEL: Record<BrainLevel, { label: string; pill: string }> = {
  critical: { label: "Critical", pill: "border-danger/40 bg-danger/10 text-danger" },
  high: { label: "High", pill: "border-warning/40 bg-warning/10 text-warning" },
  normal: { label: "Normal", pill: "border-border bg-secondary text-foreground" },
  info: { label: "FYI", pill: "border-border text-muted-foreground" },
};

const gbp = (n: number) => `£${Math.round(n).toLocaleString("en-GB")}`;

export function CommandCenter() {
  const q = useFounderCommand();
  const d = q.data;

  return (
    <section aria-labelledby="cc-title" className="mt-8">
      <div className="flex flex-wrap items-center gap-3">
        <h2 id="cc-title" className="text-lg font-bold text-foreground">
          Right now
        </h2>
        {d ? <LightChip light={d.light} /> : null}
        <span className="ax-caption ml-auto text-muted-foreground" aria-live="polite">
          {q.isFetching ? "Refreshing…" : d ? `Updated ${clock(d.generated_at)}` : ""}
        </span>
        <Button
          type="button"
          variant="secondary"
          size="sm"
          className="ax-tap"
          onClick={() => void q.refetch()}
          disabled={q.isFetching}
          aria-label="Refresh command center"
        >
          <RefreshCw className={cn("size-4", q.isFetching && "animate-spin")} aria-hidden="true" />
          <span className="hidden sm:inline">Refresh</span>
        </Button>
      </div>

      {q.isLoading ? (
        <Skeleton />
      ) : q.isError || !d ? (
        <div className="ax-plane mt-3 rounded-2xl">
          <StateBlock
            tone="error"
            icon={<AlertTriangle className="size-5" aria-hidden="true" />}
            title="Command center could not load"
            body={
              q.error?.status === 403
                ? "This view is for the founder account only."
                : q.error?.status === 401
                  ? "Your session ended. Sign in again."
                  : "The Rust engine did not answer. Nothing below is guessed — try again, or check the Launch page."
            }
            action={
              <Button type="button" onClick={() => void q.refetch()} className="ax-tap">
                Try again
              </Button>
            }
            live
          />
        </div>
      ) : (
        <>
          <NeedsYou d={d} />
          <Tiles d={d} />
        </>
      )}
    </section>
  );
}

function LightChip({ light }: { light: BrainLight }) {
  const l = LIGHT[light];
  return (
    <span className={cn("ax-caption inline-flex items-center gap-1.5 rounded-full border px-2.5 py-1 font-semibold", l.chip)}>
      <l.Icon className="size-3.5" aria-hidden="true" />
      {l.label}
    </span>
  );
}

function NeedsYou({ d }: { d: FounderCommand }) {
  const blind = d.blind_spots.length > 0;
  return (
    <div className="mt-3">
      {d.attention.length === 0 ? (
        <div className="ax-plane rounded-2xl">
          <StateBlock
            tone={blind ? "quiet" : "success"}
            icon={blind ? <Info className="size-5" aria-hidden="true" /> : <CheckCircle2 className="size-5" aria-hidden="true" />}
            title={blind ? "Nothing flagged — but not everything was measured" : "Nothing needs you right now"}
            body={
              blind
                ? `Could not read: ${d.blind_spots.join(", ")}. Treat those as unknown, not as fine.`
                : "Releases, move-ins, mail and leads are all inside their limits. This page re-checks every minute."
            }
          />
        </div>
      ) : (
        <ol className="space-y-2" aria-label="Needs your attention, most urgent first">
          {d.attention.map((i, n) => (
            <Item key={i.id} item={i} n={n + 1} />
          ))}
        </ol>
      )}
      {blind && d.attention.length > 0 ? (
        <p className="ax-caption mt-2 text-muted-foreground">Not measured this time: {d.blind_spots.join(", ")}.</p>
      ) : null}
    </div>
  );
}

function Item({ item, n }: { item: BrainItem; n: number }) {
  const l = LEVEL[item.level];
  return (
    <li>
      <Link
        to={item.href}
        className="ax-plane ax-press ax-focus flex min-h-[3.5rem] items-center gap-3 rounded-2xl px-4 py-3"
      >
        <span className="ax-caption w-5 shrink-0 text-center font-semibold text-muted-foreground" aria-hidden="true">
          {n}
        </span>
        <span className="min-w-0 flex-1">
          <span className="flex flex-wrap items-center gap-2">
            <span className={cn("ax-caption rounded-full border px-2 py-0.5 font-semibold", l.pill)}>{l.label}</span>
            <span className="text-sm font-semibold text-foreground">{item.title}</span>
          </span>
          <span className="mt-1 block text-xs leading-relaxed text-muted-foreground">{item.detail}</span>
        </span>
        <ChevronRight className="size-4 shrink-0 text-muted-foreground" aria-hidden="true" />
      </Link>
    </li>
  );
}

function Tiles({ d }: { d: FounderCommand }) {
  const m = d.money;
  const pct = m && m.target_gbp > 0 ? Math.min(100, Math.round((m.committed_mrr_gbp / m.target_gbp) * 100)) : null;
  const r = d.release;
  const mv = d.movein;
  return (
    <div className="mt-4 grid grid-cols-1 gap-3 min-[480px]:grid-cols-2 lg:grid-cols-4">
      <Tile
        label="Monthly recurring revenue"
        value={m ? gbp(m.committed_mrr_gbp) : "—"}
        note={m ? `${pct}% of ${gbp(m.target_gbp)} target · ${gbp(m.gap_gbp)} to go` : "Not measured"}
        to="/app/founder/revenue/pipeline"
      >
        {pct !== null ? (
          <div
            className="mt-2 h-1.5 overflow-hidden rounded-full bg-secondary"
            role="progressbar"
            aria-valuemin={0}
            aria-valuemax={100}
            aria-valuenow={pct}
            aria-label="Progress to monthly target"
          >
            <div className="h-full rounded-full bg-primary" style={{ width: `${pct}%` }} />
          </div>
        ) : null}
      </Tile>
      <Tile
        label="Release gate"
        value={r.gate ? r.gate[0]!.toUpperCase() + r.gate.slice(1) : "—"}
        note={
          r.gate === null
            ? "Not measured"
            : [r.version ? `v${r.version}` : "No version locked", r.blockers ? `${r.blockers} blocking` : "nothing blocking"].join(" · ")
        }
        to="/app/founder/launch"
      />
      <Tile
        label="Move-ins"
        value={mv ? String(mv.active_moves) : "—"}
        note={
          mv
            ? `${mv.blocked} blocked · ${mv.waitlisted} waitlisted · ${mv.cutovers_tonight} tonight`
            : "Not measured"
        }
        to="/app/founder/movein"
      />
      <Tile
        label="Systems"
        value={d.pulse.brain.status === "fail" ? "Brain down" : "Online"}
        note={[
          `Brain ${d.pulse.brain.status === "fail" ? "not answering" : d.pulse.brain.ms != null ? `${d.pulse.brain.ms} ms` : "ok"}`,
          "Rust ok",
          d.pulse.outbox_held == null ? "outbox ?" : `${d.pulse.outbox_held} mail held`,
        ].join(" · ")}
        to="/app/founder/launch/qa"
      />
    </div>
  );
}

function Tile({ label, value, note, to, children }: { label: string; value: string; note: string; to: string; children?: ReactNode }) {
  return (
    <Link to={to} className="ax-plane ax-press ax-focus block rounded-2xl p-4">
      <p className="ax-caption text-muted-foreground">{label}</p>
      <p className="mt-1 text-2xl font-bold text-foreground">{value}</p>
      <p className="mt-1 text-xs leading-relaxed text-muted-foreground">{note}</p>
      {children}
    </Link>
  );
}

function Skeleton() {
  return (
    <div className="mt-3 space-y-2" role="status" aria-label="Loading command center">
      {[0, 1, 2].map((i) => (
        <div key={i} className="ax-plane h-[3.5rem] animate-pulse rounded-2xl" />
      ))}
      <div className="grid grid-cols-1 gap-3 pt-2 min-[480px]:grid-cols-2 lg:grid-cols-4">
        {[0, 1, 2, 3].map((i) => (
          <div key={i} className="ax-plane h-24 animate-pulse rounded-2xl" />
        ))}
      </div>
    </div>
  );
}

function clock(iso: string): string {
  const t = new Date(iso);
  return Number.isNaN(t.getTime()) ? "just now" : t.toLocaleTimeString("en-GB", { hour: "2-digit", minute: "2-digit" });
}
