import { createFileRoute, Link, useNavigate } from "@tanstack/react-router";
import { Building2, Mail, Paperclip, Search, Users } from "lucide-react";

import { EmptyState } from "@/components/app/Panel";
import { NotWired } from "@/components/app/dashboard/DashboardCard";
import { Avatar, RelationshipChip } from "@/components/app/people/Bits";
import { ListSkeleton } from "@/components/state/Skeletons";
import { ErrorState } from "@/components/state/StateBlock";
import { useUniversalSearch } from "@/lib/contacts";
import { formatBytes, relativeTime } from "@/lib/mail";

export const Route = createFileRoute("/app/search")({
  validateSearch: (search: Record<string, unknown>) => ({
    q: typeof search["q"] === "string" ? search["q"] : "",
  }),
  head: () => ({
    meta: [
      { title: "Search — ANEXOMAIL Workspace" },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: SearchPage,
});

function SearchPage() {
  const { q } = Route.useSearch();
  const navigate = useNavigate({ from: "/app/search" });
  const results = useUniversalSearch(q);

  return (
    <div className="min-h-0 flex-1 overflow-y-auto">
      <div className="mx-auto w-full max-w-3xl px-6 py-12 md:px-10">
        <p className="ax-eyebrow">Everything</p>
        <h1 className="mt-3 text-3xl text-foreground md:text-4xl">Search</h1>

        <label className="mt-8 flex items-center gap-2 rounded-xl border border-border px-3 py-2.5">
          <Search className="size-4 shrink-0 text-steel" />
          <input
            autoFocus
            value={q}
            onChange={(e) => void navigate({ search: { q: e.target.value } })}
            placeholder="People, companies, threads, attachments…"
            className="min-w-0 flex-1 bg-transparent text-sm text-foreground outline-none placeholder:text-steel"
          />
        </label>

        <div className="mt-8">
          <Body q={q} results={results} />
        </div>
      </div>
    </div>
  );
}

function Body({ q, results }: { q: string; results: ReturnType<typeof useUniversalSearch> }) {
  if (q.trim().length < 2) {
    return (
      <EmptyState
        icon={<Search className="size-5" />}
        title="Type to search everything"
        body="One index across mail, people, companies and attachments — built from your own mailboxes."
      />
    );
  }
  if (results.error) {
    if (results.error.isNotImplemented || results.error.code === "no_api_url") {
      return <NotWired endpoint="GET /api/search/universal" />;
    }
    return <ErrorState body={results.error.message} onRetry={() => void results.refetch()} />;
  }
  if (results.isPending) return <ListSkeleton rows={6} label="Searching" />;

  const data = results.data;
  const total =
    (data?.people.length ?? 0) +
    (data?.companies.length ?? 0) +
    (data?.threads.length ?? 0) +
    (data?.attachments.length ?? 0);

  if (!data || total === 0) {
    return (
      <EmptyState
        icon={<Search className="size-5" />}
        title={`No results for “${q}”`}
        body="Nothing in mail, people, companies or attachments matches that yet."
      />
    );
  }

  return (
    <div className="space-y-8">
      {data.people.length > 0 && (
        <Group icon={<Users className="size-3.5" />} title="People">
          {data.people.map((p) => (
            <Link
              key={p.id}
              to="/app/people"
              search={{ view: "people", id: p.id, q: "", filter: "all", tag: "" }}
              className="flex items-center gap-ax-3 px-ax-4 py-ax-3 transition-colors hover:bg-secondary/40"
            >
              <Avatar contact={p} size="sm" />
              <span className="min-w-0 flex-1">
                <span className="block truncate text-[13px] font-medium text-foreground">
                  {p.display_name || p.primary_address}
                </span>
                <span className="ax-caption block truncate text-muted-foreground">
                  {p.primary_address}
                </span>
              </span>
              <RelationshipChip relationship={p.relationship} />
            </Link>
          ))}
        </Group>
      )}

      {data.companies.length > 0 && (
        <Group icon={<Building2 className="size-3.5" />} title="Companies">
          {data.companies.map((c) => (
            <Link
              key={c.domain}
              to="/app/people"
              search={{ view: "companies", id: c.domain, q: "", filter: "all", tag: "" }}
              className="flex items-center gap-ax-3 px-ax-4 py-ax-3 transition-colors hover:bg-secondary/40"
            >
              <span className="min-w-0 flex-1 truncate text-[13px] font-medium text-foreground">
                {c.name || c.domain}
              </span>
              <span className="ax-caption shrink-0 text-muted-foreground">
                {c.people_count} people
              </span>
            </Link>
          ))}
        </Group>
      )}

      {data.threads.length > 0 && (
        <Group icon={<Mail className="size-3.5" />} title="Threads">
          {data.threads.map((t) => (
            <Link
              key={t.id}
              to="/app/mail/$folder/$threadId"
              params={{ folder: t.folder || "inbox", threadId: t.id }}
              className="block px-ax-4 py-ax-3 transition-colors hover:bg-secondary/40"
            >
              <span className="flex items-baseline gap-2">
                <span className="truncate text-[13px] font-medium text-foreground">
                  {t.subject || "(no subject)"}
                </span>
                <span className="ml-auto shrink-0 text-[10px] text-steel">
                  {relativeTime(t.last_message_at)}
                </span>
              </span>
              {t.snippet && (
                <span className="ax-caption mt-0.5 block truncate text-muted-foreground">
                  {t.snippet}
                </span>
              )}
            </Link>
          ))}
        </Group>
      )}

      {data.attachments.length > 0 && (
        <Group icon={<Paperclip className="size-3.5" />} title="Attachments">
          {data.attachments.map((a) => (
            <div key={a.id} className="flex items-center gap-ax-3 px-ax-4 py-ax-3">
              <span className="min-w-0 flex-1 truncate text-[13px] text-foreground">
                {a.filename}
              </span>
              <span className="ax-caption shrink-0 text-muted-foreground">
                {formatBytes(a.size_bytes)}
              </span>
              {a.thread_id && (
                <Link
                  to="/app/mail/$folder/$threadId"
                  params={{ folder: a.folder || "inbox", threadId: a.thread_id }}
                  className="ax-caption shrink-0 text-steel underline-offset-4 hover:text-foreground hover:underline"
                >
                  Open
                </Link>
              )}
            </div>
          ))}
        </Group>
      )}
    </div>
  );
}

function Group({
  icon,
  title,
  children,
}: {
  icon: React.ReactNode;
  title: string;
  children: React.ReactNode;
}) {
  return (
    <section>
      <p className="ax-eyebrow flex items-center gap-1.5">
        {icon}
        {title}
      </p>
      <div className="mt-ax-2 divide-y divide-border rounded-xl border border-border">{children}</div>
    </section>
  );
}
