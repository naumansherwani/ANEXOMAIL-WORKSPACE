import { createFileRoute, useNavigate } from "@tanstack/react-router";
import { Building2, Search, Users, X } from "lucide-react";
import { useState } from "react";

import { ComposeOverlay } from "@/components/app/ComposeOverlay";
import { DetailPanel, EmptyState, ListPanel } from "@/components/app/Panel";
import { NotWired } from "@/components/app/dashboard/DashboardCard";
import { Avatar, RelationshipChip } from "@/components/app/people/Bits";
import { CompanyProfile } from "@/components/app/people/CompanyProfile";
import { ContactProfile } from "@/components/app/people/ContactProfile";
import { ListSkeleton } from "@/components/state/Skeletons";
import { ErrorState } from "@/components/state/StateBlock";
import {
  SMART_FILTERS,
  useCompanies,
  useContacts,
  useContactTags,
  type SmartFilter,
} from "@/lib/contacts";
import { relativeTime } from "@/lib/mail";
import { cn } from "@/lib/utils";

type View = "people" | "companies";

export const Route = createFileRoute("/app/people")({
  validateSearch: (search: Record<string, unknown>) => ({
    view: (search["view"] === "companies" ? "companies" : "people") as View,
    id: typeof search["id"] === "string" ? search["id"] : "",
    q: typeof search["q"] === "string" ? search["q"] : "",
    filter: (typeof search["filter"] === "string" ? search["filter"] : "all") as SmartFilter,
    tag: typeof search["tag"] === "string" ? search["tag"] : "",
  }),
  head: () => ({
    meta: [
      { title: "People & companies — ANEXOMAIL Workspace" },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: PeoplePage,
});

function PeoplePage() {
  const { view, id, q, filter, tag } = Route.useSearch();
  const navigate = useNavigate({ from: "/app/people" });
  const [composeTo, setComposeTo] = useState<string | null>(null);

  type PeopleSearch = { view: View; id: string; q: string; filter: SmartFilter; tag: string };
  const current: PeopleSearch = { view, id, q, filter, tag };
  const set = (patch: Partial<PeopleSearch>) =>
    void navigate({ search: { ...current, ...patch } });

  const contacts = useContacts({ q, filter, tag: tag || null });
  const companies = useCompanies({ q });
  const tags = useContactTags();

  return (
    <>
      <ListPanel title={view === "people" ? "People" : "Companies"}>
        <div className="space-y-ax-2 border-b border-border px-ax-4 py-ax-3">
          <div className="flex rounded-lg bg-secondary p-0.5">
            {(["people", "companies"] as View[]).map((v) => (
              <button
                key={v}
                type="button"
                onClick={() => set({ view: v, id: "" })}
                className={cn(
                  "ax-press flex flex-1 items-center justify-center gap-1.5 rounded-md px-2 py-1 text-[11px] font-bold uppercase tracking-wide transition-colors",
                  view === v ? "bg-background text-foreground" : "text-steel hover:text-foreground",
                )}
              >
                {v === "people" ? <Users className="size-3" /> : <Building2 className="size-3" />}
                {v === "people" ? "People" : "Companies"}
              </button>
            ))}
          </div>

          <label className="flex items-center gap-2 rounded-lg border border-border px-2 py-1.5">
            <Search className="size-3.5 shrink-0 text-steel" />
            <input
              value={q}
              onChange={(e) => set({ q: e.target.value })}
              placeholder={view === "people" ? "Find a person" : "Find a company"}
              className="min-w-0 flex-1 bg-transparent text-[13px] text-foreground outline-none placeholder:text-steel"
            />
            {q && (
              <button type="button" aria-label="Clear" onClick={() => set({ q: "" })}>
                <X className="size-3.5 text-steel" />
              </button>
            )}
          </label>

          {view === "people" && (
            <div className="flex flex-wrap gap-1">
              {SMART_FILTERS.map((f) => (
                <button
                  key={f.id}
                  type="button"
                  onClick={() => set({ filter: f.id })}
                  className={cn(
                    "ax-press rounded-full border px-2 py-0.5 text-[10px] font-bold uppercase tracking-wide transition-colors",
                    filter === f.id
                      ? "border-foreground text-foreground"
                      : "border-border text-steel hover:text-foreground",
                  )}
                >
                  {f.label}
                </button>
              ))}
              {(tags.data?.tags ?? []).map((t) => (
                <button
                  key={t.id}
                  type="button"
                  onClick={() => set({ tag: tag === t.name ? "" : t.name })}
                  className={cn(
                    "ax-press rounded-full px-2 py-0.5 text-[10px] font-medium transition-colors",
                    tag === t.name ? "bg-foreground text-background" : "bg-secondary text-steel hover:text-foreground",
                  )}
                >
                  {t.name}
                  {typeof t.count === "number" && <span className="ml-1 opacity-60">{t.count}</span>}
                </button>
              ))}
            </div>
          )}
        </div>

        {view === "people" ? (
          <PeopleRail
            state={contacts}
            activeId={id}
            onOpen={(next) => set({ id: next })}
          />
        ) : (
          <CompanyRail
            state={companies}
            activeId={id}
            onOpen={(next) => set({ id: next })}
          />
        )}
      </ListPanel>

      <DetailPanel>
        {!id ? (
          <EmptyState
            title={view === "people" ? "Nobody selected" : "No company selected"}
            body="Open a record to see every message, meeting and open thread with them — one spine, no digging."
          />
        ) : view === "people" ? (
          <ContactProfile id={id} onCompose={setComposeTo} />
        ) : (
          <CompanyProfile
            domain={id}
            onOpenPerson={(contactId) => set({ view: "people", id: contactId })}
          />
        )}
      </DetailPanel>

      {composeTo && <ComposeOverlay initialTo={composeTo} onClose={() => setComposeTo(null)} />}
    </>
  );
}

function PeopleRail({
  state,
  activeId,
  onOpen,
}: {
  state: ReturnType<typeof useContacts>;
  activeId: string;
  onOpen: (id: string) => void;
}) {
  if (state.error) {
    if (state.error.isNotImplemented || state.error.code === "no_api_url") {
      return (
        <div className="p-ax-4">
          <NotWired endpoint="GET /api/contacts" />
        </div>
      );
    }
    return <ErrorState body={state.error.message} onRetry={() => void state.refetch()} />;
  }
  if (state.isPending) return <ListSkeleton rows={8} label="Loading people" />;
  const contacts = state.data?.contacts ?? [];
  if (contacts.length === 0) {
    return (
      <EmptyState
        icon={<Users className="size-5" />}
        title="No contacts match"
        body="Contacts build themselves from real conversations, and stay editable by hand."
      />
    );
  }

  return (
    <div className="divide-y divide-border">
      {contacts.map((c) => (
        <button
          key={c.id}
          type="button"
          onClick={() => onOpen(c.id)}
          className={cn(
            "flex w-full items-center gap-ax-3 px-ax-4 py-ax-3 text-left transition-colors",
            c.id === activeId ? "bg-secondary" : "hover:bg-secondary/40",
          )}
        >
          <Avatar contact={c} />
          <span className="min-w-0 flex-1">
            <span className="flex items-center gap-1.5">
              <span className="truncate text-[13px] font-bold text-foreground">
                {c.display_name || c.primary_address}
              </span>
              <span className="ml-auto shrink-0 text-[10px] text-steel">
                {c.last_contact_at ? relativeTime(c.last_contact_at) : ""}
              </span>
            </span>
            <span className="ax-caption block truncate text-muted-foreground">
              {c.company_name || c.primary_address}
            </span>
            <span className="mt-1 flex items-center gap-1">
              <RelationshipChip relationship={c.relationship} />
              {c.open_threads > 0 && (
                <span className="text-[10px] text-steel">{c.open_threads} open</span>
              )}
            </span>
          </span>
        </button>
      ))}
    </div>
  );
}

function CompanyRail({
  state,
  activeId,
  onOpen,
}: {
  state: ReturnType<typeof useCompanies>;
  activeId: string;
  onOpen: (domain: string) => void;
}) {
  if (state.error) {
    if (state.error.isNotImplemented || state.error.code === "no_api_url") {
      return (
        <div className="p-ax-4">
          <NotWired endpoint="GET /api/companies" />
        </div>
      );
    }
    return <ErrorState body={state.error.message} onRetry={() => void state.refetch()} />;
  }
  if (state.isPending) return <ListSkeleton rows={8} label="Loading companies" />;
  const companies = state.data?.companies ?? [];
  if (companies.length === 0) {
    return (
      <EmptyState
        icon={<Building2 className="size-5" />}
        title="No companies yet"
        body="Every email domain you talk to becomes an organisation automatically."
      />
    );
  }

  return (
    <div className="divide-y divide-border">
      {companies.map((company) => (
        <button
          key={company.domain}
          type="button"
          onClick={() => onOpen(company.domain)}
          className={cn(
            "flex w-full items-center gap-ax-3 px-ax-4 py-ax-3 text-left transition-colors",
            company.domain === activeId ? "bg-secondary" : "hover:bg-secondary/40",
          )}
        >
          <span className="grid size-8 shrink-0 place-items-center rounded-md bg-secondary">
            <Building2 className="size-4 text-foreground" />
          </span>
          <span className="min-w-0 flex-1">
            <span className="block truncate text-[13px] font-bold text-foreground">
              {company.name || company.domain}
            </span>
            <span className="ax-caption block truncate text-muted-foreground">
              {company.people_count} people · {company.messages_total} messages
            </span>
          </span>
          <RelationshipChip relationship={company.relationship} />
        </button>
      ))}
    </div>
  );
}
