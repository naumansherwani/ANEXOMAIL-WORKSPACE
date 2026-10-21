import { BrandSpinner } from "@/components/state/BrandLoader";
import { Download, ShieldAlert } from "lucide-react";
import { useState } from "react";

import { Button } from "@/components/ui/button";
import { exportErrorMessage, sendAppeal, startExport, useMyIntegrity } from "@/lib/account-export";
import { useAuth } from "@/lib/auth";
import { notify } from "@/lib/notify";

/**
 * G37 — account integrity ka sach, user ko seedha:
 *  - warned : upar patti — likhi hui final warning + wajah (ek hi warning, agla qadam block)
 *  - blocked: poori screen — wajah, export ke baqi ghante (72 ghante), uske baad hamesha ke liye delete. Export button + Sign out.
 *  - purged : poori screen — data delete ho chuka
 * Engine khud block nahi karti (E18/phase24a): block insaan karta hai, warning ke baad. Yeh component sirf sach dikhata hai.
 */
export function IntegrityGate() {
  const { session, signOut } = useAuth();
  const { data } = useMyIntegrity(Boolean(session));
  const [busy, setBusy] = useState(false);
  const [appealText, setAppealText] = useState("");
  const [appealBusy, setAppealBusy] = useState(false);
  const [appealDone, setAppealDone] = useState(false);
  if (!session || !data || data.unknown) return null;

  const doExport = async () => {
    setBusy(true);
    try {
      await startExport();
      notify.done("Export started", "Your download begins in a moment. Large mailboxes take longer.");
    } catch (e) {
      notify.failed("Export not started", { description: exportErrorMessage(e) });
    } finally {
      setBusy(false);
    }
  };

  const doAppeal = async () => {
    const text = appealText.trim();
    if (text.length < 20) {
      notify.failed("Tell us more", { description: "Write at least 20 characters explaining why this block is wrong." });
      return;
    }
    setAppealBusy(true);
    try {
      const r = await sendAppeal(text);
      if (r.ok) {
        setAppealDone(true);
        notify.done("Appeal sent", "A person reviews it and the decision is written down.");
      } else {
        notify.failed("Appeal not sent", { description: r.message ?? r.error ?? "Try again." });
      }
    } catch (e) {
      notify.failed("Appeal not sent", { description: e instanceof Error ? e.message : "Try again." });
    } finally {
      setAppealBusy(false);
    }
  };

  if (data.state === "blocked" || data.state === "purged") {
    const purged = data.state === "purged";
    const hours = data.export_hours_left ?? 0;
    return (
      <div
        role="dialog"
        aria-modal="true"
        aria-labelledby="integrity-title"
        className="fixed inset-0 z-[90] flex items-center justify-center overflow-y-auto bg-background px-4 py-10"
      >
        <div className="w-full max-w-[30rem] rounded-2xl border border-border bg-card p-ax-5 shadow-2xl">
          <ShieldAlert className="size-6 text-red-400" aria-hidden="true" />
          <h1 id="integrity-title" className="ax-heading mt-ax-3 text-foreground">
            {purged ? "This account's data has been deleted" : "Your account is blocked"}
          </h1>
          {data.reason ? (
            <p className="ax-caption mt-2 text-foreground">
              <span className="font-semibold">Reason:</span> {data.reason}
            </p>
          ) : null}
          {purged ? (
            <p className="ax-caption mt-2">
              The 72-hour export window ended and the data was permanently deleted, as the Privacy policy says.
            </p>
          ) : (
            <>
              <p className="ax-caption mt-2">
                You can download everything — your mail, attachments, contacts and calendar — for{" "}
                <span className="font-semibold text-foreground">{hours > 0 ? `${Math.ceil(hours)} more hour${Math.ceil(hours) === 1 ? "" : "s"}` : "a little longer"}</span>
                . After that the account and its data are permanently deleted.
              </p>
              <Button className="ax-press mt-ax-4 w-full" onClick={doExport} disabled={busy}>
                {busy ? <BrandSpinner className="size-4" /> : <Download className="size-4" />}
                Download all my data
              </Button>
            </>
          )}
          {!purged ? (
            <div className="mt-ax-3 border-t border-border pt-ax-3" data-testid="integrity-appeal">
              <h2 className="ax-caption font-semibold text-foreground">Appeal this block</h2>
              {appealDone ? (
                <p className="ax-caption mt-1">Your appeal is with a reviewer. You will get the decision by email.</p>
              ) : (
                <>
                  <p className="ax-caption mt-1">The block is on your device record only — never your address or network. Tell us what is wrong.</p>
                  <textarea
                    aria-label="Why is this block wrong?"
                    value={appealText}
                    onChange={(e) => setAppealText(e.target.value)}
                    maxLength={2000}
                    rows={3}
                    className="mt-2 w-full rounded-md border border-border bg-background p-2 text-sm text-foreground"
                  />
                  <Button variant="outline" className="mt-2 w-full" onClick={doAppeal} disabled={appealBusy}>
                    {appealBusy ? <BrandSpinner className="size-4" /> : null}
                    Send appeal
                  </Button>
                </>
              )}
            </div>
          ) : null}
          <p className="ax-caption mt-ax-3">
            If you think this is a mistake, write to{" "}
            <a className="underline" href="mailto:resolved@anexomail.com">
              resolved@anexomail.com
            </a>{" "}
            before the window ends.
          </p>
          <Button variant="ghost" className="mt-ax-2 w-full" onClick={() => void signOut()}>
            Sign out
          </Button>
        </div>
      </div>
    );
  }

  if (data.state === "warned") {
    return (
      <div
        role="alert"
        data-testid="integrity-warning"
        className="flex shrink-0 flex-wrap items-center gap-x-3 gap-y-1 border-b border-amber-500/40 bg-amber-500/10 px-4 py-2"
      >
        <ShieldAlert className="size-4 text-amber-400" aria-hidden="true" />
        <span className="ax-caption text-foreground">
          <span className="font-semibold">Final warning.</span>{" "}
          {data.reason ? `${data.reason} ` : ""}If this happens again, your account will be blocked.
        </span>
        <a className="ax-caption ml-auto underline" href="mailto:resolved@anexomail.com">
          Disagree? Write to us
        </a>
      </div>
    );
  }
  return null;
}
