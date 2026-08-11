import { createFileRoute, Link } from "@tanstack/react-router";
import { useEffect, useState } from "react";

import { SiteFooter } from "@/components/site/SiteFooter";
import { SiteNav } from "@/components/site/SiteNav";
import {
  founderPreviewEnabled,
  founderPreviewFromUrl,
  setFounderPreview,
} from "@/lib/founder-preview";

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
      {
        label: "AI Studio (AI)",
        path: "/ai/studio",
        note: "Coming soon gate — studio belongs to ai.anexomail.com, not the email plans",
      },
      {
        label: "AI Automation (AI)",
        path: "/ai/automation",
        note: "Coming soon gate — workflows, rules and suggestions live on ai.anexomail.com",
      },
      {
        label: "AI Credits (AI)",
        path: "/ai/credits",
        note: "Coming soon gate — wallet, burn and top-ups belong to ai.anexomail.com",
      },
      {
        label: "AI Knowledge (AI)",
        path: "/ai/knowledge",
        note: "Coming soon gate — documents, memory and cited answers on ai.anexomail.com",
      },
      { label: "Security", path: "/security", note: "TLS, DKIM/SPF/DMARC, data handling" },
      {
        label: "Service status",
        path: "/status",
        note: "Phase 30 — public status page generated from the same live probes as the release gate",
      },
      {
        label: "Handbook",
        path: "/docs",
        note: "Phase 30 — setup, DNS records, migration, export, ownership and every keyboard shortcut",
      },
      { label: "Ownership", path: "/ownership", note: "Export, delete, domain ownership proof" },
      { label: "Move in", path: "/move-in", note: "Migration from another provider" },
      {
        label: "Managed migration",
        path: "/migration",
        note: "Phase 28 — fixed-price migration quote calculator (£500–£2,000) + real booking",
      },
      {
        label: "Partner programme",
        path: "/partners",
        note: "Phase 28 — white-label reseller, 20/25/30% recurring commission calculator + apply",
      },
      {
        label: "Enterprise support",
        path: "/enterprise",
        note: "Phase 28 — £500/mo add-on: named manager, 1h response, quarterly review",
      },
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
      {
        label: "Billing",
        path: "/app/billing",
        note: "Phase 21 — workspace plan, seats, invoices, tax details, cards (no AI billing here)",
        auth: true,
      },
      {
        label: "Integrations",
        path: "/app/integrations",
        note: "Phase 22 — Gmail/M365/Zoho/Proton/IMAP connect, one-run migration, delivery proof, one-click export, Leo Actions (no API keys, no webhooks)",
        auth: true,
      },
      {
        label: "Settings",
        path: "/app/settings",
        note: "Phase 23 — personal/workspace/appearance/notifications/privacy/AI, each row with Explain (Leo), blast radius and history",
        auth: true,
      },
      {
        label: "Settings · Time machine",
        path: "/app/settings/history",
        note: "Phase 23 — every setting change with who/when/why and one-click revert",
        auth: true,
      },
      {
        label: "Settings · Drift & schedule",
        path: "/app/settings/health",
        note: "Phase 23 — drift vs safe baseline score + scheduled change with auto-rollback",
        auth: true,
      },
      {
        label: "Analytics",
        path: "/app/analytics",
        note: "Phase 24 — response debt in £, thread economics, deep work, attention leaks, promise SLA, forecast, team load",
        auth: true,
      },
      {
        label: "Outbox (offline)",
        path: "/app/mail/outbox",
        note: "Phase 30 — offline queue on this device, exponential retry, never says “sent” before the server confirms",
        auth: true,
      },
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
      {
        label: "Founder AI workbench",
        path: "/app/founder/ai",
        note: "LEO workbench 3-panel: sessions | chat | sources — TTFT, receipts, burn (aiemail host only)",
        auth: true,
      },
      {
        label: "Founder AI arena",
        path: "/app/founder/ai/arena",
        note: "One question, 3 agent slots (Leo+Jimmy+Sherlock default), Sherlock scores each answer",
        auth: true,
      },
      {
        label: "Founder AI studio",
        path: "/app/founder/ai/studio",
        note: "Phase 17 — 9 tools, before/after diff, batch mode, recipes, real writes into calendar + tasks",
        auth: true,
      },
      {
        label: "Founder AI automation",
        path: "/app/founder/ai/automation",
        note: "Phase 18 — workflows, email automation, rules, variables, LEO suggestions, dry run + approval gate",
        auth: true,
      },
      {
        label: "Founder AI prompts",
        path: "/app/founder/ai/prompts",
        note: "Prompt library — versions, fork, diff, variables",
        auth: true,
      },
      {
        label: "Founder AI memory",
        path: "/app/founder/ai/memory",
        note: "What LEO remembers — forget this = real server delete",
        auth: true,
      },
      {
        label: "Founder AI receipts",
        path: "/app/founder/ai/receipts",
        note: "Answer receipts, credits ledger (unlimited, cost visible) and guardrail pauses",
        auth: true,
      },
      {
        label: "Founder AI knowledge",
        path: "/app/founder/ai/knowledge",
        note: "Phase 20 — spaces, documents, real recall search, ask with citations or refusal",
        auth: true,
      },
      {
        label: "Founder AI billing",
        path: "/app/founder/ai/billing",
        note: "Phase 19 — wallet, burn, runway, usage analytics, spend cap, sandbox checkout",
        auth: true,
      },
      {
        label: "Founder revenue truth",
        path: "/app/founder/billing",
        note: "Phase 21 god-view — MRR, ARR, unpaid, churn, by-plan split across every tenant",
        auth: true,
      },
      {
        label: "Founder integrations god-view",
        path: "/app/founder/integrations",
        note: "Phase 22 god-view — connections, re-auth queue, migration failures, worst delivery scores",
        auth: true,
      },
      {
        label: "Founder settings god-view",
        path: "/app/founder/settings",
        note: "Phase 23 god-view — changes 24h, reverts 7d, riskiest tenants, most-changed settings, pending scheduled",
        auth: true,
      },
      {
        label: "Founder analytics god-view",
        path: "/app/founder/analytics",
        note: "Phase 24 god-view — platform response debt in £, keep rate, worst tenants",
      },
      {
        label: "Founder admin god-view",
        path: "/app/founder/admin",
        note: "Phase 25 god-view — failing checks, self-heals, incidents, held mail, storage across every tenant",
        auth: true,
      },
      {
        label: "Founder security god-view",
        path: "/app/founder/security",
        note: "Phase 26 god-view — anomalies, frozen accounts, blocked devices, kill switches per tenant",
        auth: true,
      },
      {
        label: "Release command",
        path: "/app/founder/launch",
        note: "Phase 30 — release gate verdict, blockers, last deployment, run full QA",
        auth: true,
      },
      {
        label: "QA suite",
        path: "/app/founder/launch/qa",
        note: "Phase 30 — 60+ live checks suite-wise with HTTP code, latency and reason",
        auth: true,
      },
      {
        label: "Production checklist",
        path: "/app/founder/launch/checklist",
        note: "Phase 30 — open / done / blocker per item; a blocker keeps the gate shut",
        auth: true,
      },
      {
        label: "Deploy receipts",
        path: "/app/founder/launch/deployments",
        note: "Phase 30 — commit sha, actor, duration, rollback trail, what changed since last green",
        auth: true,
      },
      {
        label: "v1.0 lock",
        path: "/app/founder/launch/lock",
        note: "Phase 30 — append-only signature ledger; disabled while any check is red",
        auth: true,
      },
      {
        label: "v2.0 roadmap",
        path: "/app/founder/launch/roadmap",
        note: "Phase 30 — impact × effort board with the revenue road each item feeds",
        auth: true,
      },
      {
        label: "Revenue pipeline truth",
        path: "/app/founder/revenue/pipeline",
        note: "Phase 30 — Committed MRR vs Pipeline MRR vs gap to £500; one-off cash never counted as MRR",
        auth: true,
      },
    ],
  },
  {
    title: "Security platform",
    blurb: "Phase 26 — device trust replaces API keys. Owner and admin only.",
    items: [
      {
        label: "Security overview",
        path: "/app/security",
        note: "Phase 26 — score, hash-chained ledger, what to fix next",
        auth: true,
      },
      {
        label: "Device trust",
        path: "/app/security/devices",
        note: "Phase 26 — fingerprint + live trust score + one-click device kill (no API keys)",
        auth: true,
      },
      {
        label: "Sessions & kill switch",
        path: "/app/security/sessions",
        note: "Phase 26 — live sessions with risk, plus blast-radius kill switch",
        auth: true,
      },
      {
        label: "Login replay",
        path: "/app/security/history",
        note: "Phase 26 — every sign-in as a risk story, impossible-travel freeze, “wasn’t me”",
        auth: true,
      },
      {
        label: "Encryption ledger",
        path: "/app/security/encryption",
        note: "Phase 26 — at rest + in transit per surface, hashed key rotations",
        auth: true,
      },
      {
        label: "Ownership proof",
        path: "/app/security/proof",
        note: "Phase 26 — live DKIM/SPF/DMARC/TLS probe, hashed exportable pack",
        auth: true,
      },
    ],
  },
  {
    title: "Performance platform",
    blurb: "Phase 27 — speed as a feature, with receipts. Owner and admin only.",
    items: [
      {
        label: "Speed overview",
        path: "/app/perf",
        note: "Phase 27 — speed score from real samples, slowest actions, advice",
        auth: true,
      },
      {
        label: "Speed receipts",
        path: "/app/perf/budgets",
        note: "Phase 27 — per-action millisecond budget vs real p50/p95/p99",
        auth: true,
      },
      {
        label: "Prefetch brain",
        path: "/app/perf/prefetch",
        note: "Phase 27 — predicted opens, hit rate, ms saved, cold-start map",
        auth: true,
      },
      {
        label: "Query lab",
        path: "/app/perf/search",
        note: "Phase 27 — run a real query, get the stage-by-stage waterfall",
        auth: true,
      },
      {
        label: "Device twins",
        path: "/app/perf/devices",
        note: "Phase 27 — per-device network class, rtt and the surfaces that lag",
        auth: true,
      },
      {
        label: "Regression sentinel",
        path: "/app/perf/regressions",
        note: "Phase 27 — release-over-release latency diff + rollback advice",
        auth: true,
      },
      {
        label: "Founder speed god-view",
        path: "/app/founder/perf",
        note: "Phase 27 god-view — p95 per tenant, failing budgets, regressions",
        auth: true,
      },
    ],
  },
  {
    title: "Revenue engine",
    blurb: "Phase 28 — four money roads without AI. Founder only.",
    items: [
      {
        label: "Devices & offline",
        path: "/app/devices",
        note: "Phase 28 — install status, offline cache, low-data mode, device handoff drafts",
        auth: true,
      },
      {
        label: "Motion contract & focus ledger",
        path: "/app/founder/motion",
        note: "Phase 29 — measured animation budgets, long-frame watcher, focus audit, delight switches",
        auth: true,
      },
      {
        label: "Founder revenue god-view",
        path: "/app/founder/revenue",
        note: "Phase 28 — MRR vs target, streams, live leads, partner commission, gap maths",
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
      {
        label: "Health",
        path: "/app/admin/health",
        note: "Phase 25 — self-healing checks with one-click heal + proof log",
        auth: true,
      },
      {
        label: "Monitoring",
        path: "/app/admin/monitoring",
        note: "Phase 25 — delivery watchtower: queue/defer/bounce in plain English",
        auth: true,
      },
      {
        label: "Storage",
        path: "/app/admin/storage",
        note: "Phase 25 — days-until-full forecast + reclaimable bytes per mailbox",
        auth: true,
      },
      {
        label: "Logs & incidents",
        path: "/app/admin/logs",
        note: "Phase 25 — log lens with trace ids + blame-free incident timeline",
        auth: true,
      },
      {
        label: "Organisation reports",
        path: "/app/admin/reports",
        note: "Phase 25 — board-ready report built only from real numbers",
        auth: true,
      },
      {
        label: "Diagnostics",
        path: "/app/admin/diagnostics",
        note: "Phase 25 — whole-stack probe pack, hashed and exportable",
        auth: true,
      },
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
  const [allowed, setAllowed] = useState(false);

  // Founder review state is a local, private checklist — no server, no account.
  useEffect(() => {
    try {
      const raw = window.localStorage.getItem("ax.pagemap.reviewed");
      if (raw) setChecked(JSON.parse(raw) as Record<string, boolean>);
    } catch {
      /* ignore corrupt state */
    }
    setReady(true);
    const founder = founderPreviewFromUrl() || founderPreviewEnabled();
    setPreview(founder);
    setAllowed(founder);
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

  // Founder-only surface. The public never sees the internal route inventory.
  if (ready && !allowed) {
    return (
      <div className="flex min-h-svh flex-col">
        <SiteNav />
        <main className="flex-1">
          <div className="ax-container py-24">
            <p className="ax-eyebrow">Private</p>
            <h1 className="ax-display mt-3 text-foreground">This page is internal</h1>
            <p className="ax-body mt-ax-3 max-w-xl">
              The page map is an internal review tool. Everything built for you lives in the
              main navigation.
            </p>
            <Link
              to="/"
              className="mt-ax-5 inline-flex rounded-full bg-primary px-5 py-2.5 text-sm font-semibold text-primary-foreground transition-colors hover:bg-primary/85"
            >
              Back to home
            </Link>
          </div>
        </main>
        <SiteFooter />
      </div>
    );
  }

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