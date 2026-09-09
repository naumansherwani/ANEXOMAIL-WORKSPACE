import { motion } from "framer-motion";
import { MailPlus } from "lucide-react";

import { useAuth } from "@/lib/auth";
import {
  formatDuration,
  useAnalytics,
  useSummary,
  useUpcoming,
} from "@/lib/dashboard";

function timeGreeting(): { text: string; emoji: string } {
  const h = new Date().getHours();
  if (h < 12) return { text: "Good morning", emoji: "☀️" };
  if (h < 17) return { text: "Good afternoon", emoji: "🌤️" };
  return { text: "Good evening", emoji: "🌙" };
}

function minutesUntil(iso: string): number {
  return Math.round((new Date(iso).getTime() - Date.now()) / 60_000);
}

/**
 * Greeting — P2 Dashboard top banner.
 *
 * Time-aware greeting with the user's first name.
 * Situational awareness strip: unread · upcoming event · avg reply speed.
 * Reuses existing dashboard React Query hooks — zero extra API calls.
 * Primary compose CTA floats right.
 *
 * Wire: useAuth (session) + useSummary + useUpcoming + useAnalytics
 *       → all routed through /api/dashboard/* → Bun :3100 → Supabase
 */
export function Greeting({
  enabled,
  onCompose,
}: {
  enabled: boolean;
  onCompose: () => void;
}) {
  const { session } = useAuth();
  const firstName =
    session?.user.name?.split(" ")[0] ??
    session?.user.email?.split("@")[0] ??
    "";
  const { text, emoji } = timeGreeting();

  // React Query deduplicates — these calls hit the same in-memory cache
  // used by WidgetGrid, AnalyticsPanel, and UpcomingPanel siblings.
  const summary = useSummary(enabled);
  const upcoming = useUpcoming(enabled);
  const analytics = useAnalytics(enabled);

  const s = summary.data;
  const events = upcoming.data?.events ?? [];
  const a = analytics.data;

  // Build situational awareness strip — pure JS logic, no AI, no extra API
  const strips: string[] = [];

  if (s) {
    if (s.unread > 0) {
      strips.push(`${s.unread} unread ${s.unread === 1 ? "thread" : "threads"}`);
    }
    if (s.assigned_to_me > 0) {
      strips.push(`${s.assigned_to_me} assigned to you`);
    }
  }

  if (events.length > 0) {
    const next = events[0];
    const mins = minutesUntil(next.starts_at);
    if (mins > 0 && mins < 480) {
      const label = mins < 60 ? `${mins}m` : `${Math.round(mins / 60)}h`;
      strips.push(`"${next.title}" in ${label}`);
    }
  }

  if (a?.avg_first_reply_seconds != null) {
    strips.push(`Avg reply ${formatDuration(a.avg_first_reply_seconds)}`);
  }

  const fallback =
    "Everything that needs you — mail, activity, schedule. One surface, no reload.";

  return (
    <motion.header
      initial={{ opacity: 0, y: -10 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.5, ease: [0.25, 0.46, 0.45, 0.94] }}
      className="flex items-start justify-between gap-6"
    >
      <div className="min-w-0">
        <p className="ax-eyebrow">Command center</p>
        <h2 className="ax-display mt-2 text-foreground">
          {text}
          {firstName ? `, ${firstName}` : ""} {emoji}
        </h2>
        {strips.length > 0 ? (
          <motion.p
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            transition={{ delay: 0.35, duration: 0.5 }}
            className="ax-body mt-2 max-w-2xl text-muted-foreground"
          >
            {strips.join("  ·  ")}
          </motion.p>
        ) : (
          <p className="ax-body mt-2 max-w-xl text-muted-foreground">{fallback}</p>
        )}
      </div>

      <motion.button
        initial={{ opacity: 0, scale: 0.92 }}
        animate={{ opacity: 1, scale: 1 }}
        transition={{ delay: 0.2, duration: 0.4, ease: "easeOut" }}
        whileTap={{ scale: 0.95 }}
        type="button"
        onClick={onCompose}
        className="ax-press ax-tap flex shrink-0 items-center gap-2 rounded-xl bg-primary px-4 py-2.5 text-sm font-semibold text-primary-foreground transition-colors hover:bg-primary/90"
      >
        <MailPlus className="size-4" />
        <span className="hidden sm:inline">New email</span>
      </motion.button>
    </motion.header>
  );
}
