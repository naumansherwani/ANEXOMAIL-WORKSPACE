import { createFileRoute } from "@tanstack/react-router";
import { useState } from "react";
import { Bot, GitBranch, Lightbulb, Play, ShieldCheck, Variable } from "lucide-react";

import { Chip } from "@/components/app/ai/AiBits";
import { SectionTitle } from "@/components/app/crm/CrmBits";
import { CardBody, StatSkeleton } from "@/components/app/dashboard/DashboardCard";
import { Button } from "@/components/ui/button";
import { relativeTime } from "@/lib/mail";
import { notify } from "@/lib/notify";
import {
  TRIGGER_LABEL,
  useAiRules,
  useAiSuggestions,
  useAiVariables,
  useDecideSuggestion,
  useDeleteVariable,
  useDryRunWorkflow,
  useEmailAutomations,
  useRunWorkflow,
  useSaveVariable,
  useToggleEmailAutomation,
  useToggleRule,
  useToggleWorkflow,
  useWorkflowRuns,
  useWorkflows,
} from "@/lib/ai-automation";

/**
 * Phase 18 — AI Automation, founder surface (aiemail.anexomail.com, IP locked).
 * Awam ke liye /ai/automation coming-soon gate.
 * NO WEBHOOK / NO PUBLIC API: automation LEO Actions + native integrations se chalti hai.
 */
export const Route = createFileRoute("/app/founder_/ai/automation")({
  head: () => ({
    meta: [
      { title: "AI Automation — ANEXOMAIL" },
      {
        name: "description",
        content:
          "Founder AI Automation: workflows, rules, variables, email automation and LEO suggestions — with dry run and approval gates before anything sends.",
      },
      { property: "og:title", content: "AI Automation — ANEXOMAIL" },
      {
        property: "og:description",
        content: "Workflows, rules, variables and suggestions — dry run first, approval before send.",
      },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: AutomationPage,
});

function AutomationPage() {
  const workflows = useWorkflows();
  const runs = useWorkflowRuns();
  const rules = useAiRules();
  const variables = useAiVariables();
  const suggestions = useAiSuggestions();
  const email = useEmailAutomations();

  const toggleWorkflow = useToggleWorkflow();
  const runWorkflow = useRunWorkflow();
  const dryRun = useDryRunWorkflow();
  const toggleRule = useToggleRule();
  const saveVar = useSaveVariable();
  const delVar = useDeleteVariable();
  const decide = useDecideSuggestion();
  const toggleEmail = useToggleEmailAutomation();

  const [key, setKey] = useState("");
  const [value, setValue] = useState("");

  const fail = (label: string) => (e: { isNotImplemented?: boolean; message: string }) =>
    notify.failed(e.isNotImplemented ? `${label} abhi wired nahi` : `${label} fail hua`, {
      description: e.message,
    });

  return (
    <div className="min-h-0 flex-1 overflow-y-auto">
      <div className="mx-auto w-full max-w-6xl px-6 py-8 md:px-10">
        <p className="ax-eyebrow flex items-center gap-2">
          <Bot className="size-3.5" aria-hidden="true" /> Phase 18 · Automation · dry run pehle, approval phir
        </p>
        <h1 className="mt-2 text-2xl text-foreground">Workflows that never send behind your back</h1>
        <p className="mt-ax-3 max-w-2xl text-sm leading-relaxed text-muted-foreground">
          Har workflow default pe approval gate ke saath aata hai. Auto-send tab tak nahi jab tak
          tum khud switch nahi karte — aur dry run pehle bata deta hai kya hota.
        </p>

        {/* Workflows */}
        <section className="mt-ax-6">
          <SectionTitle title="AI workflows" hint="Trigger → steps. Server evaluate karta hai, UI sirf state dikhati hai." />
          <CardBody
            query={{
              data: workflows.data,
              isPending: workflows.isPending,
              error: workflows.error ?? null,
              refetch: () => void workflows.refetch(),
            }}
            endpoint="/api/ai/automation/workflows"
            skeleton={<StatSkeleton rows={4} />}
          >
            {(data) =>
              data.workflows.length === 0 ? (
                <p className="ax-caption text-muted-foreground">Koi workflow abhi banaya nahi gaya.</p>
              ) : (
                <ul className="space-y-ax-2">
                  {data.workflows.map((w) => (
                    <li key={w.id} className="ax-plane rounded-2xl p-ax-4">
                      <div className="flex flex-wrap items-center gap-2">
                        <GitBranch className="size-4 text-steel" aria-hidden="true" />
                        <p className="min-w-0 flex-1 truncate text-[13px] font-semibold text-foreground">
                          {w.name}
                        </p>
                        <Chip>{TRIGGER_LABEL[w.trigger_kind]}</Chip>
                        <Chip>{w.steps.length} steps</Chip>
                        <Chip tone={w.requires_approval ? "good" : "warn"}>
                          {w.requires_approval ? "approval gate" : "auto-send"}
                        </Chip>
                        <Chip tone={w.enabled ? "good" : "quiet"}>{w.enabled ? "live" : "off"}</Chip>
                        {w.failures > 0 && <Chip tone="bad">{w.failures} failed</Chip>}
                      </div>
                      {w.description && (
                        <p className="ax-caption mt-1 text-muted-foreground">{w.description}</p>
                      )}
                      <div className="mt-ax-3 flex flex-wrap gap-2">
                        <Button
                          size="sm"
                          variant="secondary"
                          disabled={dryRun.isPending}
                          onClick={() =>
                            dryRun.mutate(
                              { id: w.id },
                              {
                                onSuccess: (d) =>
                                  notify.done(
                                    `Dry run — ${d.would_match} matches`,
                                    d.log.slice(0, 3).join(" · "),
                                  ),
                                onError: fail("Dry run"),
                              },
                            )
                          }
                        >
                          Dry run
                        </Button>
                        <Button
                          size="sm"
                          variant={w.enabled ? "secondary" : "default"}
                          disabled={toggleWorkflow.isPending}
                          onClick={() =>
                            toggleWorkflow.mutate(
                              { id: w.id, enabled: !w.enabled },
                              {
                                onSuccess: () => notify.done("Switch applied", "Server ne confirm kiya."),
                                onError: fail("Toggle"),
                              },
                            )
                          }
                        >
                          {w.enabled ? "Turn off" : "Turn on"}
                        </Button>
                        <Button
                          size="sm"
                          variant="secondary"
                          disabled={runWorkflow.isPending}
                          onClick={() =>
                            runWorkflow.mutate(
                              { id: w.id },
                              {
                                onSuccess: () => notify.done("Run started", "History mein dikh raha hai."),
                                onError: fail("Run"),
                              },
                            )
                          }
                        >
                          <Play className="size-3.5" aria-hidden="true" /> Run now
                        </Button>
                        {w.last_run_at && (
                          <span className="ax-caption ml-auto self-center text-muted-foreground">
                            last run {relativeTime(w.last_run_at)}
                          </span>
                        )}
                      </div>
                    </li>
                  ))}
                </ul>
              )
            }
          </CardBody>
        </section>

        {/* Email automation */}
        <section className="mt-10">
          <SectionTitle
            title="Email automation"
            hint="Per mailbox: draft only, notify only, ya auto-send. Escalation LEO → Jimmy chain se hoti hai."
          />
          <CardBody
            query={{
              data: email.data,
              isPending: email.isPending,
              error: email.error ?? null,
              refetch: () => void email.refetch(),
            }}
            endpoint="/api/ai/automation/email"
            skeleton={<StatSkeleton rows={3} />}
          >
            {(data) =>
              data.automations.length === 0 ? (
                <p className="ax-caption text-muted-foreground">Kisi mailbox pe automation nahi lagi.</p>
              ) : (
                <ul className="space-y-ax-2">
                  {data.automations.map((a) => (
                    <li key={a.id} className="ax-plane rounded-2xl p-ax-4">
                      <div className="flex flex-wrap items-center gap-2">
                        <p className="min-w-0 flex-1 truncate text-[13px] font-semibold text-foreground">
                          {a.name}
                          <span className="ax-caption ml-2 font-mono text-steel">{a.mailbox}</span>
                        </p>
                        <Chip tone={a.mode === "auto_send" ? "warn" : "good"}>
                          {a.mode.replace("_", " ")}
                        </Chip>
                        <Chip>{a.handled} handled</Chip>
                        {a.escalations > 0 && <Chip tone="warn">{a.escalations} escalated</Chip>}
                        <Chip tone={a.enabled ? "good" : "quiet"}>{a.enabled ? "live" : "off"}</Chip>
                        <Button
                          size="sm"
                          variant="secondary"
                          disabled={toggleEmail.isPending}
                          onClick={() =>
                            toggleEmail.mutate(
                              { id: a.id, enabled: !a.enabled },
                              {
                                onSuccess: () => notify.done("Switch applied", "Server ne confirm kiya."),
                                onError: fail("Toggle"),
                              },
                            )
                          }
                        >
                          {a.enabled ? "Turn off" : "Turn on"}
                        </Button>
                      </div>
                    </li>
                  ))}
                </ul>
              )
            }
          </CardBody>
        </section>

        {/* Rules */}
        <section className="mt-10">
          <SectionTitle title="AI rules" hint="If this, then that — priority order mein server chalata hai." />
          <CardBody
            query={{
              data: rules.data,
              isPending: rules.isPending,
              error: rules.error ?? null,
              refetch: () => void rules.refetch(),
            }}
            endpoint="/api/ai/automation/rules"
            skeleton={<StatSkeleton rows={4} />}
          >
            {(data) =>
              data.rules.length === 0 ? (
                <p className="ax-caption text-muted-foreground">Koi rule abhi set nahi.</p>
              ) : (
                <ul className="space-y-1.5">
                  {data.rules.map((r) => (
                    <li
                      key={r.id}
                      className="flex flex-wrap items-center gap-2 rounded-xl border border-border px-ax-3 py-ax-2"
                    >
                      <ShieldCheck className="size-3.5 text-steel" aria-hidden="true" />
                      <span className="text-[13px] font-semibold text-foreground">{r.name}</span>
                      <Chip>{r.scope}</Chip>
                      <span className="ax-caption min-w-0 flex-1 truncate text-muted-foreground">
                        {r.conditions.map((c) => `${c.field} ${c.op} ${c.value}`).join(" · ")} →{" "}
                        {r.actions.map((a) => a.action).join(", ")}
                      </span>
                      <Chip>{r.matches} matches</Chip>
                      <Button
                        size="sm"
                        variant="secondary"
                        disabled={toggleRule.isPending}
                        onClick={() =>
                          toggleRule.mutate(
                            { id: r.id, enabled: !r.enabled },
                            {
                              onSuccess: () => notify.done("Rule updated", "Server ne confirm kiya."),
                              onError: fail("Rule toggle"),
                            },
                          )
                        }
                      >
                        {r.enabled ? "Disable" : "Enable"}
                      </Button>
                    </li>
                  ))}
                </ul>
              )
            }
          </CardBody>
        </section>

        {/* Variables */}
        <section className="mt-10">
          <SectionTitle
            title="AI variables"
            hint="Reusable values — company name, SLA, signature line. Koi secret yahan nahi."
          />
          <div className="ax-plane rounded-2xl p-ax-4">
            <div className="flex flex-wrap gap-2">
              <input
                value={key}
                onChange={(e) => setKey(e.target.value)}
                placeholder="key e.g. sla_hours"
                className="min-w-[10rem] flex-1 rounded-xl border border-border bg-card px-3 py-2 text-[13px] text-foreground outline-none focus-visible:ring-2 focus-visible:ring-ring/50"
              />
              <input
                value={value}
                onChange={(e) => setValue(e.target.value)}
                placeholder="value e.g. 4"
                className="min-w-[10rem] flex-1 rounded-xl border border-border bg-card px-3 py-2 text-[13px] text-foreground outline-none focus-visible:ring-2 focus-visible:ring-ring/50"
              />
              <Button
                disabled={saveVar.isPending || !key.trim()}
                onClick={() =>
                  saveVar.mutate(
                    { key: key.trim(), value },
                    {
                      onSuccess: () => {
                        setKey("");
                        setValue("");
                        notify.done("Variable saved", "Server pe likh diya gaya.");
                      },
                      onError: fail("Variable save"),
                    },
                  )
                }
              >
                Save
              </Button>
            </div>
          </div>
          <div className="mt-ax-3">
            <CardBody
              query={{
                data: variables.data,
                isPending: variables.isPending,
                error: variables.error ?? null,
                refetch: () => void variables.refetch(),
              }}
              endpoint="/api/ai/automation/variables"
              skeleton={<StatSkeleton rows={3} />}
            >
              {(data) =>
                data.variables.length === 0 ? (
                  <p className="ax-caption text-muted-foreground">Koi variable abhi nahi.</p>
                ) : (
                  <ul className="space-y-1.5">
                    {data.variables.map((v) => (
                      <li
                        key={v.id}
                        className="flex flex-wrap items-center gap-2 rounded-xl border border-border px-ax-3 py-ax-2"
                      >
                        <Variable className="size-3.5 text-steel" aria-hidden="true" />
                        <span className="font-mono text-[12px] text-foreground">{`{{${v.key}}}`}</span>
                        <span className="ax-caption min-w-0 flex-1 truncate text-muted-foreground">
                          {v.value}
                        </span>
                        <Chip>{v.kind}</Chip>
                        <Button
                          size="sm"
                          variant="secondary"
                          disabled={delVar.isPending}
                          onClick={() =>
                            delVar.mutate(
                              { id: v.id },
                              {
                                onSuccess: () => notify.done("Deleted", "Server se hat gaya."),
                                onError: fail("Delete"),
                              },
                            )
                          }
                        >
                          Delete
                        </Button>
                      </li>
                    ))}
                  </ul>
                )
              }
            </CardBody>
          </div>
        </section>

        {/* Suggestions */}
        <section className="mt-10">
          <SectionTitle
            title="LEO suggestions"
            hint="Tumhare asli patterns se banti hain — accept karo to workflow ban jata hai."
          />
          <CardBody
            query={{
              data: suggestions.data,
              isPending: suggestions.isPending,
              error: suggestions.error ?? null,
              refetch: () => void suggestions.refetch(),
            }}
            endpoint="/api/ai/automation/suggestions"
            skeleton={<StatSkeleton rows={3} />}
          >
            {(data) =>
              data.suggestions.length === 0 ? (
                <p className="ax-caption text-muted-foreground">
                  LEO ke paas abhi koi suggestion nahi.
                </p>
              ) : (
                <ul className="space-y-ax-2">
                  {data.suggestions.map((s) => (
                    <li key={s.id} className="ax-plane rounded-2xl p-ax-4">
                      <div className="flex flex-wrap items-center gap-2">
                        <Lightbulb className="size-4 text-steel" aria-hidden="true" />
                        <p className="min-w-0 flex-1 truncate text-[13px] font-semibold text-foreground">
                          {s.title}
                        </p>
                        <Chip>{s.kind}</Chip>
                        {s.confidence !== null && <Chip>{s.confidence}% sure</Chip>}
                        <Chip tone={s.state === "open" ? "warn" : s.state === "accepted" ? "good" : "quiet"}>
                          {s.state}
                        </Chip>
                      </div>
                      <p className="ax-caption mt-1 text-muted-foreground">{s.reason}</p>
                      {s.state === "open" && (
                        <div className="mt-ax-3 flex gap-2">
                          <Button
                            size="sm"
                            disabled={decide.isPending}
                            onClick={() =>
                              decide.mutate(
                                { id: s.id, decision: "accept" },
                                {
                                  onSuccess: () =>
                                    notify.done("Accepted", "Server ne workflow bana diya."),
                                  onError: fail("Accept"),
                                },
                              )
                            }
                          >
                            Accept
                          </Button>
                          <Button
                            size="sm"
                            variant="secondary"
                            disabled={decide.isPending}
                            onClick={() =>
                              decide.mutate(
                                { id: s.id, decision: "dismiss" },
                                {
                                  onSuccess: () => notify.done("Dismissed", "Dobara nahi poochega."),
                                  onError: fail("Dismiss"),
                                },
                              )
                            }
                          >
                            Dismiss
                          </Button>
                        </div>
                      )}
                    </li>
                  ))}
                </ul>
              )
            }
          </CardBody>
        </section>

        {/* Run history */}
        <section className="mt-10">
          <SectionTitle title="Automation run history" hint="Kya chala, kya rukka, kitna kharch hua." />
          <CardBody
            query={{
              data: runs.data,
              isPending: runs.isPending,
              error: runs.error ?? null,
              refetch: () => void runs.refetch(),
            }}
            endpoint="/api/ai/automation/runs"
            skeleton={<StatSkeleton rows={5} />}
          >
            {(data) =>
              data.runs.length === 0 ? (
                <p className="ax-caption text-muted-foreground">Abhi koi run nahi hua.</p>
              ) : (
                <ul className="space-y-1.5">
                  {data.runs.map((r) => (
                    <li
                      key={r.id}
                      className="flex flex-wrap items-center gap-2 rounded-xl border border-border px-ax-3 py-ax-2"
                    >
                      <span className="text-[13px] font-semibold text-foreground">
                        {r.workflow_name ?? "workflow"}
                      </span>
                      <Chip
                        tone={
                          r.state === "done"
                            ? "good"
                            : r.state === "failed"
                              ? "bad"
                              : r.state === "awaiting_approval"
                                ? "warn"
                                : "quiet"
                        }
                      >
                        {r.state.replace("_", " ")}
                      </Chip>
                      <span className="ax-caption min-w-0 flex-1 truncate text-muted-foreground">
                        {r.steps_done} steps{r.error ? ` · ${r.error}` : ""}
                      </span>
                      <Chip>
                        {r.currency === "GBP" ? "£" : `${r.currency} `}
                        {r.cost.toFixed(4)}
                      </Chip>
                      <span className="ax-caption text-muted-foreground">
                        {relativeTime(r.created_at)}
                      </span>
                    </li>
                  ))}
                </ul>
              )
            }
          </CardBody>
        </section>
      </div>
    </div>
  );
}