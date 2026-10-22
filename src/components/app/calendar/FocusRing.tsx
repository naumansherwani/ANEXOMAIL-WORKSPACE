import type { OverlapAssess } from "@/lib/overlap";
import { focusLoad } from "@/lib/overlap";

/**
 * Focus Ring — a small SVG ring: how full this person's working day is (booked time + this meeting).
 * Fresh blue → amber as it fills. Metadata only (free/busy minutes), no percentage claims, no image of the person.
 * `fallback` is drawn when there is nothing honest to show (no shared schedule / day off).
 */
export function FocusRing({
  assess,
  meetingMin,
  fallback,
}: {
  assess: OverlapAssess | undefined;
  meetingMin: number;
  fallback: React.ReactNode;
}) {
  const load = focusLoad(assess, meetingMin);
  if (!load) return <>{fallback}</>;
  const r = 6;
  const c = 2 * Math.PI * r;
  const hue = 215 - 177 * load.frac; // 215 = fresh blue, 38 = amber
  return (
    <svg
      viewBox="0 0 16 16"
      className="size-4 shrink-0 translate-y-[2px] -rotate-90"
      role="img"
      aria-label={load.text}
    >
      <title>{load.text}</title>
      <circle cx="8" cy="8" r={r} fill="none" strokeWidth="2.2" className="stroke-muted" />
      <circle
        cx="8"
        cy="8"
        r={r}
        fill="none"
        strokeWidth="2.2"
        strokeLinecap="round"
        strokeDasharray={`${c * load.frac} ${c}`}
        style={{ stroke: `hsl(${hue} 80% 52%)`, transition: "stroke-dasharray .3s, stroke .3s" }}
      />
    </svg>
  );
}
