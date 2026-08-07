import { motion } from "motion/react";
import { CalendarDays, CircleCheck, Inbox, ShieldCheck, User } from "lucide-react";

import { EASE } from "./Reveal";

/**
 * Hero composition — an elegant floating arrangement of workspace cards.
 * Not a screenshot, not a fake dashboard: structure only, drawn in tokens.
 */
export function HeroComposition() {
  return (
    <div className="relative mx-auto w-full max-w-md select-none">
      {/* Inbox plane */}
      <motion.div
        initial={{ opacity: 0, y: 18 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.8, delay: 0.35, ease: EASE }}
        className="ax-plane ax-drift rounded-xl p-5"
      >
        <div className="flex items-center gap-2.5">
          <Inbox className="size-4 text-steel" strokeWidth={1.6} />
          <span className="ax-eyebrow">Inbox</span>
          <span className="ml-auto text-[10px] font-semibold text-cyan-accent">3 new</span>
        </div>
        <ul className="mt-4 space-y-3">
          {[
            { from: "sales@", subject: "Renewal quote — Q3", tag: "Assigned" },
            { from: "hello@", subject: "Domain records verified", tag: "Done" },
            { from: "support@", subject: "Mailbox migration window", tag: "Waiting" },
          ].map((m) => (
            <li key={m.subject} className="flex items-center gap-3">
              <span className="size-1.5 shrink-0 rounded-full bg-steel/60" />
              <span className="min-w-0 flex-1">
                <span className="block truncate text-[12px] font-semibold text-foreground">
                  {m.subject}
                </span>
                <span className="block text-[10px] text-muted-foreground">{m.from}</span>
              </span>
              <span className="shrink-0 rounded-full border border-border px-2 py-0.5 text-[9px] tracking-wider text-muted-foreground uppercase">
                {m.tag}
              </span>
            </li>
          ))}
        </ul>
      </motion.div>

      {/* Calendar + task row */}
      <div className="mt-4 grid grid-cols-2 gap-4">
        <motion.div
          initial={{ opacity: 0, y: 18 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.8, delay: 0.5, ease: EASE }}
          className="ax-plane rounded-xl p-4"
        >
          <CalendarDays className="size-4 text-steel" strokeWidth={1.6} />
          <p className="mt-3 text-[12px] font-semibold text-foreground">10:30 · Handover</p>
          <p className="mt-1 text-[10px] text-muted-foreground">Two attendees</p>
        </motion.div>

        <motion.div
          initial={{ opacity: 0, y: 18 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.8, delay: 0.58, ease: EASE }}
          className="ax-plane rounded-xl p-4"
        >
          <CircleCheck className="size-4 text-success" strokeWidth={1.6} />
          <p className="mt-3 text-[12px] font-semibold text-foreground">Reply to invoice</p>
          <p className="mt-1 text-[10px] text-muted-foreground">Due today</p>
        </motion.div>
      </div>

      {/* Contact + seal strip */}
      <motion.div
        initial={{ opacity: 0, y: 18 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.8, delay: 0.66, ease: EASE }}
        className="ax-plane mt-4 flex items-center gap-3 rounded-xl p-4"
      >
        <span className="flex size-8 shrink-0 items-center justify-center rounded-full border border-border">
          <User className="size-3.5 text-steel" strokeWidth={1.6} />
        </span>
        <span className="min-w-0 flex-1">
          <span className="block truncate text-[12px] font-semibold text-foreground">
            Priya N. · Operations
          </span>
          <span className="block text-[10px] text-muted-foreground">
            14 threads · 2 shared addresses
          </span>
        </span>
        <span className="inline-flex shrink-0 items-center gap-1.5 text-[10px] font-semibold text-success">
          <ShieldCheck className="size-3.5" strokeWidth={2} />
          Sealed
        </span>
      </motion.div>
    </div>
  );
}