import { createFileRoute } from "@tanstack/react-router";
import { BookOpen, Pin, Quote, Search, Trash2 } from "lucide-react";
import { useState } from "react";

import { CardBody, StatSkeleton } from "@/components/app/dashboard/DashboardCard";
import {
  useAddDocument,
  useAskKnowledge,
  useDeleteDocument,
  useKnowledgeDocs,
  useKnowledgeSearch,
  useKnowledgeSpaces,
  usePinDocument,
  type KnowledgeScope,
} from "@/lib/knowledge";
import { relativeTime } from "@/lib/mail";
import { notify } from "@/lib/notify";

export const Route = createFileRoute("/app/founder_/ai/knowledge")({
  component: FounderKnowledge,
});

/**
 * Phase 20 — AI Knowledge Workspace, founder surface.
 * Three columns: spaces | documents | grounded ask.
 * CITATION RULE: answer sirf sources ke saath. Server refuse kar de to refusal
 * dikhti hai — kabhi banaya hua jawab nahi.
 */
function FounderKnowledge() {
  const [spaceId, setSpaceId] = useState<string | null>(null);
  const [query, setQuery] = useState("");
  const [question, setQuestion] = useState("");
  const [scope, setScope] = useState<KnowledgeScope>("business");
  const [title, setTitle] = useState("");
  const [body, setBody] = useState("");

  const spaces = useKnowledgeSpaces();
  const docs = useKnowledgeDocs(spaceId);
  const search = useKnowledgeSearch(query);
  const ask = useAskKnowledge();
  const add = useAddDocument();
  const remove = useDeleteDocument();
  const pin = usePinDocument();

  const notWired = (endpoint: string) => (err: { isNotImplemented: boolean; message: string }) =>
    notify.failed(err.isNotImplemented ? "Not wired yet" : "Failed", {
      description: err.isNotImplemented ? `${endpoint} is pending on the server.` : err.message,
    });

  return (
    <div className="min-h-0 flex-1 overflow-y-auto">
      <div className="mx-auto w-full max-w-6xl px-6 py-8 md:px-8">
        <p className="ax-eyebrow flex items-center gap-2">
          <BookOpen className="size-3.5" aria-hidden="true" /> Knowledge
        </p>
        <h2 className="ax-h2 mt-1 text-foreground">Your knowledge, always cited</h2>

        <div className="mt-ax-5 grid gap-ax-4 lg:grid-cols-[220px_1fr_1fr]">
          {/* spaces */}
          <aside>
            <h3 className="ax-label text-foreground">Spaces</h3>
            <div className="mt-ax-3">
              <CardBody
                query={{
                  data: spaces.data,
                  isPending: spaces.isPending,
                  error: spaces.error ?? null,
                  refetch: () => void spaces.refetch(),
                }}
                endpoint="/api/knowledge/spaces"
                skeleton={<StatSkeleton rows={3} />}
              >
                {(d) =>
                  d.spaces.length === 0 ? (
                    <p className="ax-caption text-muted-foreground">No spaces yet.</p>
                  ) : (
                    <ul className="space-y-1">
                      {d.spaces.map((s) => (
                        <li key={s.id}>
                          <button
                            type="button"
                            onClick={() => setSpaceId(s.id)}
                            data-on={spaceId === s.id ? "true" : "false"}
                            className="ax-press w-full rounded-xl border border-border px-3 py-2 text-left text-[12px] text-muted-foreground data-[on=true]:border-primary data-[on=true]:text-foreground"
                          >
                            <span className="font-semibold">{s.name}</span>
                            <span className="ax-caption block text-steel">
                              {s.scope} · {s.documents} docs · {s.chunks} chunks
                            </span>
                          </button>
                        </li>
                      ))}
                    </ul>
                  )
                }
              </CardBody>
            </div>

            <form
              className="ax-plane mt-ax-4 flex flex-col gap-2 rounded-2xl p-ax-3"
              onSubmit={(e) => {
                e.preventDefault();
                if (!title.trim() || !body.trim()) return;
                add.mutate(
                  { ...(spaceId ? { space_id: spaceId } : { scope }), title, body },
                  {
                    onSuccess: () => {
                      setTitle("");
                      setBody("");
                      notify.done("Added", "Server chunked and indexed it.");
                    },
                    onError: notWired("POST /api/knowledge/documents"),
                  },
                );
              }}
            >
              <p className="ax-label text-foreground">Add knowledge</p>
              <select
                aria-label="Scope"
                value={scope}
                onChange={(e) => setScope(e.target.value as KnowledgeScope)}
                className="h-8 rounded-lg border border-border bg-card px-2 text-[11px] text-foreground"
              >
                <option value="business">Business</option>
                <option value="personal">Personal</option>
              </select>
              <input
                aria-label="Title"
                value={title}
                onChange={(e) => setTitle(e.target.value)}
                placeholder="Title"
                className="h-8 rounded-lg border border-border bg-card px-2 text-[11px] text-foreground"
              />
              <textarea
                aria-label="Body"
                value={body}
                onChange={(e) => setBody(e.target.value)}
                rows={4}
                placeholder="Paste the real thing — no summaries."
                className="rounded-lg border border-border bg-card px-2 py-1.5 text-[11px] text-foreground"
              />
              <button
                type="submit"
                disabled={add.isPending}
                className="ax-press rounded-xl bg-primary px-3 py-2 text-[11px] font-semibold text-primary-foreground disabled:opacity-50"
              >
                Index it
              </button>
            </form>
          </aside>

          {/* documents + search */}
          <section>
            <div className="flex items-center gap-2">
              <Search className="size-4 text-steel" aria-hidden="true" />
              <input
                aria-label="Search knowledge"
                value={query}
                onChange={(e) => setQuery(e.target.value)}
                placeholder="Search documents and threads"
                className="h-9 w-full rounded-xl border border-border bg-card px-3 text-[12px] text-foreground"
              />
            </div>

            {query.trim().length > 1 ? (
              <div className="mt-ax-4">
                <CardBody
                  query={{
                    data: search.data,
                    isPending: search.isPending,
                    error: search.error ?? null,
                    refetch: () => void search.refetch(),
                  }}
                  endpoint="/api/knowledge/search"
                  skeleton={<StatSkeleton rows={4} />}
                >
                  {(d) =>
                    d.hits.length === 0 ? (
                      <p className="ax-caption text-muted-foreground">Nothing matched.</p>
                    ) : (
                      <ul className="space-y-ax-2">
                        {d.hits.map((h) => (
                          <li key={h.chunk_id} className="ax-plane rounded-xl p-ax-3">
                            <p className="text-[12px] font-semibold text-foreground">{h.doc_title}</p>
                            <p className="ax-caption mt-1 text-muted-foreground">{h.excerpt}</p>
                            <p className="ax-caption mt-1 text-steel">
                              {h.scope} · score {h.score.toFixed(2)}
                            </p>
                          </li>
                        ))}
                      </ul>
                    )
                  }
                </CardBody>
              </div>
            ) : (
              <div className="mt-ax-4">
                <CardBody
                  query={{
                    data: docs.data,
                    isPending: docs.isPending,
                    error: docs.error ?? null,
                    refetch: () => void docs.refetch(),
                  }}
                  endpoint="/api/knowledge/documents"
                  skeleton={<StatSkeleton rows={5} />}
                >
                  {(d) =>
                    d.documents.length === 0 ? (
                      <p className="ax-caption text-muted-foreground">This space is empty.</p>
                    ) : (
                      <ul className="space-y-ax-2">
                        {d.documents.map((doc) => (
                          <li key={doc.id} className="ax-plane rounded-xl p-ax-3">
                            <div className="flex items-start gap-2">
                              <div className="min-w-0">
                                <p className="truncate text-[12px] font-semibold text-foreground">
                                  {doc.title}
                                </p>
                                <p className="ax-caption text-steel">
                                  {doc.kind} · {doc.chunks} chunks · {doc.words} words ·{" "}
                                  {relativeTime(doc.updated_at ?? doc.created_at)}
                                </p>
                              </div>
                              <div className="ml-auto flex shrink-0 gap-1">
                                <button
                                  type="button"
                                  aria-label={doc.pinned ? "Unpin" : "Pin"}
                                  onClick={() =>
                                    pin.mutate(
                                      { id: doc.id, pinned: !doc.pinned },
                                      { onError: notWired("POST /api/knowledge/documents/:id/pin") },
                                    )
                                  }
                                  data-on={doc.pinned ? "true" : "false"}
                                  className="ax-press rounded-lg border border-border p-1.5 text-steel data-[on=true]:border-primary data-[on=true]:text-primary"
                                >
                                  <Pin className="size-3.5" />
                                </button>
                                <button
                                  type="button"
                                  aria-label="Delete document"
                                  onClick={() =>
                                    remove.mutate(
                                      { id: doc.id },
                                      {
                                        onSuccess: () =>
                                          notify.done("Deleted", "Real delete — chunks gone too."),
                                        onError: notWired("DELETE /api/knowledge/documents/:id"),
                                      },
                                    )
                                  }
                                  className="ax-press rounded-lg border border-border p-1.5 text-steel hover:text-foreground"
                                >
                                  <Trash2 className="size-3.5" />
                                </button>
                              </div>
                            </div>
                          </li>
                        ))}
                      </ul>
                    )
                  }
                </CardBody>
              </div>
            )}
          </section>

          {/* grounded ask */}
          <section>
            <h3 className="ax-label flex items-center gap-2 text-foreground">
              <Quote className="size-3.5" aria-hidden="true" /> Ask with citations
            </h3>
            <form
              className="mt-ax-3 flex flex-col gap-2"
              onSubmit={(e) => {
                e.preventDefault();
                if (!question.trim()) return;
                ask.mutate(
                  { question, scope },
                  { onError: notWired("POST /api/knowledge/ask") },
                );
              }}
            >
              <textarea
                aria-label="Question"
                value={question}
                onChange={(e) => setQuestion(e.target.value)}
                rows={3}
                placeholder="Ask only what your own knowledge can answer."
                className="rounded-xl border border-border bg-card px-3 py-2 text-[12px] text-foreground"
              />
              <button
                type="submit"
                disabled={ask.isPending}
                className="ax-press self-start rounded-xl bg-primary px-3 py-2 text-[12px] font-semibold text-primary-foreground disabled:opacity-50"
              >
                {ask.isPending ? "Thinking…" : "Ask"}
              </button>
            </form>

            {ask.data && (
              <article className="ax-plane mt-ax-4 rounded-2xl p-ax-4">
                {ask.data.refused ? (
                  <p className="text-[12px] text-foreground">
                    Refused: {ask.data.refusal_reason ?? "no source covered this question."}
                  </p>
                ) : (
                  <p className="text-[13px] leading-relaxed whitespace-pre-wrap text-foreground">
                    {ask.data.answer}
                  </p>
                )}
                <ul className="mt-ax-3 space-y-1.5">
                  {ask.data.citations.map((c) => (
                    <li key={c.chunk_id} className="rounded-lg border border-border px-2 py-1.5">
                      <p className="text-[11px] font-semibold text-foreground">{c.doc_title}</p>
                      <p className="ax-caption text-muted-foreground">“{c.quote}”</p>
                    </li>
                  ))}
                </ul>
                <p className="ax-caption mt-ax-3 text-steel">
                  {ask.data.model ?? "—"} · {ask.data.currency} {ask.data.cost.toFixed(4)} ·{" "}
                  {ask.data.latency_ms ?? "?"}ms
                </p>
              </article>
            )}
          </section>
        </div>
      </div>
    </div>
  );
}
