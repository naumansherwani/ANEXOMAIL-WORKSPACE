import { createFileRoute, Link } from "@tanstack/react-router";

import { SiteFooter } from "@/components/site/SiteFooter";
import { SiteNav } from "@/components/site/SiteNav";
import { useStatusPage } from "@/lib/release";

export const Route = createFileRoute("/status")({
  head: () => ({
    meta: [
      { title: "Service status — ANEXOMAIL Workspace" },
      {
        name: "description",
        content:
          "Live component health for ANEXOMAIL Workspace: mail delivery, workspace, sign-in and the domain checks — generated from our own probes, not marketing.",
      },
      { property: "og:title", content: "Service status — ANEXOMAIL Workspace" },
      {
        property: "og:description",
        content: "Live component health and the last incident, generated from real probes.",
      },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
    ],
  }),
  component: StatusPage,
});

const TONE: Record<string, string> = {
  operational: "border-success/40 bg-success/10 text-success",
  degraded: "border-warning/40 bg-warning/10 text-warning",
  down: "border-danger/40 bg-danger/10 text-danger",
};

const HEADLINE: Record<string, string> = {
  operational: "All systems operational",
  degraded: "Some components are degraded",
  down: "We have an outage",
};

/**
 * Feature 5 — public status page generated from the same probes the release
 * gate uses. No internal hostnames, no ports, no invented uptime.
 */
function StatusPage() {
  const q = useStatusPage();

  return (
    <div className="min-h-screen bg-background">
      <SiteNav />
      <main className="ax-container pt-20 pb-24 md:pt-24">
        <p className="ax-eyebrow">Service status</p>
        <h1 className="mt-4 max-w-3xl text-4xl text-foreground md:text-5xl">
          {q.data ? HEADLINE[q.data.state] : "Checking the platform…"}
        </h1>
        <p className="mt-5 max-w-2xl text-sm leading-relaxed text-muted-foreground">
          This page is generated from the same live probes our release gate runs — mail delivery, workspace,
          sign-in and domain authentication. If something is broken, it says so here first.
        </p>

        {q.error && (
          <p className="mt-8 rounded-2xl border border-dashed border-border px-5 py-4 text-sm text-muted-foreground">
            Status feed unreachable right now. That is itself a signal — if mail is affected, write to
            support@anexomail.com and a human replies.
          </p>
        )}

        {q.data && (
          <>
            <div className="mt-8 grid gap-px overflow-hidden rounded-2xl border border-border sm:grid-cols-2">
              {q.data.components.map((c) => (
                <div key={c.name} className="ax-plane rounded-none border-0 p-5">
                  <div className="flex items-center gap-3">
                    <span className={"rounded-md border px-1.5 py-0.5 text-[11px] font-semibold " + TONE[c.state]}>
                      {c.state}
                    </span>
                    <p className="text-sm font-semibold text-foreground">{c.name}</p>
                  </div>
                  {c.note && <p className="mt-2 text-[12px] leading-relaxed text-muted-foreground">{c.note}</p>}
                </div>
              ))}
            </div>

            <p className="mt-4 text-[12px] text-muted-foreground">
              Last checked {new Date(q.data.updated_at).toLocaleString("en-GB")} · refreshes every minute.
            </p>

            <h2 className="ax-h2 mt-12 text-foreground">Last incident</h2>
            {q.data.last_incident ? (
              <div className="ax-plane mt-4 rounded-2xl p-5">
                <p className="text-sm font-semibold text-foreground">{q.data.last_incident.title}</p>
                <p className="mt-1.5 text-[12px] text-muted-foreground">
                  Started {new Date(q.data.last_incident.started_at).toLocaleString("en-GB")} ·{" "}
                  {q.data.last_incident.resolved_at
                    ? `resolved ${new Date(q.data.last_incident.resolved_at).toLocaleString("en-GB")}`
                    : "still open"}
                </p>
              </div>
            ) : (
              <p className="mt-4 text-sm text-muted-foreground">No incident has been recorded.</p>
            )}
          </>
        )}

        <p className="mt-12 text-sm text-muted-foreground">
          Need the setup guide instead?{" "}
          <Link to="/docs" className="text-foreground underline underline-offset-4">
            Read the handbook
          </Link>{" "}
          or{" "}
          <Link to="/" className="text-foreground underline underline-offset-4">
            go back home
          </Link>
          .
        </p>
      </main>
      <SiteFooter />
    </div>
  );
}
