import { motion } from "framer-motion";
import { MailPlus } from "lucide-react";
import { useEffect, useState } from "react";

import { useAuth } from "@/lib/auth";
import { useCalPrefs } from "@/lib/calprefs";
import { dayPart } from "@/lib/greeting";
import { useLocale } from "@/lib/i18n";
import { showCrm, surfaceFromSession } from "@/lib/plan-surface";
import { formatDuration, useAnalytics, useSummary, useUpcoming } from "@/lib/dashboard";

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
export function Greeting({ enabled, onCompose }: { enabled: boolean; onCompose: () => void }) {
  const { session, organisation } = useAuth();
  const { t } = useLocale();
  const { copyName, kind, billed } = surfaceFromSession(session?.user, organisation?.slug);
  const firstName =
    session?.user.display_name?.split(" ")[0] || session?.user.name?.split(" ")[0] || "";
  // Literal t() calls — extractor (scripts/i18n-extract.mjs) inhe dhoond leta hai.
  // A dashboard left open across 12:00 / sunset / 22:00 must change its words without a reload: re-read the clock every minute.
  const [, setMinute] = useState(0);
  useEffect(() => {
    const id = window.setInterval(() => setMinute((n) => n + 1), 60_000);
    return () => window.clearInterval(id);
  }, []);
  // Home city from Settings (one source of truth for "where am I"); the browser's zone only when none is saved.
  const prefs = useCalPrefs();
  // Home city (Settings > Personal > Home city) gives the exact sunset; the zone saved with the working hours is the older fallback.
  const part = prefs.home
    ? dayPart(new Date(), prefs.home.iana, prefs.home)
    : dayPart(new Date(), prefs.hoursSet ? prefs.workHours.tz : undefined);
  const greeting =
    part === "morning"
      ? { text: t("Good morning"), emoji: "☀️" }
      : part === "afternoon"
        ? { text: t("Good afternoon"), emoji: "🌤️" }
        : part === "evening"
          ? { text: t("Good evening"), emoji: "🌆" }
          : { text: t("Good night"), emoji: "🌙" };

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
      strips.push(`${s.unread} ${t(s.unread === 1 ? "unread thread" : "unread threads")}`);
    }
    // Assigning threads is a team idea — a Personal account has nobody to assign to.
    if (kind !== "personal" && s.assigned_to_me > 0) {
      strips.push(`${s.assigned_to_me} ${t("assigned to you")}`);
    }
  }

  const next = events[0];
  if (next) {
    const mins = minutesUntil(next.starts_at);
    if (mins > 0 && mins < 480) {
      const label = mins < 60 ? `${mins}m` : `${Math.round(mins / 60)}h`;
      strips.push(`"${next.title}" in ${label}`);
    }
  }

  if (a?.avg_first_reply_seconds != null) {
    strips.push(`${t("Avg reply")} ${formatDuration(a.avg_first_reply_seconds)}`);
  }

  return (
    <motion.header
      initial={{ opacity: 0, y: -10 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.5, ease: [0.25, 0.46, 0.45, 0.94] }}
      className="flex items-start justify-between gap-6"
    >
      <div className="min-w-0">
        {/* "Command center" sirf founder ke liye (22 Oct hukm) — real user ko yeh label nahi dikhta */}
        {session?.user.is_founder ? <p className="ax-eyebrow">{t("Command center")}</p> : null}
        <h2 className={`ax-display text-foreground ${session?.user.is_founder ? "mt-2" : ""}`}>
          {greeting.text}
          {firstName ? `, ${firstName}` : ""} {greeting.emoji}
        </h2>
        {session ? <p className="ax-caption mt-1.5 text-cyan-accent/90">{t(copyName)}</p> : null}
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
          <p className="ax-body mt-2 max-w-xl text-muted-foreground">
            {kind === "personal"
              ? showCrm(billed, null, kind)
                ? t("Private command of mail, people, calendar, work, CRM and chat — one surface.")
                : t("Private command of mail, people, calendar and work — one surface.")
              : billed === "business" || billed === "business_pro"
                ? t("Company mail, org, chat and the shared book — one surface.")
                : billed === "pro"
                  ? t("Company mail, shared inbox, tasks and the shared book — one surface.")
                  : t("Company mail on your own domain, people and calendar — one surface.")}
          </p>
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
        <span className="hidden sm:inline">{t("New email")}</span>
      </motion.button>
    </motion.header>
  );
}
