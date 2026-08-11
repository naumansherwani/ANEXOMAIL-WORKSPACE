import { createFileRoute } from "@tanstack/react-router";
import { Download, PlugZap, Radar, Sparkles, Truck } from "lucide-react";
import { useState } from "react";

import { CardBody, StatSkeleton } from "@/components/app/dashboard/DashboardCard";
import {
  bytes,
  pct,
  useConnectProvider,
  useConnections,
  useControlMigration,
  useDeliveryHealth,
  useDisconnectProvider,
  useExports,
  useLeoActions,
  useMigrations,
  useProviders,
  useRequestExport,
  useStartMigration,
  useToggleLeoAction,
  type ExportJob,
} from "@/lib/integrations";
import { relativeTime } from "@/lib/mail";
import { notify } from "@/lib/notify";
import { cn } from "@/lib/utils";

/**
 * Phase 22 — Integrations Platform (awam surface).
 * NO API / NO WEBHOOK: koi public key, koi webhook URL nahi. Native providers,
 * ek-click migration, delivery proof, one-click export aur LEO Actions.
 * Founder god-view alag route hai: /app/founder/integrations.
 */
export const Route = createFileRoute("/app/integrations")({
  head: () => ({
    meta: [
      { title: "Integrations — ANEXOMAIL Workspace" },
      {
        name: "description",
        content:
          "Connect Gmail, Microsoft 365, Zoho, Proton or any IMAP mailbox, migrate everything in one run, prove delivery and export your data whenever you want.",
      },
      { property: "og:title", content: "Integrations — ANEXOMAIL Workspace" },
      {
        property: "og:description",
        content: "Native mailbox connections, one-run migration, delivery proof and one-click export.",
      },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: Integrations,
});

const TABS = [
  { id: "providers", label: "Providers", icon: PlugZap },
  { id: "migration", label: "Migration", icon: Truck },
  { id: "delivery", label: "Delivery proof", icon: Radar },
  { id: "export", label: "Export", icon: Download },
  { id: "actions", label: "Leo Actions", icon: Sparkles },
] as const;

type TabId = (typeof TABS)[number]["id"];

function Integrations() {
  const [tab, setTab] = useState<TabId>("providers");

  return (
    <div className="flex min-h-0 flex-1 flex-col">
      <header className="shrink-0 border-b border-border px-ax-5 pt-ax-4">
        <p className="ax-eyebrow">Integrations</p>
        <h2 className="ax-h3 mt-1 text-foreground">Bring everything in. Take everything out.</h2>
        <p className="ax-caption mt-1 text-muted-foreground">
          No API keys, no webhooks. Real connections, one migration run, and an export button that
          actually works.
        </p>
        <nav className="mt-ax-3 flex gap-1 overflow-x-auto">
          {TABS.map((t) => (
            <button
              key={t.id}
              type="button"
              onClick={() => setTab(t.id)}
              className={cn(
                "ax-press flex items-center gap-1.5 whitespace-nowrap rounded-t-lg border-b-2 px-3 py-2 text-[13px] font-semibold transition-colors",
                tab === t.id
                  ? "border-foreground text-foreground"
                  : "border-transparent text-muted-foreground hover:text-foreground",
              )}
            >
              <t.icon className="size-3.5" aria-hidden="true" />
              {t.label}
            </button>
          ))}
        </nav>
      </header>

      <div className="min-h-0 flex-1 overflow-y-auto">
        <div className="mx-auto w-full max-w-5xl px-6 py-8 md:px-8">
          {tab === "providers" && <ProvidersTab />}
          {tab === "migration" && <MigrationTab />}
          {tab === "delivery" && <DeliveryTab />}
          {tab === "export" && <ExportTab />}
          {tab === "actions" && <ActionsTab />}
        </div>
      </div>
    </div>
  );
}

function ProvidersTab() {
  const providers = useProviders();
  const connections = useConnections();
  const connect = useConnectProvider();
  const disconnect = useDisconnectProvider();

  return (
    <>
      <h2 className="ax-heading text-foreground">Available providers</h2>
      <div className="mt-ax-3">
        <CardBody
          query={{
            data: providers.data,
            isPending: providers.isPending,
            error: providers.error ?? null,
            refetch: () => void providers.refetch(),
          }}
          endpoint="/api/integrations/providers"
          skeleton={<StatSkeleton rows={4} />}
        >
          {(d) => (
            <ul className="grid gap-ax-3 sm:grid-cols-2">
              {d.providers.map((p) => (
                <li key={p.id} className="ax-plane rounded-2xl p-ax-4">
                  <div className="flex items-start gap-ax-3">
                    <div className="min-w-0">
                      <p className="text-[14px] font-bold text-foreground">{p.label}</p>
                      <p className="ax-caption mt-1 text-muted-foreground">
                        {p.kind === "oauth" ? "One-tap sign-in" : p.kind === "bridge" ? "Bridge" : "Host + credentials"}
                        {p.can_migrate ? " · migration" : ""}
                        {p.can_sync ? " · live sync" : ""}
                        {p.can_send ? " · sending" : ""}
                      </p>
                      {p.notes && <p className="ax-caption mt-1 text-steel">{p.notes}</p>}
                    </div>
                    <button
                      type="button"
                      disabled={!p.available || connect.isPending}
                      onClick={() =>
                        connect.mutate(
                          { provider: p.id },
                          {
                            onSuccess: (r) => {
                              if (r.redirect_url) window.location.assign(r.redirect_url);
                              else notify.done("Connected", `${p.label} is linked.`);
                            },
                            onError: (err) =>
                              notify.failed(err.isNotImplemented ? "Not wired yet" : "Failed", {
                                description: err.isNotImplemented
                                  ? "POST /api/integrations/connect pending."
                                  : err.message,
                              }),
                          },
                        )
                      }
                      className="ax-press ml-auto shrink-0 rounded-xl bg-primary px-3 py-2 text-[12px] font-semibold text-primary-foreground disabled:opacity-40"
                    >
                      {p.available ? "Connect" : "Soon"}
                    </button>
                  </div>
                </li>
              ))}
            </ul>
          )}
        </CardBody>
      </div>

      <h2 className="ax-heading mt-ax-6 text-foreground">Your connections</h2>
      <div className="mt-ax-3">
        <CardBody
          query={{
            data: connections.data,
            isPending: connections.isPending,
            error: connections.error ?? null,
            refetch: () => void connections.refetch(),
          }}
          endpoint="/api/integrations/connections"
          skeleton={<StatSkeleton rows={3} />}
        >
          {(d) =>
            d.connections.length === 0 ? (
              <p className="ax-caption text-muted-foreground">
                Nothing connected yet — pick a provider above.
              </p>
            ) : (
              <ul className="space-y-1.5">
                {d.connections.map((c) => (
                  <li
                    key={c.id}
                    className="ax-plane flex flex-wrap items-center gap-ax-3 rounded-xl px-ax-4 py-ax-3 text-[12px]"
                  >
                    <StateChip state={c.state} />
                    <span className="font-semibold text-foreground">{c.account}</span>
                    <span className="text-muted-foreground">{c.provider}</span>
                    <span className="text-steel">
                      {c.synced_threads.toLocaleString()} threads
                      {c.last_sync_at ? ` · synced ${relativeTime(c.last_sync_at)}` : ""}
                    </span>
                    {c.error && <span className="text-destructive">{c.error}</span>}
                    <button
                      type="button"
                      onClick={() =>
                        disconnect.mutate(
                          { id: c.id },
                          {
                            onSuccess: () => notify.done("Disconnected", "Tokens revoked on the server."),
                            onError: (err) =>
                              notify.failed(err.isNotImplemented ? "Not wired yet" : "Failed", {
                                description: err.isNotImplemented
                                  ? "POST /api/integrations/disconnect pending."
                                  : err.message,
                              }),
                          },
                        )
                      }
                      className="ax-press ml-auto rounded-lg border border-border px-2 py-1 font-semibold text-muted-foreground"
                    >
                      Disconnect
                    </button>
                  </li>
                ))}
              </ul>
            )
          }
        </CardBody>
      </div>
    </>
  );
}

function MigrationTab() {
  const connections = useConnections();
  const jobs = useMigrations();
  const start = useStartMigration();
  const control = useControlMigration();
  const [source, setSource] = useState("");
  const [target, setTarget] = useState("");
  const [mode, setMode] = useState<"copy" | "mirror">("copy");

  return (
    <>
      <h2 className="ax-heading text-foreground">Move in — one run, nothing lost</h2>
      <p className="ax-caption mt-1 text-muted-foreground">
        Threads, folders, attachments, read state and dates stay intact. Mirror keeps syncing until you
        cut over; copy runs once.
      </p>

      <form
        className="ax-plane mt-ax-4 flex flex-wrap items-end gap-ax-3 rounded-2xl p-ax-4"
        onSubmit={(e) => {
          e.preventDefault();
          if (!source || !target) return;
          start.mutate(
            { connection_id: source, target_mailbox: target, mode },
            {
              onSuccess: () => notify.done("Migration queued", "Progress updates live below."),
              onError: (err) =>
                notify.failed(err.isNotImplemented ? "Not wired yet" : "Failed", {
                  description: err.isNotImplemented
                    ? "POST /api/integrations/migrations pending."
                    : err.message,
                }),
            },
          );
        }}
      >
        <label className="flex flex-col gap-1 text-[11px] text-muted-foreground">
          Source connection
          <select
            value={source}
            onChange={(e) => setSource(e.target.value)}
            className="h-9 w-56 rounded-lg border border-border bg-card px-2 text-[12px] text-foreground"
          >
            <option value="">Select…</option>
            {(connections.data?.connections ?? []).map((c) => (
              <option key={c.id} value={c.id}>
                {c.account} ({c.provider})
              </option>
            ))}
          </select>
        </label>
        <label className="flex flex-col gap-1 text-[11px] text-muted-foreground">
          Target mailbox
          <input
            value={target}
            onChange={(e) => setTarget(e.target.value)}
            placeholder="you@anexomail.com"
            className="h-9 w-56 rounded-lg border border-border bg-card px-2 text-[12px] text-foreground"
          />
        </label>
        <label className="flex flex-col gap-1 text-[11px] text-muted-foreground">
          Mode
          <select
            value={mode}
            onChange={(e) => setMode(e.target.value as "copy" | "mirror")}
            className="h-9 w-32 rounded-lg border border-border bg-card px-2 text-[12px] text-foreground"
          >
            <option value="copy">Copy once</option>
            <option value="mirror">Mirror</option>
          </select>
        </label>
        <button
          type="submit"
          disabled={start.isPending}
          className="ax-press h-9 rounded-xl bg-primary px-3 text-[12px] font-semibold text-primary-foreground disabled:opacity-50"
        >
          Start migration
        </button>
      </form>

      <div className="mt-ax-5">
        <CardBody
          query={{
            data: jobs.data,
            isPending: jobs.isPending,
            error: jobs.error ?? null,
            refetch: () => void jobs.refetch(),
          }}
          endpoint="/api/integrations/migrations"
          skeleton={<StatSkeleton rows={4} />}
        >
          {(d) =>
            d.jobs.length === 0 ? (
              <p className="ax-caption text-muted-foreground">No migration has run yet.</p>
            ) : (
              <ul className="space-y-ax-3">
                {d.jobs.map((j) => (
                  <li key={j.id} className="ax-plane rounded-2xl p-ax-4">
                    <div className="flex flex-wrap items-center gap-ax-3 text-[12px]">
                      <StateChip state={j.state} />
                      <span className="font-semibold text-foreground">{j.source_account}</span>
                      <span className="text-steel">→ {j.target_mailbox}</span>
                      <span className="text-muted-foreground">{j.mode}</span>
                      <span className="ml-auto text-steel">
                        {j.done.toLocaleString()}/{j.total.toLocaleString()}
                        {j.failed > 0 ? ` · ${j.failed} failed` : ""}
                        {j.eta_minutes !== null ? ` · ~${j.eta_minutes}m left` : ""}
                      </span>
                    </div>
                    <span className="mt-ax-3 block h-1.5 overflow-hidden rounded-full bg-secondary">
                      <span
                        className="block h-full rounded-full bg-primary transition-[width]"
                        style={{ width: `${pct(j.done, j.total)}%` }}
                      />
                    </span>
                    {j.last_error && <p className="ax-caption mt-1 text-destructive">{j.last_error}</p>}
                    <div className="mt-ax-3 flex gap-1.5">
                      {(["pause", "resume", "retry", "cancel"] as const).map((a) => (
                        <button
                          key={a}
                          type="button"
                          onClick={() =>
                            control.mutate(
                              { id: j.id, action: a },
                              {
                                onSuccess: () => notify.done("Done", `Migration ${a}d.`),
                                onError: (err) =>
                                  notify.failed(err.isNotImplemented ? "Not wired yet" : "Failed", {
                                    description: err.isNotImplemented
                                      ? "POST /api/integrations/migrations/control pending."
                                      : err.message,
                                  }),
                              },
                            )
                          }
                          className="ax-press rounded-lg border border-border px-2 py-1 text-[11px] font-semibold capitalize text-muted-foreground"
                        >
                          {a}
                        </button>
                      ))}
                    </div>
                  </li>
                ))}
              </ul>
            )
          }
        </CardBody>
      </div>
    </>
  );
}

function DeliveryTab() {
  const health = useDeliveryHealth();
  return (
    <>
      <h2 className="ax-heading text-foreground">Delivery proof</h2>
      <p className="ax-caption mt-1 text-muted-foreground">
        Ownership is proof, not a promise — every record checked live against DNS.
      </p>
      <div className="mt-ax-4">
        <CardBody
          query={{
            data: health.data,
            isPending: health.isPending,
            error: health.error ?? null,
            refetch: () => void health.refetch(),
          }}
          endpoint="/api/integrations/delivery/health"
          skeleton={<StatSkeleton rows={5} />}
        >
          {(h) => (
            <div className="ax-plane rounded-2xl p-ax-4">
              <div className="flex flex-wrap items-center gap-ax-3">
                <p className="text-[15px] font-bold text-foreground">{h.domain}</p>
                <span className="rounded-md bg-secondary px-1.5 py-0.5 text-[11px] font-semibold text-muted-foreground">
                  score {h.score}/100 · reputation {h.reputation}
                </span>
              </div>
              <ul className="mt-ax-4 grid gap-1.5 sm:grid-cols-2">
                {h.checks.map((c) => (
                  <li key={c.key} className="rounded-xl border border-border px-ax-4 py-ax-3 text-[12px]">
                    <div className="flex items-center gap-2">
                      <StateChip state={c.state} />
                      <span className="font-semibold text-foreground">{c.key}</span>
                      {c.checked_at && (
                        <span className="ml-auto text-steel">{relativeTime(c.checked_at)}</span>
                      )}
                    </div>
                    <p className="ax-caption mt-1 text-muted-foreground">{c.detail}</p>
                    {c.fix && <p className="ax-caption mt-1 text-steel">Fix: {c.fix}</p>}
                  </li>
                ))}
              </ul>
              <h3 className="ax-heading mt-ax-5 text-foreground">Blocklists</h3>
              <ul className="mt-ax-3 flex flex-wrap gap-1.5">
                {h.blocklists.map((b) => (
                  <li
                    key={b.name}
                    data-listed={b.listed ? "true" : "false"}
                    className="rounded-lg border border-border px-2 py-1 text-[11px] text-muted-foreground data-[listed=true]:border-destructive data-[listed=true]:text-destructive"
                  >
                    {b.name} {b.listed ? "listed" : "clear"}
                  </li>
                ))}
              </ul>
            </div>
          )}
        </CardBody>
      </div>
    </>
  );
}

const SCOPES: ExportJob["scope"][] = ["mail", "calendar", "contacts", "everything"];
const FORMATS: ExportJob["format"][] = ["mbox", "eml", "ics", "csv", "json"];

function ExportTab() {
  const jobs = useExports();
  const request = useRequestExport();
  const [scope, setScope] = useState<ExportJob["scope"]>("everything");
  const [format, setFormat] = useState<ExportJob["format"]>("mbox");

  return (
    <>
      <h2 className="ax-heading text-foreground">Your data, on demand</h2>
      <p className="ax-caption mt-1 text-muted-foreground">
        No lock-in: one click, full archive, standard formats. Delete means real delete.
      </p>
      <div className="ax-plane mt-ax-4 flex flex-wrap items-end gap-ax-3 rounded-2xl p-ax-4">
        <label className="flex flex-col gap-1 text-[11px] text-muted-foreground">
          Scope
          <select
            value={scope}
            onChange={(e) => setScope(e.target.value as ExportJob["scope"])}
            className="h-9 w-40 rounded-lg border border-border bg-card px-2 text-[12px] capitalize text-foreground"
          >
            {SCOPES.map((s) => (
              <option key={s} value={s}>
                {s}
              </option>
            ))}
          </select>
        </label>
        <label className="flex flex-col gap-1 text-[11px] text-muted-foreground">
          Format
          <select
            value={format}
            onChange={(e) => setFormat(e.target.value as ExportJob["format"])}
            className="h-9 w-32 rounded-lg border border-border bg-card px-2 text-[12px] uppercase text-foreground"
          >
            {FORMATS.map((f) => (
              <option key={f} value={f}>
                {f}
              </option>
            ))}
          </select>
        </label>
        <button
          type="button"
          disabled={request.isPending}
          onClick={() =>
            request.mutate(
              { scope, format },
              {
                onSuccess: () => notify.done("Export queued", "Download link appears below when ready."),
                onError: (err) =>
                  notify.failed(err.isNotImplemented ? "Not wired yet" : "Failed", {
                    description: err.isNotImplemented
                      ? "POST /api/integrations/exports pending."
                      : err.message,
                  }),
              },
            )
          }
          className="ax-press h-9 rounded-xl bg-primary px-3 text-[12px] font-semibold text-primary-foreground disabled:opacity-50"
        >
          Export now
        </button>
      </div>

      <div className="mt-ax-5">
        <CardBody
          query={{
            data: jobs.data,
            isPending: jobs.isPending,
            error: jobs.error ?? null,
            refetch: () => void jobs.refetch(),
          }}
          endpoint="/api/integrations/exports"
          skeleton={<StatSkeleton rows={3} />}
        >
          {(d) =>
            d.jobs.length === 0 ? (
              <p className="ax-caption text-muted-foreground">No export requested yet.</p>
            ) : (
              <ul className="space-y-1.5">
                {d.jobs.map((j) => (
                  <li
                    key={j.id}
                    className="ax-plane flex flex-wrap items-center gap-ax-3 rounded-xl px-ax-4 py-ax-3 text-[12px]"
                  >
                    <StateChip state={j.state} />
                    <span className="font-semibold capitalize text-foreground">{j.scope}</span>
                    <span className="uppercase text-muted-foreground">{j.format}</span>
                    <span className="text-steel">{bytes(j.size_bytes)}</span>
                    <span className="text-steel">{relativeTime(j.created_at)}</span>
                    {j.url && j.state === "ready" && (
                      <a
                        href={j.url}
                        className="ax-press ml-auto rounded-lg border border-border px-2 py-1 font-semibold text-foreground"
                      >
                        Download
                      </a>
                    )}
                  </li>
                ))}
              </ul>
            )
          }
        </CardBody>
      </div>
    </>
  );
}

function ActionsTab() {
  const actions = useLeoActions();
  const toggle = useToggleLeoAction();
  return (
    <>
      <h2 className="ax-heading text-foreground">Leo Actions — instead of an API</h2>
      <p className="ax-caption mt-1 text-muted-foreground">
        You never hand out a key. Leo does the work inside your workspace, with approval where it
        matters, and every run is on the receipt.
      </p>
      <div className="mt-ax-4">
        <CardBody
          query={{
            data: actions.data,
            isPending: actions.isPending,
            error: actions.error ?? null,
            refetch: () => void actions.refetch(),
          }}
          endpoint="/api/integrations/leo-actions"
          skeleton={<StatSkeleton rows={4} />}
        >
          {(d) => (
            <ul className="space-y-1.5">
              {d.actions.map((a) => (
                <li key={a.id} className="ax-plane rounded-xl px-ax-4 py-ax-3">
                  <div className="flex flex-wrap items-center gap-ax-3 text-[12px]">
                    <span className="font-semibold text-foreground">{a.label}</span>
                    <span className="text-steel">{a.target}</span>
                    {a.requires_approval && (
                      <span className="rounded-md bg-secondary px-1.5 py-0.5 text-[10px] font-semibold uppercase text-muted-foreground">
                        approval
                      </span>
                    )}
                    <span className="text-steel">{a.runs_30d} runs / 30d</span>
                    <button
                      type="button"
                      onClick={() =>
                        toggle.mutate(
                          { id: a.id, enabled: !a.enabled },
                          {
                            onError: (err) =>
                              notify.failed(err.isNotImplemented ? "Not wired yet" : "Failed", {
                                description: err.isNotImplemented
                                  ? "POST /api/integrations/leo-actions/toggle pending."
                                  : err.message,
                              }),
                          },
                        )
                      }
                      data-on={a.enabled ? "true" : "false"}
                      className="ax-press ml-auto rounded-lg border border-border px-2 py-1 text-[11px] font-semibold text-muted-foreground data-[on=true]:border-primary data-[on=true]:text-primary"
                    >
                      {a.enabled ? "On" : "Off"}
                    </button>
                  </div>
                  <p className="ax-caption mt-1 text-muted-foreground">{a.description}</p>
                </li>
              ))}
            </ul>
          )}
        </CardBody>
      </div>
    </>
  );
}

function StateChip({ state }: { state: string }) {
  const tone =
    state === "ok" || state === "connected" || state === "done" || state === "ready"
      ? "border-primary/60 text-primary"
      : state === "failed" || state === "error" || state === "fail"
        ? "border-destructive/60 text-destructive"
        : "border-border text-muted-foreground";
  return (
    <span className={cn("rounded-md border px-1.5 py-0.5 text-[10px] font-semibold uppercase", tone)}>
      {state.replace(/_/g, " ")}
    </span>
  );
}
