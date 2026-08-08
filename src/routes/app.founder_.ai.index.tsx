import { createFileRoute } from "@tanstack/react-router";
import { GitBranch, Plus, Send, Sparkles, Square } from "lucide-react";
import { useEffect, useRef, useState } from "react";

import {
  Chip,
  CreditsMeter,
  ExportButtons,
  GuardrailCard,
  ReceiptCard,
  TtftBadge,
} from "@/components/app/ai/AiBits";
import { CardBody, StatSkeleton } from "@/components/app/dashboard/DashboardCard";
import { Button } from "@/components/ui/button";
import {
  downloadFile,
  exportSession,
  streamAiChat,
  useAiCredits,
  useAiSession,
  useAiSessions,
  useCreateAiSession,
  type AiAgentKey,
  type AiGuardrailEvent,
  type AiTurn,
} from "@/lib/ai-workspace";
import { notify } from "@/lib/notify";
import { relativeTime } from "@/lib/mail";

export const Route = createFileRoute("/app/founder_/ai/")({
  component: Workbench,
});

/** LEO Workbench — 3 panel: sessions | chat | sources. LEO primary, hamesha. */
function Workbench() {
  const sessions = useAiSessions();
  const create = useCreateAiSession();
  const credits = useAiCredits();
  const [sessionId, setSessionId] = useState<string | null>(null);
  const session = useAiSession(sessionId);

  const [input, setInput] = useState("");
  const [streaming, setStreaming] = useState(false);
  const [live, setLive] = useState("");
  const [ttft, setTtft] = useState<number | null>(null);
  const [activeAgent, setActiveAgent] = useState<AiAgentKey | null>(null);
  const [guardrail, setGuardrail] = useState<AiGuardrailEvent | null>(null);
  const [branchFrom, setBranchFrom] = useState<string | null>(null);
  const abort = useRef<AbortController | null>(null);
  const box = useRef<HTMLTextAreaElement | null>(null);

  useEffect(() => {
    const first = sessions.data?.sessions[0];
    if (!sessionId && first) setSessionId(first.id);
  }, [sessions.data, sessionId]);

  useEffect(() => {
    box.current?.focus();
  }, [sessionId, streaming]);

  const turns: AiTurn[] = session.data?.turns ?? [];
  const sources = turns.flatMap((t) => t.receipt?.sources ?? []);

  const send = async () => {
    const text = input.trim();
    if (!text || !sessionId || streaming) return;
    setInput("");
    setLive("");
    setTtft(null);
    setGuardrail(null);
    setActiveAgent("leo");
    setStreaming(true);
    const controller = new AbortController();
    abort.current = controller;
    try {
      await streamAiChat(
        {
          session_id: sessionId,
          message: text,
          parent_turn_id: branchFrom,
        },
        (event) => {
          if (event.type === "delta") setLive((prev) => prev + event.text);
          else if (event.type === "ttft") setTtft(event.ms);
          else if (event.type === "escalation") setActiveAgent(event.agent);
          else if (event.type === "guardrail") setGuardrail(event.event);
          else if (event.type === "error") notify.failed("LEO could not answer", { description: event.message });
        },
        controller.signal,
      );
      setBranchFrom(null);
      await session.refetch();
      await credits.refetch();
      setLive("");
    } catch (error) {
      notify.failed("Chat not available", {
        description: error instanceof Error ? error.message : "Server did not answer.",
      });
    } finally {
      setStreaming(false);
      abort.current = null;
    }
  };

  return (
    <div className="flex min-h-0 flex-1 flex-col lg:flex-row">
      {/* Panel 1 — sessions */}
      <aside className="flex w-full shrink-0 flex-col border-b border-border lg:w-[16rem] lg:border-r lg:border-b-0">
        <div className="flex items-center gap-2 px-4 py-3">
          <p className="ax-caption flex-1 font-semibold text-foreground">Sessions</p>
          <Button
            size="sm"
            variant="secondary"
            disabled={create.isPending}
            onClick={() =>
              create.mutate(
                { title: "New session" },
                {
                  onSuccess: (d) => setSessionId(d.session.id),
                  onError: (e) =>
                    notify.failed(
                      e.isNotImplemented ? "Sessions not wired yet" : "Could not create session",
                      { description: e.message },
                    ),
                },
              )
            }
          >
            <Plus className="size-3.5" aria-hidden="true" /> New
          </Button>
        </div>
        <div className="min-h-0 flex-1 overflow-y-auto px-3 pb-4">
          <CardBody
            query={{
              data: sessions.data,
              isPending: sessions.isPending,
              error: sessions.error ?? null,
              refetch: () => void sessions.refetch(),
            }}
            endpoint="/api/ai/sessions"
            skeleton={<StatSkeleton rows={5} />}
          >
            {(d) =>
              d.sessions.length === 0 ? (
                <p className="ax-caption text-muted-foreground">No sessions yet.</p>
              ) : (
                <ul className="space-y-1">
                  {d.sessions.map((s) => (
                    <li key={s.id}>
                      <button
                        type="button"
                        onClick={() => setSessionId(s.id)}
                        data-on={s.id === sessionId ? "true" : "false"}
                        className="ax-press w-full rounded-xl border border-transparent px-3 py-2 text-left hover:bg-secondary/60 data-[on=true]:border-border data-[on=true]:bg-secondary"
                      >
                        <span className="block truncate text-[13px] font-semibold text-foreground">
                          {s.title}
                        </span>
                        <span className="ax-caption block truncate text-muted-foreground">
                          {s.turns} turns · {s.currency === "GBP" ? "£" : `${s.currency} `}
                          {s.cost.toFixed(4)}
                          {s.updated_at ? ` · ${relativeTime(s.updated_at)}` : ""}
                        </span>
                      </button>
                    </li>
                  ))}
                </ul>
              )
            }
          </CardBody>
        </div>
      </aside>

      {/* Panel 2 — chat */}
      <section className="flex min-h-0 min-w-0 flex-1 flex-col">
        <div className="min-h-0 flex-1 overflow-y-auto px-6 py-5">
          {!sessionId ? (
            <p className="ax-caption text-muted-foreground">
              Pick a session on the left, or start a new one.
            </p>
          ) : (
            <CardBody
              query={{
                data: session.data,
                isPending: session.isPending,
                error: session.error ?? null,
                refetch: () => void session.refetch(),
              }}
              endpoint="/api/ai/sessions/:id"
              skeleton={<StatSkeleton rows={6} />}
            >
              {(d) => (
                <>
                  <div className="flex flex-wrap items-center gap-2">
                    <Chip>{d.session.model}</Chip>
                    <Chip>LEO primary</Chip>
                    <TtftBadge ms={ttft} />
                    {activeAgent && activeAgent !== "leo" && (
                      <Chip tone="warn">escalated · {activeAgent}</Chip>
                    )}
                    <div className="ml-auto">
                      <ExportButtons
                        onExport={(f) => downloadFile(exportSession(d.session, d.turns, f))}
                      />
                    </div>
                  </div>

                  <ul className="mt-ax-5 space-y-ax-4">
                    {d.turns.map((t) => (
                      <li key={t.id} className="ax-plane rounded-2xl p-ax-4">
                        <div className="flex items-center gap-2">
                          <Chip tone={t.role === "user" ? "quiet" : "good"}>
                            {t.role === "user" ? "You" : (t.agent ?? "leo").toUpperCase()}
                          </Chip>
                          <span className="ax-caption text-muted-foreground">
                            {relativeTime(t.created_at)}
                          </span>
                          <button
                            type="button"
                            onClick={() => setBranchFrom(t.id)}
                            data-on={branchFrom === t.id ? "true" : "false"}
                            className="ax-press ml-auto rounded-lg border border-border px-2 py-1 text-[11px] font-semibold text-muted-foreground data-[on=true]:border-primary data-[on=true]:text-primary"
                          >
                            <GitBranch className="mr-1 inline size-3" aria-hidden="true" />
                            {branchFrom === t.id ? "Branching here" : "Branch / rewind"}
                          </button>
                        </div>
                        <p className="mt-ax-3 whitespace-pre-wrap text-[13px] leading-relaxed text-foreground">
                          {t.content}
                        </p>
                        {t.guardrail && <GuardrailCard event={t.guardrail} />}
                        {t.receipt && <ReceiptCard receipt={t.receipt} />}
                      </li>
                    ))}
                  </ul>

                  {(streaming || live) && (
                    <div className="ax-plane mt-ax-4 rounded-2xl p-ax-4">
                      <div className="flex items-center gap-2">
                        <Chip tone="good">LEO</Chip>
                        <TtftBadge ms={ttft} />
                        {streaming && <span className="ax-caption text-muted-foreground">typing…</span>}
                      </div>
                      <p className="mt-ax-3 whitespace-pre-wrap text-[13px] leading-relaxed text-foreground">
                        {live}
                      </p>
                      {guardrail && <GuardrailCard event={guardrail} />}
                    </div>
                  )}
                </>
              )}
            </CardBody>
          )}
        </div>

        {/* Composer — inline, context kabhi nahi tootta */}
        <div className="shrink-0 border-t border-border px-6 py-4">
          {branchFrom && (
            <p className="ax-caption mb-2 text-muted-foreground">
              Branching from an earlier turn.{" "}
              <button type="button" className="underline" onClick={() => setBranchFrom(null)}>
                cancel
              </button>
            </p>
          )}
          <div className="flex items-end gap-2">
            <textarea
              ref={box}
              value={input}
              onChange={(e) => setInput(e.target.value)}
              onKeyDown={(e) => {
                if (e.key === "Enter" && !e.shiftKey) {
                  e.preventDefault();
                  void send();
                }
              }}
              rows={2}
              placeholder="Ask LEO. Escalation to Jimmy happens only when LEO needs it."
              className="ax-focus min-h-[3rem] flex-1 resize-y rounded-xl border border-border bg-card px-3 py-2 text-sm text-foreground"
            />
            {streaming ? (
              <Button variant="secondary" onClick={() => abort.current?.abort()}>
                <Square className="size-3.5" aria-hidden="true" /> Stop
              </Button>
            ) : (
              <Button disabled={!input.trim() || !sessionId} onClick={() => void send()}>
                <Send className="size-3.5" aria-hidden="true" /> Send
              </Button>
            )}
          </div>
        </div>
      </section>

      {/* Panel 3 — sources + burn */}
      <aside className="w-full shrink-0 space-y-ax-3 border-t border-border p-4 lg:w-[18rem] lg:border-t-0 lg:border-l">
        <CardBody
          query={{
            data: credits.data,
            isPending: credits.isPending,
            error: credits.error ?? null,
            refetch: () => void credits.refetch(),
          }}
          endpoint="/api/ai/credits"
          skeleton={<StatSkeleton rows={3} />}
        >
          {(c) => <CreditsMeter credits={c} estimateTokens={Math.ceil(input.length / 4) + 600} />}
        </CardBody>

        <div className="ax-plane rounded-2xl p-ax-4">
          <p className="ax-caption flex items-center gap-1.5 text-muted-foreground">
            <Sparkles className="size-3.5" aria-hidden="true" /> Sources in this session
          </p>
          {sources.length === 0 ? (
            <p className="ax-caption mt-2 text-muted-foreground">
              No sources yet — every grounded answer lists what it used.
            </p>
          ) : (
            <ul className="mt-2 space-y-1.5">
              {sources.map((s, i) => (
                <li key={`${s.ref}-${i}`} className="ax-caption text-muted-foreground">
                  <span className="font-semibold text-foreground">{s.title}</span>
                  <span className="block font-mono text-[10px]">{s.ref}</span>
                </li>
              ))}
            </ul>
          )}
        </div>
      </aside>
    </div>
  );
}