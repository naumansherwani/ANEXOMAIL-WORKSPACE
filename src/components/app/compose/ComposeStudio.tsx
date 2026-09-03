import {
  AlertTriangle,
  BellRing,
  Clock,
  Crown,
  FileText,
  History,
  Languages,
  Loader2,
  Maximize2,
  Minimize2,
  Paperclip,
  Send,
  ShieldCheck,
  Sparkles,
  Wand2,
  Zap,
} from "lucide-react";
import { useEffect, useMemo, useRef, useState } from "react";

import { GhostTextArea } from "@/components/app/compose/GhostTextArea";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";

import {
  applyVariables,
  findVariables,
  readingStats,
  useAskJimmy,
  useCreateFollowUp,
  useDraftVersions,
  useLeoCompose,
  useSaveDraft,
  useScheduleSend,
  useSendConfidence,
  useSignatures,
  useSnippets,
  useTemplates,
  type ComposeTone,
  type DraftPayload,
} from "@/lib/compose";
import { learnWritingPattern } from "@/lib/mail-predict";
import { notify } from "@/lib/notify";
import { useSendMail } from "@/lib/mail";
import { cn } from "@/lib/utils";

const TONES: { id: ComposeTone; label: string }[] = [
  { id: "warm", label: "Warm" },
  { id: "direct", label: "Direct" },
  { id: "formal", label: "Formal" },
  { id: "short", label: "Shorter" },
  { id: "apologetic", label: "Apologetic" },
];

const LANGUAGES = ["English", "Urdu", "Arabic", "French", "German", "Spanish", "Chinese"];

/** How long an outgoing mail is held on the server before it is queued. */
const UNDO_HOLD_SECONDS = 20;

type StudioProps = {
  threadId?: string;
  initialTo?: string;
  initialSubject?: string;
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
  detectedLanguage,
  inReplyTo,
  onSent,
  variant = "overlay",
}: StudioProps) {
  const [to, setTo] = useState(initialTo);
  const [cc, setCc] = useState("");
  const [bcc, setBcc] = useState("");
  const [showMore, setShowMore] = useState(false);
  const [subject, setSubject] = useState(initialSubject);
  const [body, setBody] = useState("");
  const [sendAt, setSendAt] = useState("");
  const [scheduling, setScheduling] = useState(false);
  const [zen, setZen] = useState(false);
  const [identity, setIdentity] = useState<string>("");
  const [language, setLanguage] = useState(detectedLanguage ?? "English");
  const [attachments, setAttachments] = useState<File[]>([]);
  const [variables, setVariables] = useState<Record<string, string>>({});
  const [draftId, setDraftId] = useState<string | undefined>();
  const [savedAt, setSavedAt] = useState<string | null>(null);
  const [showVersions, setShowVersions] = useState(false);
  const [followUpDays, setFollowUpDays] = useState(0);
  const bodyRef = useRef<HTMLTextAreaElement | null>(null);

  const templates = useTemplates();
  const snippets = useSnippets();
  const signatures = useSignatures();
  const versions = useDraftVersions(showVersions ? draftId : undefined);
  const saveDraft = useSaveDraft();
  const confidence = useSendConfidence();
  const schedule = useScheduleSend();
  const send = useSendMail();
  const leo = useLeoCompose();
  const jimmy = useAskJimmy();
  const followUp = useCreateFollowUp();

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
    [draftId, threadId, identity, to, cc, bcc, subject, body, variables, language, scheduling, sendAt],
  );

  // Autosave every 3s of quiet — the server owns the version history.
  useEffect(() => {
    if (!body.trim() && !subject.trim()) return;
    const timer = setTimeout(() => {
      saveDraft.mutate(payload, {
        onSuccess: (record) => {
          setDraftId(record.id);
          setSavedAt(record.saved_at);
        },
        onError: () => undefined, // silent: offline queue keeps the text on screen
      });
    }, 3000);
    return () => clearTimeout(timer);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [payload]);

  const openVars = findVariables(body).filter((name) => !variables[name]?.trim());
  const stats = readingStats(body);
  const busy = send.isPending || schedule.isPending || confidence.isPending;

  const insertSnippet = (text: string) => {
    const el = bodyRef.current;
    if (!el) {
      setBody((v) => `${v}${text}`);
      return;
    }
    const start = el.selectionStart ?? body.length;
    setBody(`${body.slice(0, start)}${text}${body.slice(el.selectionEnd ?? start)}`);
  };

  const finalSend = () => {
    if (scheduling && sendAt) {
      schedule.mutate(
        { ...payload, hold_seconds: 0 },
        {
          onSuccess: () => {
            notify.done("Scheduled", `Leaves at ${new Date(sendAt).toLocaleString()}.`);
            onSent?.();
          },
          onError: (error) => reportFailure(error.isNotImplemented, error.message, "POST /api/mail/schedule"),
        },
      );
      return;
    }

    // Undo Send = a real server-side hold, not a browser timer.
    schedule.mutate(
      { ...payload, hold_seconds: UNDO_HOLD_SECONDS },
      {
        onSuccess: () => {
          notify.done("Sending", `Held for ${UNDO_HOLD_SECONDS}s — cancel from Sent.`);
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
            { ...payload, ...(inReplyTo ? { in_reply_to: inReplyTo } : {}) },
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
    // Pre-send confidence scan runs server-side first.
    confidence.mutate(
      { ...payload, attachments: attachments.length },
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
      )}
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
          <select
            aria-label="Send as"
            value={identity}
            onChange={(e) => setIdentity(e.target.value)}
            className="h-8 rounded-lg border border-border bg-card px-2 text-[11px] text-foreground"
          >
            <option value="">Send as — default identity</option>
            {signatures.data?.signatures.map((sig) => (
              <option key={sig.id} value={sig.identity}>
                {sig.identity}
              </option>
            ))}
          </select>
          <select
            aria-label="Reply language"
            value={language}
            onChange={(e) => setLanguage(e.target.value)}
            className="h-8 rounded-lg border border-border bg-card px-2 text-[11px] text-foreground"
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
            className="ax-press ml-auto rounded-lg p-1.5 text-steel hover:bg-secondary"
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
            className="ax-press self-start text-[11px] font-semibold text-steel underline-offset-4 hover:underline"
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
          </div>
        </div>

        {/* templates + snippets */}
        <div className="flex flex-wrap items-center gap-2">
          <select
            aria-label="Insert template"
            value=""
            onChange={(e) => {
              const tpl = templates.data?.templates.find((t) => t.id === e.target.value);
              if (!tpl) return;
              if (tpl.subject) setSubject(tpl.subject);
              setBody((v) => (v ? `${v}\n\n${tpl.body}` : tpl.body));
            }}
            className="h-8 rounded-lg border border-border bg-card px-2 text-[11px] text-foreground"
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
          {snippets.data?.snippets.slice(0, 4).map((s) => (
            <button
              key={s.id}
              type="button"
              onClick={() => insertSnippet(s.body)}
              className="ax-press rounded-lg border border-border px-2 py-1 text-[10px] text-muted-foreground hover:text-foreground"
            >
              <Zap className="mr-1 inline size-3" />
              {s.shortcut}
            </button>
          ))}
        </div>

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
          placeholder="Write it once. Leo can tighten it, translate it or coach the tone."
        />


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

        {/* AI row */}
        <div className="flex flex-wrap items-center gap-2">
          <Button
            type="button"
            variant="secondary"
            className="ax-press"
            disabled={leo.isPending}
            onClick={() => runLeo({ task: "COACH" })}
          >
            {leo.isPending ? (
              <Loader2 className="size-4 animate-spin" />
            ) : (
              <Wand2 className="size-4" />
            )}
            Draft coach
          </Button>
          {TONES.map((tone) => (
            <button
              key={tone.id}
              type="button"
              onClick={() => runLeo({ task: "REWRITE", tone: tone.id })}
              disabled={leo.isPending}
              className="ax-press rounded-lg border border-border px-2 py-1 text-[11px] text-muted-foreground hover:text-foreground"
            >
              {tone.label}
            </button>
          ))}
          <button
            type="button"
            onClick={() => runLeo({ task: "TRANSLATE", language })}
            disabled={leo.isPending}
            className="ax-press rounded-lg border border-border px-2 py-1 text-[11px] text-muted-foreground hover:text-foreground"
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
            className="ax-press rounded-lg border border-border px-2 py-1 text-[11px] font-semibold text-foreground hover:bg-secondary"
          >
            <Crown className="mr-1 inline size-3" />
            Jimmy se poochho
          </button>
        </div>

        {/* attachments */}
        <div className="flex flex-wrap items-center gap-2">
          <label className="ax-press flex cursor-pointer items-center gap-1.5 rounded-lg border border-border px-2 py-1 text-[11px] text-muted-foreground hover:text-foreground">
            <Paperclip className="size-3" />
            Attach
            <input
              type="file"
              multiple
              className="hidden"
              onChange={(e) => setAttachments(Array.from(e.target.files ?? []))}
            />
          </label>
          {attachments.map((file) => (
            <span key={file.name} className="text-[10px] text-steel">
              {file.name}
            </span>
          ))}
          <button
            type="button"
            onClick={() => setShowVersions((v) => !v)}
            disabled={!draftId}
            className="ax-press rounded-lg border border-border px-2 py-1 text-[11px] text-muted-foreground disabled:opacity-40"
          >
            <History className="mr-1 inline size-3" />
            Version history
          </button>
          <select
            aria-label="Follow-up promise"
            value={followUpDays}
            onChange={(e) => setFollowUpDays(Number(e.target.value))}
            className="h-8 rounded-lg border border-border bg-card px-2 text-[11px] text-foreground"
          >
            <option value={0}>No follow-up</option>
            <option value={2}>Remind me in 2 days</option>
            <option value={3}>Remind me in 3 days</option>
            <option value={7}>Remind me in a week</option>
          </select>
        </div>

        {showVersions && (
          <div className="ax-plane flex flex-col gap-1.5 rounded-xl p-ax-3">
            {versions.isError ? (
              <p className="text-[11px] text-muted-foreground">
                GET /api/mail/drafts/:id is pending on the server.
              </p>
            ) : versions.isPending ? (
              <p className="text-[11px] text-steel">Loading versions…</p>
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

        {scheduling && (
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

        <div className="flex flex-wrap items-center gap-ax-2">
          <Button type="submit" className="ax-press ax-tap" disabled={busy}>
            {busy ? <Loader2 className="size-4 animate-spin" /> : <Send className="size-4" />}
            <span>{scheduling ? "Schedule" : "Send"}</span>
          </Button>
          <Button
            type="button"
            variant="ghost"
            className="ax-press"
            onClick={() => setScheduling((v) => !v)}
          >
            <Clock className="size-4" />
            {scheduling ? "Send now instead" : "Schedule send"}
          </Button>
          {followUpDays > 0 && (
            <span className="flex items-center gap-1 text-[10px] text-steel">
              <BellRing className="size-3" />
              follow-up in {followUpDays}d
            </span>
          )}
          <span className="ml-auto flex items-center gap-2 text-[10px] text-steel">
            <FileText className="size-3" />
            {stats.words} words · {stats.seconds}s read · {stats.level}
            {savedAt ? ` · saved ${new Date(savedAt).toLocaleTimeString()}` : ""}
          </span>
        </div>
        <p className="text-[10px] text-steel">
          ⌘↵ send · held {UNDO_HOLD_SECONDS}s on the server so you can still stop it
        </p>
      </div>
    </form>
  );
}

function reportFailure(notWired: boolean, message: string, endpoint: string) {
  notify.failed(notWired ? "Not wired yet" : "Not sent", {
    description: notWired ? `Your draft stays here. ${endpoint} is pending on the server.` : message,
  });
}