import { Link, createFileRoute } from "@tanstack/react-router";
import { CalendarDays, CheckSquare, Clock, Inbox, Shield } from "lucide-react";

export const Route = createFileRoute("/app/")({
  head: () => ({
    meta: [
      { title: "Today — ANEXOMAIL Workspace" },
      {
        name: "description",
        content:
          "Today brings mail needing a reply, the day's events and due work onto one surface.",
      },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: TodayPage,
});

const lanes = [
  {
    icon: Inbox,
    title: "Needs a reply",
    body: "Threads assigned to you with an open status.",
    to: "/app/mail/assigned",
    cta: "Open assigned",
  },
  {
    icon: Clock,
    title: "Waiting on someone",
    body: "Threads you replied to that are still without an answer.",
    to: "/app/mail/waiting",
    cta: "Open waiting",
  },
  {
    icon: CalendarDays,
    title: "Today's schedule",
    body: "Events and invitations for the current day.",
    to: "/app/calendar",
    cta: "Open calendar",
  },
  {
    icon: CheckSquare,
    title: "Due work",
    body: "Tasks and notes linked to a thread and due today.",
    to: "/app/work",
    cta: "Open work",
  },
];

function TodayPage() {
  return (
    <div className="min-h-0 flex-1 overflow-y-auto">
      <div className="mx-auto w-full max-w-5xl px-6 py-10 md:px-10 md:py-14">
        <p className="ax-eyebrow">One surface</p>
        <h1 className="mt-3 text-4xl text-foreground md:text-5xl">Today</h1>
        <p className="mt-4 max-w-xl text-sm leading-relaxed text-muted-foreground">
          Everything that needs you before anything else — replies, waiting threads, the
          day's schedule and due work. No second app, no tab switching.
        </p>

        <div className="mt-10 grid gap-4 sm:grid-cols-2">
          {lanes.map((lane) => (
            <article key={lane.title} className="ax-plane rounded-2xl p-5">
              <span className="flex size-9 items-center justify-center rounded-xl bg-secondary text-steel">
                <lane.icon className="size-4" />
              </span>
              <h2 className="mt-4 text-base font-bold text-foreground">{lane.title}</h2>
              <p className="mt-1.5 text-sm leading-relaxed text-muted-foreground">
                {lane.body}
              </p>
              <p className="mt-4 text-xs text-muted-foreground">
                Nothing here until a mailbox is connected.
              </p>
              <Link
                to={lane.to}
                className="mt-3 inline-flex text-xs font-semibold text-foreground underline-offset-4 hover:underline"
              >
                {lane.cta}
              </Link>
            </article>
          ))}
        </div>

        <div className="ax-plane mt-8 flex flex-col gap-4 rounded-2xl p-5 sm:flex-row sm:items-center">
          <span className="flex size-9 shrink-0 items-center justify-center rounded-xl bg-secondary text-steel">
            <Shield className="size-4" />
          </span>
          <div>
            <h2 className="text-base font-bold text-foreground">
              Connect your domain first
            </h2>
            <p className="mt-1.5 text-sm leading-relaxed text-muted-foreground">
              Mailboxes, shared addresses and calendars all hang off a verified domain.
              DKIM, SPF, DMARC and TLS stay visible the whole time.
            </p>
          </div>
          <Link
            to="/app/admin"
            className="shrink-0 rounded-xl bg-primary px-4 py-2.5 text-sm font-semibold text-primary-foreground transition-colors hover:bg-primary/90 sm:ml-auto"
          >
            Open domains
          </Link>
        </div>
      </div>
    </div>
  );
}