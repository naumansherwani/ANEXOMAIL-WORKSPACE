import { createFileRoute } from "@tanstack/react-router";
import { useMemo, useState } from "react";
import { Layers, Play, Sparkles, Wand2 } from "lucide-react";

import { Chip, GuardrailCard, ReceiptCard } from "@/components/app/ai/AiBits";
import { CardBody, StatSkeleton } from "@/components/app/dashboard/DashboardCard";
import { SectionTitle } from "@/components/app/crm/CrmBits";
import { Button } from "@/components/ui/button";
import { notify } from "@/lib/notify";
import { relativeTime } from "@/lib/mail";
import {
  STUDIO_TOOLS,
  TOOL_LABEL,
  useApplyStudioRun,
  useRunStudioBatch,
  useRunStudioRecipe,
  useRunStudioTool,
  useStudioRecipes,
  useStudioRuns,
  useStudioTargets,
  wordDiff,
  type StudioRun,
  type StudioToolKey,
} from "@/lib/ai-studio";

/**
 * Phase 17 — AI Studio, founder surface (aiemail.anexomail.com, IP locked).
 * Awam ke liye /ai/studio coming-soon gate hai.
 * NO MOCK: har output server se aata hai, receipt ke saath.
 */
export const Route = createFileRoute("/app/founder_/ai/studio")({
  head: () => ({
    meta: [
      { title: "AI Studio — ANEXOMAIL" },
      {
        name: "description",
        content:
          "Founder AI Studio: rewrite, grammar, translate, summarize, draft, tone, meeting and task extraction with before/after diff, batch mode and recipes.",
      },
      { property: "og:title", content: "AI Studio — ANEXOMAIL" },
      {
        property: "og:description",
        content: "Nine focused tools, before/after diff, batch mode, recipes — every run with a receipt.",
      },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: StudioPage,
});

function Diff({ before, after }: { before: string; after: string }) {
  const parts = useMemo(() => wordDiff(before, after), [before, after]);
  return (
    <p className="text-[13px] leading-relaxed whitespace-pre-wrap">
      {parts.map((p, i) => (
        <span
          key={i}
          className={
            p.kind === "added"
              ? "rounded bg-success/15 text-success"
              : p.kind === "removed"
                ? "rounded bg-danger/15 text-danger line-through"
                : "text-foreground"
          }
        >
          {p.text}
        </span>
      ))}
    </p>
  );
}

function StudioPage() {
  const [tool, setTool] = useState<StudioToolKey>("rewrite");
  const [option, setOption] = useState<string>("");
  const [input, setInput] = useState("");
  const [batch, setBatch] = useState(false);
  const [picked, setPicked] = useState<string[]>([]);
  const [run, setRun] = useState<StudioRun | null>(null);

  const runs = useStudioRuns("all");
  const recipes = useStudioRecipes();
  const targets = useStudioTargets();
  const runTool = useRunStudioTool();
  const runBatch = useRunStudioBatch();
  const runRecipe = useRunStudioRecipe();
  const apply = useApplyStudioRun();

  const spec = STUDIO_TOOLS.find((t) => t.key === tool)!;

  const doRun = () => {
    if (!input.trim()) {
      notify.failed("Kuch text do", { description: "Studio khaali input pe kabhi nahi chalta." });
      return;
    }
    runTool.mutate(
      {
        tool,
        input: input.trim(),
        ...(spec.option && option ? { options: { [spec.option.name]: option } } : {}),
      },
      {
        onSuccess: (d) => setRun(d.run),
        onError: (e) =>
          notify.failed(e.isNotImplemented ? "Studio abhi wired nahi" : "Run fail hua", {
            description: e.message,
          }),
      },
    );
  };

  const doBatch = () => {
    const all = targets.data?.targets ?? [];
    const chosen = all.filter((t) => picked.includes(t.ref));
    if (chosen.length === 0) {
      notify.failed("Koi target select nahi", { description: "Batch ke liye threads chuno." });
      return;
    }
    runBatch.mutate(
      {
        tool,
        targets: chosen,
        ...(spec.option && option ? { options: { [spec.option.name]: option } } : {}),
      },
      {
        onSuccess: (d) => notify.done("Batch chala", `${d.batch.total} targets server pe queued.`),
        onError: (e) =>
          notify.failed(e.isNotImplemented ? "Batch abhi wired nahi" : "Batch fail hua", {
            description: e.message,
          }),
      },
    );
  };

  return (
    <div className="min-h-0 flex-1 overflow-y-auto">
      <div className="mx-auto w-full max-w-6xl px-6 py-8 md:px-10">
        <p className="ax-eyebrow flex items-center gap-2">
          <Wand2 className="size-3.5" aria-hidden="true" /> Phase 17 · Studio · every run has a receipt
        </p>
        <h2 className="mt-2 text-2xl text-foreground">Nine tools, each finishes one job</h2>

        {/* Tool picker */}
        <div className="mt-ax-5 grid gap-2 sm:grid-cols-3">
          {STUDIO_TOOLS.map((t) => (
            <button
              key={t.key}
              type="button"
              onClick={() => {
                setTool(t.key);
                setOption("");
                setRun(null);
              }}
              data-on={t.key === tool ? "true" : "false"}
              className="ax-press ax-plane rounded-2xl p-ax-4 text-left data-[on=true]:border-primary/60 data-[on=true]:bg-primary/5"
            >
              <p className="text-[13px] font-semibold text-foreground">{t.label}</p>
              <p className="ax-caption mt-1 text-muted-foreground">{t.job}</p>
              {t.writesTo && (
                <p className="ax-caption mt-2 font-mono text-steel">writes → {t.writesTo}</p>
              )}
            </button>
          ))}
        </div>

        {/* Runner */}
        <section className="ax-plane mt-ax-5 rounded-2xl p-ax-5">
          <div className="flex flex-wrap items-center gap-2">
            <Chip>{spec.label}</Chip>
            {spec.option && (
              <select
                value={option}
                onChange={(e) => setOption(e.target.value)}
                aria-label={spec.option.name}
                className="rounded-xl border border-border bg-card px-2.5 py-1.5 text-[12px] text-foreground"
              >
                <option value="">{spec.option.name} · default</option>
                {spec.option.choices.map((c) => (
                  <option key={c} value={c}>
                    {c}
                  </option>
                ))}
              </select>
            )}
            <button
              type="button"
              onClick={() => setBatch((b) => !b)}
              data-on={batch ? "true" : "false"}
              className="ax-press rounded-xl border border-border px-3 py-1.5 text-[12px] font-semibold text-muted-foreground data-[on=true]:border-primary data-[on=true]:text-primary"
            >
              <Layers className="mr-1 inline size-3.5" aria-hidden="true" /> Batch mode
            </button>
          </div>

          <textarea
            value={input}
            onChange={(e) => setInput(e.target.value)}
            rows={6}
            placeholder="Paste the text, or open a thread and run the tool on it."
            className="mt-ax-4 w-full resize-y rounded-xl border border-border bg-card p-ax-3 text-[13px] text-foreground outline-none focus-visible:ring-2 focus-visible:ring-ring/50"
          />

          {batch && (
            <div className="mt-ax-4">
              <CardBody
                query={{
                  data: targets.data,
                  isPending: targets.isPending,
                  error: targets.error ?? null,
                  refetch: () => void targets.refetch(),
                }}
                endpoint="/api/ai/studio/targets"
                skeleton={<StatSkeleton rows={3} />}
              >
                {(data) =>
                  data.targets.length === 0 ? (
                    <p className="ax-caption text-muted-foreground">
                      Server ke paas abhi koi target nahi.
                    </p>
                  ) : (
                    <ul className="grid gap-1.5 sm:grid-cols-2">
                      {data.targets.map((t) => {
                        const on = picked.includes(t.ref);
                        return (
                          <li key={t.ref}>
                            <button
                              type="button"
                              onClick={() =>
                                setPicked((p) =>
                                  on ? p.filter((r) => r !== t.ref) : [...p, t.ref],
                                )
                              }
                              data-on={on ? "true" : "false"}
                              className="ax-press w-full rounded-xl border border-border px-ax-3 py-ax-2 text-left text-[12px] text-muted-foreground data-[on=true]:border-primary data-[on=true]:text-foreground"
                            >
                              {t.label}
                              <span className="ax-caption ml-2 text-steel">{t.kind}</span>
                            </button>
                          </li>
                        );
                      })}
                    </ul>
                  )
                }
              </CardBody>
            </div>
          )}

          <div className="mt-ax-4 flex flex-wrap gap-2">
            {batch ? (
              <Button disabled={runBatch.isPending} onClick={doBatch}>
                <Play className="size-3.5" aria-hidden="true" /> Run on {picked.length} targets
              </Button>
            ) : (
              <Button disabled={runTool.isPending} onClick={doRun}>
                <Play className="size-3.5" aria-hidden="true" />
                {runTool.isPending ? "Running…" : `Run ${spec.label}`}
              </Button>
            )}
            {run && spec.writesTo && (
              <Button
                variant="secondary"
                disabled={apply.isPending || run.applied}
                onClick={() =>
                  apply.mutate(
                    { id: run.id },
                    {
                      onSuccess: (d) =>
                        notify.done("Applied", `Server ne ${d.applied_to} mein likh diya.`),
                      onError: (e) =>
                        notify.failed(e.isNotImplemented ? "Apply abhi wired nahi" : "Apply fail", {
                          description: e.message,
                        }),
                    },
                  )
                }
              >
                {run.applied ? "Applied" : `Apply → ${spec.writesTo}`}
              </Button>
            )}
          </div>

          {run && (
            <div className="mt-ax-4 rounded-xl border border-border bg-secondary/30 p-ax-4">
              <p className="ax-caption text-muted-foreground">Before / after</p>
              <div className="mt-2">
                <Diff before={run.input} after={run.output} />
              </div>
              {run.receipt && <ReceiptCard receipt={run.receipt} />}
              {run.guardrail && <GuardrailCard event={run.guardrail} />}
            </div>
          )}
        </section>

        {/* Recipes */}
        <section className="mt-10">
          <SectionTitle
            title="Studio recipes"
            hint="Chained tools — summarize → tasks → draft — saved once, run again exactly the same."
          />
          <CardBody
            query={{
              data: recipes.data,
              isPending: recipes.isPending,
              error: recipes.error ?? null,
              refetch: () => void recipes.refetch(),
            }}
            endpoint="/api/ai/studio/recipes"
            skeleton={<StatSkeleton rows={3} />}
          >
            {(data) =>
              data.recipes.length === 0 ? (
                <p className="ax-caption text-muted-foreground">Koi recipe abhi save nahi hui.</p>
              ) : (
                <ul className="space-y-ax-2">
                  {data.recipes.map((r) => (
                    <li key={r.id} className="ax-plane rounded-2xl p-ax-4">
                      <div className="flex flex-wrap items-center gap-2">
                        <Sparkles className="size-4 text-steel" aria-hidden="true" />
                        <p className="min-w-0 flex-1 truncate text-[13px] font-semibold text-foreground">
                          {r.name}
                        </p>
                        {r.steps.map((s, i) => (
                          <Chip key={`${r.id}-${i}`}>{TOOL_LABEL[s.tool]}</Chip>
                        ))}
                        <Chip>{r.runs} runs</Chip>
                        <Button
                          size="sm"
                          variant="secondary"
                          disabled={runRecipe.isPending || !input.trim()}
                          onClick={() =>
                            runRecipe.mutate(
                              { recipe_id: r.id, input: input.trim() },
                              {
                                onSuccess: (d) => {
                                  setInput(d.output);
                                  notify.done("Recipe chali", "Output runner mein aa gaya.");
                                },
                                onError: (e) =>
                                  notify.failed(
                                    e.isNotImplemented ? "Recipes abhi wired nahi" : "Recipe fail",
                                    { description: e.message },
                                  ),
                              },
                            )
                          }
                        >
                          Run on input
                        </Button>
                      </div>
                      {r.description && (
                        <p className="ax-caption mt-1 text-muted-foreground">{r.description}</p>
                      )}
                    </li>
                  ))}
                </ul>
              )
            }
          </CardBody>
        </section>

        {/* History */}
        <section className="mt-10">
          <SectionTitle title="Run history" hint="Har run ka input, output, cost aur kahan apply hua." />
          <CardBody
            query={{
              data: runs.data,
              isPending: runs.isPending,
              error: runs.error ?? null,
              refetch: () => void runs.refetch(),
            }}
            endpoint="/api/ai/studio/runs"
            skeleton={<StatSkeleton rows={5} />}
          >
            {(data) =>
              data.runs.length === 0 ? (
                <p className="ax-caption text-muted-foreground">Abhi koi studio run nahi hua.</p>
              ) : (
                <ul className="space-y-1.5">
                  {data.runs.map((r) => (
                    <li
                      key={r.id}
                      className="flex flex-wrap items-center gap-2 rounded-xl border border-border px-ax-3 py-ax-2"
                    >
                      <Chip>{TOOL_LABEL[r.tool]}</Chip>
                      <span className="min-w-0 flex-1 truncate text-[12px] text-muted-foreground">
                        {r.output || r.input}
                      </span>
                      {r.applied && <Chip tone="good">applied → {r.applied_to}</Chip>}
                      {r.state === "failed" && <Chip tone="bad">failed</Chip>}
                      {r.receipt && (
                        <Chip>
                          {r.receipt.currency === "GBP" ? "£" : `${r.receipt.currency} `}
                          {r.receipt.cost.toFixed(4)}
                        </Chip>
                      )}
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