/**
 * SLA proof strip — real numbers only.
 *
 * NO MOCK rule: this reads GET /api/public/sla (public, no auth) which the
 * backend computes from `resolution_log`. If the endpoint is not wired yet,
 * or there is no measured window, the strip renders nothing at all — we never
 * print an invented response time on the landing page.
 */

import { useQuery } from "@tanstack/react-query";

import { Reveal } from "@/components/site/Reveal";
import { api, type ApiError } from "@/lib/api";

type SlaStats = {
  avg_first_reply_seconds: number | null;
  resolved_count: number;
  window_days: number;
  resolution_rate: number | null;
};

function duration(seconds: number) {
  if (seconds < 60) return `${Math.round(seconds)}s`;
  const m = Math.floor(seconds / 60);
  const s = Math.round(seconds % 60);
  return s === 0 ? `${m}m` : `${m}m ${s.toString().padStart(2, "0")}s`;
}

export function SlaProof() {
  const { data } = useQuery<SlaStats, ApiError>({
    queryKey: ["public", "sla"],
    queryFn: () => api<SlaStats>("/api/public/sla", { auth: false }),
    retry: false,
    staleTime: 300_000,
  });

  if (!data || data.avg_first_reply_seconds === null || data.resolved_count === 0) return null;

  const items: { v: string; k: string }[] = [
    { v: duration(data.avg_first_reply_seconds), k: "Average first reply" },
    { v: data.resolved_count.toLocaleString(), k: `Conversations resolved · last ${data.window_days} days` },
  ];
  if (data.resolution_rate !== null) {
    items.push({ v: `${Math.round(data.resolution_rate * 100)}%`, k: "Resolved on first reply" });
  }

  return (
    <Reveal>
      <div className="ax-container">
        <div className="grid gap-px overflow-hidden rounded-xl border border-border sm:grid-cols-3">
          {items.map((i) => (
            <div key={i.k} className="ax-plane rounded-none border-0 p-7 text-center">
              <p className="text-3xl md:text-[2.5rem] text-cyan-accent drop-shadow-[0_0_28px_rgba(6,182,212,0.3)]">
                {i.v}
              </p>
              <p className="mt-2.5 text-[12px] tracking-[0.06em] text-muted-foreground uppercase">
                {i.k}
              </p>
            </div>
          ))}
        </div>
      </div>
    </Reveal>
  );
}
