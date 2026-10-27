import { CalendarCheck, Check, ListChecks, PhoneCall, Timer, X } from "lucide-react";
import { AnimatePresence, motion, useReducedMotion } from "motion/react";

import { Button } from "@/components/ui/button";
import type { IntentPromise } from "@/lib/kernel/kernel";
import { duration, money, type AttentionRate, type Outcomes } from "@/lib/outcomes";
import { cn } from "@/lib/utils";

export type PromiseKey = string;
export const promiseKey = (p: IntentPromise): PromiseKey =>
  `${p.phrase.toLowerCase()}|${p.due_date ?? ""}`;
export type LinkChoice = { withEvent: boolean };

/**
 * Compose ke neeche "Business Outcomes" (Pro): jo wada likha gaya (task/calendar se jodna) aur is email ka asli kharcha.
 * Sab kuch WASM kernel (intent@1) ne browser mein nikala; yahan sirf dikhana + user ki marzi (link / dismiss).
 * Cinematic nahi (Rule 60: kaam wali screen) — halka, tez, reduced-motion ka ehtram.
 */
export function OutcomesBar({
  outcomes,
  rate,
  linked,
  dismissed,
  onLink,
  onUnlink,
  onDismiss,
}: {
  outcomes: Outcomes;
  rate: AttentionRate;
  linked: Record<PromiseKey, LinkChoice>;
  dismissed: Set<PromiseKey>;
  onLink: (k: PromiseKey, c: LinkChoice) => void;
  onUnlink: (k: PromiseKey) => void;
  onDismiss: (k: PromiseKey) => void;
}) {
  const reduce = useReducedMotion();
  const shown = outcomes.promises.filter((p) => !dismissed.has(promiseKey(p)));
  const cost = outcomes.cost;
  if (shown.length === 0 && !cost) return null;

  const fade = reduce
    ? {}
    : {
        initial: { opacity: 0, y: 4 },
        animate: { opacity: 1, y: 0 },
        exit: { opacity: 0, y: -4 },
        transition: { duration: 0.15 },
      };

  return (
    <div className="flex flex-col gap-2" aria-live="polite" data-testid="outcomes-bar">
      <AnimatePresence initial={false}>
        {shown.map((p) => {
          const k = promiseKey(p);
          const choice = linked[k];
          return (
            <motion.div
              key={k}
              {...fade}
              className={cn(
                "ax-plane flex flex-col gap-2 rounded-xl p-ax-3",
                choice && "ring-1 ring-primary/40",
              )}
              data-testid="promise-badge"
            >
              <div className="flex items-start gap-2">
                <CalendarCheck className="mt-0.5 size-4 shrink-0 text-primary" aria-hidden />
                <div className="min-w-0 flex-1">
                  <p className="ax-label text-foreground">
                    {choice
                      ? "Promise will be tracked"
                      : "Detecting a Promise. Link to Calendar & Tasks?"}
                  </p>
                  <p className="truncate text-xs text-muted-foreground" title={p.phrase}>
                    “{p.action}”
                    {p.due_date
                      ? ` · due ${p.due_label === p.due_date ? p.due_date : `${p.due_label} (${p.due_date})`}`
                      : " · no date found"}
                    {!p.due_exact && p.due_date ? " · estimated" : ""}
                  </p>
                </div>
                <button
                  type="button"
                  onClick={() => onDismiss(k)}
                  aria-label="Ignore this promise"
                  className="ax-press rounded p-1 text-muted-foreground hover:text-foreground"
                >
                  <X className="size-4" />
                </button>
              </div>
              <div className="flex flex-wrap items-center gap-2">
                {choice ? (
                  <>
                    <span className="inline-flex items-center gap-1 text-xs text-foreground">
                      <Check className="size-3.5 text-primary" aria-hidden />
                      Task on send{choice.withEvent ? " + calendar hold" : ""}
                    </span>
                    <Button
                      type="button"
                      variant="ghost"
                      size="sm"
                      className="ax-press"
                      onClick={() => onUnlink(k)}
                    >
                      Undo
                    </Button>
                  </>
                ) : (
                  <>
                    <Button
                      type="button"
                      size="sm"
                      className="ax-press"
                      onClick={() => onLink(k, { withEvent: !!p.due_date })}
                    >
                      <ListChecks className="size-4" aria-hidden />
                      {p.due_date ? "Task + Calendar" : "Task only"}
                    </Button>
                    {p.due_date ? (
                      <Button
                        type="button"
                        variant="secondary"
                        size="sm"
                        className="ax-press"
                        onClick={() => onLink(k, { withEvent: false })}
                      >
                        Task only
                      </Button>
                    ) : null}
                  </>
                )}
              </div>
            </motion.div>
          );
        })}
      </AnimatePresence>

      {cost ? (
        <motion.div
          {...fade}
          className="ax-plane flex flex-col gap-1 rounded-xl p-ax-3"
          data-testid="thread-economics"
        >
          <p className="flex items-center gap-2 text-xs text-foreground">
            <Timer className="size-4 shrink-0 text-muted-foreground" aria-hidden />
            <span>
              This email will cost about <strong>{money(cost.cost_minor, rate.currency)}</strong> of
              attention to read — {duration(cost.seconds_total)} across {outcomes.recipients.length}{" "}
              {outcomes.recipients.length === 1 ? "person" : "people"}.
            </span>
          </p>
          {cost.suggest_call ? (
            <p
              className="flex items-start gap-2 text-xs text-muted-foreground"
              data-testid="call-suggestion"
            >
              <PhoneCall className="mt-0.5 size-4 shrink-0 text-primary" aria-hidden />
              <span>
                A {cost.call_minutes}-minute call would cost about{" "}
                {money(cost.call_cost_minor, rate.currency)} — it could save{" "}
                {money(cost.saving_minor, rate.currency)}.
              </span>
            </p>
          ) : null}
        </motion.div>
      ) : null}
    </div>
  );
}
