import { Link } from "@tanstack/react-router";
import { ArrowRight, ChevronDown, Mail, SlidersHorizontal } from "lucide-react";
import { useRef, useState } from "react";

import { Chip } from "@/components/app/crm/CrmBits";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { money, probabilityPercent, useAttachDealThread, useDealToWork } from "@/lib/crm";
import { useCrmBoard, useMoveDealStage, useSetCustom, useSetDealPipeline, type Board, type BoardDeal, type FieldDef } from "@/lib/crm-setup";
import { useLocale } from "@/lib/i18n";
import { notify } from "@/lib/notify";

/**
 * The pipeline board driven by the server: stages come from the selected pipeline (any number of pipelines, each with its own stages),
 * a deal can only move to a stage of its own pipeline (checked server-side), and custom fields are edited on the card.
 */
export function PipelineBoard({ pipelineId, onPipeline, onNewDeal }: { pipelineId: string | undefined; onPipeline: (id: string) => void; onNewDeal: () => void }) {
  const board = useCrmBoard(pipelineId);
  if (board.error) throw board.error; // parent decides: fall back to the classic board when the server lacks CRM setup
  if (!board.data) return <p className="ax-caption text-muted-foreground" aria-busy="true">Loading…</p>;
  return <BoardView data={board.data} onPipeline={onPipeline} onNewDeal={onNewDeal} />;
}

function BoardView({ data, onPipeline, onNewDeal }: { data: Board; onPipeline: (id: string) => void; onNewDeal: () => void }) {
  const { t } = useLocale();
  const move = useMoveDealStage();
  const toWork = useDealToWork();
  const attach = useAttachDealThread();
  const setPipe = useSetDealPipeline();
  const boardRef = useRef<HTMLDivElement>(null);
  const { pipeline, pipelines, deals, fields } = data;

  const jumpTo = (key: string) =>
    boardRef.current?.querySelector<HTMLElement>(`[data-stage="${key}"]`)?.scrollIntoView({ behavior: "smooth", inline: "start", block: "nearest" });

  const moveTo = (d: BoardDeal, stage: string) => {
    if (stage === d.stage) return;
    const label = pipeline.stages.find((s) => s.key === stage)?.label ?? stage;
    move.mutate(
      { id: d.id, stage },
      { onSuccess: () => notify.done("Deal moved", `${d.title} → ${label}`), onError: (e) => notify.failed("Could not move deal", { description: e.message }) },
    );
  };
  const advance = (d: BoardDeal) => {
    const i = pipeline.stages.findIndex((s) => s.key === d.stage);
    const next = pipeline.stages.slice(i + 1).find((s) => s.kind === "open") ?? pipeline.stages.find((s) => s.kind === "won");
    if (next) moveTo(d, next.key);
  };

  return (
    <>
      {pipelines.length > 1 && (
        <div className="mb-ax-3 flex items-center gap-2">
          <label htmlFor="pipeline-pick" className="ax-caption text-muted-foreground">{t("Pipeline")}</label>
          <select
            id="pipeline-pick"
            value={pipeline.id}
            onChange={(e) => onPipeline(e.target.value)}
            className="h-9 rounded-md border border-border bg-background px-2 text-[13px] font-semibold text-foreground"
          >
            {pipelines.map((p) => <option key={p.id} value={p.id}>{p.name}</option>)}
          </select>
        </div>
      )}

      <nav aria-label={t("Pipeline stages")} className="-mx-ax-4 mb-ax-3 flex gap-1.5 overflow-x-auto px-ax-4 [scrollbar-width:none] md:hidden">
        {pipeline.stages.map((s) => (
          <button key={s.key} type="button" onClick={() => jumpTo(s.key)} className="ax-press ax-tap inline-flex shrink-0 items-center gap-1.5 rounded-full border border-border px-3 py-1 text-[12px] font-semibold text-foreground">
            {s.label}
            <span className="tabular-nums text-muted-foreground">{deals.filter((d) => d.stage === s.key).length}</span>
          </button>
        ))}
      </nav>

      <div ref={boardRef} className="flex snap-x snap-mandatory gap-ax-3 overflow-x-auto pb-ax-4 md:snap-none">
        {pipeline.stages.map((s, si) => {
          const items = deals.filter((d) => d.stage === s.key);
          const total = items.reduce((sum, d) => sum + d.value, 0);
          return (
            <section key={s.key} data-stage={s.key} className="ax-plane flex w-72 shrink-0 snap-start flex-col rounded-2xl p-ax-3">
              <header className="mb-ax-3">
                <p className="text-[13px] font-bold text-foreground">{s.label}</p>
                <p className="ax-caption text-muted-foreground">{items.length} · {money(total, items[0]?.currency ?? "GBP")}</p>
              </header>
              <div className="space-y-ax-2">
                {items.length === 0 ? (
                  si === 0 ? (
                    <button type="button" onClick={onNewDeal} className="ax-press flex w-full flex-col items-start gap-1 rounded-lg border border-dashed border-border px-2.5 py-3 text-start transition-colors hover:border-foreground/30">
                      <span className="text-[12px] font-semibold text-foreground">{t("No deals yet")}</span>
                      <span className="ax-caption text-muted-foreground">{t("Capture one from mail or open a deal here.")}</span>
                    </button>
                  ) : (
                    <p className="ax-caption text-muted-foreground">{t("No deals in this stage")}</p>
                  )
                ) : (
                  items.map((d) => (
                    <DealCard
                      key={d.id}
                      d={d}
                      stageKind={s.kind}
                      stages={pipeline.stages}
                      fields={fields}
                      otherPipelines={pipelines.filter((p) => p.id !== pipeline.id)}
                      busy={move.isPending}
                      onAdvance={() => advance(d)}
                      onMove={(k) => moveTo(d, k)}
                      onPipeline={(pid) =>
                        setPipe.mutate({ id: d.id, pipeline_id: pid }, { onSuccess: () => notify.done("Deal moved to another pipeline"), onError: (e) => notify.failed("Could not change pipeline", { description: e.message }) })
                      }
                      onWork={() =>
                        toWork.mutate({ id: d.id }, { onSuccess: () => notify.done("Work opened", "The deal is a task on Work."), onError: (e) => notify.failed("Could not open work", { description: e.message }) })
                      }
                      onAttach={() =>
                        attach.mutate(
                          { id: d.id },
                          {
                            onSuccess: () => notify.done(t("Mail attached from this address"), d.contact_email || ""),
                            onError: (e) => notify.failed(e.status === 404 ? t("No mail thread on this address yet") : t("Could not attach mail"), { description: e.message }),
                          },
                        )
                      }
                    />
                  ))
                )}
              </div>
            </section>
          );
        })}
      </div>
    </>
  );
}

function DealCard({
  d, stageKind, stages, fields, otherPipelines, busy, onAdvance, onMove, onPipeline, onWork, onAttach,
}: {
  d: BoardDeal;
  stageKind: "open" | "won" | "lost";
  stages: { key: string; label: string }[];
  fields: FieldDef[];
  otherPipelines: { id: string; name: string }[];
  busy: boolean;
  onAdvance: () => void;
  onMove: (key: string) => void;
  onPipeline: (id: string) => void;
  onWork: () => void;
  onAttach: () => void;
}) {
  const { t } = useLocale();
  const [open, setOpen] = useState(false);
  const pill = "ax-press ax-hit ax-caption rounded-full border border-border px-2 py-0.5 font-semibold text-foreground";
  const filled = fields.filter((f) => d.custom[f.key]);
  return (
    <article className="rounded-xl border border-border bg-card p-ax-3">
      <p className="break-words text-[13px] font-semibold text-foreground">{d.title}</p>
      <p className="ax-caption mt-0.5 text-muted-foreground">{d.company ?? d.contact_email ?? t("No company yet")}</p>
      <div className="mt-1.5 flex flex-wrap items-center gap-2">
        <span className="text-[13px] font-semibold text-foreground">{money(d.value, d.currency)}</span>
        {probabilityPercent(d.probability) !== null && <Chip>{probabilityPercent(d.probability)}% {t("likely")}</Chip>}
        {d.stale_days !== null && d.stale_days > 7 && <Chip tone="warn">{d.stale_days}d {t("quiet")}</Chip>}
      </div>
      {d.next_step && (
        <p className="ax-caption mt-1.5 text-muted-foreground">{t("Next")}: {d.next_step}{d.next_step_due ? ` · ${d.next_step_due}` : ""}</p>
      )}
      {filled.length > 0 && (
        <dl className="mt-1.5 grid grid-cols-[auto_1fr] gap-x-2 gap-y-0.5 text-[12px]">
          {filled.map((f) => (
            <div key={f.key} className="contents">
              <dt className="text-muted-foreground">{f.label}</dt>
              <dd className="break-words text-foreground">{f.kind === "checkbox" ? (d.custom[f.key] === "true" ? "Yes" : "No") : d.custom[f.key]}</dd>
            </div>
          ))}
        </dl>
      )}
      <div className="mt-ax-2 flex flex-wrap items-center gap-2">
        {d.thread_id && (
          <Link to="/app/mail/$folder/$threadId" params={{ folder: "inbox", threadId: d.thread_id }} className={`${pill} inline-flex items-center gap-1`}>
            <Mail className="size-3" aria-hidden="true" /> {t("Thread")}
          </Link>
        )}
        {!d.thread_id && d.contact_email ? <button type="button" onClick={onAttach} className={pill}>{t("Attach mail")}</button> : null}
        {stageKind === "open" && (
          <button type="button" onClick={onAdvance} disabled={busy} className="ax-press ax-hit ax-caption inline-flex items-center gap-1 rounded-full border border-cyan-accent/50 px-2 py-0.5 font-semibold text-foreground">
            {t("Advance")} <ArrowRight className="size-3" aria-hidden="true" />
          </button>
        )}
        <button type="button" onClick={onWork} className={pill}>{t("Work")}</button>
        {fields.length > 0 && (
          <button type="button" onClick={() => setOpen((v) => !v)} aria-expanded={open} className={`${pill} inline-flex items-center gap-1`}>
            <SlidersHorizontal className="size-3" aria-hidden="true" /> {t("Fields")}
          </button>
        )}
        <label className="ax-press ax-caption relative inline-flex cursor-pointer items-center gap-1 rounded-full border border-border px-2 py-0.5 font-semibold text-foreground focus-within:ring-2 focus-within:ring-ring">
          {t("Move to…")}
          <ChevronDown className="size-3" aria-hidden="true" />
          <select aria-label={t("Move deal to another stage")} value="" disabled={busy} onChange={(e) => onMove(e.target.value)} className="absolute -inset-x-1 -inset-y-2 h-[calc(100%+1rem)] w-[calc(100%+0.5rem)] cursor-pointer opacity-0">
            <option value="" disabled>{t("Move to…")}</option>
            {stages.filter((s) => s.key !== d.stage).map((s) => <option key={s.key} value={s.key}>{s.label}</option>)}
          </select>
        </label>
        {otherPipelines.length > 0 && (
          <label className="ax-press ax-caption relative inline-flex cursor-pointer items-center gap-1 rounded-full border border-border px-2 py-0.5 font-semibold text-foreground focus-within:ring-2 focus-within:ring-ring">
            {t("Pipeline")}
            <ChevronDown className="size-3" aria-hidden="true" />
            <select aria-label={t("Move deal to another pipeline")} value="" onChange={(e) => onPipeline(e.target.value)} className="absolute -inset-x-1 -inset-y-2 h-[calc(100%+1rem)] w-[calc(100%+0.5rem)] cursor-pointer opacity-0">
              <option value="" disabled>{t("Pipeline")}</option>
              {otherPipelines.map((p) => <option key={p.id} value={p.id}>{p.name}</option>)}
            </select>
          </label>
        )}
      </div>
      {open && <CustomEditor d={d} fields={fields} onDone={() => setOpen(false)} />}
    </article>
  );
}

function CustomEditor({ d, fields, onDone }: { d: BoardDeal; fields: FieldDef[]; onDone: () => void }) {
  const set = useSetCustom();
  const [vals, setVals] = useState<Record<string, string>>(() => Object.fromEntries(fields.map((f) => [f.key, d.custom[f.key] ?? ""])));
  return (
    <form
      className="mt-ax-2 space-y-2 border-t border-border pt-ax-2"
      onSubmit={(e) => {
        e.preventDefault();
        set.mutate(
          { entity: "deal", id: d.id, values: vals },
          { onSuccess: () => { notify.done("Fields saved"); onDone(); }, onError: (er) => notify.failed("Could not save fields", { description: er.message }) },
        );
      }}
    >
      {fields.map((f) => (
        <label key={f.key} className="block text-[12px] text-muted-foreground">
          {f.label}
          {f.kind === "select" ? (
            <select value={vals[f.key] ?? ""} onChange={(e) => setVals({ ...vals, [f.key]: e.target.value })} className="mt-0.5 h-8 w-full rounded-md border border-border bg-background px-2 text-[13px] text-foreground">
              <option value="">—</option>
              {f.options.map((o) => <option key={o} value={o}>{o}</option>)}
            </select>
          ) : f.kind === "checkbox" ? (
            <select value={vals[f.key] ?? ""} onChange={(e) => setVals({ ...vals, [f.key]: e.target.value })} className="mt-0.5 h-8 w-full rounded-md border border-border bg-background px-2 text-[13px] text-foreground">
              <option value="">—</option>
              <option value="true">Yes</option>
              <option value="false">No</option>
            </select>
          ) : (
            <Input className="mt-0.5 h-8" type={f.kind === "number" ? "number" : f.kind === "date" ? "date" : "text"} maxLength={500} value={vals[f.key] ?? ""} onChange={(e) => setVals({ ...vals, [f.key]: e.target.value })} />
          )}
        </label>
      ))}
      <div className="flex gap-2">
        <Button type="submit" size="sm" disabled={set.isPending}>Save</Button>
        <Button type="button" size="sm" variant="ghost" onClick={onDone}>Cancel</Button>
      </div>
    </form>
  );
}
