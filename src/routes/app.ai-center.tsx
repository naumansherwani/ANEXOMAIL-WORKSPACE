import { createFileRoute, Link } from "@tanstack/react-router";
import { Bot, Check, Crown, Inbox, ShieldAlert } from "lucide-react";
import { useState } from "react";

import { StateBlock } from "@/components/state/StateBlock";
import { Button } from "@/components/ui/button";
import { useAiAgents, useAiMail, useApproveAiDraft, type AiMailItem } from "@/lib/founder";
import { AI_MAILBOXES } from "@/lib/founder-plan";
import { notify } from "@/lib/notify";
import { cn } from "@/lib/utils";

export const Route = createFileRoute("/app/ai-center")({
  head: () => ({
    meta: [
      { title: "AI email center — ANEXOMAIL Workspace" },
      {
        name: "description",
        content:
          "Every AI mailbox in one control room: Leo, Jimmy John, Sherlock and the industry desks, with drafts awaiting founder approval.",
      },
      { property: "og:title", content: "AI email center — ANEXOMAIL Workspace" },
      {
        property: "og:description",
        content: "Control room for every AI mailbox, its replies and the drafts waiting for approval.",
      },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: AiCenter,
});

const STATES: (AiMailItem["state"] | "all")[] = ["draft", "escalated", "held", "sent", "all"];

const STATE_LABEL: Record<AiMailItem["state"] | "all", string> = {
  draft: "Awaiting approval",
  escalated: "Escalated to Jimmy",
  held: "Held",
  sent: "Sent",
  all: "Everything",
};

function AiCenter() {
  const [state, setState] = useState<AiMailItem["state"] | "all">("draft");
  const agents = useAiAgents();
  const mail = useAiMail(state);
  const approve = useApproveAiDraft();

  const notWired = (agents.error?.isNotImplemented ?? false) || (mail.error?.isNotImplemented ?? false);
  const items = mail.data?.items ?? [];

  return (
    <div className="min-h-0 flex-1 overflow-y-auto">
      <div className="mx-auto w-full max-w-5xl px-6 py-10 md:px-10">
        <p className="ax-eyebrow flex items-center gap-2">
          <Bot className="size-3.5" aria-hidden="true" /> AI email center
        </p>
        <h2 className="mt-3 text-3xl text-foreground">Every AI mailbox, one room</h2>
        <p className="mt-4 max-w-2xl text-sm leading-relaxed text-muted-foreground">
          Leo answers first, always. Anything out of depth escalates to Jimmy John, Sherlock
          validates, and money, legal or cancellation topics never leave without your approval.
        </p>

        <div className="ax-plane mt-6 flex flex-wrap items-center gap-3 rounded-2xl p-5">
          <div className="min-w-0 flex-1">
            <p className="text-[13px] font-semibold text-foreground">Escalation chain</p>
            <p className="ax-caption text-muted-foreground">
              User → Leo → Jimmy John (Business only) → Sherlock validation → final reply.
            </p>
          </div>
          <Button asChild variant="secondary">
            <Link to="/app/founder">
              <Crown className="size-4" aria-hidden="true" /> Founder deck
            </Link>
          </Button>
        </div>

        <section className="mt-10">
          <h2 className="text-base font-bold text-foreground">Agents</h2>
          <ul className="mt-3 grid gap-2 sm:grid-cols-2">
            {AI_MAILBOXES.map((planned) => {
              const server = (agents.data?.agents ?? []).find(
                (a) => a.address.toLowerCase() === planned.address.toLowerCase(),
              );
              return (
                <li key={planned.address} className="ax-plane rounded-2xl p-4">
                  <div className="flex items-center gap-2">
                    <p className="min-w-0 flex-1 truncate text-sm font-semibold text-foreground">
                      {planned.display_name}
                    </p>
                    <span
                      className={cn(
                        "ax-caption rounded-full border px-2 py-0.5 font-semibold",
                        server?.status === "live"
                          ? "border-success/40 bg-success/10 text-success"
                          : "border-border text-muted-foreground",
                      )}
                    >
                      {server?.status ?? "not wired"}
                    </span>
                  </div>
                  <p className="ax-caption mt-1 truncate text-muted-foreground">{planned.address}</p>
                  <p className="ax-caption mt-2 text-muted-foreground">
                    {server
                      ? `${server.drafts_pending} awaiting approval · ${server.replies_sent} sent · ${server.escalations} escalated`
                      : "No server data yet — counts stay blank until the endpoint is live."}
                  </p>
                </li>
              );
            })}
          </ul>
        </section>

        <section className="mt-10">
          <div className="flex flex-wrap items-center gap-2">
            <h2 className="text-base font-bold text-foreground">AI mail</h2>
            <div className="ml-auto flex flex-wrap gap-1">
              {STATES.map((s) => (
                <button
                  key={s}
                  type="button"
                  onClick={() => setState(s)}
                  className={cn(
                    "ax-press ax-caption rounded-full border px-2.5 py-1 font-semibold",
                    state === s
                      ? "border-cyan-accent/50 bg-secondary text-foreground"
                      : "border-border text-muted-foreground",
                  )}
                >
                  {STATE_LABEL[s]}
                </button>
              ))}
            </div>
          </div>

          <div className="mt-3">
            {notWired ? (
              <div className="ax-plane rounded-2xl">
                <StateBlock
                  tone="error"
                  icon={<ShieldAlert className="size-5" aria-hidden="true" />}
                  title="AI mail feed not wired yet"
                  body="This room reads /api/founder/ai-agents and /api/founder/ai-mail on the brain. Until those exist it stays empty on purpose — no invented drafts."
                />
              </div>
            ) : mail.isLoading ? (
              <div className="ax-shimmer h-32 rounded-2xl" />
            ) : items.length === 0 ? (
              <div className="ax-plane rounded-2xl">
                <StateBlock
                  icon={<Inbox className="size-5" aria-hidden="true" />}
                  title="Nothing here"
                  body="No AI mail in this state right now."
                />
              </div>
            ) : (
              <ul className="space-y-2">
                {items.map((item) => (
                  <li key={item.id} className="ax-plane rounded-2xl p-4">
                    <div className="flex flex-wrap items-center gap-2">
                      <span className="ax-caption rounded-full border border-border px-2 py-0.5 font-semibold text-muted-foreground">
                        {item.agent}
                      </span>
                      <p className="min-w-0 flex-1 truncate text-sm font-semibold text-foreground">
                        {item.subject}
                      </p>
                      {item.confidence !== null && (
                        <span className="ax-caption text-muted-foreground">
                          confidence {Math.round(item.confidence * 100)}%
                        </span>
                      )}
                      {item.state === "draft" && (
                        <Button
                          size="sm"
                          disabled={approve.isPending}
                          onClick={() =>
                            approve.mutate(
                              { id: item.id },
                              {
                                onSuccess: () => notify.done("Sent", "Draft approved and delivered."),
                                onError: (error) =>
                                  notify.failed("Could not send", { description: error.message }),
                              },
                            )
                          }
                        >
                          <Check className="size-4" aria-hidden="true" /> Approve & send
                        </Button>
                      )}
                    </div>
                    <p className="ax-caption mt-1 text-muted-foreground">
                      {item.from_address} → {item.to_address}
                      {item.escalated_to ? ` · escalated to ${item.escalated_to}` : ""}
                    </p>
                    <p className="mt-2 text-sm leading-relaxed text-muted-foreground">{item.preview}</p>
                  </li>
                ))}
              </ul>
            )}
          </div>
        </section>
      </div>
    </div>
  );
}
