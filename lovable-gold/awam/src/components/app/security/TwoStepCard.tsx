import { useState } from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { ShieldCheck } from "lucide-react";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { api } from "@/lib/api";
import { notify } from "@/lib/notify";

type Enroll = { factor_id: string; otpauth_url: string; secret: string; qr_code: string | null };
const KEY = ["auth", "mfa"] as const;
const digits = (v: string) => v.replace(/\D/g, "").slice(0, 6);
const why = (e: unknown) => (e instanceof Error ? e.message : "Please try again.");

/** Two-step sign-in (authenticator app). Server: /api/auth/mfa* — status, enroll, enroll/confirm, disable; login step: /api/auth/mfa/verify. */
export function TwoStepCard() {
  const qc = useQueryClient();
  const status = useQuery({ queryKey: KEY, queryFn: () => api<{ enabled: boolean }>("/api/auth/mfa"), retry: false });
  const [setup, setSetup] = useState<Enroll | null>(null);
  const [code, setCode] = useState("");
  const [disabling, setDisabling] = useState(false);

  const start = useMutation({
    mutationFn: () => api<Enroll>("/api/auth/mfa/enroll", { method: "POST" }),
    onSuccess: (r) => {
      setSetup(r);
      setCode("");
    },
    onError: (e) => notify.failed("Two-step setup unavailable", { description: why(e) }),
  });
  const confirm = useMutation({
    mutationFn: () =>
      api("/api/auth/mfa/enroll/confirm", { method: "POST", body: JSON.stringify({ factor_id: setup?.factor_id, code }) }),
    onSuccess: () => {
      setSetup(null);
      setCode("");
      void qc.invalidateQueries({ queryKey: KEY });
      notify.done("Two-step is on", "Next sign-in will ask for a code from your authenticator app.");
    },
    onError: (e) => notify.failed("Code not accepted", { description: why(e) }),
  });
  const disable = useMutation({
    mutationFn: () => api("/api/auth/mfa/disable", { method: "POST", body: JSON.stringify({ code }) }),
    onSuccess: () => {
      setDisabling(false);
      setCode("");
      void qc.invalidateQueries({ queryKey: KEY });
      notify.done("Two-step is off", "Sign-in asks for your password only.");
    },
    onError: (e) => notify.failed("Code not accepted", { description: why(e) }),
  });

  const enabled = status.data?.enabled === true;

  return (
    <div className="mt-ax-3 rounded-lg border border-border p-ax-3">
      <div className="flex flex-wrap items-center justify-between gap-ax-2">
        <div>
          <p className="text-sm font-medium text-foreground">Two-step sign-in</p>
          <p className="ax-caption">
            {status.isError ? "Status unavailable right now." : enabled ? "On — a code from your authenticator app is asked at sign-in." : "Off — add a code from an authenticator app."}
          </p>
        </div>
        {!setup && !disabling && !status.isLoading && !status.isError && (
          <Button
            variant="outline"
            className="ax-press"
            disabled={start.isPending}
            onClick={() => (enabled ? (setDisabling(true), setCode("")) : start.mutate())}
          >
            <ShieldCheck className="size-4" />
            {enabled ? "Turn off" : "Turn on two-step"}
          </Button>
        )}
      </div>

      {setup && (
        <form
          className="mt-ax-3 grid gap-ax-2"
          onSubmit={(e) => {
            e.preventDefault();
            if (code.length === 6) confirm.mutate();
          }}
        >
          <p className="ax-caption">Scan this in Google Authenticator, 1Password, Authy or similar, then type the 6-digit code.</p>
          {setup.qr_code && <img src={setup.qr_code} alt="Two-step QR code" className="size-40 rounded-md bg-white p-1" />}
          <p className="ax-caption break-all">
            Can't scan? Secret: <span className="font-mono text-foreground select-all">{setup.secret}</span>
          </p>
          <div className="flex flex-wrap gap-ax-2">
            <Input
              inputMode="numeric"
              autoComplete="one-time-code"
              placeholder="123456"
              aria-label="6-digit code"
              className="w-32 font-mono"
              value={code}
              onChange={(e) => setCode(digits(e.target.value))}
            />
            <Button type="submit" disabled={code.length !== 6 || confirm.isPending}>
              Confirm
            </Button>
            <Button type="button" variant="ghost" onClick={() => setSetup(null)}>
              Cancel
            </Button>
          </div>
        </form>
      )}

      {disabling && (
        <form
          className="mt-ax-3 flex flex-wrap gap-ax-2"
          onSubmit={(e) => {
            e.preventDefault();
            if (code.length === 6) disable.mutate();
          }}
        >
          <Input
            inputMode="numeric"
            autoComplete="one-time-code"
            placeholder="Current code"
            aria-label="Current 6-digit code"
            className="w-40 font-mono"
            value={code}
            onChange={(e) => setCode(digits(e.target.value))}
          />
          <Button type="submit" variant="destructive" disabled={code.length !== 6 || disable.isPending}>
            Turn off
          </Button>
          <Button type="button" variant="ghost" onClick={() => setDisabling(false)}>
            Cancel
          </Button>
        </form>
      )}
    </div>
  );
}
