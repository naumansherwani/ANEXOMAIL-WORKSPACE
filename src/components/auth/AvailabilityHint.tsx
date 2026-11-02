import { useEffect, useRef, useState } from "react";
import { Check, X, Loader2 } from "lucide-react";

import { checkAvailability, type CheckResult } from "@/lib/signx";
import { ApiError } from "@/lib/api";
import { anexomailLocalPart } from "@/lib/anexomail-address";
import { cn } from "@/lib/utils";

export type Availability =
  | { state: "idle" }
  | { state: "checking" }
  | { state: "free"; address: string }
  | { state: "taken"; reason: string; suggestions: string[] }
  | { state: "invalid" }
  | { state: "blocked" }
  | { state: "error"; message: string };

/** Gmail-style live check of the ANEXOMAIL name: green when free, red + ideas when taken. Waits 450 ms after the last key; ignores stale answers. */
export function useHandleAvailability(local: string, enabled: boolean): Availability {
  const [a, setA] = useState<Availability>({ state: "idle" });
  const seq = useRef(0);
  useEffect(() => {
    const v = anexomailLocalPart(local).toLowerCase();
    if (!enabled || v.length < 3) {
      setA({ state: "idle" });
      return;
    }
    const mine = ++seq.current;
    setA({ state: "checking" });
    const timer = window.setTimeout(async () => {
      try {
        const r: CheckResult = await checkAvailability("handle", v);
        if (mine !== seq.current) return;
        if (r.available) setA({ state: "free", address: r.address ?? `${v}@anexomail.com` });
        else if (r.reason === "invalid_handle") setA({ state: "invalid" });
        else setA({ state: "taken", reason: r.reason ?? "taken", suggestions: r.suggestions ?? [] });
      } catch (e) {
        if (mine !== seq.current) return;
        if (e instanceof ApiError && e.code === "country_not_available") setA({ state: "blocked" });
        else if (e instanceof ApiError && e.status === 429) setA({ state: "error", message: "Too many checks. Wait a minute." });
        else setA({ state: "error", message: "Could not check right now." });
      }
    }, 450);
    return () => window.clearTimeout(timer);
  }, [local, enabled]);
  return a;
}

export function AvailabilityHint({ a, onPick }: { a: Availability; onPick: (local: string) => void }) {
  if (a.state === "idle") return null;
  return (
    <div className="space-y-1.5" aria-live="polite">
      {a.state === "checking" && (
        <p className="ax-caption inline-flex items-center gap-1.5 text-muted-foreground">
          <Loader2 className="size-3.5 animate-spin" aria-hidden="true" /> Checking…
        </p>
      )}
      {a.state === "free" && (
        <p className="ax-caption inline-flex items-center gap-1.5 font-semibold text-emerald-600">
          <Check className="size-3.5" aria-hidden="true" /> {a.address} is available
        </p>
      )}
      {a.state === "taken" && (
        <>
          <p className="ax-caption inline-flex items-center gap-1.5 font-semibold text-destructive">
            <X className="size-3.5" aria-hidden="true" /> {a.reason === "reserved_handle" ? "This name is reserved" : "That name is already taken"}
          </p>
          {a.suggestions.length > 0 && (
            <div className="flex flex-wrap items-center gap-1.5">
              <span className="ax-caption text-muted-foreground">Available:</span>
              {a.suggestions.map((s) => (
                <button
                  key={s}
                  type="button"
                  onClick={() => onPick(s)}
                  className={cn("ax-focus rounded-full border border-emerald-600/40 bg-emerald-600/10 px-2.5 py-0.5 text-xs font-semibold text-emerald-700")}
                >
                  {s}
                </button>
              ))}
            </div>
          )}
        </>
      )}
      {a.state === "invalid" && (
        <p className="ax-caption inline-flex items-center gap-1.5 font-semibold text-destructive">
          <X className="size-3.5" aria-hidden="true" /> Use 3–30 letters, numbers, dots or dashes
        </p>
      )}
      {a.state === "blocked" && <p className="ax-caption font-semibold text-destructive">ANEXOMAIL is not available in your country.</p>}
      {a.state === "error" && <p className="ax-caption text-muted-foreground">{a.message}</p>}
    </div>
  );
}
