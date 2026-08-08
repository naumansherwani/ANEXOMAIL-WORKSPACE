import { createFileRoute } from "@tanstack/react-router";
import { AtSign, CheckCheck, Inbox, PenLine } from "lucide-react";
import { useState } from "react";

import { Chip, SectionTitle } from "@/components/app/crm/CrmBits";
import { CardBody, StatSkeleton } from "@/components/app/dashboard/DashboardCard";
import { Button } from "@/components/ui/button";
import { relativeTime } from "@/lib/mail";
import { notify } from "@/lib/notify";
import {
  money,
  useApprovals,
  useDecideApproval,
  useMentions,
  useSharedItems,
} from "@/lib/crm";
import { cn } from "@/lib/utils";

export const Route = createFileRoute("/app/crm/collab")({
  head: () => ({
    meta: [
      { title: "Shared work — ANEXOMAIL AI CRM" },
      {
        name: "description",
        content:
          "Shared inbox, shared drafts, mentions and approvals — one team surface where nothing gets answered twice.",
      },
      { property: "og:title", content: "Shared work — ANEXOMAIL AI CRM" },
      { property: "og:description", content: "Shared inbox, drafts, mentions and approvals." },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: CollabPage,
});

type Tab = "inbox" | "drafts" | "mentions" | "approvals";

const TABS: { id: Tab; label: string; icon: typeof Inbox }[] = [
  { id: "inbox", label: "Shared inbox", icon: Inbox },
  { id: "drafts", label: "Shared drafts", icon: PenLine },
  { id: "mentions", label: "Mentions", icon: AtSign },
  { id: "approvals", label: "Approvals", icon: CheckCheck },
];

function CollabPage() {
  const [tab, setTab] = useState<Tab>("inbox");

  return (
    <div className="mx-auto w-full max-w-5xl px-ax-5 py-ax-6">
      <SectionTitle
        title="Shared work"
        hint="Assignment, mentions and approvals are server truth — two people can never own the same reply."
      />

      <div className="mb-ax-4 flex flex-wrap gap-1">
        {TABS.map((t) => (
          <button
            key={t.id}
            type="button"
            onClick={() => setTab(t.id)}
            className={cn(
              "ax-press inline-flex items-center gap-1.5 rounded-full border px-3 py-1 text-[12px] font-semibold transition-colors",
              tab === t.id
                ? "border-foreground bg-secondary text-foreground"
                : "border-border text-muted-foreground hover:text-foreground",
            )}
          >
            <t.icon className="size-3.5" aria-hidden="true" />
            {t.label}
          </button>
        ))}
      </div>

      {tab === "inbox" || tab === "drafts" ? (
        <SharedList kind={tab === "inbox" ? "inbox" : "draft"} />
      ) : tab === "mentions" ? (
        <MentionsList />
      ) : (
        <ApprovalsList />
      )}
    </div>
  );
}

function SharedList({ kind }: { kind: "inbox" | "draft" }) {
  const items = useSharedItems(kind);
  return (
    <CardBody
      query={{
        data: items.data,
        isPending: items.isPending,
        error: items.error ?? null,
        refetch: () => void items.refetch(),
      }}
      endpoint="/api/crm/shared"
      skeleton={<StatSkeleton rows={5} />}
    >
      {(data) =>
        data.items.length === 0 ? (
          <p className="ax-caption text-muted-foreground">
            Nothing waiting. Shared items appear when a team address receives mail or a teammate
            leaves a draft.
          </p>
        ) : (
          <ul className="space-y-ax-2">
            {data.items.map((i) => (
              <li key={i.id} className="ax-plane rounded-2xl p-ax-4">
                <div className="flex flex-wrap items-center gap-ax-3">
                  <p className="min-w-0 flex-1 truncate text-[13px] font-semibold text-foreground">
                    {i.subject}
                  </p>
                  <Chip tone={i.state === "unassigned" ? "warn" : "quiet"}>
                    {i.assigned_to ?? i.state.replace("_", " ")}
                  </Chip>
                  <span className="ax-caption text-muted-foreground">
                    {relativeTime(i.created_at)}
                  </span>
                </div>
                <p className="ax-caption mt-1 truncate text-muted-foreground">
                  {i.from_address} — {i.preview}
                </p>
              </li>
            ))}
          </ul>
        )
      }
    </CardBody>
  );
}

function MentionsList() {
  const mentions = useMentions();
  return (
    <CardBody
      query={{
        data: mentions.data,
        isPending: mentions.isPending,
        error: mentions.error ?? null,
        refetch: () => void mentions.refetch(),
      }}
      endpoint="/api/crm/mentions"
      skeleton={<StatSkeleton rows={4} />}
    >
      {(data) =>
        data.mentions.length === 0 ? (
          <p className="ax-caption text-muted-foreground">No one has mentioned you yet.</p>
        ) : (
          <ul className="space-y-ax-2">
            {data.mentions.map((m) => (
              <li key={m.id} className="ax-plane rounded-2xl p-ax-4">
                <div className="flex flex-wrap items-center gap-ax-3">
                  <p className="min-w-0 flex-1 text-[13px] text-foreground">
                    <strong>{m.actor}</strong> mentioned {m.target}
                  </p>
                  {!m.read && <Chip tone="warn">Unread</Chip>}
                  <span className="ax-caption text-muted-foreground">
                    {relativeTime(m.created_at)}
                  </span>
                </div>
                <p className="ax-body mt-1">{m.context}</p>
              </li>
            ))}
          </ul>
        )
      }
    </CardBody>
  );
}

function ApprovalsList() {
  const approvals = useApprovals();
  const decide = useDecideApproval();

  const act = (id: string, decision: "approved" | "rejected") =>
    decide.mutate(
      { id, decision },
      {
        onSuccess: () => notify.done("Decision saved", `Request ${decision}.`),
        onError: (e) =>
          notify.failed(e.isNotImplemented ? "Approvals not wired yet" : "Could not save", {
            description: e.message,
          }),
      },
    );

  return (
    <CardBody
      query={{
        data: approvals.data,
        isPending: approvals.isPending,
        error: approvals.error ?? null,
        refetch: () => void approvals.refetch(),
      }}
      endpoint="/api/crm/approvals"
      skeleton={<StatSkeleton rows={4} />}
    >
      {(data) =>
        data.approvals.length === 0 ? (
          <p className="ax-caption text-muted-foreground">
            Nothing needs a decision. Money and legal replies always land here before they send.
          </p>
        ) : (
          <ul className="space-y-ax-2">
            {data.approvals.map((a) => (
              <li key={a.id} className="ax-plane rounded-2xl p-ax-4">
                <div className="flex flex-wrap items-center gap-ax-3">
                  <p className="min-w-0 flex-1 text-[13px] font-semibold text-foreground">
                    {a.subject}
                  </p>
                  {a.amount !== null && (
                    <Chip>{money(a.amount, a.currency ?? "GBP")}</Chip>
                  )}
                  <Chip
                    tone={
                      a.state === "approved" ? "good" : a.state === "rejected" ? "bad" : "warn"
                    }
                  >
                    {a.state}
                  </Chip>
                </div>
                <p className="ax-body mt-1">
                  {a.requested_by} — {a.reason}
                </p>
                {a.state === "pending" && (
                  <div className="mt-ax-3 flex gap-2">
                    <Button size="sm" disabled={decide.isPending} onClick={() => act(a.id, "approved")}>
                      Approve
                    </Button>
                    <Button
                      size="sm"
                      variant="secondary"
                      disabled={decide.isPending}
                      onClick={() => act(a.id, "rejected")}
                    >
                      Reject
                    </Button>
                  </div>
                )}
              </li>
            ))}
          </ul>
        )
      }
    </CardBody>
  );
}
