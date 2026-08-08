import { createFileRoute, Link } from "@tanstack/react-router";
import { useEffect, useState } from "react";

import { SiteFooter } from "@/components/site/SiteFooter";
import { SiteNav } from "@/components/site/SiteNav";
import { founderPreviewEnabled, setFounderPreview } from "@/lib/founder-preview";

export const Route = createFileRoute("/pages")({
  head: () => ({
    meta: [
      { title: "Page map — ANEXOMAIL Workspace" },
      {
        name: "description",
        content:
          "Every page of the ANEXOMAIL Workspace product in one list: public site, sign-in, workspace surfaces and the admin centre.",
      },
      { property: "og:title", content: "Page map — ANEXOMAIL Workspace" },
      {
        property: "og:description",
        content: "Every public and workspace page of ANEXOMAIL in one reviewable list.",
      },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: PageMap,
});

type Entry = { label: string; path: string; note: string; auth?: boolean };

const GROUPS: { title: string; blurb: string; items: Entry[] }[] = [
  {
    title: "Public site",
    blurb: "Anyone can open these — this is what the world sees.",
    items: [
      { label: "Landing", path: "/", note: "Hero, positioning, proof, plans teaser" },
      { label: "Plans", path: "/plans", note: "Basic £20 · Pro £40 · Business £85" },
      { label: "Leo (AI)", path: "/ai", note: "Coming soon page — AI not public yet" },
      { label: "Security", path: "/security", note: "TLS, DKIM/SPF/DMARC, data handling" },
      { label: "Ownership", path: "/ownership", note: "Export, delete, domain ownership proof" },
      { label: "Move in", path: "/move-in", note: "Migration from another provider" },
      { label: "Page map", path: "/pages", note: "This page — every route, always current" },
    ],
  },
  {
    title: "Entry",
    blurb: "Sign in and first-run setup.",
    items: [
      { label: "Sign in / sign up", path: "/auth", note: "Password, magic link, passkey" },
      { label: "Auth callback", path: "/auth/callback", note: "Magic link + OAuth return" },
      {
        label: "Claim address",
        path: "/claim",
        note: "Mandatory @anexomail.com identity after Google / Apple / GitHub sign-in",
      },
      { label: "Onboarding", path: "/onboarding", note: "Create organisation, add domain" },
    ],
  },
  {
    title: "Workspace",
    blurb: "Signed-in surfaces. One shell, no reload.",
    items: [
      { label: "Dashboard", path: "/app", note: "Command center widgets", auth: true },
      { label: "Inbox", path: "/app/mail/inbox", note: "3-panel mail + Compose Studio", auth: true },
      {
        label: "Thread reader",
        path: "/app/mail/inbox",
        note: "Open any thread from the inbox list — inline reply, insights, meeting",
        auth: true,
      },
      { label: "Assigned to me", path: "/app/mail/assigned", note: "Threads you own", auth: true },
      { label: "Waiting", path: "/app/mail/waiting", note: "Waiting on someone else", auth: true },
      { label: "Sent", path: "/app/mail/sent", note: "Includes held / scheduled mail", auth: true },
      { label: "Drafts", path: "/app/mail/drafts", note: "Autosave + version history", auth: true },
      { label: "Archive", path: "/app/mail/archive", note: "Done and filed", auth: true },
      { label: "Spam", path: "/app/mail/spam", note: "Postgrey + RBL filtered", auth: true },
      { label: "Trash", path: "/app/mail/trash", note: "Real delete on request", auth: true },
      {
        label: "Work",
        path: "/app/work",
        note: "Task board, promise inbox, follow-through score",
        auth: true,
      },
      {
        label: "Calendar",
        path: "/app/calendar",
        note: "Week grid, cost meter, availability, team load",
        auth: true,
      },
      { label: "People", path: "/app/people", note: "Contacts, tags, smart filters, relationship history", auth: true },
      { label: "Companies", path: "/app/people?view=companies", note: "One domain = one organisation rollup", auth: true },
      { label: "Search", path: "/app/search", note: "People + companies + threads + attachments, one query", auth: true },
      { label: "CRM dashboard", path: "/app/crm", note: "Pipeline value, forecast, unworked leads, Leo insights (aicrm.anexomail.com)", auth: true },
      { label: "CRM leads", path: "/app/crm/leads", note: "Scored leads from real threads, one-click convert", auth: true },
      { label: "CRM pipeline", path: "/app/crm/pipeline", note: "Stage board, deal thread never lost", auth: true },
      { label: "CRM shared work", path: "/app/crm/collab", note: "Shared inbox, drafts, mentions, approvals", auth: true },
      { label: "CRM activity", path: "/app/crm/activity", note: "System-written timeline of every touch", auth: true },
      { label: "Org overview", path: "/app/org", note: "Seats, security score, ownership proof, privilege radar", auth: true },
      { label: "Org members", path: "/app/org/members", note: "Instant revoke + offboarding blast radius preview", auth: true },
      { label: "Org roles", path: "/app/org/roles", note: "Capability matrix + least-privilege radar", auth: true },
      { label: "Org departments", path: "/app/org/departments", note: "Shared address, SLA, escalation chain, budget", auth: true },
      { label: "Org policies", path: "/app/org/policies", note: "Policy list + dry-run simulator before switching on", auth: true },
      { label: "Org security", path: "/app/org/security", note: "Session/device map, kill device, anomaly alerts, break-glass", auth: true },
      { label: "Org audit ledger", path: "/app/org/audit", note: "Hash-chained append-only ledger with one-click verify", auth: true },
      { label: "Org graph", path: "/app/org/graph", note: "Live communication graph, centrality, bottlenecks", auth: true },
      { label: "Org compliance", path: "/app/org/compliance", note: "Retention, export, delete, data region, evidence pack", auth: true },
      { label: "Account", path: "/app/account", note: "Profile, sessions, security", auth: true },
    ],
  },
  {
    title: "Founder only",
    blurb: "Chairman surfaces. Public users never see these.",
    items: [
      {
        label: "Founder deck",
        path: "/app/founder",
        note: "Founder mailboxes, AI addresses, provisioning state, DNS verdicts, founderworkspace host",
        auth: true,
      },
      {
        label: "AI email center",
        path: "/app/ai-center",
        note: "Leo · Jimmy John · Sherlock · 8 industry desks — drafts awaiting founder approval",
        auth: true,
      },
      {
        label: "Founder CRM control",
        path: "/app/founder/crm",
        note: "God-view: kill switch, tenant totals, team permissions, CRM audit (founderworkspace host only)",
        auth: true,
      },
      {
        label: "Founder org control",
        path: "/app/founder/org",
        note: "God-view: global write freeze, per-tenant freeze, seats, MRR truth, ledger health (founderworkspace host only)",
        auth: true,
      },
    ],
  },
  {
    title: "Admin centre",
    blurb: "Owner and admin only.",
    items: [
      { label: "Domains", path: "/app/admin", note: "DNS, DKIM, SPF, DMARC, TLS", auth: true },
      { label: "Members", path: "/app/admin/members", note: "People and roles", auth: true },
      { label: "Teams", path: "/app/admin/teams", note: "Groups owning shared work", auth: true },
      { label: "Addresses", path: "/app/admin/addresses", note: "Personal + shared", auth: true },
      { label: "Audit", path: "/app/admin/audit", note: "Every action, who and when", auth: true },
      { label: "Export", path: "/app/admin/export", note: "Take your data out", auth: true },
    ],
  },
];

/**
 * Founder Page Map — locked rule: every page of the product is listed here so
 * the whole surface can be reviewed before launch. New route => new row here.
 */
function PageMap() {
  const total = GROUPS.reduce((sum, g) => sum + g.items.length, 0);
  const [checked, setChecked] = useState<Record<string, boolean>>({});
  const [ready, setReady] = useState(false);
  const [preview, setPreview] = useState(false);

  // Founder review state is a local, private checklist — no server, no account.
  useEffect(() => {
    try {
      const raw = window.localStorage.getItem("ax.pagemap.reviewed");
      if (raw) setChecked(JSON.parse(raw) as Record<string, boolean>);
    } catch {
      /* ignore corrupt state */
    }
    setReady(true);
    setPreview(founderPreviewEnabled());
  }, []);

  const toggle = (key: string) => {
    setChecked((prev) => {
      const next = { ...prev, [key]: !prev[key] };
      try {
        window.localStorage.setItem("ax.pagemap.reviewed", JSON.stringify(next));
      } catch {
        /* ignore quota */
      }
      return next;
    });
  };

  const reviewed = ready ? Object.values(checked).filter(Boolean).length : 0;

  return (
    <div className="flex min-h-svh flex-col">
      <SiteNav />
      <main className="flex-1">
        <div className="ax-container py-16 md:py-24">
          <p className="ax-eyebrow">Founder review</p>
          <h1 className="ax-display mt-3 text-foreground">Page map</h1>
          <p className="ax-body mt-ax-3 max-w-2xl">
            Every page that exists in ANEXOMAIL right now — {total} in total. Open each one
            and check it with your own eyes. Workspace pages need a signed-in session.
          </p>

          <div className="ax-plane mt-ax-5 flex flex-wrap items-center gap-ax-4 rounded-2xl p-ax-4">
            <div>
              <p className="text-[13px] font-semibold text-foreground">
                Reviewed {reviewed} of {total}
              </p>
              <p className="ax-caption text-muted-foreground">
                Tick a page once you have seen it. Saved on this device only.
              </p>
            </div>
            <div className="h-1.5 min-w-[160px] flex-1 overflow-hidden rounded-full bg-secondary">
              <div
                className="h-full rounded-full bg-primary transition-[width] duration-300"
                style={{ width: `${total ? (reviewed / total) * 100 : 0}%` }}
              />
            </div>
            <button
              type="button"
              onClick={() => {
                setChecked({});
                try {
                  window.localStorage.removeItem("ax.pagemap.reviewed");
                } catch {
                  /* ignore */
                }
              }}
              className="ax-press rounded-xl border border-border px-3 py-2 text-[11px] font-semibold text-muted-foreground"
            >
              Reset ticks
            </button>
          </div>

          <div className="ax-plane mt-ax-3 flex flex-wrap items-center gap-ax-4 rounded-2xl p-ax-4">
            <div className="min-w-0 flex-1">
              <p className="text-[13px] font-semibold text-foreground">
                Founder access {preview ? "— ON" : "— OFF"}
              </p>
              <p className="ax-caption text-muted-foreground">
                Turn this on to open every workspace page without signing in. Data stays real —
                unwired endpoints show an honest state, never dummy content.
              </p>
            </div>
            <button
              type="button"
              onClick={() => {
                const next = !preview;
                setFounderPreview(next);
                setPreview(next);
              }}
              data-on={preview ? "true" : "false"}
              className="ax-press rounded-xl border border-border px-3 py-2 text-[11px] font-semibold text-foreground data-[on=true]:border-primary data-[on=true]:bg-primary data-[on=true]:text-primary-foreground"
            >
              {preview ? "Founder access ON" : "Enable founder access"}
            </button>
          </div>

          <div className="mt-ax-7 flex flex-col gap-ax-6">
            {GROUPS.map((group) => (
              <section key={group.title}>
                <h2 className="ax-heading text-foreground">{group.title}</h2>
                <p className="ax-caption mt-1 text-muted-foreground">{group.blurb}</p>
                <ul className="mt-ax-4 grid gap-ax-2 sm:grid-cols-2 lg:grid-cols-3">
                  {group.items.map((item) => {
                    const key = `${item.label}:${item.path}`;
                    const done = Boolean(checked[key]);
                    return (
                      <li key={key}>
                        <div
                          data-reviewed={done ? "true" : "false"}
                          className="ax-plane ax-lift flex h-full flex-col rounded-2xl p-ax-4 data-[reviewed=true]:border-primary/40"
                        >
                          <div className="flex items-baseline gap-2">
                            <span className="text-[13px] font-semibold text-foreground">
                              {item.label}
                            </span>
                            {item.auth && (
                              <span className="rounded-md bg-secondary px-1.5 py-0.5 text-[9px] font-semibold tracking-wide text-muted-foreground uppercase">
                                sign-in
                              </span>
                            )}
                          </div>
                          <p className="mt-1 text-[11px] text-muted-foreground">{item.note}</p>
                          <p className="mt-ax-3 font-mono text-[10px] text-steel">{item.path}</p>
                          <div className="mt-ax-3 flex items-center gap-2">
                            <Link
                              to={item.path}
                              className="ax-press rounded-xl bg-primary px-3 py-1.5 text-[11px] font-semibold text-primary-foreground"
                            >
                              Open
                            </Link>
                            <a
                              href={item.path}
                              target="_blank"
                              rel="noreferrer"
                              className="ax-press rounded-xl border border-border px-3 py-1.5 text-[11px] font-semibold text-muted-foreground"
                            >
                              New tab
                            </a>
                            <button
                              type="button"
                              onClick={() => toggle(key)}
                              aria-pressed={done}
                              className="ax-press ml-auto rounded-xl border border-border px-3 py-1.5 text-[11px] font-semibold text-foreground data-[on=true]:border-primary data-[on=true]:text-primary"
                              data-on={done ? "true" : "false"}
                            >
                              {done ? "Reviewed" : "Mark seen"}
                            </button>
                          </div>
                        </div>
                      </li>
                    );
                  })}
                </ul>
              </section>
            ))}
          </div>
        </div>
      </main>
      <SiteFooter />
    </div>
  );
}