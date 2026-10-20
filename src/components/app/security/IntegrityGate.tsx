import { Download, Loader2, ShieldAlert } from "lucide-react";
import { useState } from "react";

import { Button } from "@/components/ui/button";
import { exportErrorMessage, startExport, useMyIntegrity } from "@/lib/account-export";
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
                {busy ? <Loader2 className="size-4 animate-spin" /> : <Download className="size-4" />}
                Download all my data
              </Button>
            </>
          )}
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
