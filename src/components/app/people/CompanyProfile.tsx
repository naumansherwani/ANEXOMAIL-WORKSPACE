import { Building2 } from "lucide-react";

import { Avatar, RelationshipChip, Stat } from "@/components/app/people/Bits";
import { Timeline } from "@/components/app/people/Timeline";
import { NotWired } from "@/components/app/dashboard/DashboardCard";
import { EmptyState } from "@/components/app/Panel";
import { ThreadSkeleton } from "@/components/state/Skeletons";
import { ErrorState } from "@/components/state/StateBlock";
import { useCompany, useCompanyTimeline } from "@/lib/contacts";
import { relativeTime } from "@/lib/mail";

/** One domain = one organisation. Every person and every thread in one place. */
export function CompanyProfile({
  domain,
  onOpenPerson,
}: {
  domain: string;
  onOpenPerson: (contactId: string) => void;
}) {
  const detail = useCompany(domain);
  const timeline = useCompanyTimeline(domain);

  if (detail.error) {
    if (detail.error.isNotImplemented || detail.error.code === "no_api_url") {
      return (
        <div className="p-ax-6">
          <NotWired endpoint={`GET /api/companies/${domain}`} />
        </div>
      );
    }
    return <ErrorState body={detail.error.message} onRetry={() => void detail.refetch()} />;
  }
  if (detail.isPending) return <ThreadSkeleton />;
  if (!detail.data) return <EmptyState title="Not found" body="This organisation has no history yet." />;

  const { company, people } = detail.data;

  return (
    <div className="mx-auto w-full max-w-3xl px-ax-6 py-ax-6">
      <header className="flex items-start gap-ax-4">
        <span className="grid size-12 shrink-0 place-items-center rounded-md bg-secondary">
          <Building2 className="size-5 text-foreground" />
        </span>
        <div className="min-w-0 flex-1">
          <h1 className="truncate text-xl font-bold text-foreground">
            {company.name || company.domain}
          </h1>
          <p className="ax-caption mt-0.5 text-muted-foreground">{company.domain}</p>
          <div className="mt-ax-2">
            <RelationshipChip relationship={company.relationship} score={company.health_score} />
          </div>
        </div>
      </header>

      <section className="mt-ax-6 grid grid-cols-2 gap-ax-2 md:grid-cols-4">
        <Stat label="People" value={company.people_count} />
        <Stat label="Messages" value={company.messages_total} />
        <Stat label="Open threads" value={company.open_threads} />
        <Stat
          label="Last contact"
          value={company.last_contact_at ? relativeTime(company.last_contact_at) : "—"}
        />
      </section>

      <section className="mt-ax-6">
        <p className="ax-eyebrow">People here</p>
        <div className="mt-ax-2 divide-y divide-border rounded-md border border-border">
          {people.length === 0 && (
            <p className="ax-caption px-ax-4 py-ax-3 text-muted-foreground">
              No individual contacts derived yet.
            </p>
          )}
          {people.map((person) => (
            <button
              key={person.id}
              type="button"
              onClick={() => onOpenPerson(person.id)}
              className="flex w-full items-center gap-ax-3 px-ax-4 py-ax-3 text-left transition-colors hover:bg-secondary/40"
            >
              <Avatar contact={person} size="sm" />
              <span className="min-w-0 flex-1">
                <span className="block truncate text-[13px] font-medium text-foreground">
                  {person.display_name || person.primary_address}
                </span>
                <span className="ax-caption block truncate text-muted-foreground">
                  {person.primary_address}
                </span>
              </span>
              <RelationshipChip relationship={person.relationship} />
            </button>
          ))}
        </div>
      </section>

      <section className="mt-ax-6">
        <p className="ax-eyebrow">Organisation history</p>
        <div className="mt-ax-2">
          <Timeline
            events={timeline.data?.events}
            isPending={timeline.isPending}
            error={timeline.error ?? null}
            onRetry={() => void timeline.refetch()}
            endpoint={`GET /api/companies/${domain}/timeline`}
          />
        </div>
      </section>
    </div>
  );
}
