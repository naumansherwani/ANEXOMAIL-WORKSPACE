import { AlertTriangle, DownloadCloud, ShieldAlert, ShieldCheck, UserCheck } from "lucide-react";
import { useState } from "react";

import { Button } from "@/components/ui/button";
import {
  INTEGRITY_LABEL,
  INTEGRITY_TONE,
  useIntegrityBlock,
  useIntegrityEvaluate,
  useIntegrityExport,
  useIntegrityQueue,
  useIntegrityRelease,
  useIntegrityStatus,
  useIntegrityWarn,
} from "@/lib/account-integrity";
import { relativeTime } from "@/lib/mail";
import { notify } from "@/lib/notify";

/**
 * ACCOUNT INTEGRITY — one person, one account.
 * A block only ever lands on a device shape, never on an address or a network.
 * The engine can flag, but only a person can warn or block, and every decision
 * carries a written reason. A blocked account keeps a full 72 hour export.
 */
export function AccountIntegrityPanel() {
  const q = useIntegrityStatus();
  const queue = useIntegrityQueue("all");
  const evaluate = useIntegrityEvaluate();
  const warn = useIntegrityWarn();
  const block = useIntegrityBlock();
  const release = useIntegrityRelease();
  const exportNow = useIntegrityExport();
  const [busy, setBusy] = useState<string | null>(null);

  const s = q.data;
  const policy = s?.policy;
  const state = s?.state ?? "clean";

  const decide = (kind: "warn" | "block" | "release", userId: string) => {
    const reason = window.prompt(
      kind === "warn"
        ? "Reason for the final warning (at least 12 characters):"
        : kind === "block"
          ? "Reason for blocking this account (at least 12 characters):"
          : "Reason for restoring this account (at least 12 characters):",
    );
    if (!reason || reason.trim().length < 12) {
      notify.failed("Nothing recorded", {
        description: "Every decision needs a written reason of at least 12 characters.",
      });
      return;
    }
    const runner = kind === "warn" ? warn : kind === "block" ? block : release;
    setBusy(userId + kind);
    runner.mutate(
      { user_id: userId, reason: reason.trim() },
      {
        onSuccess: (r) =>
          r.ok
            ? notify.done(
                kind === "warn"
                  ? "Final warning recorded"
                  : kind === "block"
                    ? "Account blocked"
                    : "Account restored",
                kind === "block"
                  ? `Export stays open for ${r.export_hours ?? 72} hours, and the block can be appealed.`
                  : "Written into the permanent record.",
              )
            : notify.failed("Not recorded", { description: r.message ?? r.error ?? "Try again." }),
        onError: (e) => notify.failed("Not recorded", { description: e.message }),
        onSettled: () => setBusy(null),
      },
    );
  };

  return (
    <section className="mt-ax-6 space-y-ax-4">
      <header className="flex flex-wrap items-center gap-ax-3">
        <h2 className="ax-heading text-foreground">
          <UserCheck className="mr-2 inline size-4" aria-hidden="true" />
          Account integrity
        </h2>
        <Button
          size="sm"
          variant="outline"
          className="ml-auto"
          disabled={evaluate.isPending}
          onClick={() =>
            evaluate.mutate(
              {},
              {
                onSuccess: (r) =>
                  notify.done("Checked", `Standing: ${INTEGRITY_LABEL[r.state ?? "clean"]}`),
                onError: (e) => notify.failed("Check failed", { description: e.message }),
              },
            )
          }
        >
          Check my standing
        </Button>
      </header>

      {policy && (
        <div className="ax-plane rounded-2xl p-ax-4 text-[12px]">
          <p className="text-foreground">
            <ShieldCheck className="mr-1.5 inline size-3.5" aria-hidden="true" />
            One person, one account. A device reaching {policy.max_accounts_per_device} or more
            accounts, or creating {policy.max_signups_in_window} accounts within{" "}
            {policy.signup_window_hours} hours, is flagged for a person to review.
          </p>
          <p className="ax-caption mt-1 text-muted-foreground">
            A block always follows one written final warning, is placed on the device record only —
            never on an address or a network — and can be appealed. A blocked account keeps full
            export for {policy.export_window_hours} hours; only after that window is the data
            permanently deleted.
          </p>
        </div>
      )}

      {q.isPending ? (
        <p className="ax-caption text-muted-foreground">Reading your standing…</p>
      ) : q.error ? (
        <p className="ax-caption text-amber-400">Standing didn&apos;t load: {q.error.message}</p>
      ) : s ? (
        <div className="ax-plane rounded-2xl p-ax-4 text-[12px]">
          <p className={`ax-heading ${INTEGRITY_TONE[state]}`}>{INTEGRITY_LABEL[state]}</p>
          {s.reason && <p className="ax-caption mt-1 text-muted-foreground">{s.reason}</p>}
          <p className="ax-caption mt-1 text-steel">
            {s.accounts_on_device} account(s) seen on this device shape · {s.signups_in_window} new
            sign-up(s) in the review window
            {s.evidence?.device_hash_prefix ? ` · device ${s.evidence.device_hash_prefix}` : ""}
          </p>
          {(s.evidence?.signals ?? []).length > 0 && (
            <ul className="ax-caption mt-2 space-y-1 text-amber-400">
              {s.evidence.signals!.map((line) => (
                <li key={line}>
                  <AlertTriangle className="mr-1.5 inline size-3" aria-hidden="true" />
                  {line}
                </li>
              ))}
            </ul>
          )}
          {state === "warned" && s.warned_at && (
            <p className="ax-caption mt-2 text-amber-400">
              Final warning issued {relativeTime(s.warned_at)}. There is no second warning.
            </p>
          )}
          {state === "blocked" && (
            <div className="mt-ax-3 space-y-2">
              <p className="ax-caption text-red-400">
                Blocked {s.blocked_at ? relativeTime(s.blocked_at) : ""}. Export stays open for{" "}
                {s.export_hours_left ?? 0} more hour(s), then the data is permanently deleted.
              </p>
              <Button
                size="sm"
                variant="outline"
                disabled={exportNow.isPending}
                onClick={() =>
                  exportNow.mutate(undefined, {
                    onSuccess: (r) =>
                      r.export_open
                        ? notify.done(
                            "Export open",
                            `You have ${r.hours_left ?? 0} hour(s) to take everything with you.`,
                          )
                        : notify.failed("Export window closed", {
                            description: "The 72 hour window has passed.",
                          }),
                    onError: (e) => notify.failed("Export failed", { description: e.message }),
                  })
                }
              >
                <DownloadCloud className="size-3.5" aria-hidden="true" />
                Start my export
              </Button>
              {s.appeal ? (
                <p className="ax-caption text-steel">
                  Appeal {s.appeal.state} · filed {relativeTime(s.appeal.created_at)}
                  {s.appeal.decision_reason ? ` · ${s.appeal.decision_reason}` : ""}
                </p>
              ) : (
                <p className="ax-caption text-steel">
                  You can appeal this block below — the device record is what was blocked, not your
                  network.
                </p>
              )}
            </div>
          )}
          {s.timeline.length > 0 && (
            <ul className="ax-caption mt-ax-3 space-y-1 text-steel">
              {s.timeline.slice(0, 6).map((row, i) => (
                <li key={`${row.event}-${row.at}-${i}`}>
                  {row.event.replace(/_/g, " ")} · {row.actor} · {relativeTime(row.at)}
                  {row.reason ? ` · ${row.reason}` : ""}
                </li>
              ))}
            </ul>
          )}
        </div>
      ) : null}

      {queue.data?.allowed && (
        <div className="space-y-ax-3">
          <h3 className="ax-caption text-muted-foreground">
            <ShieldAlert className="mr-1.5 inline size-3.5" aria-hidden="true" />
            Review queue — the engine flags, a person decides
          </h3>
          {queue.data.accounts.length === 0 ? (
            <p className="ax-caption text-muted-foreground">Nothing flagged right now.</p>
          ) : (
            <ul className="space-y-ax-2">
              {queue.data.accounts.map((row) => (
                <li key={row.user_id} className="ax-plane rounded-2xl p-ax-4 text-[12px]">
                  <p className={`ax-heading ${INTEGRITY_TONE[row.state]}`}>
                    {INTEGRITY_LABEL[row.state]}
                  </p>
                  <p className="ax-caption mt-1 text-steel">
                    {row.user_id} · {row.accounts_on_device} account(s) on device ·{" "}
                    {row.signups_in_window} sign-up(s) in window · {relativeTime(row.updated_at)}
                  </p>
                  {row.reason && (
                    <p className="ax-caption mt-1 text-muted-foreground">{row.reason}</p>
                  )}
                  {(row.evidence?.signals ?? []).length > 0 && (
                    <ul className="ax-caption mt-1 space-y-0.5 text-amber-400">
                      {row.evidence.signals!.map((line) => (
                        <li key={line}>{line}</li>
                      ))}
                    </ul>
                  )}
                  <div className="mt-ax-3 flex flex-wrap gap-2">
                    <Button
                      size="sm"
                      variant="outline"
                      disabled={row.state !== "suspicious" || busy === row.user_id + "warn"}
                      onClick={() => decide("warn", row.user_id)}
                    >
                      Issue final warning
                    </Button>
                    <Button
                      size="sm"
                      variant="outline"
                      disabled={row.state !== "warned" || busy === row.user_id + "block"}
                      onClick={() => decide("block", row.user_id)}
                    >
                      Block account
                    </Button>
                    <Button
                      size="sm"
                      variant="ghost"
                      disabled={
                        !["warned", "blocked"].includes(row.state) ||
                        busy === row.user_id + "release"
                      }
                      onClick={() => decide("release", row.user_id)}
                    >
                      Restore
                    </Button>
                  </div>
                  {row.state === "warned" && (
                    <p className="ax-caption mt-1 text-steel">
                      Blocking is only possible because a written warning already exists.
                    </p>
                  )}
                </li>
              ))}
            </ul>
          )}
        </div>
      )}
    </section>
  );
}
