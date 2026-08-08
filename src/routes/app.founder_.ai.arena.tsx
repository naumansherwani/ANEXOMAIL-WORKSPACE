import { createFileRoute } from "@tanstack/react-router";
import { Swords } from "lucide-react";
import { useState } from "react";

import { Chip } from "@/components/app/ai/AiBits";
import { CardBody, StatSkeleton } from "@/components/app/dashboard/DashboardCard";
import { Button } from "@/components/ui/button";
import {
  AGENT_LABEL,
  ARENA_DEFAULT,
  useAiArenaRuns,
  useRunArena,
  type AiAgentKey,
} from "@/lib/ai-workspace";
import { relativeTime } from "@/lib/mail";
import { notify } from "@/lib/notify";

export const Route = createFileRoute("/app/founder_/ai/arena")({
  component: Arena,
});

const CHOICES: AiAgentKey[] = ["leo", "jimmy", "sherlock"];

/** Multi-agent Arena — 3 slots, Jimmy+Sherlock+Leo default, founder change kar sakta hai. */
function Arena() {
  const runs = useAiArenaRuns();
  const run = useRunArena();
  const [question, setQuestion] = useState("");
  const [slots, setSlots] = useState<string[]>([...ARENA_DEFAULT]);

  const setSlot = (i: number, value: string) =>
    setSlots((prev) => prev.map((s, idx) => (idx === i ? value : s)));

  return (
    <div className="min-h-0 flex-1 overflow-y-auto">
      <div className="mx-auto w-full max-w-5xl px-6 py-8 md:px-8">
        <p className="ax-eyebrow flex items-center gap-2">
          <Swords className="size-3.5" aria-hidden="true" /> Arena
        </p>
        <h2 className="ax-h2 mt-1 text-foreground">Same question, three agents</h2>
        <p className="ax-caption mt-1 text-muted-foreground">
          Sherlock scores every answer. Cost and latency are real, never estimated.
        </p>

        <div className="ax-plane mt-ax-5 rounded-2xl p-ax-5">
          <div className="grid gap-2 sm:grid-cols-3">
            {slots.map((slot, i) => (
              <label key={i} className="block">
                <span className="ax-caption text-muted-foreground">Slot {i + 1}</span>
                <select
                  value={slot}
                  onChange={(e) => setSlot(i, e.target.value)}
                  className="ax-focus mt-1 w-full rounded-xl border border-border bg-card px-3 py-2 text-sm text-foreground"
                >
                  {CHOICES.map((c) => (
                    <option key={c} value={c}>
                      {AGENT_LABEL[c]}
                    </option>
                  ))}
                </select>
              </label>
            ))}
          </div>
          <textarea
            value={question}
            onChange={(e) => setQuestion(e.target.value)}
            rows={3}
            placeholder="Ask one question. All three answer it."
            className="ax-focus mt-ax-4 w-full resize-y rounded-xl border border-border bg-card px-3 py-2 text-sm text-foreground"
          />
          <Button
            className="mt-ax-3"
            disabled={!question.trim() || run.isPending}
            onClick={() =>
              run.mutate(
                { question: question.trim(), agents: slots },
                {
                  onSuccess: () => notify.done("Arena run finished", "Sherlock scored every answer."),
                  onError: (e) =>
                    notify.failed(e.isNotImplemented ? "Arena not wired yet" : "Run failed", {
                      description: e.message,
                    }),
                },
              )
            }
          >
            {run.isPending ? "Running…" : "Run arena"}
          </Button>
        </div>

        <section className="mt-ax-7">
          <h3 className="ax-heading text-foreground">Past runs</h3>
          <div className="mt-ax-4">
            <CardBody
              query={{
                data: runs.data,
                isPending: runs.isPending,
                error: runs.error ?? null,
                refetch: () => void runs.refetch(),
              }}
              endpoint="/api/ai/arena"
              skeleton={<StatSkeleton rows={5} />}
            >
              {(d) =>
                d.runs.length === 0 ? (
                  <p className="ax-caption text-muted-foreground">No runs yet.</p>
                ) : (
                  <ul className="space-y-ax-4">
                    {d.runs.map((r) => (
                      <li key={r.id} className="ax-plane rounded-2xl p-ax-4">
                        <div className="flex flex-wrap items-center gap-2">
                          <p className="min-w-0 flex-1 text-[13px] font-semibold text-foreground">
                            {r.question}
                          </p>
                          <span className="ax-caption text-muted-foreground">
                            {relativeTime(r.created_at)}
                          </span>
                          {r.winner && <Chip tone="good">winner {r.winner}</Chip>}
                        </div>
                        <div className="mt-ax-3 grid gap-2 sm:grid-cols-3">
                          {r.entries.map((e, i) => (
                            <div key={`${e.agent}-${i}`} className="rounded-xl border border-border p-ax-3">
                              <div className="flex flex-wrap items-center gap-1.5">
                                <Chip>{e.agent}</Chip>
                                {e.sherlock_score !== null && (
                                  <Chip tone={e.sherlock_score >= 80 ? "good" : e.sherlock_score >= 50 ? "warn" : "bad"}>
                                    {e.sherlock_score}
                                  </Chip>
                                )}
                              </div>
                              <p className="ax-caption mt-1 text-muted-foreground">
                                {e.model} · {e.latency_ms ?? "?"}ms · {e.cost.toFixed(4)}
                              </p>
                              <p className="mt-2 whitespace-pre-wrap text-[12px] leading-relaxed text-foreground">
                                {e.answer}
                              </p>
                            </div>
                          ))}
                        </div>
                      </li>
                    ))}
                  </ul>
                )
              }
            </CardBody>
          </div>
        </section>
      </div>
    </div>
  );
}