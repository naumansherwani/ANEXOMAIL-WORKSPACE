/**
 * RPC CONTRACT — tRPC-style typed procedures, ek jagah (founder: "tRPC" sirf naam nahi, asli contract).
 * Har gated proc ka MINIMUM package yahan likha hai; Rust server (mailx_core::pro_only_proc, cal_core::pro_only_cal_proc, analytics_core::need_of)
 * isi ki asli enforcement hai. `rpc-contract.test.ts` Rust source parh kar dono ko match karata hai — drift = test fail.
 * Browser ke liye typed call: `callProc("calendar.availability", {date})` => compile time par proc naam + input/output type.
 */
import { rpc } from "./rpc";

export type MinPlan = "pro" | "business";

/** proc -> kam se kam package. Basic ke liye jo proc yahan NAHI, woh sab packages ko khule hain. */
export const PROC_MIN_PLAN = {
  "mail.confidence": "pro",
  "mail.followup.create": "pro",
  "mail.followup.list": "pro",
  "mail.followup.delete": "pro",
  "mail.snippets.list": "pro",
  "mail.snippets.save": "pro",
  "mail.snippets.delete": "pro",
  "mail.handoff.list": "pro",
  "mail.handoff.save": "pro",
  "mail.handoff.claim": "pro",
  "mail.handoff.delete": "pro",
  "calendar.availability": "pro",
  "calendar.focus": "pro",
  "calendar.rates": "pro",
  "calendar.rates.set": "pro",
  "calendar.files.list": "pro",
  "calendar.files.attach": "pro",
  "calendar.files.remove": "pro",
  "crm.pipelines.list": "pro",
  "crm.pipelines.save": "pro",
  "crm.pipelines.delete": "pro",
  "crm.fields.list": "pro",
  "crm.fields.save": "pro",
  "crm.fields.delete": "pro",
  "crm.custom.set": "pro",
  "crm.dups.list": "pro",
  "crm.merge": "pro",
  "crm.forms.list": "pro",
  "crm.forms.save": "pro",
  "crm.forms.delete": "pro",
  "crm.board": "pro",
  "crm.deals.move": "pro",
  "crm.deals.setPipeline": "pro",
  "work.tasks": "pro",
  "work.promises": "pro",
  "work.task.create": "pro",
  "work.task.update": "pro",
  "work.note": "pro",
  "work.note.save": "pro",
  "work.followThrough": "pro",
  "calendar.outcome.post": "pro",
  "commit.record": "pro",
  "commit.status": "pro",
  "commit.list": "pro",
  "commit.verify": "pro",
  "commit.economics": "pro",
  "commit.rate": "pro",
  "commit.rateSet": "pro",
  "file.context": "pro",
  "crm.overview": "pro",
  "crm.live": "pro",
  "crm.leads": "pro",
  "crm.deals": "pro",
  "crm.createLead": "pro",
  "crm.createDeal": "pro",
  "crm.moveDeal": "pro",
  "crm.convertLead": "pro",
  "crm.dealWork": "pro",
  "crm.dealThread": "pro",
  "crm.insights": "pro",
  "crm.memory": "pro",
  "work.promise.commit": "pro",
  "work.promise.dismiss": "pro",
  "analytics.threadEconomics": "pro",
  "analytics.deepWork": "pro",
  "analytics.attentionLeaks": "business",
  "analytics.promiseSla": "business",
  "analytics.forecast": "business",
  "analytics.team": "business",
} as const satisfies Record<string, MinPlan>;

export type GatedProc = keyof typeof PROC_MIN_PLAN;

/** Input/output shapes (jahan stable hain). Naye procs yahan jode jate hain; baqi `unknown` rehte hain. */
export interface ProcShapes {
  "calendar.availability": {
    in: { date?: string };
    out: { slots: { starts_at: string; ends_at: string; state: "free" | "focus" | "travel_buffer"; label: string | null }[]; share_url: string | null };
  };
  "calendar.rates": {
    in: Record<string, never>;
    out: { self: number; guest: number; currency: string };
  };
  "calendar.rates.set": {
    in: { self?: number; guest?: number };
    out: { self: number; guest: number; currency: string };
  };
  "calendar.focus": {
    in: Record<string, never>;
    out: { windows: { id: string; label: string; weekday: number; start_minute: number; end_minute: number; protected: boolean }[] };
  };
}

export type InOf<P extends string> = P extends keyof ProcShapes ? ProcShapes[P]["in"] : unknown;
export type OutOf<P extends string> = P extends keyof ProcShapes ? ProcShapes[P]["out"] : unknown;

/** Typed call: proc naam galat likha to compile nahi hota. Transport wahi: kernel WebTransport, warna fetch. */
export function callProc<P extends keyof ProcShapes>(proc: P, input: InOf<P>): Promise<OutOf<P>> {
  return rpc<OutOf<P>>(proc, input);
}

export function minPlanOf(proc: string): MinPlan | null {
  return (PROC_MIN_PLAN as Record<string, MinPlan>)[proc] ?? null;
}
