// Import mail — one page, two doors (20 Oct 2026, Basic live review: customers could not find it).
//   /app/import        every signed-in customer (Basic, Pro, Business, Business Pro) — copy YOUR old mailbox in
//   /app/admin/migrate founder's platform-admin surface (unchanged)
// Backend: Rust :3200 `migration.*` (G30, walled garden E35) — this file is only the screen.
import { useEffect, useMemo, useState } from "react";
import { AlertTriangle, Check, CheckCircle2, Copy, Inbox, Loader2, RotateCcw, ShieldCheck, X } from "lucide-react";

import { ListSkeleton } from "@/components/state/Skeletons";
import { ErrorState, StateBlock } from "@/components/state/StateBlock";
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from "@/components/ui/alert-dialog";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import type { ApiError } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { useAddresses } from "@/lib/domains";
import {
  activeSession,
  describeSession,
  describeVerify,
  formatBytes,
  isNotSwitchedOn,
  phaseOf,
  progressPct,
  shortHash,
  skippedFolderLine,
  useMigrationMutations,
  useMigrations,
  useProviders,
  type MigProvider,
  type MigSession,
  type MigVerify,
  type Tone,
} from "@/lib/migration";
import { notify } from "@/lib/notify";



const toneClass: Record<Tone, string> = {
  info: "border-border bg-card text-foreground",
  ok: "border-success/40 bg-success/10 text-foreground",
  warn: "border-warning/50 bg-warning/10 text-foreground",
  bad: "border-danger/40 bg-danger/10 text-foreground",
};

function ToneIcon({ tone, busy }: { tone: Tone; busy?: boolean }) {
  if (busy) return <Loader2 className="size-5 animate-spin text-cyan-accent" aria-hidden="true" />;
  if (tone === "ok") return <CheckCircle2 className="size-5 text-success" aria-hidden="true" />;
  if (tone === "bad") return <X className="size-5 text-danger" aria-hidden="true" />;
  if (tone === "warn") return <AlertTriangle className="size-5 text-warning" aria-hidden="true" />;
  return <Inbox className="size-5 text-cyan-accent" aria-hidden="true" />;
}

export function ImportMailPage() {
  const { organisation, session } = useAuth();
  const orgId = organisation?.id;
  const canManage = organisation?.role === "owner" || organisation?.role === "admin";

  const list = useMigrations(orgId);
  const providers = useProviders();
  const addresses = useAddresses();
  const m = useMigrationMutations(orgId);

  const sessions = list.data?.sessions ?? [];
  const active = activeSession(sessions);
  const closed = sessions.filter((s) => s !== active);

  // receipts the person asked to re-check (kept for this visit only)
  const [receipts, setReceipts] = useState<Record<string, MigVerify>>({});
  const checkReceipt = (id: string) =>
    m.verify.mutate(id, {
      onSuccess: (v) => setReceipts((r) => ({ ...r, [id]: v })),
      onError: (e: ApiError) => notify.failed("Receipt not checked", { description: e.message }),
    });

  if (!organisation) {
    return (
      <div className="mx-auto w-full max-w-3xl px-6 py-10 md:px-10">
        <StateBlock title="No organisation yet" body="Create your organisation first — mail is copied into one of its mailboxes." />
      </div>
    );
  }

  const mailboxes = (addresses.data?.addresses ?? []).filter((a) => a.kind === "mailbox" && a.active);
  const mine = canManage ? mailboxes : mailboxes.filter((a) => a.owner_user_id === session?.user.id);
  // Har plan (Basic bhi): apna login pata (you@anexomail.com) hamesha pehla nishana — `mail.addresses.list` use
  // company addresses se alag `login_address` mein deta hai. Rust/E35 isay qubool karta hai (user ka apna email).
  const login = (addresses.data?.login_address ?? "").trim().toLowerCase();
  const targets = Array.from(new Set([...(login ? [login] : []), ...mine.map((a) => a.address.toLowerCase())]));

  return (
    <div className="mx-auto w-full max-w-3xl px-ax-4 py-ax-6 md:px-10 md:py-10">
      <p className="ax-eyebrow">Move in</p>
      <h2 className="mt-3 text-3xl text-foreground">Import mail</h2>
      <p className="mt-4 text-sm leading-relaxed text-muted-foreground">
        Bring the mail from your old provider into ANEXOMAIL. We only <strong className="text-foreground">read</strong> your old
        mailbox — nothing there is moved, marked as read or deleted — and when the copy ends you get a sealed receipt you can
        check.
      </p>

      {list.isLoading ? (
        <div className="mt-8">
          <ListSkeleton rows={3} />
        </div>
      ) : list.error && isNotSwitchedOn(list.error) ? (
        <StateBlock
          className="mt-8"
          title="Mail import isn't switched on yet"
          body="This server has not been updated for mail import. Nothing is wrong with your account — it will appear here as soon as the update is done."
        />
      ) : list.error ? (
        <div className="mt-8">
          <ErrorState body={list.error.message} onRetry={() => void list.refetch()} />
        </div>
      ) : (
        <>
          {active ? (
            <ActiveCard
              s={active}
              busyCancel={m.cancel.isPending}
              busyResume={m.resume.isPending}
              onCancel={() =>
                m.cancel.mutate(active.id, {
                  onSuccess: (r) =>
                    r.requested
                      ? notify.info("Stopping the copy", "It stops after the batch it is on.")
                      : notify.done("Copy cancelled", "What was copied stays. Nothing is copied twice if you start again."),
                  onError: (e: ApiError) => notify.failed("Not cancelled", { description: e.message }),
                })
              }
              onResume={(password, done) =>
                m.resume.mutate(
                  { session_id: active.id, password },
                  {
                    onSuccess: (r) =>
                      r.connecting
                        ? notify.info("Reconnecting…", "The old provider is slow to answer; this page updates by itself.")
                        : notify.done("Copy resumed", "It continues where it stopped."),
                    onError: (e: ApiError) => notify.failed("Could not resume", { description: e.message }),
                    onSettled: done,
                  },
                )
              }
            />
          ) : (
            <StartForm
              providers={providers.data?.providers ?? []}
              providersFailed={Boolean(providers.error)}
              mailboxes={targets}
              preferred={addresses.data?.login_address || mine.find((a) => a.owner_user_id === session?.user.id)?.address}
              noMailboxes={Boolean(addresses.data) && targets.length === 0}
              pending={m.start.isPending}
              onStart={(input, done) =>
                m.start.mutate(input, {
                  onSuccess: (r) =>
                    r.connecting
                      ? notify.info("Connecting…", "The old provider is slow to answer; this page updates by itself.")
                      : notify.done("Signed in — copying has started", "You can leave this page; the copy keeps running."),
                  onError: (e: ApiError) => notify.failed("Copy not started", { description: e.message }),
                  onSettled: done,
                })
              }
            />
          )}

          <section className="mt-8 rounded-2xl border border-border bg-card p-5" aria-labelledby="what-copied">
            <h3 id="what-copied" className="ax-label text-foreground">
              What is copied — and what is not
            </h3>
            <ul className="ax-caption mt-2 list-disc space-y-1 pl-5 text-muted-foreground">
              <li>E-mails with sender, recipients, dates, subject, text, read and starred state, in the folders they came from.</li>
              <li>E-mails already here are skipped, so running it twice never doubles anything.</li>
              <li>Attachment files are not copied yet — e-mails that had attachments are marked.</li>
              <li>Your App Password is kept in memory only while the copy runs. It is never saved to disk or the database, and never written to logs.</li>
            </ul>
          </section>

          {closed.length > 0 && (
            <section className="mt-8">
              <h3 className="ax-label text-foreground">Earlier copies</h3>
              <ul className="mt-3 space-y-2">
                {closed.slice(0, 10).map((s) => (
                  <HistoryRow
                    key={s.id}
                    s={s}
                    verify={receipts[s.id]}
                    checking={m.verify.isPending && m.verify.variables === s.id}
                    onCheck={() => checkReceipt(s.id)}
                  />
                ))}
              </ul>
            </section>
          )}
        </>
      )}
    </div>
  );
}

/* ------------------------------------------------------------------ start */

function StartForm({
  providers,
  providersFailed,
  mailboxes,
  preferred,
  noMailboxes,
  pending,
  onStart,
}: {
  providers: MigProvider[];
  providersFailed: boolean;
  mailboxes: string[];
  preferred: string | undefined;
  noMailboxes: boolean;
  pending: boolean;
  onStart: (
    input: { mailbox: string; provider: string; host?: string; login: string; password: string; include_trash_spam: boolean },
    done: () => void,
  ) => void;
}) {
  const [mailbox, setMailbox] = useState("");
  const [providerId, setProviderId] = useState("gmail");
  const [host, setHost] = useState("");
  const [login, setLogin] = useState("");
  const [password, setPassword] = useState("");
  const [trashSpam, setTrashSpam] = useState(false);

  useEffect(() => {
    if (!mailbox) setMailbox(preferred && mailboxes.includes(preferred) ? preferred : (mailboxes[0] ?? ""));
  }, [mailbox, mailboxes, preferred]);

  const provider = useMemo(() => providers.find((p) => p.id === providerId), [providers, providerId]);
  const ready =
    mailbox !== "" && login.trim() !== "" && password !== "" && (!provider?.custom || host.trim() !== "") && !pending && Boolean(provider);

  if (noMailboxes) {
    return (
      <StateBlock
        className="mt-8"
        title="No mailbox to copy into"
        body="Mail is copied into a mailbox here. Add one under Domains first, then come back."
      />
    );
  }

  return (
    <form
      className="mt-8 rounded-2xl border border-border bg-card p-5"
      autoComplete="off"
      onSubmit={(event) => {
        event.preventDefault();
        if (!ready) return;
        const pw = password;
        // the password leaves this form the moment it is sent
        setPassword("");
        onStart(
          {
            mailbox,
            provider: providerId,
            ...(provider?.custom ? { host: host.trim() } : {}),
            login: login.trim(),
            password: pw,
            include_trash_spam: trashSpam,
          },
          () => setPassword(""),
        );
      }}
    >
      <h3 className="ax-label text-foreground">Copy a mailbox</h3>

      <div className="mt-3 space-y-1.5">
        <Label htmlFor="mig-mailbox" className="ax-caption text-foreground">
          Copy into
        </Label>
        <select
          id="mig-mailbox"
          value={mailbox}
          onChange={(event) => setMailbox(event.target.value)}
          className="ax-tap w-full min-w-0 rounded-md border border-border bg-background px-2 py-2 text-base"
        >
          {mailboxes.map((a) => (
            <option key={a} value={a}>
              {a}
            </option>
          ))}
        </select>
      </div>

      <div className="mt-3 space-y-1.5">
        <Label htmlFor="mig-provider" className="ax-caption text-foreground">
          Old provider
        </Label>
        <select
          id="mig-provider"
          value={providerId}
          onChange={(event) => setProviderId(event.target.value)}
          className="ax-tap w-full min-w-0 rounded-md border border-border bg-background px-2 py-2 text-base"
        >
          {providers.map((p) => (
            <option key={p.id} value={p.id}>
              {p.label}
            </option>
          ))}
        </select>
        {providersFailed ? (
          <p className="ax-caption text-danger" role="alert">
            The provider list could not be loaded. Reload the page.
          </p>
        ) : provider ? (
          <p className="ax-caption text-muted-foreground">{provider.note}</p>
        ) : null}
      </div>

      {provider?.custom && (
        <div className="mt-3 space-y-1.5">
          <Label htmlFor="mig-host" className="ax-caption text-foreground">
            IMAP server
          </Label>
          <Input
            id="mig-host"
            value={host}
            onChange={(event) => setHost(event.target.value)}
            placeholder="imap.example.com"
            autoCapitalize="none"
            autoCorrect="off"
            spellCheck={false}
            inputMode="url"
          />
          <p className="ax-caption text-muted-foreground">Secure connections only (port 993).</p>
        </div>
      )}

      <div className="mt-3 space-y-1.5">
        <Label htmlFor="mig-login" className="ax-caption text-foreground">
          Your e-mail address at the old provider
        </Label>
        <Input
          id="mig-login"
          type="email"
          value={login}
          onChange={(event) => setLogin(event.target.value)}
          placeholder="you@gmail.com"
          autoCapitalize="none"
          autoCorrect="off"
          spellCheck={false}
          autoComplete="off"
        />
      </div>

      <div className="mt-3 space-y-1.5">
        <Label htmlFor="mig-password" className="ax-caption text-foreground">
          App Password
        </Label>
        <Input
          id="mig-password"
          type="password"
          name="migration-app-password"
          value={password}
          onChange={(event) => setPassword(event.target.value)}
          autoComplete="new-password"
          autoCapitalize="none"
          autoCorrect="off"
          spellCheck={false}
          data-1p-ignore
          data-lpignore="true"
        />
      </div>

      <label className="mt-4 flex items-start gap-2 text-sm text-foreground">
        <input
          type="checkbox"
          checked={trashSpam}
          onChange={(event) => setTrashSpam(event.target.checked)}
          className="mt-1 size-4 shrink-0"
        />
        <span>
          Also copy Trash and Spam <span className="text-muted-foreground">(off by default)</span>
        </span>
      </label>

      <Button type="submit" className="ax-press mt-5 w-full sm:w-auto" disabled={!ready}>
        {pending ? <Loader2 className="size-4 animate-spin" /> : <Inbox className="size-4" />}
        {pending ? "Signing in…" : "Start copying"}
      </Button>
    </form>
  );
}

/* ------------------------------------------------------------------ live copy */

function Stat({ label, value }: { label: string; value: number }) {
  return (
    <div className="rounded-xl border border-border bg-background px-3 py-2">
      <p className="ax-caption text-muted-foreground">{label}</p>
      <p className="text-lg font-semibold tabular-nums text-foreground">{value.toLocaleString("en-GB")}</p>
    </div>
  );
}

function ActiveCard({
  s,
  busyCancel,
  busyResume,
  onCancel,
  onResume,
}: {
  s: MigSession;
  busyCancel: boolean;
  busyResume: boolean;
  onCancel: () => void;
  onResume: (password: string, done: () => void) => void;
}) {
  const ph = phaseOf(s);
  const d = describeSession(s);
  const pct = progressPct(s);
  const [confirm, setConfirm] = useState(false);
  const [password, setPassword] = useState("");
  const skipped = skippedFolderLine(s.skipped_folders);
  const live = ph === "copying" || ph === "connecting" || ph === "cancelling";

  return (
    <section className="mt-8 rounded-2xl border border-border bg-card p-5" aria-labelledby="mig-live">
      <p className="ax-caption text-muted-foreground">
        {s.source_login} → {s.mailbox}
      </p>
      <div className={`mt-2 flex items-start gap-3 rounded-xl border px-4 py-3 ${toneClass[d.tone]}`} role="status" aria-live="polite">
        <span className="mt-0.5 shrink-0">
          <ToneIcon tone={d.tone} busy={live} />
        </span>
        <div className="min-w-0">
          <h3 id="mig-live" className="ax-label text-foreground">
            {d.title}
          </h3>
          <p className="ax-caption mt-1 break-words text-muted-foreground">{d.detail}</p>
        </div>
      </div>

      <div
        className="mt-4 h-2 w-full overflow-hidden rounded-full bg-secondary"
        role="progressbar"
        aria-label="Copy progress"
        aria-valuemin={0}
        aria-valuemax={100}
        {...(pct != null ? { "aria-valuenow": pct } : {})}
      >
        <div
          className={`h-full rounded-full bg-cyan-accent transition-[width] duration-500 ${pct == null ? "w-1/5 animate-pulse" : ""}`}
          style={pct != null ? { width: `${pct}%` } : undefined}
        />
      </div>
      <p className="ax-caption mt-1 text-muted-foreground">
        {pct != null ? `${pct}%` : "Counting…"} · {formatBytes(s.bytes)} copied · folder {Math.min(s.folders_done + 1, Math.max(s.folders_total, 1))} of{" "}
        {Math.max(s.folders_total, 1)}
      </p>

      <div className="mt-4 grid grid-cols-2 gap-2 sm:grid-cols-5">
        <Stat label="Found" value={s.found} />
        <Stat label="Copied" value={s.copied} />
        <Stat label="Already here" value={s.duplicate} />
        <Stat label="Too large" value={s.skipped} />
        <Stat label="Not readable" value={s.failed} />
      </div>

      {skipped.length > 0 && (
        <details className="mt-3">
          <summary className="ax-caption cursor-pointer text-muted-foreground">{skipped.length} folder{skipped.length === 1 ? "" : "s"} not copied</summary>
          <ul className="ax-caption mt-2 list-disc space-y-1 pl-5 text-muted-foreground">
            {skipped.map((line) => (
              <li key={line} className="break-words">
                {line}
              </li>
            ))}
          </ul>
        </details>
      )}

      {ph === "stopped" && (
        <form
          className="mt-4 space-y-2 rounded-xl border border-border bg-background p-4"
          autoComplete="off"
          onSubmit={(event) => {
            event.preventDefault();
            if (!password) return;
            const pw = password;
            setPassword("");
            onResume(pw, () => setPassword(""));
          }}
        >
          <Label htmlFor="mig-resume-password" className="ax-caption text-foreground">
            App Password again (it was never saved)
          </Label>
          <Input
            id="mig-resume-password"
            type="password"
            name="migration-app-password"
            value={password}
            onChange={(event) => setPassword(event.target.value)}
            autoComplete="new-password"
            autoCapitalize="none"
            autoCorrect="off"
            spellCheck={false}
            data-1p-ignore
            data-lpignore="true"
          />
          <Button type="submit" className="ax-press w-full sm:w-auto" disabled={!password || busyResume}>
            {busyResume ? <Loader2 className="size-4 animate-spin" /> : <RotateCcw className="size-4" />}
            Resume
          </Button>
        </form>
      )}

      <div className="mt-4 flex flex-wrap gap-2">
        <Button
          variant="outline"
          className="ax-press w-full sm:w-auto"
          disabled={busyCancel || ph === "cancelling"}
          onClick={() => setConfirm(true)}
        >
          {busyCancel ? <Loader2 className="size-4 animate-spin" /> : <X className="size-4" />}
          {ph === "stopped" ? "Cancel this copy" : "Stop copying"}
        </Button>
      </div>

      <AlertDialog open={confirm} onOpenChange={setConfirm}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>Stop this copy?</AlertDialogTitle>
            <AlertDialogDescription>
              What is already copied stays. The copy is sealed with a receipt, and a new one can start later — e-mails already here are
              never copied twice. Nothing at the old provider is touched.
            </AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>Keep copying</AlertDialogCancel>
            <AlertDialogAction
              onClick={() => {
                setConfirm(false);
                onCancel();
              }}
            >
              Stop
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </section>
  );
}

/* ------------------------------------------------------------------ history + receipt */

function CopyCode({ code }: { code: string }) {
  const [copied, setCopied] = useState(false);
  return (
    <button
      type="button"
      className="ax-focus ax-tap inline-flex items-center gap-1.5 rounded-full bg-secondary px-3 py-1 text-xs font-semibold text-foreground"
      onClick={() => {
        void navigator.clipboard
          ?.writeText(code)
          .then(() => {
            setCopied(true);
            window.setTimeout(() => setCopied(false), 2000);
          })
          .catch(() => notify.failed("Could not copy", { description: "Select the code and copy it by hand." }));
      }}
      aria-label="Copy the full receipt code"
    >
      {copied ? <Check className="size-3.5 text-success" /> : <Copy className="size-3.5" />}
      {copied ? "Copied" : "Copy code"}
    </button>
  );
}

function HistoryRow({
  s,
  verify,
  checking,
  onCheck,
}: {
  s: MigSession;
  verify: MigVerify | undefined;
  checking: boolean;
  onCheck: () => void;
}) {
  const d = describeSession(s);
  const v = describeVerify(verify);
  const sealed = Boolean(s.seal_hash);
  return (
    <li className="rounded-xl border border-border bg-card px-4 py-3">
      <div className="flex items-start gap-3">
        <span className="mt-0.5 shrink-0">
          <ToneIcon tone={d.tone} />
        </span>
        <div className="min-w-0 flex-1">
          <p className="ax-label text-foreground">{d.title}</p>
          <p className="ax-caption break-all text-muted-foreground">
            {s.source_login} → {s.mailbox} · {new Date(s.finished_at ?? s.created_at).toLocaleDateString("en-GB", { day: "numeric", month: "short", year: "numeric" })}
          </p>
          <p className="ax-caption mt-1 break-words text-muted-foreground">{d.detail}</p>
        </div>
      </div>
      {sealed && (
        <div className="mt-3 flex flex-wrap items-center gap-2">
          <ShieldCheck className="size-4 shrink-0 text-cyan-accent" aria-hidden="true" />
          <span className="ax-caption text-muted-foreground">Receipt</span>
          <code className="rounded bg-secondary px-2 py-0.5 text-xs text-foreground" title={s.seal_hash ?? undefined}>
            {shortHash(s.seal_hash)}
          </code>
          <CopyCode code={s.seal_hash ?? ""} />
          <Button variant="outline" size="sm" className="ax-press ax-tap ml-auto" disabled={checking} onClick={onCheck}>
            {checking ? <Loader2 className="size-4 animate-spin" /> : <ShieldCheck className="size-4" />}
            Check receipt
          </Button>
        </div>
      )}
      {v && (
        <div className={`mt-3 rounded-lg border px-3 py-2 ${toneClass[v.tone]}`} role="status">
          <p className="ax-label text-foreground">{v.title}</p>
          <p className="ax-caption mt-1 break-words text-muted-foreground">{v.detail}</p>
        </div>
      )}
    </li>
  );
}
