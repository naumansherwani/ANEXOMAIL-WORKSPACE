import { BarChart3 } from "lucide-react";

import { useThreadInsights } from "@/lib/compose";

/**
 * Feature 23 — per-thread email analytics. Every number comes from the
 * server (opens, response rate, best send hour). Nothing is estimated here.
 */
export function ThreadInsights({ threadId }: { threadId: string }) {
  const query = useThreadInsights(threadId);
  if (query.isError || query.isPending || !query.data) return null;

  const d = query.data;
  const items = [
    d.opened === null
      ? null
      : { label: "Opened", value: d.opened ? `Yes · ${d.open_count}×` : "Not yet" },
    d.response_rate === null
      ? null
      : { label: "Replies back", value: `${Math.round(d.response_rate * 100)}%` },
    d.avg_response_minutes === null
      ? null
      : { label: "Usual reply", value: formatMinutes(d.avg_response_minutes) },
    d.best_send_hour === null
      ? null
      : {
          label: "Best time to send",
          value: `${String(d.best_send_hour).padStart(2, "0")}:00${
            d.recipient_timezone ? ` ${d.recipient_timezone}` : ""
          }`,
        },
  ].filter(Boolean) as { label: string; value: string }[];

  if (!items.length) return null;

  return (
    <section className="ax-plane flex flex-wrap items-center gap-ax-4 rounded-2xl p-ax-4">
      <span className="flex items-center gap-1.5 text-[11px] font-semibold text-foreground">
        <BarChart3 className="size-3.5" />
        Thread insight
      </span>
      {items.map((item) => (
        <span key={item.label} className="text-[11px] text-muted-foreground">
          {item.label}: <span className="text-foreground">{item.value}</span>
        </span>
      ))}
    </section>
  );
}

function formatMinutes(minutes: number) {
  if (minutes < 60) return `${Math.round(minutes)}m`;
  const hours = minutes / 60;
  return hours < 24 ? `${hours.toFixed(1)}h` : `${(hours / 24).toFixed(1)}d`;
}