import { useQueryClient } from "@tanstack/react-query";
import { KeyRound, Loader2, ShieldAlert } from "lucide-react";
import { useState } from "react";

import { RecoveryCodesPanel } from "@/components/app/security/RecoveryCodesPanel";
import { Button } from "@/components/ui/button";
import { useAuth } from "@/lib/auth";
import { notify } from "@/lib/notify";
import { enrolPasskey, PASSKEY_STATUS_KEY, passkeySupported, usePasskeyStatus } from "@/lib/passkey";

const DISMISS_KEY = "anexo.passkey.banner.dismissed";

function dismissedToday(): boolean {
  try {
    return window.sessionStorage.getItem(DISMISS_KEY) === "1";
  } catch {
    return false;
  }
}

/**
 * G35 — passkey lazmi.
 *  - 0 passkey + hard (naya account / grace khatam): poori screen, bypass nahi (sirf Sign out)
 *  - 0 passkey + grace baqi: upar patti ("X tak lazmi")
 *  - 1 passkey: patti "backup passkey (phone/laptop) add karein" (is session ke liye band ho sakti hai)
 *  - recovery codes baqi nahi: patti "codes save karein" (Account → Security)
 * Server par E43 SQL na chala ho to status `unknown` aata hai aur kuch nahi lagta (jhoota gate nahi).
 */
export function PasskeyGate() {
  const { session, signOut } = useAuth();
  const { data } = usePasskeyStatus(Boolean(session));
  const qc = useQueryClient();
  const [busy, setBusy] = useState(false);
  const [err, setErr] = useState<string | null>(null);
  const [codes, setCodes] = useState<string[] | null>(null);
  const [hidden, setHidden] = useState(dismissedToday());

  if (!session || !data || data.unknown) return null;

  const add = async () => {
    setErr(null);
    setBusy(true);
    try {
      const res = await enrolPasskey();
      await qc.invalidateQueries({ queryKey: PASSKEY_STATUS_KEY });
      if (res.recovery_codes) setCodes(res.recovery_codes);
      else notify.done("Passkey added", "You now have a backup way in.");
    } catch (e) {
      setErr(
        e instanceof Error && e.message
          ? e.message
          : "Could not create the passkey. Try again, or choose your phone when the browser asks.",
      );
    } finally {
      setBusy(false);
    }
  };

  if (codes) {
    return (
      <div className="fixed inset-0 z-[80] flex items-center justify-center overflow-y-auto bg-background/95 px-4 py-10">
        <div className="w-full max-w-[28rem] rounded-2xl border border-border bg-card p-ax-5 shadow-2xl">
          <RecoveryCodesPanel codes={codes} onDone={() => setCodes(null)} />
        </div>
      </div>
    );
  }

  if (data.required && data.hard) {
    return (
      <div
        role="dialog"
        aria-modal="true"
        aria-labelledby="passkey-gate-title"
        className="fixed inset-0 z-[80] flex items-center justify-center overflow-y-auto bg-background/95 px-4 py-10"
      >
        <div className="w-full max-w-[27rem] rounded-2xl border border-border bg-card p-ax-5 text-center shadow-2xl">
          <ShieldAlert className="mx-auto size-6 text-cyan-accent" aria-hidden="true" />
          <h1 id="passkey-gate-title" className="ax-heading mt-ax-3 text-foreground">
            Add a passkey to continue
          </h1>
          <p className="ax-caption mt-2">
            Your password keeps working. A passkey (Face ID, Touch ID, fingerprint or Windows Hello — or your phone via QR
            code) protects this workspace if the password is ever stolen.
          </p>
          {!passkeySupported() && (
            <p role="alert" className="ax-caption mt-ax-3 text-destructive">
              This browser can't create passkeys. Open ANEXOMAIL in an up-to-date Chrome, Edge, Safari or Firefox.
            </p>
          )}
          {err && (
            <p role="alert" className="ax-caption mt-ax-3 text-destructive">
              {err}
            </p>
          )}
          <Button className="ax-press mt-ax-4 w-full" onClick={add} disabled={busy || !passkeySupported()}>
            {busy ? <Loader2 className="size-4 animate-spin" /> : <KeyRound className="size-4" />}
            Create my passkey
          </Button>
          <Button variant="ghost" className="mt-ax-2 w-full" onClick={() => void signOut()}>
            Sign out
          </Button>
        </div>
      </div>
    );
  }

  let message: string | null = null;
  if (data.required) {
    const until = data.grace_until ? new Date(data.grace_until).toLocaleDateString(undefined, { day: "numeric", month: "short" }) : null;
    message = `Add a passkey${until ? ` — required from ${until}` : ""}.`;
  } else if (data.count < data.target) {
    message = "Add a backup passkey on your phone or laptop, so losing one device never locks you out.";
  } else if (data.codes_remaining === 0) {
    message = "You have no recovery codes left. Create new ones in Account.";
  }
  if (!message || (hidden && !data.required)) return null;

  return (
    <div
      role="status"
      className="flex shrink-0 flex-wrap items-center gap-x-3 gap-y-1 border-b border-border bg-secondary/40 px-4 py-1.5"
      data-testid="passkey-banner"
    >
      <KeyRound className="size-3.5 text-cyan-accent" aria-hidden="true" />
      <span className="ax-caption text-foreground">{message}</span>
      {data.count < data.target || data.required ? (
        <Button size="sm" variant="outline" className="h-7" onClick={add} disabled={busy}>
          {busy && <Loader2 className="size-3.5 animate-spin" />}
          {data.required ? "Create passkey" : "Add backup passkey"}
        </Button>
      ) : null}
      {err && <span className="ax-caption text-destructive">{err}</span>}
      {!data.required && (
        <button
          type="button"
          className="ax-caption ml-auto text-muted-foreground underline"
          onClick={() => {
            try {
              window.sessionStorage.setItem(DISMISS_KEY, "1");
            } catch {
              /* ignore */
            }
            setHidden(true);
          }}
        >
          Later
        </button>
      )}
    </div>
  );
}
