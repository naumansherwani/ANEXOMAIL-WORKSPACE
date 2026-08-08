import { createFileRoute, Link } from "@tanstack/react-router";
import { Crown, MailCheck, RefreshCw, ShieldCheck, Sparkles } from "lucide-react";

import { StateBlock } from "@/components/state/StateBlock";
import { Button } from "@/components/ui/button";
import {
  FOUNDER_MAILBOXES,
  FOUNDER_WORKSPACE_HOST,
  KIND_LABEL,
  PLANNED_MAILBOXES,
  SUPPORT_MAILBOXES,
  AI_MAILBOXES,
  type PlannedMailbox,
} from "@/lib/founder-plan";
import { useFounderMailboxes, useFounderOverview, useProvisionMailboxes } from "@/lib/founder";
import { notify } from "@/lib/notify";
import { cn } from "@/lib/utils";

export const Route = createFileRoute("/app/founder")({
  head: () => ({
    meta: [
      { title: "Founder deck — ANEXOMAIL Workspace" },
      {
        name: "description",
        content:
          "Founder command deck: every founder and AI mailbox, its provisioning state and its DNS verdict in one place.",
      },
      { property: "og:title", content: "Founder deck — ANEXOMAIL Workspace" },
      {
        property: "og:description",
        content: "Founder and AI mailboxes, provisioning state and DNS verdicts in one surface.",
      },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: FounderDeck,
});

function FounderDeck() {
  const overview = useFounderOverview();
  const mailboxes = useFounderMailboxes();
  const provision = useProvisionMailboxes();

  const live = new Map(
    (mailboxes.data?.mailboxes ?? []).map((m) => [m.address.toLowerCase(), m] as const),
  );
  const provisioned = PLANNED_MAILBOXES.filter(
    (p) => live.get(p.address.toLowerCase())?.provisioned,
  ).length;

  const notWired =
    (overview.error?.isNotImplemented ?? false) || (mailboxes.error?.isNotImplemented ?? false);

  const runProvision = (addresses?: string[]) => {
    provision.mutate(
      addresses ? { addresses } : {},
      {
        onSuccess: (r) =>
          notify.done(
            r.created.length ? `${r.created.length} mailbox(es) created` : "Nothing left to create",
            r.created.join(", ") || "Every planned mailbox already exists.",
          ),
        onError: (error) =>
          notify.failed(error.isNotImplemented ? "Provisioning not wired yet" : "Could not provision", {
            description: error.message,
          }),
      },
    );
  };

  return (
    <div className="min-h-0 flex-1 overflow-y-auto">
      <div className="mx-auto w-full max-w-5xl px-6 py-10 md:px-10">
        <p className="ax-eyebrow flex items-center gap-2">
          <Crown className="size-3.5" aria-hidden="true" /> Founder · chairman
        </p>
        <h1 className="mt-3 text-3xl text-foreground">Command deck</h1>
        <p className="mt-4 max-w-2xl text-sm leading-relaxed text-muted-foreground">
          Your identity, your mailboxes and every AI address in one surface. The plan below is
          locked; the state next to each row is server truth, so nothing reads as live until the
          mailbox really exists.
        </p>

        <div className="mt-8 grid gap-3 sm:grid-cols-3">
          <Stat label="Planned mailboxes" value={String(PLANNED_MAILBOXES.length)} />
          <Stat
            label="Provisioned"
            value={mailboxes.isLoading ? "…" : `${provisioned}/${PLANNED_MAILBOXES.length}`}
          />
          <Stat
            label="Founder workspace host"
            value={overview.data?.workspace_host ?? FOUNDER_WORKSPACE_HOST}
            small
          />
        </div>

        <div className="ax-plane mt-3 flex flex-wrap items-center gap-3 rounded-2xl p-5">
          <div className="min-w-0 flex-1">
            <p className="text-[13px] font-semibold text-foreground">Provision everything</p>
            <p className="ax-caption text-muted-foreground">
              Creates the missing mailboxes on the mail server and registers them in the workspace.
              Existing mailboxes are never touched.
            </p>
          </div>
          <Button onClick={() => runProvision()} disabled={provision.isPending}>
            {provision.isPending ? (
              <RefreshCw className="size-4 animate-spin" aria-hidden="true" />
            ) : (
              <MailCheck className="size-4" aria-hidden="true" />
            )}
            Provision missing
          </Button>
          <Button asChild variant="secondary">
            <Link to="/app/ai-center">
              <Sparkles className="size-4" aria-hidden="true" /> AI email center
            </Link>
          </Button>
        </div>

        {notWired ? (
          <div className="ax-plane mt-3 rounded-2xl">
            <StateBlock
              tone="error"
              icon={<ShieldCheck className="size-5" aria-hidden="true" />}
              title="Founder endpoints not wired yet"
              body="The deck is ready and reads the real server. /api/founder/* is still missing on the brain, so mailbox state and DNS verdicts stay blank instead of showing invented numbers."
            />
          </div>
        ) : null}

        <Group title="Founder identity" items={FOUNDER_MAILBOXES} live={live} onProvision={runProvision} />
        <Group title="Support desk (Leo)" items={SUPPORT_MAILBOXES} live={live} onProvision={runProvision} />
        <Group title="AI email addresses" items={AI_MAILBOXES} live={live} onProvision={runProvision} />

        <section className="mt-10">
          <h2 className="text-base font-bold text-foreground">Founder workspace host</h2>
          <p className="mt-2 text-sm leading-relaxed text-muted-foreground">
            <code className="rounded-md bg-secondary px-1.5 py-0.5 text-foreground">
              {FOUNDER_WORKSPACE_HOST}
            </code>{" "}
            serves this same app. Point it at the web server and it lands straight on this deck —
            same session, same data, one build. No separate product, no second codebase.
          </p>
        </section>
      </div>
    </div>
  );
}

function Group({
  title,
  items,
  live,
  onProvision,
}: {
  title: string;
  items: PlannedMailbox[];
  live: Map<string, { provisioned: boolean; dns_ok: boolean; messages_total: number }>;
  onProvision: (addresses: string[]) => void;
}) {
  return (
    <section className="mt-10">
      <h2 className="text-base font-bold text-foreground">{title}</h2>
      <ul className="mt-3 space-y-2">
        {items.map((m) => {
          const state = live.get(m.address.toLowerCase());
          return (
            <li key={m.address} className="ax-plane rounded-2xl p-4">
              <div className="flex flex-wrap items-center gap-2">
                <span className="ax-caption rounded-full border border-border px-2 py-0.5 font-semibold text-muted-foreground">
                  {KIND_LABEL[m.kind]}
                </span>
                <p className="min-w-0 flex-1 truncate text-sm font-semibold text-foreground">
                  {m.address}
                </p>
                <Badge ok={state?.provisioned ?? false}>
                  {state?.provisioned ? "Mailbox live" : "Not created"}
                </Badge>
                <Badge ok={state?.dns_ok ?? false}>{state?.dns_ok ? "DNS green" : "DNS unchecked"}</Badge>
                {!state?.provisioned && (
                  <button
                    type="button"
                    onClick={() => onProvision([m.address])}
                    className="ax-press ax-caption rounded-full border border-cyan-accent/50 px-2.5 py-1 font-semibold text-foreground"
                  >
                    Create
                  </button>
                )}
              </div>
              <p className="mt-1.5 text-sm leading-relaxed text-muted-foreground">
                {m.display_name} — {m.note}
                {m.agent ? ` Answered by ${m.agent}.` : ""}
              </p>
            </li>
          );
        })}
      </ul>
    </section>
  );
}

function Badge({ ok, children }: { ok: boolean; children: string }) {
  return (
    <span
      className={cn(
        "ax-caption rounded-full border px-2 py-0.5 font-semibold",
        ok ? "border-success/40 bg-success/10 text-success" : "border-border text-muted-foreground",
      )}
    >
      {children}
    </span>
  );
}

function Stat({ label, value, small }: { label: string; value: string; small?: boolean }) {
  return (
    <div className="ax-plane rounded-2xl p-4">
      <p className="ax-caption text-muted-foreground">{label}</p>
      <p className={cn("mt-1 font-bold text-foreground", small ? "text-sm break-all" : "text-2xl")}>
        {value}
      </p>
    </div>
  );
}
