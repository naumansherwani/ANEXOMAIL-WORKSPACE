/**
 * "Bring your old mail" — what a person is told about a mailbox copy. Pure (no network, no React) so it is unit-tested:
 * docs/cursor-work/frontend/tests/migration-report.test.ts.
 *
 * Truth rule: every number and every sentence comes from the engine's own session row (`migration.status` / `.list`) or
 * from the evidence check (`migration.verify`). "Done" is only said when the session is sealed; a copy that stopped
 * is never described as finished; the receipt is only called "intact" when BOTH checks (Rust and database) agree and the
 * sealed head equals the receipt the person was given.
 */

export type MigStatus = "created" | "verified" | "running" | "completed" | "failed" | "cancelled";

export type MigSession = {
  id: string;
  mailbox: string;
  provider: string;
  source_login: string;
  status: MigStatus;
  locked: boolean;
  /** open session whose worker has been silent for 3 minutes (restart / dropped) — can be resumed */
  stale: boolean;
  cancel_requested: boolean;
  current_folder: string | null;
  folders_total: number;
  folders_done: number;
  skipped_folders: { name: string; why: string }[] | null;
  found: number;
  copied: number;
  duplicate: number;
  skipped: number;
  failed: number;
  bytes: number;
  last_error: string | null;
  chain_len: number;
  seal_hash: string | null;
  created_at: string;
  started_at: string | null;
  heartbeat_at: string | null;
  finished_at: string | null;
};

export type MigProvider = {
  id: string;
  label: string;
  host: string;
  port: number;
  note: string;
  custom: boolean;
};

export type MigVerify = {
  ok: boolean;
  session_id?: string;
  entries: number;
  expected_entries: number;
  head: string;
  sealed: boolean;
  seal_hash: string;
  matches_seal: boolean;
  rust_check: boolean;
  database_check: boolean;
  partial: boolean;
  broken_at: number | null;
  why: string | null;
};

export type Phase = "connecting" | "copying" | "stopped" | "cancelling" | "done" | "cancelled" | "failed";

export function phaseOf(s: MigSession): Phase {
  if (s.status === "completed") return "done";
  if (s.status === "cancelled") return "cancelled";
  if (s.status === "failed") return "failed";
  if (s.stale) return "stopped";
  if (s.cancel_requested) return "cancelling";
  if (s.status === "running") return "copying";
  return "connecting";
}

/** A copy that is not finished or sealed: one at a time per mailbox. */
export function isOpen(s: MigSession): boolean {
  return !s.locked && (s.status === "created" || s.status === "verified" || s.status === "running");
}

/** The copy the page should show live: the newest open one. */
export function activeSession(list: MigSession[] | undefined): MigSession | undefined {
  return (list ?? []).find(isOpen);
}

const handled = (s: MigSession) => s.copied + s.duplicate + s.skipped + s.failed;

/** 0–100 once the engine knows how many e-mails there are; null before that (never a made-up percentage). */
export function progressPct(s: MigSession): number | null {
  if (s.status === "completed") return 100;
  if (!s.found || s.found <= 0) return null;
  const p = Math.floor((handled(s) / s.found) * 100);
  // the engine counts folders as it opens them, so never show 100 before the seal
  return Math.max(0, Math.min(p, 99));
}

export function formatBytes(n: number): string {
  if (!Number.isFinite(n) || n <= 0) return "0 MB";
  const mb = n / (1024 * 1024);
  if (mb < 1) return "under 1 MB";
  if (mb < 1024) return `${mb >= 100 ? Math.round(mb) : Math.round(mb * 10) / 10} MB`;
  const gb = mb / 1024;
  return `${Math.round(gb * 10) / 10} GB`;
}

const plural = (n: number, one: string, many: string) => `${n.toLocaleString("en-GB")} ${n === 1 ? one : many}`;

/** Why the copy stopped — plain words for the engine's stable codes. */
export function stopReason(code: string | null | undefined): string {
  switch (code) {
    case "auth_failed":
      return "the old provider refused the password";
    case "tls_failed":
      return "a secure connection to the old provider could not be made";
    case "provider_throttled":
      return "the old provider asked us to slow down";
    case "connection_lost":
      return "the connection to the old provider dropped";
    case "folder_changed":
      return "the old provider renumbered a folder";
    case "time_limit":
      return "this copy reached its time limit";
    case "cancelled_by_user":
      return "you cancelled it";
    case "abandoned":
      return "it was never started";
    case "worker_error":
      return "something went wrong on our side";
    default:
      return "";
  }
}

export type Tone = "info" | "ok" | "warn" | "bad";

export function describeSession(s: MigSession): { title: string; detail: string; tone: Tone } {
  const ph = phaseOf(s);
  const why = stopReason(s.last_error);
  switch (ph) {
    case "done": {
      const bits = [`${plural(s.copied, "e-mail", "e-mails")} copied`];
      if (s.duplicate) bits.push(`${s.duplicate.toLocaleString("en-GB")} already here`);
      if (s.skipped) bits.push(`${s.skipped.toLocaleString("en-GB")} too large to copy`);
      if (s.failed) bits.push(`${s.failed.toLocaleString("en-GB")} could not be read`);
      return {
        title: "Copy finished and sealed",
        detail: `${bits.join(" · ")}. The old mailbox was not changed.`,
        tone: s.failed || s.skipped ? "warn" : "ok",
      };
    }
    case "cancelled":
      return {
        title: "Copy cancelled",
        detail: `${plural(s.copied, "e-mail", "e-mails")} were copied before it stopped. You can start again — nothing is copied twice.`,
        tone: "info",
      };
    case "failed":
      return {
        title: "Copy did not start",
        detail: why ? `Stopped because ${why}.` : "The old provider did not accept the login.",
        tone: "bad",
      };
    case "stopped":
      return {
        title: "Copy paused",
        detail: `${why ? `Stopped because ${why}. ` : "It stopped. "}${plural(s.copied, "e-mail", "e-mails")} are already in. Resume to continue where it stopped — nothing is copied twice.`,
        tone: "warn",
      };
    case "cancelling":
      return { title: "Stopping…", detail: "It will stop after the batch it is on.", tone: "info" };
    case "copying": {
      const where = s.current_folder ? ` Now in “${s.current_folder}”.` : "";
      return {
        title: "Copying your mail",
        detail: `${plural(handled(s), "e-mail", "e-mails")} of ${s.found ? s.found.toLocaleString("en-GB") : "…"} done.${where}`,
        tone: "info",
      };
    }
    default:
      return { title: "Connecting to the old provider…", detail: "Logging in. This usually takes a few seconds.", tone: "info" };
  }
}

/** Folders we did not copy, in words (shown under the counts so nothing is silently left out). */
export function skippedFolderLine(list: MigSession["skipped_folders"]): string[] {
  const label = (why: string) => {
    switch (why) {
      case "duplicate_view":
        return "it only shows mail that is already in your other folders";
      case "trash_or_spam_not_requested":
        return "Trash and Spam were not requested";
      case "not_a_mailbox":
        return "it is not a mail folder";
      case "could_not_open":
        return "the old provider would not open it";
      default:
        return "skipped";
    }
  };
  return (list ?? []).map((f) => `${f.name} — ${label(f.why)}`);
}

/** The evidence receipt check. "intact" only when both checks agree and the sealed head equals the receipt. */
export function describeVerify(v: MigVerify | undefined): { title: string; detail: string; tone: Tone } | null {
  if (!v) return null;
  if (v.ok) {
    return {
      title: "Receipt checked — the record is intact",
      detail: `All ${v.entries.toLocaleString("en-GB")} entries in the copy record link up, our two independent checks agree, and the record ends exactly at your receipt code.`,
      tone: "ok",
    };
  }
  if (v.partial) {
    return { title: "Receipt only partly checked", detail: "This copy is very large; part of its record was not re-checked yet. Try again.", tone: "warn" };
  }
  if (v.broken_at != null) {
    return {
      title: "The copy record does not add up",
      detail: `Entry ${v.broken_at} does not match what was recorded (${v.why ?? "unknown"}). Keep this screen and contact support — do not delete anything.`,
      tone: "bad",
    };
  }
  if (!v.database_check || !v.rust_check) {
    return { title: "The two checks disagree", detail: "One of our two independent checks failed. Contact support and keep this receipt.", tone: "bad" };
  }
  if (v.sealed && !v.matches_seal) {
    return { title: "Receipt code does not match", detail: "The record is intact but does not end at your receipt code. Contact support.", tone: "bad" };
  }
  return { title: "Could not confirm the receipt", detail: "Try again in a moment.", tone: "warn" };
}

/** "9f3c…a41b" — enough to compare by eye; the full code is copyable. */
export function shortHash(h: string | null | undefined): string {
  if (!h) return "";
  return h.length > 16 ? `${h.slice(0, 8)}…${h.slice(-8)}` : h;
}
