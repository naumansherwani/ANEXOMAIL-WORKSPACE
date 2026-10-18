import { describe, expect, test } from "bun:test";

import {
  activeSession,
  describeSession,
  describeVerify,
  formatBytes,
  isOpen,
  phaseOf,
  progressPct,
  shortHash,
  skippedFolderLine,
  stopReason,
  type MigSession,
  type MigVerify,
} from "../../../../src/lib/migration-report";

const base: MigSession = {
  id: "11111111-1111-1111-1111-111111111111",
  mailbox: "me@acme.co.uk",
  provider: "gmail",
  source_login: "me@gmail.com",
  status: "running",
  locked: false,
  stale: false,
  cancel_requested: false,
  current_folder: "INBOX",
  folders_total: 3,
  folders_done: 1,
  skipped_folders: [],
  found: 200,
  copied: 80,
  duplicate: 10,
  skipped: 0,
  failed: 0,
  bytes: 300 * 1024 * 1024,
  last_error: null,
  chain_len: 90,
  seal_hash: null,
  created_at: "2026-10-19T00:00:00Z",
  started_at: "2026-10-19T00:00:05Z",
  heartbeat_at: "2026-10-19T00:05:00Z",
  finished_at: null,
};

const s = (o: Partial<MigSession>): MigSession => ({ ...base, ...o });

describe("phase — what state the copy is really in", () => {
  test("running with a fresh heartbeat is copying", () => expect(phaseOf(s({}))).toBe("copying"));
  test("created / verified is still connecting", () => {
    expect(phaseOf(s({ status: "created" }))).toBe("connecting");
    expect(phaseOf(s({ status: "verified" }))).toBe("connecting");
  });
  test("a silent worker is 'paused', not 'copying' (this is the Resume case)", () => {
    expect(phaseOf(s({ stale: true }))).toBe("stopped");
    expect(phaseOf(s({ status: "verified", stale: true }))).toBe("stopped");
  });
  test("cancel asked but worker alive is 'stopping'", () => expect(phaseOf(s({ cancel_requested: true }))).toBe("cancelling"));
  test("closed sessions", () => {
    expect(phaseOf(s({ status: "completed", locked: true }))).toBe("done");
    expect(phaseOf(s({ status: "cancelled", locked: true }))).toBe("cancelled");
    expect(phaseOf(s({ status: "failed", locked: true }))).toBe("failed");
  });
  test("only open, unlocked sessions are active; the newest open one is picked", () => {
    expect(isOpen(s({}))).toBe(true);
    expect(isOpen(s({ status: "completed", locked: true }))).toBe(false);
    expect(isOpen(s({ locked: true }))).toBe(false);
    const list = [s({ id: "a", status: "completed", locked: true }), s({ id: "b" }), s({ id: "c", stale: true })];
    expect(activeSession(list)?.id).toBe("b");
    expect(activeSession([])).toBeUndefined();
    expect(activeSession(undefined)).toBeUndefined();
  });
});

describe("progress — never a made-up percentage", () => {
  test("unknown before the engine has counted", () => expect(progressPct(s({ found: 0 }))).toBeNull());
  test("handled / found, floored", () => expect(progressPct(s({ found: 200, copied: 80, duplicate: 10 }))).toBe(45));
  test("never 100 before the seal", () => expect(progressPct(s({ found: 10, copied: 10 }))).toBe(99));
  test("100 only when sealed as completed", () => expect(progressPct(s({ status: "completed", locked: true, found: 10, copied: 10 }))).toBe(100));
  test("bytes", () => {
    expect(formatBytes(0)).toBe("0 MB");
    expect(formatBytes(300 * 1024)).toBe("under 1 MB");
    expect(formatBytes(5.5 * 1024 * 1024)).toBe("5.5 MB");
    expect(formatBytes(512 * 1024 * 1024)).toBe("512 MB");
    expect(formatBytes(3.25 * 1024 * 1024 * 1024)).toBe("3.3 GB");
  });
});

describe("describeSession — says only what is true", () => {
  test("finished: counts what was copied and what was not, and says the old mailbox was untouched", () => {
    const d = describeSession(s({ status: "completed", locked: true, copied: 1200, duplicate: 30, skipped: 2, failed: 0 }));
    expect(d.title).toBe("Copy finished and sealed");
    expect(d.detail).toContain("1,200 e-mails copied");
    expect(d.detail).toContain("30 already here");
    expect(d.detail).toContain("2 too large to copy");
    expect(d.detail).toContain("old mailbox was not changed");
    expect(d.tone).toBe("warn"); // something was left out: never a plain green tick
  });
  test("clean finish is green", () => expect(describeSession(s({ status: "completed", locked: true, copied: 5 })).tone).toBe("ok"));
  test("one e-mail is singular", () => expect(describeSession(s({ status: "completed", locked: true, copied: 1 })).detail).toContain("1 e-mail copied"));
  test("a stopped copy is never called finished and says why + that Resume is safe", () => {
    const d = describeSession(s({ stale: true, last_error: "connection_lost" }));
    expect(d.title).toBe("Copy paused");
    expect(d.detail).toContain("the connection to the old provider dropped");
    expect(d.detail).toContain("Resume");
    expect(d.detail).toContain("nothing is copied twice");
    expect(d.tone).toBe("warn");
  });
  test("login refused", () => {
    const d = describeSession(s({ status: "failed", locked: true, last_error: "auth_failed", copied: 0 }));
    expect(d.title).toBe("Copy did not start");
    expect(d.detail).toContain("refused the password");
    expect(d.tone).toBe("bad");
  });
  test("live copy shows the folder and 'of N'", () => {
    const d = describeSession(s({}));
    expect(d.detail).toContain("90 e-mails of 200 done");
    expect(d.detail).toContain("“INBOX”");
  });
  test("before the first count, no fake total", () => expect(describeSession(s({ found: 0, copied: 0, duplicate: 0 })).detail).toContain("of … done"));
  test("cancelled keeps what was copied", () => expect(describeSession(s({ status: "cancelled", locked: true, copied: 40 })).detail).toContain("40 e-mails were copied"));
  test("every engine stop code has words and unknown codes say nothing wrong", () => {
    for (const c of ["auth_failed", "tls_failed", "provider_throttled", "connection_lost", "folder_changed", "time_limit", "cancelled_by_user", "abandoned", "worker_error"]) {
      expect(stopReason(c).length).toBeGreaterThan(5);
    }
    expect(stopReason(null)).toBe("");
    expect(stopReason("something_new")).toBe("");
  });
});

describe("skipped folders are listed, not hidden", () => {
  test("words for each reason", () => {
    const lines = skippedFolderLine([
      { name: "[Gmail]/All Mail", why: "duplicate_view" },
      { name: "Trash", why: "trash_or_spam_not_requested" },
      { name: "Weird", why: "could_not_open" },
    ]);
    expect(lines[0]).toContain("already in your other folders");
    expect(lines[1]).toContain("Trash and Spam were not requested");
    expect(lines[2]).toContain("would not open it");
    expect(skippedFolderLine(null)).toEqual([]);
  });
});

describe("receipt check — intact only when everything agrees", () => {
  const ok: MigVerify = {
    ok: true,
    entries: 1203,
    expected_entries: 1203,
    head: "a".repeat(64),
    sealed: true,
    seal_hash: "a".repeat(64),
    matches_seal: true,
    rust_check: true,
    database_check: true,
    partial: false,
    broken_at: null,
    why: null,
  };
  test("all good", () => {
    const d = describeVerify(ok)!;
    expect(d.tone).toBe("ok");
    expect(d.detail).toContain("1,203 entries");
    expect(d.detail).toContain("two independent checks agree");
  });
  test("a broken link names the entry and says do not delete", () => {
    const d = describeVerify({ ...ok, ok: false, rust_check: false, broken_at: 17, why: "entry_hash_mismatch" })!;
    expect(d.tone).toBe("bad");
    expect(d.detail).toContain("Entry 17");
    expect(d.detail).toContain("do not delete");
  });
  test("checks that disagree are bad news, not a green tick", () => {
    expect(describeVerify({ ...ok, ok: false, database_check: false })!.tone).toBe("bad");
    expect(describeVerify({ ...ok, ok: false, rust_check: false })!.tone).toBe("bad");
  });
  test("an intact record that does not end at the receipt is flagged", () => {
    expect(describeVerify({ ...ok, ok: false, matches_seal: false })!.title).toBe("Receipt code does not match");
  });
  test("partial is a warning", () => expect(describeVerify({ ...ok, ok: false, partial: true })!.tone).toBe("warn"));
  test("nothing yet", () => expect(describeVerify(undefined)).toBeNull());
  test("short hash for eyes, full for copy", () => {
    expect(shortHash("a".repeat(64))).toBe("aaaaaaaa…aaaaaaaa");
    expect(shortHash("abc")).toBe("abc");
    expect(shortHash(null)).toBe("");
  });
});
