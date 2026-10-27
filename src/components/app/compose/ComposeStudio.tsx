import { BrandSpinner, InlineLoading } from "@/components/state/BrandLoader";
import {
  AlertTriangle,
  BellRing,
  Clock,
  Crown,
  FileText,
  History,
  Languages,
  Maximize2,
  Minimize2,
  Paperclip,
  Send,
  ShieldCheck,
  Sparkles,
  Wand2,
  X,
  Zap,
} from "lucide-react";
import { useQueryClient } from "@tanstack/react-query";
import { useEffect, useMemo, useRef, useState } from "react";

import { FileContextCard } from "@/components/app/compose/FileContextCard";
import { GhostTextArea } from "@/components/app/compose/GhostTextArea";
import {
  OutcomesBar,
  promiseKey,
  type LinkChoice,
  type PromiseKey,
} from "@/components/app/compose/OutcomesBar";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";

import {
  applyVariables,
  cancelScheduledSend,
  findVariables,
  readingStats,
  useAskJimmy,
  useCreateFollowUp,
  useDraftVersions,
  useLeoCompose,
  useSaveDraft,
  useScheduleSend,
  useSendConfidence,
  useDeleteSnippet,
  useSnippets,
  useTemplates,
  useSaveTemplate,
  useDeleteTemplate,
  type ComposeTone,
  type DraftPayload,
} from "@/lib/compose";
import { useSaveHandoff } from "@/lib/handoff";
import { learnWritingPattern } from "@/lib/mail-predict";
import {
  DEFAULT_RATE,
  recordEconomics,
  recordPromises,
  recipientList,
  useAttentionRate,
  useFileContext,
  useOutcomes,
} from "@/lib/outcomes";
import { removeAttachment, uploadAttachment, useAttachLimits } from "@/lib/mail-attachments";
import {
  anyUploading,
  fmtBytes,
  precheck,
  readyIds,
  type AttachItem,
} from "@/lib/mail-attachments-core";
import { notify } from "@/lib/notify";
import { useIdentities, useSendMail } from "@/lib/mail";
import { addressTone } from "@/lib/mail-identity";
import { useAuth } from "@/lib/auth";
import { isAiHost } from "@/lib/host";
import { showProMailTools, surfaceFromSession } from "@/lib/plan-surface";
import { cn } from "@/lib/utils";

const TONES: { id: ComposeTone; label: string }[] = [
  { id: "warm", label: "Warm" },
  { id: "direct", label: "Direct" },
  { id: "formal", label: "Formal" },
  { id: "short", label: "Shorter" },
  { id: "apologetic", label: "Apologetic" },
];

const LANGUAGES = ["English", "Urdu", "Arabic", "French", "German", "Spanish", "Chinese"];

/** How long an outgoing mail is held on the server before it is queued.
 *  Card promise (plans.ts Basic): "Undo send (30s)" — server cap 120s. */
const UNDO_HOLD_SECONDS = 30;

type StudioProps = {
  threadId?: string;
  initialTo?: string;
  initialSubject?: string;
  /** Pre-filled message text (e.g. the first-email test from Domains). */
  initialBody?: string;
  /** Start "From" on this address (must be one of the workspace's own addresses; the server re-checks). */
  initialIdentity?: string;
  /** Language detected from the sender — reply starts here (feature 22). */
  detectedLanguage?: string | null;
  inReplyTo?: string;
  onSent?: () => void;
  /** Compact = inline reply inside a thread; overlay passes the same. */
  variant?: "inline" | "overlay";
};

/**
 * Compose Studio — Phase 9.
 *
 * One writer for both surfaces (inline reply + floating overlay). Everything
 * intelligent happens on the server: autosave/versions, templates, snippets,
 * signatures, the pre-send confidence scan, the undo-send hold queue, Leo
 * writing help and the Jimmy escalation. A missing endpoint is reported
 * honestly instead of being faked here.
 */
export function ComposeStudio({
  threadId,
  initialTo = "",
  initialSubject = "",
  initialBody = "",
  initialIdentity = "",
  detectedLanguage,
  inReplyTo,
  onSent,
  variant = "overlay",
}: StudioProps) {
  const { session, organisation } = useAuth();
  const [aiHost] = useState(isAiHost);
  const { billed, kind } = surfaceFromSession(session?.user, organisation?.slug);
  const proMail = showProMailTools(billed, null, kind);
  const leoUi = aiHost;

  const [to, setTo] = useState(initialTo);
  const [cc, setCc] = useState("");
  const [bcc, setBcc] = useState("");
  const [showMore, setShowMore] = useState(false);
  const [subject, setSubject] = useState(initialSubject);
  const [body, setBody] = useState(initialBody);
  const [sendAt, setSendAt] = useState("");
  const [scheduling, setScheduling] = useState(false);
  const [zen, setZen] = useState(false);
  const [identity, setIdentity] = useState<string>(initialIdentity);
  const [language, setLanguage] = useState(detectedLanguage ?? "English");
  const [variables, setVariables] = useState<Record<string, string>>({});
  const [draftId, setDraftId] = useState<string | undefined>();
  const [savedAt, setSavedAt] = useState<string | null>(null);
  const [showVersions, setShowVersions] = useState(false);
  const [followUpDays, setFollowUpDays] = useState(0);
  const bodyRef = useRef<HTMLTextAreaElement | null>(null);
  // Business Outcomes (Pro): kernel se wada + kharcha; user ne jo "link" kiya wahi send par record hota hai.
  const [linked, setLinked] = useState<Record<PromiseKey, LinkChoice>>({});
  const [dismissedPromises, setDismissedPromises] = useState<Set<PromiseKey>>(() => new Set());
  const attentionRate = useAttentionRate(proMail);
  const rate = attentionRate.data ?? DEFAULT_RATE;
  const outcomes = useOutcomes(body, [to, cc, bcc], rate, proMail);
  const fileHits = useFileContext(body, proMail);
  const [dismissedFiles, setDismissedFiles] = useState<Set<string>>(() => new Set());
  // G38 — attachments: upload turant (Rust), bhejte waqt sirf ids jati hain
  const [files, setFiles] = useState<AttachItem[]>([]);
  const filesRef = useRef<AttachItem[]>([]);
  const aborts = useRef<Map<string, AbortController>>(new Map());
  const fileInput = useRef<HTMLInputElement | null>(null);
  const [dragging, setDragging] = useState(false);
  const attachLimits = useAttachLimits();
  const limits = {
    message_cap_bytes: attachLimits.data?.message_cap_bytes ?? 7_000_000,
    max_files: attachLimits.data?.max_files ?? 10,
  };

  const templates = useTemplates();
  const saveTpl = useSaveTemplate();
  const delTpl = useDeleteTemplate();
  const [tplOpen, setTplOpen] = useState(false);
  const [tplName, setTplName] = useState("");
  const snippets = useSnippets();
  // Data decides, not the plan: a Basic user who connected their own domain still has a company
  // address and must be able to send FROM it (the server allow-list is the real gate, not the plan).
  const identities = useIdentities(true);
  const versions = useDraftVersions(showVersions ? draftId : undefined);
  const saveDraft = useSaveDraft();
  const confidence = useSendConfidence();
  const schedule = useScheduleSend();
  const qc = useQueryClient();
  const send = useSendMail();
  const leo = useLeoCompose();
  const jimmy = useAskJimmy();
  const followUp = useCreateFollowUp();
  const deleteSnippet = useDeleteSnippet();
  const saveHandoff = useSaveHandoff();

  const payload = useMemo<DraftPayload>(
    () => ({
      ...(draftId ? { id: draftId } : {}),
      ...(threadId ? { thread_id: threadId } : {}),
      ...(identity ? { identity } : {}),
      to,
      ...(cc.trim() ? { cc } : {}),
      ...(bcc.trim() ? { bcc } : {}),
      subject,
      body: applyVariables(body, variables),
      language,
      ...(scheduling && sendAt ? { send_at: new Date(sendAt).toISOString() } : {}),
    }),
    [
      draftId,
      threadId,
      identity,
      to,
      cc,
      bcc,
      subject,
      body,
      variables,
      language,
      scheduling,
      sendAt,
    ],
  );

  // Autosave every 3s of quiet — the server owns the version history.
  useEffect(() => {
    if (!body.trim() && !subject.trim()) return;
    const timer = setTimeout(() => {
      saveDraft.mutate(payload, {
        onSuccess: (record) => {
          setDraftId(record.id);
          setSavedAt(record.saved_at);
          // cross-device handoff: the same text + cursor opens on the phone / laptop (Rust mail.handoff.save)
          saveHandoff.mutate({
            ...(threadId ? { thread_id: threadId } : {}),
            to_address: to,
            subject,
            body,
            cursor_position: body.length,
          });
        },
        onError: () => undefined, // silent: offline queue keeps the text on screen
      });
    }, 3000);
    return () => clearTimeout(timer);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [payload]);

  const openVars = findVariables(body).filter((name) => !variables[name]?.trim());
  const stats = readingStats(body);
  const busy = send.isPending || schedule.isPending || confidence.isPending || anyUploading(files);

  const insertSnippet = (text: string) => {
    const el = bodyRef.current;
    if (!el) {
      setBody((v) => `${v}${text}`);
      return;
    }
    const start = el.selectionStart ?? body.length;
    setBody(`${body.slice(0, start)}${text}${body.slice(el.selectionEnd ?? start)}`);
  };

  const setFilesBoth = (next: AttachItem[]) => {
    filesRef.current = next;
    setFiles(next);
  };
  const patchFile = (key: string, patch: Partial<AttachItem>) =>
    setFilesBoth(filesRef.current.map((f) => (f.key === key ? { ...f, ...patch } : f)));

  const addFiles = (list: FileList | File[] | null) => {
    if (!list) return;
    for (const file of Array.from(list)) {
      const why = precheck(file, filesRef.current, limits);
      if (why) {
        notify.failed("Not attached", { description: why });
        continue;
      }
      const key = `${Date.now()}-${Math.random().toString(36).slice(2, 8)}`;
      const ctl = new AbortController();
      aborts.current.set(key, ctl);
      setFilesBoth([
        ...filesRef.current,
        { key, name: file.name, size: file.size, status: "uploading", progress: 0 },
      ]);
      uploadAttachment(file, {
        signal: ctl.signal,
        onProgress: (progress) => patchFile(key, { progress }),
      })
        .then((r) =>
          patchFile(key, {
            status: "ready",
            progress: 100,
            id: r.id,
            deduped: r.deduped,
            scanned: r.scanned,
          }),
        )
        .catch((e: Error & { code?: string }) => {
          if (e.code === "aborted") return;
          patchFile(key, { status: "error", error: e.message });
        })
        .finally(() => aborts.current.delete(key));
    }
    if (fileInput.current) fileInput.current.value = "";
  };

  const dropFile = (item: AttachItem) => {
    aborts.current.get(item.key)?.abort();
    if (item.id) void removeAttachment(item.id).catch(() => undefined); // server 24 ghante baad bhi saaf kar deta hai
    setFilesBoth(filesRef.current.filter((f) => f.key !== item.key));
  };

  const finalSend = () => {
    if (scheduling && sendAt) {
      schedule.mutate(
        { ...payload, attachment_ids: readyIds(files), hold_seconds: 0 },
        {
          onSuccess: () => {
            notify.done("Scheduled", `Leaves at ${new Date(sendAt).toLocaleString()}.`);
            onSent?.();
          },
          onError: (error) =>
            reportFailure(error.isNotImplemented, error.message, "POST /api/mail/schedule"),
        },
      );
      return;
    }

    // Undo Send = a real server-side hold, not a browser timer.
    schedule.mutate(
      { ...payload, attachment_ids: readyIds(files), hold_seconds: UNDO_HOLD_SECONDS },
      {
        onSuccess: (res) => {
          notify.undoable(
            "Sending…",
            `Held for ${UNDO_HOLD_SECONDS}s. Changed your mind?`,
            UNDO_HOLD_SECONDS * 1000,
            () => {
              cancelScheduledSend(res.id)
                .then(() => {
                  void qc.invalidateQueries({ queryKey: ["mail"] });
                  notify.done("Not sent", "Your message was stopped before it left.");
                })
                .catch((err: { status?: number }) =>
                  notify.failed(err?.status === 409 ? "Already sent" : "Could not undo", {
                    description:
                      err?.status === 409
                        ? "It left your workspace before Undo."
                        : "Please try again.",
                  }),
                );
            },
          );
          afterSent();
          onSent?.();
        },
        onError: (error) => {
          if (!error.isNotImplemented) {
            notify.failed("Not sent", { description: error.message });
            return;
          }
          // Hold queue not wired yet: send directly rather than lose the mail.
          send.mutate(
            {
              ...payload,
              attachment_ids: readyIds(files),
              ...(inReplyTo ? { in_reply_to: inReplyTo } : {}),
            },
            {
              onSuccess: () => {
                notify.done("Sent", "The message left your workspace.");
                afterSent();
                onSent?.();
              },
              onError: (err) =>
                reportFailure(err.isNotImplemented, err.message, "POST /api/mail/send"),
            },
          );
        },
      },
    );
  };

  /** Phase 12A: send ke baad user ke apne likhe se pattern seekha jata hai. */
  const afterSent = () => {
    void learnWritingPattern(applyVariables(body, variables)).catch(() => undefined);
    if (proMail) {
      const chosen = outcomes.promises
        .filter((p) => linked[promiseKey(p)])
        .map((p) => ({ promise: p, withEvent: !!linked[promiseKey(p)]?.withEvent }));
      const rcpt = recipientList(to, cc, bcc);
      if (chosen.length > 0) {
        void recordPromises(chosen, { threadId, subject, to: rcpt }).then((r) => {
          if (r.saved > 0)
            notify.done(
              "Promise tracked",
              `${r.saved} added to Tasks${r.events ? " and Calendar" : ""}.`,
            );
          else if (r.failed > 0)
            notify.failed("Could not track the promise", {
              description: "Add it from Work → Promises.",
            });
        });
      }
      if (outcomes.words > 0 && rcpt.length > 0)
        void recordEconomics({ words: outcomes.words, recipients: rcpt.length, threadId });
    }
    maybePromiseFollowUp();
  };

  const maybePromiseFollowUp = () => {
    if (!followUpDays) return;
    const remind = new Date();
    remind.setDate(remind.getDate() + followUpDays);
    followUp.mutate(
      {
        ...(threadId ? { thread_id: threadId } : {}),
        subject,
        remind_at: remind.toISOString(),
      },
      { onError: () => undefined },
    );
  };

  const submit = () => {
    if (openVars.length) {
      notify.failed("Variables still open", {
        description: `Fill ${openVars.map((v) => `{{${v}}}`).join(", ")} before sending.`,
      });
      return;
    }
    if (anyUploading(files)) {
      notify.failed("Still uploading", {
        description: "Wait for your attachments to finish, or remove them.",
      });
      return;
    }
    // Pre-send confidence scan runs server-side first.
    confidence.mutate(
      { ...payload, attachments: readyIds(files).length },
      {
        onSuccess: (report) => {
          const blockers = report.issues.filter((i) => i.severity === "block");
          if (blockers.length) {
            notify.failed("Hold on", { description: blockers[0]!.message });
            return;
          }
          const warn = report.issues.find((i) => i.severity === "warn");
          if (warn) notify.info("Check this", warn.message);
          finalSend();
        },
        onError: () => finalSend(), // scan not wired yet — never block the send
      },
    );
  };

  const runLeo = (task: Parameters<typeof leo.mutate>[0]) =>
    leo.mutate(
      { ...task, body, subject, ...(threadId ? { thread_id: threadId } : {}), to },
      {
        onSuccess: (result) => {
          if (result.reply) setBody(result.reply);
          if (result.subject) setSubject(result.subject);
          if (result.language) setLanguage(result.language);
          notify.done("Leo updated your draft");
        },
        onError: (error) =>
          reportFailure(error.isNotImplemented, error.message, "POST /api/leo/chat"),
      },
    );

  return (
    <form
      className={cn(
        "flex flex-col gap-ax-3",
        zen && "fixed inset-0 z-[60] overflow-y-auto bg-background p-ax-6 md:p-12",
        !zen && variant === "inline" && "ax-plane rounded-2xl p-ax-4",
        !zen && variant === "overlay" && "p-ax-4",
        dragging && "ring-2 ring-primary/60",
      )}
      onDragOver={(event) => {
        if (event.dataTransfer?.types?.includes("Files")) {
          event.preventDefault();
          setDragging(true);
        }
      }}
      onDragLeave={(event) => {
        if (event.currentTarget === event.target) setDragging(false);
      }}
      onDrop={(event) => {
        if (event.dataTransfer?.files?.length) {
          event.preventDefault();
          setDragging(false);
          addFiles(event.dataTransfer.files);
        }
      }}
      onSubmit={(event) => {
        event.preventDefault();
        submit();
      }}
      onKeyDown={(event) => {
        if ((event.metaKey || event.ctrlKey) && event.key === "Enter") {
          event.preventDefault();
          submit();
        }
      }}
    >
      <div className={cn("mx-auto flex w-full flex-col gap-ax-3", zen && "max-w-3xl")}>
        {/* identity + language */}
        <div className="flex flex-wrap items-center gap-2">
          {(identities.data?.identities.length ?? 0) > 1 ? (
            <div className="flex items-center gap-1.5">
              <span
                aria-hidden
                className="h-2.5 w-2.5 shrink-0 rounded-full"
                style={{
                  background:
                    addressTone(identity || identities.data?.default)?.color ?? "currentColor",
                }}
              />
              <select
                aria-label="Send from"
                value={identity}
                onChange={(e) => setIdentity(e.target.value)}
                className="h-8 rounded-lg border border-border bg-card px-2 text-[11px] text-foreground [@media(pointer:coarse)]:h-11"
              >
                <option value="">{`Send from — ${identities.data?.default ?? "default"}`}</option>
                {identities.data?.identities.map((i) => (
                  <option key={i.address} value={i.address}>
                    {i.address}
                  </option>
                ))}
              </select>
            </div>
          ) : null}
          <select
            aria-label="Reply language"
            value={language}
            onChange={(e) => setLanguage(e.target.value)}
            className="h-8 rounded-lg border border-border bg-card px-2 text-[11px] text-foreground [@media(pointer:coarse)]:h-11"
          >
            {LANGUAGES.map((l) => (
              <option key={l} value={l}>
                {l}
              </option>
            ))}
          </select>
          {detectedLanguage && (
            <span className="text-[10px] text-steel">Detected: {detectedLanguage}</span>
          )}
          <button
            type="button"
            onClick={() => setZen((v) => !v)}
            className="ax-press ax-hit ml-auto rounded-lg p-1.5 text-steel hover:bg-secondary"
            aria-label={zen ? "Leave full screen" : "Full-screen writer"}
          >
            {zen ? <Minimize2 className="size-4" /> : <Maximize2 className="size-4" />}
          </button>
        </div>

        <div className="flex flex-col gap-1.5">
          <Label htmlFor="studio-to">To</Label>
          <Input
            id="studio-to"
            type="email"
            multiple
            inputMode="email"
            autoCapitalize="off"
            spellCheck={false}
            required
            autoComplete="off"
            value={to}
            onChange={(e) => setTo(e.target.value)}
            placeholder="name@company.com"
          />
        </div>

        {showMore ? (
          <div className="grid gap-ax-2 sm:grid-cols-2">
            <div className="flex flex-col gap-1.5">
              <Label htmlFor="studio-cc">Cc</Label>
              <Input id="studio-cc" value={cc} onChange={(e) => setCc(e.target.value)} />
            </div>
            <div className="flex flex-col gap-1.5">
              <Label htmlFor="studio-bcc">Bcc</Label>
              <Input id="studio-bcc" value={bcc} onChange={(e) => setBcc(e.target.value)} />
            </div>
          </div>
        ) : (
          <button
            type="button"
            onClick={() => setShowMore(true)}
            className="ax-press ax-hit self-start text-[11px] font-semibold text-steel underline-offset-4 hover:underline"
          >
            Add Cc / Bcc
          </button>
        )}

        <div className="flex flex-col gap-1.5">
          <Label htmlFor="studio-subject">Subject</Label>
          <div className="flex gap-2">
            <Input
              id="studio-subject"
              required
              value={subject}
              onChange={(e) => setSubject(e.target.value)}
            />
            {leoUi ? (
              <Button
                type="button"
                variant="outline"
                className="ax-press shrink-0"
                onClick={() => runLeo({ task: "SUBJECT" })}
                disabled={leo.isPending}
              >
                <Sparkles className="size-4" />
                Suggest
              </Button>
            ) : null}
          </div>
        </div>

        {/* templates — Pro card. Snippets stay for every package. */}
        <div className="flex flex-wrap items-center gap-2">
          {proMail ? (
            <select
              aria-label="Insert template"
              value=""
              onChange={(e) => {
                const tpl = templates.data?.templates.find((t) => t.id === e.target.value);
                if (!tpl) return;
                if (tpl.subject) setSubject(tpl.subject);
                setBody((v) => (v ? `${v}\n\n${tpl.body}` : tpl.body));
              }}
              className="h-8 rounded-lg border border-border bg-card px-2 text-[11px] text-foreground [@media(pointer:coarse)]:h-11"
            >
              <option value="">
                {templates.isError ? "Templates — not wired yet" : "Insert template"}
              </option>
              {templates.data?.templates.map((t) => (
                <option key={t.id} value={t.id}>
                  {t.name} · {t.scope}
                </option>
              ))}
            </select>
          ) : null}
          {proMail ? (
            <button
              type="button"
              onClick={() => setTplOpen((o) => !o)}
              aria-expanded={tplOpen}
              className="ax-press ax-hit rounded-lg border border-border px-2 py-1 text-[11px] text-muted-foreground hover:text-foreground"
            >
              Templates…
            </button>
          ) : null}
          {snippets.data?.snippets.slice(0, 4).map((s) => (
            <span key={s.id} className="inline-flex items-center">
              <button
                type="button"
                onClick={() => insertSnippet(s.body)}
                className="ax-press ax-hit rounded-l-lg border border-border px-2 py-1 text-[10px] text-muted-foreground hover:text-foreground"
              >
                <Zap className="mr-1 inline size-3" />
                {s.shortcut}
              </button>
              <button
                type="button"
                aria-label={`Delete snippet ${s.shortcut}`}
                disabled={deleteSnippet.isPending}
                onClick={() => deleteSnippet.mutate({ id: s.id })}
                className="ax-press ax-hit rounded-r-lg border border-l-0 border-border px-1.5 py-1 text-[10px] text-muted-foreground hover:text-destructive"
              >
                ×
              </button>
            </span>
          ))}
        </div>
        {proMail && tplOpen ? (
          <div className="space-y-2 rounded-lg border border-border bg-card p-2 text-[12px]">
            <p className="text-muted-foreground">
              Save what you wrote as a template (subject + message). Use {"{{first_name}}"} for a
              value you fill in each time.
            </p>
            <div className="flex flex-wrap items-center gap-2">
              <input
                value={tplName}
                maxLength={80}
                onChange={(e) => setTplName(e.target.value)}
                placeholder="Template name"
                aria-label="Template name"
                className="h-8 min-w-[10rem] flex-1 rounded-lg border border-border bg-background px-2 text-base sm:text-[12px]"
              />
              <button
                type="button"
                disabled={!tplName.trim() || !body.trim() || saveTpl.isPending}
                onClick={() =>
                  saveTpl.mutate(
                    { name: tplName.trim(), subject: subject.trim(), body },
                    {
                      onSuccess: () => {
                        setTplName("");
                        notify.done("Template saved");
                      },
                      onError: (e) =>
                        notify.failed(
                          e.code === "too_many"
                            ? "You can keep up to 50 templates"
                            : "Could not save the template",
                          {
                            description: e.message,
                          },
                        ),
                    },
                  )
                }
                className="ax-press ax-hit rounded-lg bg-primary px-3 py-1 text-[12px] text-primary-foreground disabled:opacity-50"
              >
                {saveTpl.isPending ? "Saving…" : "Save as template"}
              </button>
            </div>
            {!body.trim() ? (
              <p className="text-muted-foreground">Write the message first, then save it.</p>
            ) : null}
            {(templates.data?.templates ?? []).filter((t) => t.scope === "personal").length > 0 ? (
              <ul className="space-y-1">
                {(templates.data?.templates ?? [])
                  .filter((t) => t.scope === "personal")
                  .map((t) => (
                    <li key={t.id} className="flex items-center gap-2">
                      <span className="min-w-0 flex-1 truncate">{t.name}</span>
                      <button
                        type="button"
                        aria-label={`Delete template ${t.name}`}
                        disabled={delTpl.isPending}
                        onClick={() =>
                          delTpl.mutate(
                            { id: t.id },
                            {
                              onSuccess: () => notify.done("Template removed"),
                              onError: () => notify.failed("Could not remove it"),
                            },
                          )
                        }
                        className="ax-press rounded px-2 py-0.5 text-muted-foreground hover:text-danger"
                      >
                        Remove
                      </button>
                    </li>
                  ))}
              </ul>
            ) : null}
          </div>
        ) : null}

        {/* Phase 12A — inline word prediction (ghost text). Composer wahi hai. */}
        <GhostTextArea
          id="studio-body"
          ref={bodyRef}
          ariaLabel="Message"
          required
          rows={zen ? 18 : variant === "inline" ? 6 : 8}
          value={body}
          onChange={setBody}
          subject={subject}
          to={to}
          {...(threadId ? { threadId } : {})}
          placeholder={
            leoUi
              ? "Write it once. Leo can tighten it, translate it or coach the tone."
              : "Write the message."
          }
        />

        {proMail ? (
          <FileContextCard
            hits={fileHits}
            dismissed={dismissedFiles}
            onDismiss={(q) => setDismissedFiles((d) => new Set(d).add(q))}
            onInsert={(line) =>
              line && setBody((b) => `${b}${b.endsWith("\n") || b === "" ? "" : "\n"}${line}`)
            }
          />
        ) : null}

        {proMail ? (
          <OutcomesBar
            outcomes={outcomes}
            rate={rate}
            linked={linked}
            dismissed={dismissedPromises}
            onLink={(k, c) => setLinked((m) => ({ ...m, [k]: c }))}
            onUnlink={(k) =>
              setLinked((m) => {
                const n = { ...m };
                delete n[k];
                return n;
              })
            }
            onDismiss={(k) => {
              setDismissedPromises((d) => new Set(d).add(k));
              setLinked((m) => {
                const n = { ...m };
                delete n[k];
                return n;
              });
            }}
          />
        ) : null}

        {/* open variables */}
        {openVars.length > 0 && (
          <div className="ax-plane flex flex-col gap-2 rounded-xl p-ax-3">
            <p className="ax-label text-foreground">Fill the variables</p>
            {openVars.map((name) => (
              <div key={name} className="flex items-center gap-2">
                <span className="w-32 shrink-0 text-[11px] text-muted-foreground">{`{{${name}}}`}</span>
                <Input
                  aria-label={name}
                  value={variables[name] ?? ""}
                  onChange={(e) => setVariables((v) => ({ ...v, [name]: e.target.value }))}
                />
              </div>
            ))}
          </div>
        )}

        {leoUi ? (
          <div className="flex flex-wrap items-center gap-2">
            <Button
              type="button"
              variant="secondary"
              className="ax-press"
              disabled={leo.isPending}
              onClick={() => runLeo({ task: "COACH" })}
            >
              {leo.isPending ? <BrandSpinner className="size-4" /> : <Wand2 className="size-4" />}
              Draft coach
            </Button>
            {TONES.map((tone) => (
              <button
                key={tone.id}
                type="button"
                onClick={() => runLeo({ task: "REWRITE", tone: tone.id })}
                disabled={leo.isPending}
                className="ax-press ax-hit rounded-lg border border-border px-2 py-1 text-[11px] text-muted-foreground hover:text-foreground"
              >
                {tone.label}
              </button>
            ))}
            <button
              type="button"
              onClick={() => runLeo({ task: "TRANSLATE", language })}
              disabled={leo.isPending}
              className="ax-press ax-hit rounded-lg border border-border px-2 py-1 text-[11px] text-muted-foreground hover:text-foreground"
            >
              <Languages className="mr-1 inline size-3" />
              Translate my reply
            </button>
            <button
              type="button"
              onClick={() =>
                jimmy.mutate(
                  {
                    ...(threadId ? { thread_id: threadId } : {}),
                    to,
                    subject,
                    body,
                    question: "Draft the strongest reply with full company context.",
                  },
                  {
                    onSuccess: (result) => {
                      if (result.reply) setBody(result.reply);
                      notify.done(
                        "Jimmy drafted this",
                        result.audited_by ? `Audited by ${result.audited_by}.` : undefined,
                      );
                    },
                    onError: (error) =>
                      reportFailure(
                        error.isNotImplemented,
                        error.status === 402 || error.status === 403
                          ? "Jimmy is available on Business plans."
                          : error.message,
                        "POST /api/leo/escalate",
                      ),
                  },
                )
              }
              disabled={jimmy.isPending}
              className="ax-press ax-hit rounded-lg border border-border px-2 py-1 text-[11px] font-semibold text-foreground hover:bg-secondary"
            >
              <Crown className="mr-1 inline size-3" />
              Jimmy se poochho
            </button>
          </div>
        ) : null}

        {/* G38 — attachments: asli upload (Rust), type/virus/size server dekhta hai; yahan sirf wahi dikhta hai jo sach hai */}
        <div className="flex flex-wrap items-center gap-2">
          <button
            type="button"
            data-testid="compose-attach"
            onClick={() => fileInput.current?.click()}
            title={`Attach files — up to ${fmtBytes(limits.message_cap_bytes)} per message`}
            className="ax-press ax-hit flex items-center gap-1.5 rounded-lg border border-border px-2 py-1 text-[11px] text-muted-foreground hover:text-foreground"
          >
            <Paperclip className="size-3" aria-hidden="true" />
            Attach files
          </button>
          <input
            ref={fileInput}
            type="file"
            multiple
            hidden
            data-testid="compose-attach-input"
            onChange={(e) => addFiles(e.target.files)}
          />
          <button
            type="button"
            onClick={() => setShowVersions((v) => !v)}
            disabled={!draftId}
            title={
              draftId
                ? "See earlier versions of this draft"
                : "Opens after your first autosave — keep typing"
            }
            className="ax-press ax-hit rounded-lg border border-border px-2 py-1 text-[11px] text-muted-foreground disabled:opacity-40"
          >
            <History className="mr-1 inline size-3" />
            Version history
          </button>
          <select
            aria-label="Follow-up promise"
            value={followUpDays}
            onChange={(e) => setFollowUpDays(Number(e.target.value))}
            className="h-8 rounded-lg border border-border bg-card px-2 text-[11px] text-foreground [@media(pointer:coarse)]:h-11"
          >
            <option value={0}>No follow-up</option>
            <option value={2}>Remind me in 2 days</option>
            <option value={3}>Remind me in 3 days</option>
            <option value={7}>Remind me in a week</option>
          </select>
        </div>

        {files.length > 0 && (
          <ul
            className="flex flex-col gap-1.5"
            data-testid="compose-attachments"
            aria-label="Attachments"
          >
            {files.map((f) => (
              <li
                key={f.key}
                className="flex items-center gap-2 rounded-lg border border-border bg-card px-2 py-1.5 text-[11px]"
                data-state={f.status}
              >
                <Paperclip className="size-3 shrink-0 text-muted-foreground" aria-hidden="true" />
                <span className="min-w-0 flex-1">
                  <span className="block truncate text-foreground">{f.name}</span>
                  <span
                    className={cn(
                      "block truncate",
                      f.status === "error" ? "text-destructive" : "text-steel",
                    )}
                  >
                    {f.status === "uploading"
                      ? `Uploading… ${f.progress}%`
                      : f.status === "error"
                        ? f.error
                        : `${fmtBytes(f.size)}${f.scanned ? " · virus-checked" : ""}`}
                  </span>
                </span>
                {f.status === "uploading" ? (
                  <BrandSpinner
                    className="size-3.5 shrink-0 text-muted-foreground"
                    aria-hidden="true"
                  />
                ) : null}
                <button
                  type="button"
                  onClick={() => dropFile(f)}
                  aria-label={`Remove ${f.name}`}
                  className="ax-press ax-hit grid size-7 shrink-0 place-items-center rounded-md text-muted-foreground hover:bg-secondary hover:text-foreground [@media(pointer:coarse)]:size-11"
                >
                  <X className="size-3.5" aria-hidden="true" />
                </button>
              </li>
            ))}
            <li className="text-[10px] text-steel">
              {fmtBytes(files.filter((f) => f.status !== "error").reduce((n, f) => n + f.size, 0))}{" "}
              of {fmtBytes(limits.message_cap_bytes)} per message
            </li>
          </ul>
        )}

        {showVersions && (
          <div className="ax-plane flex flex-col gap-1.5 rounded-xl p-ax-3">
            {versions.isError ? (
              <p className="text-[11px] text-muted-foreground">
                GET /api/mail/drafts/:id is pending on the server.
              </p>
            ) : versions.isPending ? (
              <InlineLoading label="Loading versions…" />
            ) : (
              versions.data?.versions.map((v) => (
                <button
                  key={v.id}
                  type="button"
                  onClick={() => {
                    setBody(v.body ?? "");
                    if (v.subject) setSubject(v.subject);
                    notify.info("Version restored", `v${v.version}`);
                  }}
                  className="ax-press flex items-center justify-between rounded-lg px-2 py-1 text-left text-[11px] text-muted-foreground hover:bg-secondary hover:text-foreground"
                >
                  <span>v{v.version}</span>
                  <span>{new Date(v.saved_at).toLocaleString()}</span>
                </button>
              ))
            )}
          </div>
        )}

        {proMail && scheduling && (
          <div className="flex flex-col gap-1.5">
            <Label htmlFor="studio-schedule">Send at</Label>
            <Input
              id="studio-schedule"
              type="datetime-local"
              required
              value={sendAt}
              onChange={(e) => setSendAt(e.target.value)}
            />
          </div>
        )}

        {/* confidence result */}
        {confidence.data && confidence.data.issues.length > 0 && (
          <ul className="flex flex-col gap-1">
            {confidence.data.issues.map((issue, i) => (
              <li key={i} className="flex items-start gap-1.5 text-[11px] text-muted-foreground">
                {issue.severity === "block" ? (
                  <AlertTriangle className="mt-0.5 size-3 shrink-0" />
                ) : (
                  <ShieldCheck className="mt-0.5 size-3 shrink-0" />
                )}
                <span>{issue.message}</span>
              </li>
            ))}
          </ul>
        )}

        <p className="text-[10px] text-steel">
          <span className="sm:hidden">{stats.words} words · </span>
          <span className="[@media(pointer:coarse)]:hidden">⌘↵ send · </span>
          held {UNDO_HOLD_SECONDS}s on the server so you can still stop it
        </p>

        {/* Phone par Send hamesha nazar aaye (keyboard khulne par bhi): overlay mein neeche chipki patti. */}
        <div
          className={cn(
            "flex flex-wrap items-center gap-ax-2",
            variant === "overlay" &&
              !zen &&
              "sticky bottom-0 z-10 -mx-ax-4 border-t border-border bg-card/95 px-ax-4 py-2.5 backdrop-blur sm:static sm:mx-0 sm:border-0 sm:bg-transparent sm:p-0 sm:backdrop-blur-none",
          )}
        >
          <Button type="submit" className="ax-press ax-tap" disabled={busy}>
            {busy ? <BrandSpinner className="size-4" /> : <Send className="size-4" />}
            <span>{proMail && scheduling ? "Schedule" : "Send"}</span>
          </Button>
          {proMail ? (
            <Button
              type="button"
              variant="ghost"
              className="ax-press ax-tap"
              onClick={() => setScheduling((v) => !v)}
            >
              <Clock className="size-4" />
              {scheduling ? "Send now instead" : "Schedule send"}
            </Button>
          ) : null}
          {followUpDays > 0 && (
            <span className="flex items-center gap-1 text-[10px] text-steel">
              <BellRing className="size-3" />
              follow-up in {followUpDays}d
            </span>
          )}
          <span className="ml-auto hidden items-center gap-2 text-[10px] text-steel sm:flex">
            <FileText className="size-3" />
            {stats.words} words{proMail ? ` · ${stats.seconds}s read · ${stats.level}` : ""}
            {savedAt ? ` · saved ${new Date(savedAt).toLocaleTimeString()}` : ""}
          </span>
        </div>
      </div>
    </form>
  );
}

function reportFailure(notWired: boolean, message: string, endpoint: string) {
  notify.failed(notWired ? "Not wired yet" : "Not sent", {
    description: notWired
      ? `Your draft stays here. ${endpoint} is pending on the server.`
      : message,
  });
}
