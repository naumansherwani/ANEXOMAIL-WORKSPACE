import { Link } from "@tanstack/react-router";
import { motion } from "framer-motion";
import {
  ArrowDownLeft,
  ArrowUpRight,
  CalendarDays,
  CheckSquare,
  Clock,
  Inbox,
  Lock,
  MailPlus,
  Search,
  Send,
  Shield,
  Sparkles,
  Users,
} from "lucide-react";
import { useEffect, useState } from "react";

import { CardBody, DashboardCard, StatSkeleton } from "@/components/app/dashboard/DashboardCard";
import { StateBlock } from "@/components/state/StateBlock";
import {
  formatBytes,
  formatClock,
  formatDuration,
  formatRelative,
  useActivity,
  useAiUsage,
  useAnalytics,
  useSummary,
  useUpcoming,
  type ActivityKind,
} from "@/lib/dashboard";
import { useAuth } from "@/lib/auth";
import { useLocale } from "@/lib/i18n";

/* ----------------------------- Animation helpers ---------------------------- */

/**
 * Eased count-up from 0 → target in `duration` ms.
 * Cancels cleanly on unmount or target change — no phantom state updates.
 */
function useCountUp(target: number, duration = 650): number {
  const [value, setValue] = useState(0);
  useEffect(() => {
    let cancelled = false;
    setValue(0);
    const start = Date.now();
    const tick = () => {
      if (cancelled) return;
      const elapsed = Date.now() - start;
      const progress = Math.min(elapsed / duration, 1);
      const eased = 1 - Math.pow(1 - progress, 3); // ease-out cubic
      setValue(Math.round(eased * target));
      if (progress < 1) requestAnimationFrame(tick);
    };
    requestAnimationFrame(tick);
    return () => {
      cancelled = true;
    };
  }, [target, duration]);
  return value;
}

function AnimatedNumber({ value }: { value: number }) {
  const display = useCountUp(value);
  return <>{display}</>;
}

/** Stagger container — tiles enter one by one, 80 ms apart. */
const gridVariants = {
  hidden: {},
  show: { transition: { staggerChildren: 0.08, delayChildren: 0.05 } },
};

const tileVariants = {
  hidden: { opacity: 0, y: 18 },
  show: {
    opacity: 1,
    y: 0,
    transition: { duration: 0.4, ease: [0.25, 0.46, 0.45, 0.94] as [number, number, number, number] },
  },
};

/* ---------------------------------- Widgets --------------------------------- */

export function WidgetGrid({ enabled }: { enabled: boolean }) {
  const query = useSummary(enabled);
  const { t } = useLocale();

  return (
    <CardBody
      query={query}
      endpoint="/api/dashboard/summary"
      skeleton={
        <div className="grid gap-ax-5 sm:grid-cols-2 xl:grid-cols-4">
          {Array.from({ length: 4 }).map((_, i) => (
            <div key={i} className="ax-plane rounded-2xl p-ax-5">
              <StatSkeleton rows={3} />
            </div>
          ))}
        </div>
      }
    >
      {(data) => {
        const tiles = [
          { icon: Inbox, label: t("Unread"), value: data.unread, to: "inbox" as const },
          {
            icon: CheckSquare,
            label: t("Assigned to me"),
            value: data.assigned_to_me,
            to: "assigned" as const,
          },
          { icon: Clock, label: t("Waiting"), value: data.waiting, to: "waiting" as const },
          { icon: Send, label: t("Closed today"), value: data.done_today, to: "sent" as const },
        ];
        return (
          <motion.div
            className="grid gap-ax-5 sm:grid-cols-2 xl:grid-cols-4"
            variants={gridVariants}
            initial="hidden"
            animate="show"
          >
            {tiles.map((tile) => (
              <motion.div key={tile.label} variants={tileVariants}>
                <Link
                  to="/app/mail/$folder"
                  params={{ folder: tile.to }}
                  className="ax-plane ax-lift ax-press flex w-full flex-col rounded-2xl p-ax-5"
                >
                  <span className="flex items-center gap-ax-2 text-steel">
                    <tile.icon aria-hidden="true" className="size-4" />
                    <span className="ax-caption">{tile.label}</span>
                  </span>
                  <span className="mt-ax-3 text-3xl font-bold tabular-nums text-foreground">
                    <AnimatedNumber value={tile.value} />
                  </span>
                </Link>
              </motion.div>
            ))}
            <motion.div
              variants={tileVariants}
              className="sm:col-span-2 xl:col-span-4"
            >
              <div className="ax-plane rounded-2xl p-ax-5">
                <div className="flex flex-wrap items-center gap-ax-3">
                  <Shield aria-hidden="true" className="size-4 text-steel" />
                  <p className="ax-caption text-muted-foreground">
                    {t("Storage")} {formatBytes(data.storage_used_bytes)} /{" "}
                    {formatBytes(data.storage_limit_bytes)}
                  </p>
                  {data.domain_hosted ? (
                    <span className="ax-status ml-auto text-xs font-semibold text-muted-foreground">
                      {t("ANEXOMAIL hosted")}
                    </span>
                  ) : (
                    <span
                      className={`ax-status ${data.domain_verified ? "text-success" : "text-warning"} ml-auto text-xs font-semibold`}
                    >
                      {data.domain_verified ? t("Domain verified") : t("Domain not verified")}
                    </span>
                  )}
                </div>
                <div
                  role="progressbar"
                  aria-label="Storage used"
                  aria-valuemin={0}
                  aria-valuemax={100}
                  aria-valuenow={Math.min(
                    100,
                    Math.round(
                      (data.storage_used_bytes / Math.max(1, data.storage_limit_bytes)) * 100,
                    ),
                  )}
                  className="mt-ax-3 h-1.5 w-full overflow-hidden rounded-full bg-secondary"
                >
                  <span
                    className="block h-full rounded-full bg-cyan-accent"
                    style={{
                      width: `${Math.min(100, (data.storage_used_bytes / Math.max(1, data.storage_limit_bytes)) * 100)}%`,
                    }}
                  />
                </div>
              </div>
            </motion.div>
          </motion.div>
        );
      }}
    </CardBody>
  );
}

/* ------------------------------- Quick actions ------------------------------ */

export function QuickActions({ onCompose }: { onCompose: () => void }) {
  const { session } = useAuth();
  const { t } = useLocale();
  const hostedPersonal = Boolean(
    session?.user.anexomail_address?.endsWith("@anexomail.com") && !session.user.is_founder,
  );

  return (
    <DashboardCard
      title={t("Quick actions")}
      hint={t("One keystroke away from the work.")}
      icon={<Sparkles className="size-4" />}
    >
      <div className="grid gap-ax-2 sm:grid-cols-2">
        <button
          type="button"
          onClick={onCompose}
          className="ax-press ax-tap flex items-center gap-ax-3 rounded-xl bg-primary px-ax-4 py-ax-3 text-left text-sm font-semibold text-primary-foreground transition-colors hover:bg-primary/90"
        >
          <MailPlus aria-hidden="true" className="size-4" />
          {t("New email")}
        </button>
        <Link
          to="/app/mail/$folder"
          params={{ folder: "inbox" }}
          className="ax-press ax-tap ax-row flex items-center gap-ax-3 rounded-xl border border-border px-ax-4 py-ax-3 text-sm font-semibold text-foreground"
        >
          <Inbox aria-hidden="true" className="size-4 text-steel" />
          {t("Open inbox")}
        </Link>
        <Link
          to="/app/search"
          search={{ q: "" }}
          className="ax-press ax-tap ax-row flex items-center gap-ax-3 rounded-xl border border-border px-ax-4 py-ax-3 text-sm font-semibold text-foreground"
        >
          <Search aria-hidden="true" className="size-4 text-steel" />
          {t("Search everything")}
        </Link>
        {!hostedPersonal && (
          <Link
            to="/app/admin/members"
            className="ax-press ax-tap ax-row flex items-center gap-ax-3 rounded-xl border border-border px-ax-4 py-ax-3 text-sm font-semibold text-foreground"
          >
            <Users aria-hidden="true" className="size-4 text-steel" />
            {t("Invite a teammate")}
          </Link>
        )}
        {!hostedPersonal && (
          <Link
            to="/app/admin"
            className="ax-press ax-tap ax-row flex items-center gap-ax-3 rounded-xl border border-border px-ax-4 py-ax-3 text-sm font-semibold text-foreground"
          >
            <Shield aria-hidden="true" className="size-4 text-steel" />
            {t("Domain & ownership")}
          </Link>
        )}
      </div>
    </DashboardCard>
  );
}

/* ------------------------------ Activity feed ------------------------------- */

export function ActivityFeed({ enabled }: { enabled: boolean }) {
  const query = useActivity(enabled);
  const { t } = useLocale();

  const activityLabel: Record<ActivityKind, string> = {
    message_received: t("Received"),
    message_sent: t("Sent"),
    thread_assigned: t("Assigned"),
    thread_done: t("Closed"),
    member_joined: t("Joined"),
    domain_verified: t("Domain"),
    login: t("Sign-in"),
    admin_change: t("Admin"),
  };

  return (
    <DashboardCard
      title={t("Recent activity")}
      hint={t("Every action in this workspace, newest first.")}
      icon={<Clock className="size-4" />}
    >
      <CardBody
        query={query}
        endpoint="/api/dashboard/activity"
        skeleton={<StatSkeleton rows={6} />}
      >
        {(data) =>
          data.items.length === 0 ? (
            <StateBlock
              className="min-h-[10rem]"
              title={t("No activity yet")}
              body={t("As soon as mail moves or someone joins, it shows up here.")}
            />
          ) : (
            <ul className="divide-y divide-border">
              {data.items.map((item) => (
                <li key={item.id} className="ax-row flex items-start gap-ax-3 py-ax-3">
                  <span className="ax-caption mt-0.5 w-16 shrink-0 font-semibold text-steel">
                    {activityLabel[item.kind]}
                  </span>
                  <span className="min-w-0 flex-1">
                    <span className="block truncate text-sm font-semibold text-foreground">
                      {item.subject}
                    </span>
                    <span className="ax-caption block truncate text-muted-foreground">
                      {[item.actor, item.detail].filter(Boolean).join(" · ") || "—"}
                    </span>
                  </span>
                  <time
                    dateTime={item.created_at}
                    className="ax-caption shrink-0 text-muted-foreground"
                  >
                    {formatRelative(item.created_at)}
                  </time>
                </li>
              ))}
            </ul>
          )
        }
      </CardBody>
    </DashboardCard>
  );
}

/* --------------------------------- AI usage -------------------------------- */

export function AiUsagePanel({ enabled }: { enabled: boolean }) {
  const query = useAiUsage(enabled);
  const { t } = useLocale();

  return (
    <DashboardCard
      title={t("Leo credits")}
      hint={t("AI usage for the current period.")}
      icon={<Sparkles className="size-4" />}
    >
      <CardBody
        query={query}
        endpoint="/api/dashboard/ai-usage"
        skeleton={<StatSkeleton rows={3} />}
      >
        {(data) => {
          if (!data.enabled) {
            return (
              <StateBlock
                className="min-h-[10rem]"
                title={t("Leo is not on this workspace")}
                body={t("The AI workspace is a separate product. Your email plan is unaffected.")}
                action={
                  <Link
                    to="/ai"
                    className="ax-press rounded-xl border border-border px-ax-4 py-2 text-xs font-semibold text-foreground"
                  >
                    {t("About Leo")}
                  </Link>
                }
              />
            );
          }
          const remaining = Math.max(0, data.credits_total - data.credits_used);
          const pct = Math.min(
            100,
            Math.round((data.credits_used / Math.max(1, data.credits_total)) * 100),
          );
          return (
            <div>
              <p className="text-3xl font-bold tabular-nums text-foreground">{remaining}</p>
              <p className="ax-caption mt-1 text-muted-foreground">
                {t("credits left of")} {data.credits_total}
                {data.plan ? ` · ${data.plan}` : ""}
              </p>
              <div
                role="progressbar"
                aria-label="Credits used"
                aria-valuemin={0}
                aria-valuemax={100}
                aria-valuenow={pct}
                className="mt-ax-4 h-1.5 w-full overflow-hidden rounded-full bg-secondary"
              >
                <span
                  className="block h-full rounded-full bg-cyan-accent"
                  style={{ width: `${pct}%` }}
                />
              </div>
              {data.period_end && (
                <p className="ax-caption mt-ax-3 text-muted-foreground">
                  {t("Resets")}{" "}
                  {new Date(data.period_end).toLocaleDateString(undefined, {
                    day: "numeric",
                    month: "short",
                  })}
                </p>
              )}
            </div>
          );
        }}
      </CardBody>
    </DashboardCard>
  );
}

/* -------------------------------- Analytics -------------------------------- */

/**
 * Ghost analytics bar — purely visual, no real numbers.
 * Shows locked UI so Basic users see the shape of analytics, not real data.
 * Heights are static design values — never real metrics.
 */
function LockedAnalyticsGhost({ t }: { t: (s: string) => string }) {
  const ghostHeights = [30, 55, 42, 70, 48, 65, 38, 80, 60, 45, 72, 50, 35, 68];
  return (
    <div className="relative overflow-hidden rounded-xl">
      {/* Ghost stat grid */}
      <div className="grid grid-cols-2 gap-ax-4 sm:grid-cols-4 opacity-20 blur-[1px] select-none pointer-events-none">
        {[t("Received"), t("Sent"), t("First reply"), t("Delivered")].map((label) => (
          <div key={label}>
            <span className="ax-caption text-steel">{label}</span>
            <span className="mt-1 block text-xl font-bold text-foreground">—</span>
          </div>
        ))}
      </div>
      {/* Ghost bar chart */}
      <div
        className="mt-ax-5 flex h-24 items-end gap-1 opacity-15 blur-[1.5px] select-none pointer-events-none"
        aria-hidden="true"
      >
        {ghostHeights.map((h, i) => (
          <span
            key={i}
            className="flex-1 rounded-t bg-cyan-accent/70"
            style={{ height: `${h}%` }}
          />
        ))}
      </div>
      {/* Lock overlay */}
      <div className="absolute inset-0 flex flex-col items-center justify-center gap-3 bg-card/80 backdrop-blur-sm">
        <span className="flex size-9 items-center justify-center rounded-xl bg-secondary">
          <Lock className="size-4 text-muted-foreground" />
        </span>
        <p className="text-[12px] font-bold text-foreground">{t("Email analytics")}</p>
        <p className="text-center text-[11px] leading-snug text-muted-foreground/60 max-w-[200px]">
          {t("Volume, reply speed and delivery rate — available on Pro.")}
        </p>
        <a
          href="/app/billing"
          className="flex items-center gap-1.5 rounded-xl bg-primary px-4 py-2 text-[11px] font-semibold text-primary-foreground transition-colors hover:bg-primary/90"
        >
          <Sparkles className="size-3" />
          {t("Upgrade to Pro")}
        </a>
      </div>
    </div>
  );
}

/**
 * proAccess: true  → real analytics from Rust :3200 / Bun fallback
 * proAccess: false → locked ghost panel (Basic) — no real data fetched
 */
export function AnalyticsPanel({ enabled, proAccess }: { enabled: boolean; proAccess: boolean }) {
  const query = useAnalytics(enabled && proAccess);
  const { t } = useLocale();

  return (
    <DashboardCard
      title={t("Email analytics")}
      hint={proAccess ? t("Volume and response speed.") : t("Pro feature.")}
      icon={<ArrowUpRight className="size-4" />}
    >
      {/* Basic — locked ghost panel, no real query fired */}
      {!proAccess ? (
        <LockedAnalyticsGhost t={t} />
      ) : (
        <CardBody
          query={query}
          endpoint="/api/dashboard/analytics"
          skeleton={<StatSkeleton rows={4} />}
        >
          {(data) => {
            const peak = Math.max(1, ...data.series.map((point) => point.received + point.sent));
            return (
              <div>
                <div className="grid grid-cols-2 gap-ax-4 sm:grid-cols-4">
                  <Stat
                    icon={<ArrowDownLeft className="size-3.5" />}
                    label={t("Received")}
                    value={String(data.received)}
                  />
                  <Stat
                    icon={<ArrowUpRight className="size-3.5" />}
                    label={t("Sent")}
                    value={String(data.sent)}
                  />
                  <Stat label={t("First reply")} value={formatDuration(data.avg_first_reply_seconds)} />
                  <Stat
                    label={t("Delivered")}
                    value={
                      data.delivery_rate === null ? "—" : `${Math.round(data.delivery_rate * 100)}%`
                    }
                  />
                </div>
                {data.series.length > 0 && (
                  <div
                    className="mt-ax-5 flex h-24 items-end gap-1"
                    aria-label={`Volume over the last ${data.range_days} days`}
                    role="img"
                  >
                    {data.series.map((point, i) => (
                      <motion.span
                        key={point.date}
                        initial={{ scaleY: 0 }}
                        animate={{ scaleY: 1 }}
                        transition={{
                          duration: 0.45,
                          delay: i * 0.022,
                          ease: "easeOut",
                        }}
                        title={`${point.date}: ${point.received} in, ${point.sent} out`}
                        className="flex-1 rounded-t bg-cyan-accent/70"
                        style={{
                          height: `${Math.max(4, ((point.received + point.sent) / peak) * 100)}%`,
                          transformOrigin: "bottom",
                        }}
                      />
                    ))}
                  </div>
                )}
              </div>
            );
          }}
        </CardBody>
      )}
    </DashboardCard>
  );
}

function Stat({ icon, label, value }: { icon?: React.ReactNode; label: string; value: string }) {
  return (
    <div>
      <span className="ax-caption flex items-center gap-1.5 text-steel">
        {icon}
        {label}
      </span>
      <span className="mt-1 block text-xl font-bold tabular-nums text-foreground">{value}</span>
    </div>
  );
}

/* --------------------------------- Calendar -------------------------------- */

export function UpcomingPanel({ enabled }: { enabled: boolean }) {
  const query = useUpcoming(enabled);
  const { t } = useLocale();

  return (
    <DashboardCard
      title={t("Upcoming")}
      hint={t("Next events on your calendar.")}
      icon={<CalendarDays className="size-4" />}
      to="/app/calendar"
      ctaLabel={t("Open calendar")}
    >
      <CardBody
        query={query}
        endpoint="/api/dashboard/calendar"
        skeleton={<StatSkeleton rows={4} />}
      >
        {(data) =>
          data.events.length === 0 ? (
            <StateBlock
              className="min-h-[10rem]"
              title={t("Nothing scheduled")}
              body={t("Invitations accepted from mail land here automatically.")}
            />
          ) : (
            <ul className="divide-y divide-border">
              {data.events.map((event) => (
                <li key={event.id} className="flex items-start gap-ax-3 py-ax-3">
                  <time
                    dateTime={event.starts_at}
                    className="ax-caption w-16 shrink-0 font-semibold tabular-nums text-steel"
                  >
                    {formatClock(event.starts_at, event.all_day)}
                  </time>
                  <span className="min-w-0">
                    <span className="block truncate text-sm font-semibold text-foreground">
                      {event.title}
                    </span>
                    {event.location && (
                      <span className="ax-caption block truncate text-muted-foreground">
                        {event.location}
                      </span>
                    )}
                  </span>
                </li>
              ))}
            </ul>
          )
        }
      </CardBody>
    </DashboardCard>
  );
}
