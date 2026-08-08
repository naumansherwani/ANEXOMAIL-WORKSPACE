import { Link } from "@tanstack/react-router";
import { Mail, Star } from "lucide-react";
import { useState } from "react";

import { Avatar, RelationshipChip, Stat, TagChip } from "@/components/app/people/Bits";
import { Timeline } from "@/components/app/people/Timeline";
import { NotWired } from "@/components/app/dashboard/DashboardCard";
import { EmptyState } from "@/components/app/Panel";
import { DetailSkeleton } from "@/components/state/Skeletons";
import { ErrorState } from "@/components/state/StateBlock";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import {
  replyTimeLabel,
  useContact,
  useContactTagAction,
  useContactTimeline,
  useUpdateContact,
} from "@/lib/contacts";
import { relativeTime } from "@/lib/mail";
import { notify } from "@/lib/notify";

/**
 * Column 3 — the person. One view: who they are, how the relationship is
 * trending, and every interaction ever, without leaving the shell.
 */
export function ContactProfile({ id }: { id: string }) {
  const detail = useContact(id);
  const timeline = useContactTimeline(id);
  const tagAction = useContactTagAction();
  const update = useUpdateContact();
  const [newTag, setNewTag] = useState("");

  if (detail.error) {
    if (detail.error.isNotImplemented || detail.error.code === "no_api_url") {
      return (
        <div className="p-ax-6">
          <NotWired endpoint={`GET /api/contacts/${id}`} />
        </div>
      );
    }
    return <ErrorState body={detail.error.message} onRetry={() => void detail.refetch()} />;
  }
  if (detail.isPending) return <DetailSkeleton />;
  if (!detail.data) return <EmptyState title="Not found" body="This person is no longer in the workspace." />;

  const c = detail.data.contact;

  const addTag = () => {
    const name = newTag.trim();
    if (!name) return;
    setNewTag("");
    tagAction.mutate(
      { id, add: [name] },
      {
        onSuccess: () => notify.success("Tag added", `${name} is now on this person.`),
        onError: (error) => notify.error("Could not tag", error.message),
      },
    );
  };

  return (
    <div className="mx-auto w-full max-w-3xl px-ax-6 py-ax-6">
      <header className="flex items-start gap-ax-4">
        <Avatar contact={c} size="lg" />
        <div className="min-w-0 flex-1">
          <h1 className="truncate text-xl font-bold text-foreground">
            {c.display_name || c.primary_address}
          </h1>
          <p className="ax-caption mt-0.5 truncate text-muted-foreground">
            {c.title ? `${c.title} · ` : ""}
            {c.primary_address}
          </p>
          <div className="mt-ax-2 flex flex-wrap items-center gap-2">
            <RelationshipChip relationship={c.relationship} score={c.health_score} />
            {c.company_domain && (
              <Link
                to="/app/people"
                search={{ view: "companies", id: c.company_domain, q: "", filter: "all", tag: "" }}
                className="ax-caption text-steel underline-offset-4 transition-colors hover:text-foreground hover:underline"
              >
                {c.company_name || c.company_domain}
              </Link>
            )}
          </div>
        </div>
        <div className="flex shrink-0 items-center gap-2">
          <Button
            variant="outline"
            size="sm"
            onClick={() =>
              update.mutate(
                { id, vip: !c.vip },
                { onError: (error) => notify.error("Could not update", error.message) },
              )
            }
          >
            <Star className={c.vip ? "size-4 fill-current" : "size-4"} />
            {c.vip ? "VIP" : "Mark VIP"}
          </Button>
          <Button asChild size="sm">
            <Link to="/app/mail/$folder" params={{ folder: "inbox" }} search={{ compose: c.primary_address }}>
              <Mail className="size-4" />
              Email
            </Link>
          </Button>
        </div>
      </header>

      <section className="mt-ax-6 grid grid-cols-2 gap-ax-2 md:grid-cols-4">
        <Stat label="Last contact" value={c.last_contact_at ? relativeTime(c.last_contact_at) : "—"} />
        <Stat label="Avg reply" value={replyTimeLabel(c.avg_reply_minutes)} />
        <Stat label="Messages" value={`${c.messages_in} in · ${c.messages_out} out`} />
        <Stat label="Open threads" value={c.open_threads} />
      </section>

      <section className="mt-ax-6">
        <p className="ax-eyebrow">Tags</p>
        <div className="mt-ax-2 flex flex-wrap items-center gap-2">
          {c.tags.map((tag) => (
            <TagChip
              key={tag}
              name={tag}
              onRemove={() =>
                tagAction.mutate(
                  { id, remove: [tag] },
                  { onError: (error) => notify.error("Could not remove tag", error.message) },
                )
              }
            />
          ))}
          <div className="flex items-center gap-1">
            <Input
              value={newTag}
              onChange={(e) => setNewTag(e.target.value)}
              onKeyDown={(e) => {
                if (e.key === "Enter") {
                  e.preventDefault();
                  addTag();
                }
              }}
              placeholder="Add tag"
              className="h-7 w-28 text-xs"
            />
          </div>
        </div>
      </section>

      <section className="mt-ax-6">
        <p className="ax-eyebrow">Relationship history</p>
        <div className="mt-ax-2">
          <Timeline
            events={timeline.data?.events}
            isPending={timeline.isPending}
            error={timeline.error ?? null}
            onRetry={() => void timeline.refetch()}
            endpoint={`GET /api/contacts/${id}/timeline`}
          />
        </div>
      </section>
    </div>
  );
}
