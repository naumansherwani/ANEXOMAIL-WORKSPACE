import { createFileRoute, Link } from "@tanstack/react-router";
import { ArrowDown, ArrowUp, Copy, Plus, Trash2 } from "lucide-react";
import { useState } from "react";

import { SectionTitle } from "@/components/app/crm/CrmBits";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import type { ApiError } from "@/lib/api";
import {
  atCap,
  capText,
  useDeleteField,
  useDeleteForm,
  useDeletePipeline,
  useDuplicates,
  useFieldDefs,
  useMerge,
  usePipelines,
  useSaveField,
  useSaveForm,
  useSavePipeline,
  useWebForms,
  type DupRecord,
  type FieldDef,
  type FieldKind,
  type FormField,
  type FormFieldKind,
  type Pipeline,
  type StageInput,
  type StageKind,
  type WebForm,
} from "@/lib/crm-setup";
import { useLocale } from "@/lib/i18n";
import { notify } from "@/lib/notify";
import { cn } from "@/lib/utils";

export const Route = createFileRoute("/app/crm/setup")({
  head: () => ({
    meta: [
      { title: "CRM setup — ANEXOMAIL" },
      {
        name: "description",
        content: "Pipelines, custom fields, duplicate merge and web forms for your CRM. Limits follow your plan and are enforced on the server.",
      },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: SetupPage,
});

type Tab = "pipelines" | "fields" | "duplicates" | "forms";
const TABS: { id: Tab; label: string }[] = [
  { id: "pipelines", label: "Pipelines" },
  { id: "fields", label: "Custom fields" },
  { id: "duplicates", label: "Duplicates" },
  { id: "forms", label: "Web forms" },
];

const selectCls =
  "h-9 w-full rounded-md border border-border bg-background px-2 text-[13px] text-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring";

function SetupPage() {
  const { t } = useLocale();
  const [tab, setTab] = useState<Tab>("pipelines");
  return (
    <div className="w-full px-ax-4 py-ax-5 md:px-ax-5 md:py-ax-6">
      <SectionTitle
        title={t("CRM setup")}
        hint={t("Shape the CRM to how you sell. What your plan allows is shown beside each list; the server enforces it.")}
      />
      <div role="tablist" aria-label={t("CRM setup")} className="mb-ax-4 flex gap-1.5 overflow-x-auto [scrollbar-width:none]">
        {TABS.map((x) => (
          <button
            key={x.id}
            type="button"
            role="tab"
            aria-selected={tab === x.id}
            onClick={() => setTab(x.id)}
            className={cn(
              "ax-press ax-tap shrink-0 rounded-full border px-3 py-1 text-[13px] font-semibold",
              tab === x.id ? "border-foreground bg-foreground text-background" : "border-border text-foreground",
            )}
          >
            {t(x.label)}
          </button>
        ))}
      </div>
      {tab === "pipelines" && <PipelinesTab />}
      {tab === "fields" && <FieldsTab />}
      {tab === "duplicates" && <DuplicatesTab />}
      {tab === "forms" && <FormsTab />}
    </div>
  );
}

/* ----------------------------------------------------------------- shared bits */

function Gate({ error }: { error: ApiError | null }) {
  if (!error) return null;
  const locked = error.status === 403;
  return (
    <div className="ax-plane rounded-2xl p-ax-4" role="alert">
      <p className="text-[13px] font-semibold text-foreground">
        {locked ? "CRM setup is on Pro and above" : "This could not be loaded"}
      </p>
      <p className="ax-caption mt-1 text-muted-foreground">
        {locked ? "Pipelines, custom fields, duplicate merge and web forms start with the Pro package." : error.message}
      </p>
      {locked && (
        <Link to="/app/billing" className="ax-press mt-3 inline-block text-[13px] font-semibold underline">
          See plans
        </Link>
      )}
    </div>
  );
}

function CapNote({ used, cap, what }: { used: number; cap: number; what: string }) {
  return (
    <p className="ax-caption text-muted-foreground">
      {used} of {capText(cap)} {what}
      {atCap(used, cap) && (
        <>
          {" · "}
          <Link to="/app/billing" className="font-semibold underline">
            Upgrade for more
          </Link>
        </>
      )}
    </p>
  );
}

const fail = (title: string) => (e: ApiError) => notify.failed(title, { description: e.message });

/* ----------------------------------------------------------------- pipelines */

type StageRow = StageInput & { _k: number };
let rowSeq = 0;
const blankStages = (): StageRow[] => [
  { _k: ++rowSeq, label: "New", probability: 10, kind: "open" },
  { _k: ++rowSeq, label: "Won", probability: 100, kind: "won" },
  { _k: ++rowSeq, label: "Lost", probability: 0, kind: "lost" },
];

function PipelinesTab() {
  const list = usePipelines();
  const save = useSavePipeline();
  const del = useDeletePipeline();
  const [editing, setEditing] = useState<{ id?: string; name: string; stages: StageRow[] } | null>(null);

  if (list.error) return <Gate error={list.error} />;
  if (!list.data) return <p className="ax-caption text-muted-foreground" aria-busy="true">Loading…</p>;
  const { pipelines, limits } = list.data;

  const edit = (p: Pipeline) =>
    setEditing({
      id: p.id,
      name: p.name,
      stages: p.stages.map((s) => ({ _k: ++rowSeq, key: s.key, label: s.label, probability: s.probability, kind: s.kind })),
    });

  const patch = (i: number, v: Partial<StageInput>) =>
    setEditing((e) => (e ? { ...e, stages: e.stages.map((s, j) => (j === i ? { ...s, ...v } : s)) } : e));
  const move = (i: number, d: -1 | 1) =>
    setEditing((e) => {
      if (!e) return e;
      const s = [...e.stages];
      const j = i + d;
      if (j < 0 || j >= s.length) return e;
      [s[i], s[j]] = [s[j]!, s[i]!];
      return { ...e, stages: s };
    });

  const submit = () => {
    if (!editing) return;
    save.mutate(
      { ...(editing.id ? { id: editing.id } : {}), name: editing.name, stages: editing.stages.map(({ _k, ...s }) => s) },
      {
        onSuccess: () => {
          notify.done("Pipeline saved");
          setEditing(null);
        },
        onError: fail("Could not save the pipeline"),
      },
    );
  };

  return (
    <div className="space-y-ax-3">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <CapNote used={pipelines.length} cap={limits.pipelines} what="pipelines" />
        <Button
          size="sm"
          disabled={atCap(pipelines.length, limits.pipelines) || !!editing}
          onClick={() => setEditing({ name: "", stages: blankStages() })}
          className="ax-press"
        >
          <Plus className="size-4" aria-hidden="true" /> New pipeline
        </Button>
      </div>

      {pipelines.map((p) => (
        <section key={p.id} className="ax-plane rounded-2xl p-ax-4">
          <header className="flex flex-wrap items-center justify-between gap-2">
            <p className="text-[14px] font-bold text-foreground">
              {p.name} {p.is_default && <span className="ax-caption ms-1 font-normal text-muted-foreground">default</span>}
            </p>
            <div className="flex gap-2">
              <Button size="sm" variant="outline" onClick={() => edit(p)} disabled={!!editing}>
                Edit
              </Button>
              {!p.is_default && (
                <Button
                  size="sm"
                  variant="outline"
                  disabled={del.isPending}
                  onClick={() => del.mutate({ id: p.id }, { onSuccess: () => notify.done("Pipeline deleted"), onError: fail("Could not delete the pipeline") })}
                >
                  <Trash2 className="size-4" aria-hidden="true" />
                  <span className="sr-only">Delete {p.name}</span>
                </Button>
              )}
            </div>
          </header>
          <ol className="mt-2 flex flex-wrap gap-1.5">
            {p.stages.map((s) => (
              <li key={s.key} className="rounded-full border border-border px-2.5 py-0.5 text-[12px] text-foreground">
                {s.label} <span className="text-muted-foreground">{s.probability}%</span>
              </li>
            ))}
          </ol>
        </section>
      ))}

      {editing && (
        <section className="ax-plane space-y-ax-3 rounded-2xl p-ax-4" aria-label="Pipeline editor">
          <label className="block">
            <span className="ax-caption text-muted-foreground">Name</span>
            <Input value={editing.name} maxLength={60} onChange={(e) => setEditing({ ...editing, name: e.target.value })} />
          </label>
          <div className="space-y-2">
            {editing.stages.map((s, i) => (
              <div key={s._k} className="grid grid-cols-[1fr_5rem_6rem_auto] items-center gap-2 max-sm:grid-cols-2">
                <Input aria-label="Stage name" value={s.label} maxLength={40} onChange={(e) => patch(i, { label: e.target.value })} />
                <Input
                  aria-label="Probability percent"
                  type="number"
                  min={0}
                  max={100}
                  value={s.probability}
                  disabled={s.kind !== "open"}
                  onChange={(e) => patch(i, { probability: Math.max(0, Math.min(100, Number(e.target.value) || 0)) })}
                />
                <select
                  aria-label="Stage type"
                  className={selectCls}
                  value={s.kind}
                  onChange={(e) => {
                    const kind = e.target.value as StageKind;
                    patch(i, { kind, probability: kind === "won" ? 100 : kind === "lost" ? 0 : s.probability });
                  }}
                >
                  <option value="open">Open</option>
                  <option value="won">Won</option>
                  <option value="lost">Lost</option>
                </select>
                <div className="flex gap-1">
                  <Button type="button" size="icon" variant="ghost" onClick={() => move(i, -1)} aria-label="Move up"><ArrowUp className="size-4" /></Button>
                  <Button type="button" size="icon" variant="ghost" onClick={() => move(i, 1)} aria-label="Move down"><ArrowDown className="size-4" /></Button>
                  <Button
                    type="button"
                    size="icon"
                    variant="ghost"
                    aria-label="Remove stage"
                    onClick={() => setEditing({ ...editing, stages: editing.stages.filter((_, j) => j !== i) })}
                  >
                    <Trash2 className="size-4" />
                  </Button>
                </div>
              </div>
            ))}
          </div>
          <div className="flex flex-wrap gap-2">
            <Button
              type="button"
              variant="outline"
              size="sm"
              disabled={editing.stages.length >= 12}
              onClick={() => setEditing({ ...editing, stages: [{ _k: ++rowSeq, label: "", probability: 50, kind: "open" as StageKind }, ...editing.stages].slice(0, 12) })}
            >
              <Plus className="size-4" aria-hidden="true" /> Add stage
            </Button>
            <Button type="button" size="sm" onClick={submit} disabled={save.isPending || !editing.name.trim()}>
              Save pipeline
            </Button>
            <Button type="button" size="sm" variant="ghost" onClick={() => setEditing(null)}>
              Cancel
            </Button>
          </div>
          <p className="ax-caption text-muted-foreground">2 to 12 stages. Won is always 100%, Lost always 0%. You need at least one open and one closed stage.</p>
        </section>
      )}
    </div>
  );
}

/* ----------------------------------------------------------------- custom fields */

function FieldsTab() {
  const list = useFieldDefs();
  const save = useSaveField();
  const del = useDeleteField();
  const [draft, setDraft] = useState<{ entity: "lead" | "deal"; label: string; kind: FieldKind; options: string }>({ entity: "deal", label: "", kind: "text", options: "" });
  const [rename, setRename] = useState<{ f: FieldDef; label: string; options: string } | null>(null);

  if (list.error) return <Gate error={list.error} />;
  if (!list.data) return <p className="ax-caption text-muted-foreground" aria-busy="true">Loading…</p>;
  const { fields, limits } = list.data;
  const split = (s: string) => s.split(",").map((x) => x.trim()).filter(Boolean);

  const add = () =>
    save.mutate(
      { entity: draft.entity, label: draft.label, kind: draft.kind, ...(draft.kind === "select" ? { options: split(draft.options) } : {}) },
      {
        onSuccess: () => {
          notify.done("Field added");
          setDraft({ ...draft, label: "", options: "" });
        },
        onError: fail("Could not add the field"),
      },
    );

  return (
    <div className="space-y-ax-3">
      <CapNote used={fields.length} cap={limits.fields} what="custom fields" />

      <section className="ax-plane space-y-2 rounded-2xl p-ax-4" aria-label="Add a field">
        <div className="grid grid-cols-2 gap-2 md:grid-cols-4">
          <select aria-label="Applies to" className={selectCls} value={draft.entity} onChange={(e) => setDraft({ ...draft, entity: e.target.value as "lead" | "deal" })}>
            <option value="deal">Deals</option>
            <option value="lead">Leads</option>
          </select>
          <Input aria-label="Field label" placeholder="Label, e.g. Budget" value={draft.label} maxLength={40} onChange={(e) => setDraft({ ...draft, label: e.target.value })} />
          <select aria-label="Field type" className={selectCls} value={draft.kind} onChange={(e) => setDraft({ ...draft, kind: e.target.value as FieldKind })}>
            <option value="text">Text</option>
            <option value="number">Number</option>
            <option value="date">Date</option>
            <option value="select">Choice list</option>
            <option value="checkbox">Yes / no</option>
          </select>
          <Button onClick={add} disabled={save.isPending || !draft.label.trim() || atCap(fields.length, limits.fields)}>
            <Plus className="size-4" aria-hidden="true" /> Add field
          </Button>
        </div>
        {draft.kind === "select" && <Input aria-label="Choices" placeholder="Choices, separated by commas" value={draft.options} onChange={(e) => setDraft({ ...draft, options: e.target.value })} />}
      </section>

      {fields.length === 0 ? (
        <p className="ax-caption text-muted-foreground">No custom fields yet.</p>
      ) : (
        <ul className="space-y-2">
          {fields.map((f) => (
            <li key={f.id} className="ax-plane rounded-xl p-ax-3">
              {rename?.f.id === f.id ? (
                <div className="space-y-2">
                  <Input aria-label="Label" value={rename.label} maxLength={40} onChange={(e) => setRename({ ...rename, label: e.target.value })} />
                  {f.kind === "select" && <Input aria-label="Choices" value={rename.options} onChange={(e) => setRename({ ...rename, options: e.target.value })} />}
                  <div className="flex gap-2">
                    <Button
                      size="sm"
                      onClick={() =>
                        save.mutate(
                          { id: f.id, entity: f.entity, label: rename.label, kind: f.kind, ...(f.kind === "select" ? { options: split(rename.options) } : {}) },
                          { onSuccess: () => { notify.done("Field updated"); setRename(null); }, onError: fail("Could not update the field") },
                        )
                      }
                    >
                      Save
                    </Button>
                    <Button size="sm" variant="ghost" onClick={() => setRename(null)}>Cancel</Button>
                  </div>
                </div>
              ) : (
                <div className="flex flex-wrap items-center justify-between gap-2">
                  <p className="text-[13px] text-foreground">
                    <span className="font-semibold">{f.label}</span>{" "}
                    <span className="ax-caption text-muted-foreground">
                      {f.entity === "deal" ? "Deals" : "Leads"} · {f.kind}
                      {f.kind === "select" ? ` · ${f.options.join(", ")}` : ""}
                    </span>
                  </p>
                  <div className="flex gap-2">
                    <Button size="sm" variant="outline" onClick={() => setRename({ f, label: f.label, options: f.options.join(", ") })}>Edit</Button>
                    <Button
                      size="sm"
                      variant="outline"
                      disabled={del.isPending}
                      onClick={() => del.mutate({ id: f.id }, { onSuccess: () => notify.done("Field deleted", "Its values were removed from your records."), onError: fail("Could not delete the field") })}
                    >
                      <Trash2 className="size-4" aria-hidden="true" />
                      <span className="sr-only">Delete {f.label}</span>
                    </Button>
                  </div>
                </div>
              )}
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}

/* ----------------------------------------------------------------- duplicates */

const recLabel = (r: DupRecord) => [r.display_name ?? r.title, r.email ?? r.company].filter(Boolean).join(" · ") || r.id.slice(0, 8);

function DuplicatesTab() {
  const [kind, setKind] = useState<"lead" | "deal">("lead");
  const dups = useDuplicates(kind);
  const merge = useMerge();
  const [keep, setKeep] = useState<Record<number, string>>({});
  const [confirm, setConfirm] = useState<number | null>(null);

  return (
    <div className="space-y-ax-3">
      <div className="flex gap-2">
        {(["lead", "deal"] as const).map((k) => (
          <button
            key={k}
            type="button"
            onClick={() => { setKind(k); setKeep({}); setConfirm(null); }}
            aria-pressed={kind === k}
            className={cn("ax-press ax-tap rounded-full border px-3 py-1 text-[13px] font-semibold", kind === k ? "border-foreground bg-foreground text-background" : "border-border text-foreground")}
          >
            {k === "lead" ? "Leads by email" : "Deals by name + company"}
          </button>
        ))}
      </div>
      {dups.error ? (
        <Gate error={dups.error} />
      ) : !dups.data ? (
        <p className="ax-caption text-muted-foreground" aria-busy="true">Looking for duplicates…</p>
      ) : dups.data.groups.length === 0 ? (
        <p className="ax-caption text-muted-foreground">No duplicates found.</p>
      ) : (
        dups.data.groups.map((g, gi) => {
          const chosen = keep[gi] ?? g.records[0]!.id;
          return (
            <section key={g.records.map((r) => r.id).join("")} className="ax-plane rounded-2xl p-ax-4">
              <fieldset>
                <legend className="ax-caption mb-2 text-muted-foreground">{g.records.length} records look like the same {kind}. Pick the one to keep.</legend>
                <div className="space-y-1.5">
                  {g.records.map((r) => (
                    <label key={r.id} className="flex cursor-pointer items-start gap-2 text-[13px] text-foreground">
                      <input type="radio" name={`keep-${gi}`} checked={chosen === r.id} onChange={() => setKeep({ ...keep, [gi]: r.id })} className="mt-1" />
                      <span className="min-w-0 break-words">
                        {recLabel(r)} <span className="ax-caption text-muted-foreground">added {r.created_at.slice(0, 10)}</span>
                      </span>
                    </label>
                  ))}
                </div>
              </fieldset>
              <div className="mt-3 flex flex-wrap items-center gap-2">
                {confirm === gi ? (
                  <>
                    <Button
                      size="sm"
                      disabled={merge.isPending}
                      onClick={() =>
                        merge.mutate(
                          { kind, keep: chosen, drop: g.records.filter((r) => r.id !== chosen).map((r) => r.id) },
                          { onSuccess: (r) => { notify.done("Merged", `${r.merged} duplicate${r.merged === 1 ? "" : "s"} folded into one record.`); setConfirm(null); }, onError: fail("Could not merge") },
                        )
                      }
                    >
                      Yes, merge — this cannot be undone
                    </Button>
                    <Button size="sm" variant="ghost" onClick={() => setConfirm(null)}>Cancel</Button>
                  </>
                ) : (
                  <Button size="sm" variant="outline" onClick={() => setConfirm(gi)}>Merge into the selected record</Button>
                )}
              </div>
            </section>
          );
        })
      )}
    </div>
  );
}

/* ----------------------------------------------------------------- web forms */

type FormDraft = { id?: string; name: string; success_message: string; active: boolean; fields: (FormField & { _k: number })[] };
const newForm = (): FormDraft => ({
  name: "",
  success_message: "Thank you. We will be in touch.",
  active: true,
  fields: [
    { _k: ++rowSeq, key: "email", label: "Email", kind: "email", required: true },
    { _k: ++rowSeq, key: "name", label: "Name", kind: "text", required: false },
  ],
});
const FIELD_KINDS: FormFieldKind[] = ["text", "email", "number", "date", "select", "textarea"];

function FormsTab() {
  const list = useWebForms();
  const save = useSaveForm();
  const del = useDeleteForm();
  const [draft, setDraft] = useState<FormDraft | null>(null);

  if (list.error) return <Gate error={list.error} />;
  if (!list.data) return <p className="ax-caption text-muted-foreground" aria-busy="true">Loading…</p>;
  const { forms, limits } = list.data;
  const origin = typeof window === "undefined" ? "" : window.location.origin;

  const edit = (f: WebForm) => setDraft({ id: f.id, name: f.name, success_message: f.success_message, active: f.active, fields: f.fields.map((x) => ({ ...x, _k: ++rowSeq })) });
  const setField = (i: number, v: Partial<FormField>) => setDraft((d) => (d ? { ...d, fields: d.fields.map((f, j) => (j === i ? { ...f, ...v } : f)) } : d));

  const submit = () => {
    if (!draft) return;
    save.mutate(
      {
        ...(draft.id ? { id: draft.id } : {}),
        name: draft.name,
        success_message: draft.success_message,
        active: draft.active,
        fields: draft.fields.map(({ _k, ...f }) => ({ ...f, key: f.key || "", options: f.kind === "select" ? f.options ?? [] : undefined })) as FormField[],
      },
      { onSuccess: () => { notify.done("Form saved"); setDraft(null); }, onError: fail("Could not save the form") },
    );
  };

  return (
    <div className="space-y-ax-3">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <CapNote used={forms.length} cap={limits.forms} what="web forms" />
        <Button size="sm" disabled={atCap(forms.length, limits.forms) || !!draft} onClick={() => setDraft(newForm())}>
          <Plus className="size-4" aria-hidden="true" /> New form
        </Button>
      </div>

      {forms.map((f) => (
        <section key={f.id} className="ax-plane rounded-2xl p-ax-4">
          <header className="flex flex-wrap items-center justify-between gap-2">
            <p className="text-[14px] font-bold text-foreground">
              {f.name} <span className="ax-caption ms-1 font-normal text-muted-foreground">{f.active ? "live" : "paused"} · {f.submissions} lead{f.submissions === 1 ? "" : "s"}</span>
            </p>
            <div className="flex gap-2">
              <Button size="sm" variant="outline" onClick={() => edit(f)} disabled={!!draft}>Edit</Button>
              <Button
                size="sm"
                variant="outline"
                disabled={del.isPending}
                onClick={() => del.mutate({ id: f.id }, { onSuccess: () => notify.done("Form deleted"), onError: fail("Could not delete the form") })}
              >
                <Trash2 className="size-4" aria-hidden="true" />
                <span className="sr-only">Delete {f.name}</span>
              </Button>
            </div>
          </header>
          <div className="mt-2 flex items-center gap-2">
            <code className="min-w-0 flex-1 truncate rounded-md border border-border px-2 py-1 text-[12px] text-foreground">{origin}{f.path}</code>
            <Button
              size="icon"
              variant="outline"
              aria-label="Copy form link"
              onClick={() => {
                void navigator.clipboard?.writeText(`${origin}${f.path}`).then(() => notify.done("Link copied"), () => notify.info("Select the link and copy it"));
              }}
            >
              <Copy className="size-4" />
            </Button>
          </div>
        </section>
      ))}

      {draft && (
        <section className="ax-plane space-y-ax-3 rounded-2xl p-ax-4" aria-label="Form editor">
          <label className="block">
            <span className="ax-caption text-muted-foreground">Form name</span>
            <Input value={draft.name} maxLength={60} onChange={(e) => setDraft({ ...draft, name: e.target.value })} />
          </label>
          <div className="space-y-2">
            {draft.fields.map((f, i) => (
              <div key={f._k} className="grid grid-cols-[1fr_7rem_auto_auto] items-center gap-2 max-sm:grid-cols-2">
                <Input aria-label="Field label" value={f.label} maxLength={60} disabled={f.key === "email"} onChange={(e) => setField(i, { label: e.target.value })} />
                <select aria-label="Field type" className={selectCls} value={f.kind} disabled={f.key === "email"} onChange={(e) => setField(i, { kind: e.target.value as FormFieldKind })}>
                  {FIELD_KINDS.map((k) => <option key={k} value={k}>{k}</option>)}
                </select>
                <label className="flex items-center gap-1 text-[12px] text-foreground">
                  <input type="checkbox" checked={f.required} disabled={f.key === "email"} onChange={(e) => setField(i, { required: e.target.checked })} /> Required
                </label>
                {f.key !== "email" ? (
                  <Button type="button" size="icon" variant="ghost" aria-label="Remove field" onClick={() => setDraft({ ...draft, fields: draft.fields.filter((_, j) => j !== i) })}>
                    <Trash2 className="size-4" />
                  </Button>
                ) : <span />}
                {f.kind === "select" && (
                  <Input className="col-span-full" aria-label="Choices" placeholder="Choices, separated by commas" value={(f.options ?? []).join(", ")} onChange={(e) => setField(i, { options: e.target.value.split(",").map((x) => x.trim()).filter(Boolean) })} />
                )}
              </div>
            ))}
          </div>
          <Button type="button" variant="outline" size="sm" disabled={draft.fields.length >= 12} onClick={() => setDraft({ ...draft, fields: [...draft.fields, { _k: ++rowSeq, key: "", label: "", kind: "text", required: false }] })}>
            <Plus className="size-4" aria-hidden="true" /> Add field
          </Button>
          <label className="block">
            <span className="ax-caption text-muted-foreground">Thank-you message</span>
            <Input value={draft.success_message} maxLength={300} onChange={(e) => setDraft({ ...draft, success_message: e.target.value })} />
          </label>
          <label className="flex items-center gap-2 text-[13px] text-foreground">
            <input type="checkbox" checked={draft.active} onChange={(e) => setDraft({ ...draft, active: e.target.checked })} /> Accepting submissions
          </label>
          <div className="flex gap-2">
            <Button size="sm" onClick={submit} disabled={save.isPending || !draft.name.trim() || draft.fields.some((f) => !f.label.trim())}>Save form</Button>
            <Button size="sm" variant="ghost" onClick={() => setDraft(null)}>Cancel</Button>
          </div>
          <p className="ax-caption text-muted-foreground">Each submission becomes a lead in your CRM, owned by you. Bots are filtered with a hidden trap field and a speed check; no CAPTCHA is bypassed.</p>
        </section>
      )}
    </div>
  );
}
