import { Link } from "@tanstack/react-router";
import {
  ArrowDownLeft,
  ArrowUpRight,
  CalendarDays,
  CheckSquare,
  Clock,
  Inbox,
  MailPlus,
  Search,
  Send,
  Shield,
  Sparkles,
  Users,
} from "lucide-react";

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

/* ---------------------------------- Widgets --------------------------------- */

export function WidgetGrid({ enabled }: { enabled: boolean }) {
  const query = useSummary(enabled);

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
          { icon: Inbox, label: "Unread", value: data.unread, to: "inbox" as const },
          {
            icon: CheckSquare,
            label: "Assigned to me",
            value: data.assigned_to_me,
            to: "assigned" as const,
          },
          { icon: Clock, label: "Waiting", value: data.waiting, to: "waiting" as const },
          { icon: Send, label: "Closed today", value: data.done_today, to: "sent" as const },
        ];
        return (
          <div className="grid gap-ax-5 sm:grid-cols-2 xl:grid-cols-4">
            {tiles.map((tile) => (
              <Link
                key={tile.label}
                to="/app/mail/$folder"
                params={{ folder: tile.to }}
                className="ax-plane ax-lift ax-press flex flex-col rounded-2xl p-ax-5"
              >
                <span className="flex items-center gap-ax-2 text-steel">
                  <tile.icon aria-hidden="true" className="size-4" />
                  <span className="ax-caption">{tile.label}</span>
                </span>
                <span className="mt-ax-3 text-3xl font-bold tabular-nums text-foreground">
                  {tile.value}
                </span>
              </Link>
            ))}
            <div className="ax-plane rounded-2xl p-ax-5 sm:col-span-2 xl:col-span-4">
              <div className="flex flex-wrap items-center gap-ax-3">
                <Shield aria-hidden="true" className="size-4 text-steel" />
                <p className="ax-caption text-muted-foreground">
                  Storage {formatBytes(data.storage_used_bytes)} of{" "}
                  {formatBytes(data.storage_limit_bytes)}
                </p>
                <span
                  className={`ax-status ${data.domain_verified ? "text-success" : "text-warning"} ml-auto text-xs font-semibold`}
                >
                  {data.domain_verified ? "Domain verified" : "Domain not verified"}
                </span>
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
          </div>
        );
      }}
    </CardBody>
  );
}

/* ------------------------------- Quick actions ------------------------------ */

export function QuickActions({ onCompose }: { onCompose: () => void }) {
  return (
    <DashboardCard title="Quick actions" hint="One keystroke away from the work." icon={<Sparkles className="size-4" />}>
      <div className="grid gap-ax-2 sm:grid-cols-2">
        <button
          type="button"
          onClick={onCompose}
          className="ax-press ax-tap flex items-center gap-ax-3 rounded-xl bg-primary px-ax-4 py-ax-3 text-left text-sm font-semibold text-primary-foreground transition-colors hover:bg-primary/90"
        >
          <MailPlus aria-hidden="true" className="size-4" />
          New email
        </button>
        <Link
          to="/app/search"
          search={{ q: "" }}
          className="ax-press ax-tap ax-row flex items-center gap-ax-3 rounded-xl border border-border px-ax-4 py-ax-3 text-sm font-semibold text-foreground"
        >
          <Search aria-hidden="true" className="size-4 text-steel" />
          Search everything
        </Link>
        <Link
          to="/app/admin/members"
          className="ax-press ax-tap ax-row flex items-center gap-ax-3 rounded-xl border border-border px-ax-4 py-ax-3 text-sm font-semibold text-foreground"
        >
          <Users aria-hidden="true" className="size-4 text-steel" />
          Invite a teammate
        </Link>
        <Link
          to="/app/admin"
          className="ax-press ax-tap ax-row flex items-center gap-ax-3 rounded-xl border border-border px-ax-4 py-ax-3 text-sm font-semibold text-foreground"
        >
          <Shield aria-hidden="true" className="size-4 text-steel" />
          Domain & ownership
        </Link>
      </div>
    </DashboardCard>
  );
}

/* ------------------------------ Activity feed ------------------------------- */

const activityLabel: Record<ActivityKind, string> = {
  message_received: "Received",
  message_sent: "Sent",
  thread_assigned: "Assigned",
  thread_done: "Closed",
  member_joined: "Joined",
  domain_verified: "Domain",
  login: "Sign-in",
  admin_change: "Admin",
};

export function ActivityFeed({ enabled }: { enabled: boolean }) {
  const query = useActivity(enabled);

  return (
    <DashboardCard
      title="Recent activity"
      hint="Every action in this workspace, newest first."
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
              title="No activity yet"
              body="As soon as mail moves or someone joins, it shows up here."
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

  return (
    <DashboardCard
      title="Leo credits"
      hint="AI usage for the current period."
      icon={<Sparkles className="size-4" />}
    >
      <CardBody query={query} endpoint="/api/dashboard/ai-usage" skeleton={<StatSkeleton rows={3} />}>
        {(data) => {
          if (!data.enabled) {
            return (
              <StateBlock
                className="min-h-[10rem]"
                title="Leo is not on this workspace"
                body="The AI workspace is a separate product. Your email plan is unaffected."
                action={
                  <Link
                    to="/ai"
                    className="ax-press rounded-xl border border-border px-ax-4 py-2 text-xs font-semibold text-foreground"
                  >
                    About Leo
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
                credits left of {data.credits_total}
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
                  Resets{" "}
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

export function AnalyticsPanel({ enabled }: { enabled: boolean }) {
  const query = useAnalytics(enabled);

  return (
    <DashboardCard
      title="Email analytics"
      hint="Volume and response speed."
      icon={<ArrowUpRight className="size-4" />}
    >
      <CardBody query={query} endpoint="/api/dashboard/analytics" skeleton={<StatSkeleton rows={4} />}>
        {(data) => {
          const peak = Math.max(
            1,
            ...data.series.map((point) => point.received + point.sent),
          );
          return (
            <div>
              <div className="grid grid-cols-2 gap-ax-4 sm:grid-cols-4">
                <Stat icon={<ArrowDownLeft className="size-3.5" />} label="Received" value={String(data.received)} />
                <Stat icon={<ArrowUpRight className="size-3.5" />} label="Sent" value={String(data.sent)} />
                <Stat
                  label="First reply"
                  value={formatDuration(data.avg_first_reply_seconds)}
                />
                <Stat
                  label="Delivered"
                  value={
                    data.delivery_rate === null
                      ? "—"
                      : `${Math.round(data.delivery_rate * 100)}%`
                  }
                />
              </div>
              {data.series.length > 0 && (
                <div
                  className="mt-ax-5 flex h-24 items-end gap-1"
                  aria-label={`Volume over the last ${data.range_days} days`}
                  role="img"
                >
                  {data.series.map((point) => (
                    <span
                      key={point.date}
                      title={`${point.date}: ${point.received} in, ${point.sent} out`}
                      className="flex-1 rounded-t bg-cyan-accent/70"
                      style={{
                        height: `${Math.max(4, ((point.received + point.sent) / peak) * 100)}%`,
                      }}
                    />
                  ))}
                </div>
              )}
            </div>
          );
        }}
      </CardBody>
    </DashboardCard>
  );
}

function Stat({
  icon,
  label,
  value,
}: {
  icon?: React.ReactNode;
  label: string;
  value: string;
}) {
  return (
    <div>
      <span className="ax-caption flex items-center gap-1.5 text-steel">
        {icon}
        {label}
      </span>
      <span className="mt-1 block text-xl font-bold tabular-nums text-foreground">
        {value}
      </span>
    </div>
  );
}

/* --------------------------------- Calendar -------------------------------- */

export function UpcomingPanel({ enabled }: { enabled: boolean }) {
  const query = useUpcoming(enabled);

  return (
    <DashboardCard
      title="Upcoming"
      hint="Next events on your calendar."
      icon={<CalendarDays className="size-4" />}
      to="/app/calendar"
      ctaLabel="Open calendar"
    >
      <CardBody query={query} endpoint="/api/dashboard/calendar" skeleton={<StatSkeleton rows={4} />}>
        {(data) =>
          data.events.length === 0 ? (
            <StateBlock
              className="min-h-[10rem]"
              title="Nothing scheduled"
              body="Invitations accepted from mail land here automatically."
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