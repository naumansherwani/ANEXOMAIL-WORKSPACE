import { createFileRoute } from "@tanstack/react-router";
import { BookMarked, GitFork, Save } from "lucide-react";
import { useState } from "react";

import { Chip } from "@/components/app/ai/AiBits";
import { CardBody, StatSkeleton } from "@/components/app/dashboard/DashboardCard";
import { Button } from "@/components/ui/button";
import {
  useAiPrompts,
  useAiPromptVersions,
  useForkPrompt,
  useSavePromptVersion,
} from "@/lib/ai-workspace";
import { relativeTime } from "@/lib/mail";
import { notify } from "@/lib/notify";

export const Route = createFileRoute("/app/founder_/ai/prompts")({
  component: Prompts,
});

/** Prompt Library — version, fork, diff, variables. Sab server par saved. */
function Prompts() {
  const prompts = useAiPrompts();
  const [promptId, setPromptId] = useState<string | null>(null);
  const versions = useAiPromptVersions(promptId);
  const fork = useForkPrompt();
  const save = useSavePromptVersion();
  const [draft, setDraft] = useState("");
  const [compare, setCompare] = useState<string | null>(null);

  const list = versions.data?.versions ?? [];
  const latest = list[0];
  const other = list.find((v) => v.id === compare);

  return (
    <div className="min-h-0 flex-1 overflow-y-auto">
      <div className="mx-auto w-full max-w-5xl px-6 py-8 md:px-8">
        <p className="ax-eyebrow flex items-center gap-2">
          <BookMarked className="size-3.5" aria-hidden="true" /> Prompt library
        </p>
        <h2 className="ax-h2 mt-1 text-foreground">Every prompt has a history</h2>

        <div className="mt-ax-5 grid gap-ax-4 lg:grid-cols-[18rem_1fr]">
          <div className="ax-plane rounded-2xl p-ax-4">
            <CardBody
              query={{
                data: prompts.data,
                isPending: prompts.isPending,
                error: prompts.error ?? null,
                refetch: () => void prompts.refetch(),
              }}
              endpoint="/api/ai/prompts"
              skeleton={<StatSkeleton rows={5} />}
            >
              {(d) =>
                d.prompts.length === 0 ? (
                  <p className="ax-caption text-muted-foreground">No prompts saved yet.</p>
                ) : (
                  <ul className="space-y-1">
                    {d.prompts.map((p) => (
                      <li key={p.id}>
                        <button
                          type="button"
                          onClick={() => {
                            setPromptId(p.id);
                            setCompare(null);
                            setDraft("");
                          }}
                          data-on={p.id === promptId ? "true" : "false"}
                          className="ax-press w-full rounded-xl border border-transparent px-3 py-2 text-left hover:bg-secondary/60 data-[on=true]:border-border data-[on=true]:bg-secondary"
                        >
                          <span className="block truncate text-[13px] font-semibold text-foreground">
                            {p.name}
                          </span>
                          <span className="ax-caption block text-muted-foreground">
                            v{p.latest_version}
                            {p.forked_from ? " · fork" : ""}
                            {p.updated_at ? ` · ${relativeTime(p.updated_at)}` : ""}
                          </span>
                        </button>
                      </li>
                    ))}
                  </ul>
                )
              }
            </CardBody>
          </div>

          <div className="ax-plane rounded-2xl p-ax-5">
            {!promptId ? (
              <p className="ax-caption text-muted-foreground">Pick a prompt to see its versions.</p>
            ) : (
              <CardBody
                query={{
                  data: versions.data,
                  isPending: versions.isPending,
                  error: versions.error ?? null,
                  refetch: () => void versions.refetch(),
                }}
                endpoint="/api/ai/prompts/:id/versions"
                skeleton={<StatSkeleton rows={6} />}
              >
                {(d) => (
                  <>
                    <div className="flex flex-wrap items-center gap-2">
                      <Chip>{d.versions.length} versions</Chip>
                      {latest?.variables.map((v) => (
                        <Chip key={v}>{`{{${v}}}`}</Chip>
                      ))}
                      <div className="ml-auto flex gap-2">
                        <Button
                          size="sm"
                          variant="secondary"
                          disabled={fork.isPending}
                          onClick={() =>
                            fork.mutate(
                              { prompt_id: promptId, name: "Fork" },
                              {
                                onSuccess: (r) => {
                                  setPromptId(r.prompt.id);
                                  notify.done("Forked", "New prompt starts from this version.");
                                },
                                onError: (e) =>
                                  notify.failed(
                                    e.isNotImplemented ? "Fork not wired yet" : "Fork failed",
                                    { description: e.message },
                                  ),
                              },
                            )
                          }
                        >
                          <GitFork className="size-3.5" aria-hidden="true" /> Fork
                        </Button>
                      </div>
                    </div>

                    <textarea
                      value={draft || latest?.body || ""}
                      onChange={(e) => setDraft(e.target.value)}
                      rows={10}
                      className="ax-focus mt-ax-4 w-full resize-y rounded-xl border border-border bg-card px-3 py-2 font-mono text-[12px] text-foreground"
                    />
                    <Button
                      className="mt-ax-3"
                      disabled={!draft.trim() || save.isPending}
                      onClick={() =>
                        save.mutate(
                          { prompt_id: promptId, body: draft },
                          {
                            onSuccess: () => {
                              setDraft("");
                              notify.done("Version saved", "Old versions stay untouched.");
                            },
                            onError: (e) =>
                              notify.failed(
                                e.isNotImplemented ? "Versions not wired yet" : "Save failed",
                                { description: e.message },
                              ),
                          },
                        )
                      }
                    >
                      <Save className="size-3.5" aria-hidden="true" /> Save as new version
                    </Button>

                    <div className="mt-ax-5">
                      <p className="ax-caption text-muted-foreground">Diff against</p>
                      <select
                        value={compare ?? ""}
                        onChange={(e) => setCompare(e.target.value || null)}
                        className="ax-focus mt-1 rounded-xl border border-border bg-card px-3 py-2 text-sm text-foreground"
                      >
                        <option value="">select a version</option>
                        {d.versions.map((v) => (
                          <option key={v.id} value={v.id}>
                            v{v.version}
                            {v.note ? ` · ${v.note}` : ""}
                          </option>
                        ))}
                      </select>
                      {other && latest && (
                        <div className="mt-ax-3 grid gap-2 md:grid-cols-2">
                          <pre className="overflow-x-auto rounded-xl border border-border p-ax-3 text-[11px] whitespace-pre-wrap text-muted-foreground">
                            v{other.version}
                            {"\n\n"}
                            {other.body}
                          </pre>
                          <pre className="overflow-x-auto rounded-xl border border-primary/40 p-ax-3 text-[11px] whitespace-pre-wrap text-foreground">
                            v{latest.version} (latest)
                            {"\n\n"}
                            {latest.body}
                          </pre>
                        </div>
                      )}
                    </div>
                  </>
                )}
              </CardBody>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}