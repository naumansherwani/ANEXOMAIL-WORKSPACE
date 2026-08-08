import { Copy, ShieldCheck } from "lucide-react";

import { apiHref } from "@/components/app/calendar/Bits";
import { NotWired } from "@/components/app/dashboard/DashboardCard";
import { ListSkeleton } from "@/components/state/Skeletons";
import { ErrorState } from "@/components/state/StateBlock";
import { Button } from "@/components/ui/button";
import { clockRange, useAvailability, useFocusWindows } from "@/lib/calendar";
import { notify } from "@/lib/notify";
import { cn } from "@/lib/utils";

const STATE_TONE = {
  free: "border-success/40 text-success",
  busy: "border-border text-muted-foreground",
  travel_buffer: "border-amber-400/40 text-amber-400",
  focus: "border-cyan-accent/40 text-cyan-accent",
} as const;

const STATE_LABEL = {
  free: "Free",
  busy: "Busy",
  travel_buffer: "Travel buffer",
  focus: "Deep work",
} as const;

/**
 * Availability that does not lie: real free/busy, travel buffers and protected
 * deep-work windows all come from the server, so a shared link can never
 * offer a slot that is actually taken.
 */
export function Availability({ date }: { date: string }) {
  const slots = useAvailability(date);
  const focus = useFocusWindows();

  if (slots.error) {
    if (slots.error.isNotImplemented || slots.error.code === "no_api_url") {
      return (
        <div className="p-ax-4">
          <NotWired endpoint="GET /api/calendar/availability" />
        </div>
      );
    }
    return <ErrorState body={slots.error.message} onRetry={() => void slots.refetch()} />;
  }
  if (slots.isPending) return <ListSkeleton rows={8} label="Loading availability" />;

  const shareUrl = slots.data?.share_url ? apiHref(slots.data.share_url) : null;

  return (
    <div className="space-y-ax-4 p-ax-4">
      {shareUrl && (
        <div className="flex items-center gap-2 rounded-xl border border-border px-ax-3 py-ax-2">
          <span className="ax-caption min-w-0 flex-1 truncate text-muted-foreground">{shareUrl}</span>
          <Button
            size="sm"
            variant="outline"
            onClick={() => {
              void navigator.clipboard.writeText(shareUrl);
              notify.done("Link copied", "It only ever shows genuinely free time.");
            }}
          >
            <Copy className="size-3.5" />
            Copy
          </Button>
        </div>
      )}

      <ul className="divide-y divide-border rounded-xl border border-border">
        {slots.data?.slots.length === 0 && (
          <li className="ax-caption px-ax-3 py-ax-3 text-muted-foreground">
            Nothing free on this day.
          </li>
        )}
        {slots.data?.slots.map((slot) => (
          <li key={slot.starts_at} className="flex items-center gap-ax-3 px-ax-3 py-ax-2">
            <span className="text-[13px] font-medium text-foreground">
              {clockRange(slot.starts_at, slot.ends_at)}
            </span>
            <span
              className={cn(
                "ml-auto rounded-full border px-2 py-0.5 text-[10px] font-bold uppercase tracking-wide",
                STATE_TONE[slot.state],
              )}
            >
              {slot.label || STATE_LABEL[slot.state]}
            </span>
          </li>
        ))}
      </ul>

      {focus.data && focus.data.windows.length > 0 && (
        <div>
          <p className="ax-eyebrow flex items-center gap-1.5">
            <ShieldCheck className="size-3.5" />
            Deep work shield
          </p>
          <ul className="mt-ax-2 space-y-1">
            {focus.data.windows.map((w) => (
              <li key={w.id} className="ax-caption text-muted-foreground">
                {w.label} · {minute(w.start_minute)}–{minute(w.end_minute)}
                {w.protected ? " · protected" : ""}
              </li>
            ))}
          </ul>
        </div>
      )}
    </div>
  );
}

function minute(m: number) {
  return `${String(Math.floor(m / 60)).padStart(2, "0")}:${String(m % 60).padStart(2, "0")}`;
}