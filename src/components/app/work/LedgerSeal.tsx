import { ShieldCheck, ShieldAlert } from "lucide-react";
import { useMutation } from "@tanstack/react-query";

import { rpc } from "@/lib/rpc";

type Verify = { ok: boolean; rows?: number; bad_seq?: number | null; head?: string | null };

/**
 * Promise ledger seal — Pro. "Check seal" server par poori HMAC-SHA256 chain dobara hisaab karta hai (commit.verify).
 * Kuch bhi badla ya delete hua ho to kaunsi row se toota wo dikhata hai. Kuch dikhane ko nahi to chup rehta hai.
 */
export function LedgerSeal() {
  const check = useMutation({ mutationFn: () => rpc<Verify>("commit.verify", {}) });
  const d = check.data;
  const forbidden = check.error && /feature_not_available|403/.test(String(check.error.message));
  if (forbidden) return null;
  return (
    <div className="mt-ax-3 flex flex-wrap items-center gap-2 rounded-xl border border-border px-ax-3 py-2">
      <button
        type="button"
        onClick={() => check.mutate()}
        disabled={check.isPending}
        className="ax-press ax-focus ax-tap ax-caption inline-flex items-center gap-1.5 rounded-md border border-border px-2 py-1 font-semibold"
      >
        {d && !d.ok ? <ShieldAlert className="size-3.5 text-amber-400" aria-hidden="true" /> : <ShieldCheck className="size-3.5 text-steel" aria-hidden="true" />}
        {check.isPending ? "Checking…" : "Check promise seal"}
      </button>
      <span className="ax-caption text-muted-foreground" role="status" aria-live="polite">
        {d
          ? d.ok
            ? `${d.rows ?? 0} promise${d.rows === 1 ? "" : "s"} sealed — chain intact`
            : `Chain broken at entry ${d.bad_seq ?? "?"}`
          : check.error
            ? "Could not check right now"
            : "Every promise is sealed and cannot be changed or deleted."}
      </span>
    </div>
  );
}
