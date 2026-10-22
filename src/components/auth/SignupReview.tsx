import { useState } from "react";

import { Button } from "@/components/ui/button";
import { api, ApiError } from "@/lib/api";
import { collectDeviceSignals } from "@/lib/chat-safety";
import { deviceKeyProof } from "@/lib/device-key";

/**
 * Shown only after a sign-up is refused because this identity was blocked earlier.
 * One short request; a person on the ANEXOMAIL team reads it. No account is needed to ask.
 */
export function SignupReview({ mailbox, recoveryEmail }: { mailbox: string; recoveryEmail: string }) {
  const [statement, setStatement] = useState("");
  const [contact, setContact] = useState(recoveryEmail);
  const [state, setState] = useState<"idle" | "busy" | "sent">("idle");
  const [msg, setMsg] = useState<string | null>(null);

  const send = async () => {
    setState("busy");
    setMsg(null);
    try {
      await api("/api/auth/signup-appeal", {
        method: "POST",
        auth: false,
        body: JSON.stringify({
          email: mailbox,
          recovery_email: recoveryEmail,
          contact,
          statement,
          signals: collectDeviceSignals(),
          device_proof: await deviceKeyProof(mailbox),
        }),
      });
      setState("sent");
    } catch (e) {
      setState("idle");
      setMsg(e instanceof ApiError ? e.message : "We could not send it. Try again in a minute.");
    }
  };

  if (state === "sent") {
    return (
      <p className="ax-caption text-muted-foreground" role="status">
        Request received. A person will read it. If it is approved, just try signing up again.
      </p>
    );
  }
  return (
    <div className="grid gap-2 rounded-lg border border-border p-3">
      <p className="ax-caption text-muted-foreground">
        Think this is a mistake? Tell us what happened (20+ characters). We keep your address only to answer you.
      </p>
      <input
        value={contact}
        onChange={(e) => setContact(e.target.value)}
        placeholder="An email we can reach you on"
        aria-label="An email we can reach you on"
        autoComplete="off"
        className="h-9 rounded-md border border-input bg-background px-3 text-sm"
      />
      <textarea
        value={statement}
        onChange={(e) => setStatement(e.target.value.slice(0, 2000))}
        rows={3}
        placeholder="What happened?"
        aria-label="What happened?"
        className="rounded-md border border-input bg-background px-3 py-2 text-sm"
      />
      {msg && (
        <p role="alert" className="ax-caption text-destructive">
          {msg}
        </p>
      )}
      <Button
        type="button"
        variant="outline"
        disabled={state === "busy" || statement.trim().length < 20 || !contact.includes("@")}
        onClick={send}
      >
        {state === "busy" ? "Sending…" : "Ask for a review"}
      </Button>
    </div>
  );
}
