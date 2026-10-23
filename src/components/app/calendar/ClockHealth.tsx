import { Gauge, RefreshCw } from "lucide-react";

import { describeDrift, latencyStats, protocolLabel } from "@/lib/clock-sync";
import { cn } from "@/lib/utils";
import { useClockHealth } from "@/lib/useClockHealth";

/**
 * "Device clock" + "Connection" lines in the world-clock popover. Measured from THIS device against the server; shown to this person only.
 * Nothing is stored and nothing is sent anywhere except the tiny time requests themselves. No claim beyond what was measured.
 */
export function ClockHealth({ className }: { className?: string }) {
  const q = useClockHealth(true);
  const r = q.data;
  const drift = r ? describeDrift(r.offsetMs, r.errorMs) : null;
  const lat = r ? latencyStats(r.rtts) : null;
  const proto = r ? protocolLabel(r.protocol) : "";
  return (
    <div
      className={cn("rounded-md border border-border px-2.5 py-2 text-[12px]", className)}
      aria-live="polite"
    >
      <div className="flex items-center gap-1.5">
        <Gauge className="size-3.5 shrink-0 text-muted-foreground" aria-hidden="true" />
        <span className="font-semibold text-foreground">Clock &amp; connection</span>
        <button
          type="button"
          onClick={() => void q.refetch()}
          disabled={q.isFetching}
          aria-label="Measure again"
          title="Measure again"
          className="ax-press ax-focus ml-auto rounded p-0.5 text-muted-foreground hover:text-foreground disabled:opacity-50"
        >
          <RefreshCw
            className={cn("size-3.5", q.isFetching && "animate-spin")}
            aria-hidden="true"
          />
        </button>
      </div>
      {q.isPending || (q.isFetching && !r) ? (
        <p className="mt-1 text-muted-foreground">Checking…</p>
      ) : !r || !drift || !lat ? (
        <p className="mt-1 text-muted-foreground">
          Could not measure right now. Nothing is wrong with your account.
        </p>
      ) : (
        <>
          <p
            className={cn(
              "mt-1",
              drift.tone === "warn" ? "font-semibold text-amber-300" : "text-foreground",
            )}
          >
            {drift.text}
          </p>
          {drift.fix && <p className="mt-0.5 text-muted-foreground">{drift.fix}</p>}
          <p className="mt-1 text-muted-foreground">
            Connection to ANEXOMAIL: typical {Math.round(lat.p50)} ms · slowest 5%{" "}
            {Math.round(lat.p95)} ms{proto ? ` · ${proto}` : ""}
            <span className="block text-[11px]">
              Measured now from this device ({lat.n} checks). Only you see this; nothing is saved.
            </span>
          </p>
        </>
      )}
    </div>
  );
}
