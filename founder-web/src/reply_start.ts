// QC4b: one pure builder for the three reply kinds, so the buttons, the keys r / a / f and the tests all use the same code.
import type { Start } from "./MailCompose";
import type { Sum } from "./mail_pure";
import { forwardBody, forwardSubject, referencesFor, replyBody, replySubject, replyTargets } from "./reply_pure";

export type ReplyKind = "reply" | "all" | "forward";
export const BIG_REPLY = 20;   // above this many recipients the composer warns

export function buildStart(kind: ReplyKind, o: { sum: Sum; text: string; me: string[]; selection?: string }): Start {
  const s = o.sum, who = s.from_name || s.from || "", date = s.date ? new Date(s.date).toLocaleString() : "";
  if (kind === "forward") {
    return { inline: true, to: "", subject: forwardSubject(s.subject ?? ""), in_reply_to: undefined,
      text: forwardBody({ from: s.from_name ? `${s.from_name} <${s.from ?? ""}>` : s.from ?? "", date, subject: s.subject ?? "", to: s.to ?? [], cc: s.cc, text: o.text }) };
  }
  const t = replyTargets({ from: s.from ?? "", to: s.to ?? [], cc: s.cc ?? [], replyTo: s.reply_to, me: o.me }, kind === "all");
  return { inline: true, to: t.to.join(", "), cc: t.cc.length ? t.cc.join(", ") : undefined, subject: replySubject(s.subject ?? ""),
    text: replyBody({ who, date, text: o.text, selection: o.selection }), in_reply_to: s.message_id, references: referencesFor(s.references ?? [], s.message_id ?? "") };
}
export const countPeople = (...f: string[]): number => f.reduce((n, v) => n + v.split(/[,;]+/).map((x) => x.trim()).filter(Boolean).length, 0);
