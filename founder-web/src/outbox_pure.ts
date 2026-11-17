// Outbox rows in plain words: what state, why, and what happens next. Pure (no DOM, no network). His word 17 Nov 2026 05:47 PKT:
// a mail must never sit in the Outbox without saying why.
import type { OutRow } from "./mail_api";
export type Tone = "wait" | "go" | "ok" | "bad" | "off";
export type OutView = { tone: Tone; title: string; detail: string; canCancel: boolean };

// The server's own refusal texts, turned into what the founder can act on. Unknown text is shown as it is (never hidden).
export function reasonText(raw: string | null): string {
  const e = (raw ?? "").trim(); if (!e) return "";
  const l = e.toLowerCase();
  if (l.includes("private address")) return "Our server looked up the recipient's mail server and got an internal address, so it refused to send (safety guard). Fixed on 17 Nov by using the real public DNS; a new send goes through.";
  if (l.includes("no mail server") || l.includes("nxdomain") || l.includes("no such domain")) return "The recipient's domain has no mail server. Check the address for a typo.";
  if (l.includes("timeout") || l.includes("timed out")) return "The recipient's server did not answer in time. It will be tried again.";
  if (l.includes("tls")) return "A secure (TLS) connection could not be made with the recipient's server. " + e;
  if (l.includes("sending is off") || l.includes("send_enabled")) return "Sending is switched off. Turn it on in Mail settings.";
  return e;
}
export function outView(r: OutRow, nowMs: number): OutView {
  const nb = Date.parse(r.not_before), left = Number.isFinite(nb) ? Math.max(0, Math.ceil((nb - nowMs) / 1000)) : 0;
  const why = reasonText(r.last_error);
  switch (r.state) {
    case "queued": return { tone: "wait", title: "Waiting for the undo window", detail: `Leaves in ${left}s unless you undo it.`, canCancel: false };
    case "scheduled": return { tone: "wait", title: "Scheduled", detail: Number.isFinite(nb) ? `Goes out ${new Date(nb).toLocaleString()}.` : "Goes out later.", canCancel: true };
    case "sending": return { tone: "go", title: "Sending now", detail: r.attempts > 1 ? `Attempt ${r.attempts}.` : "Talking to the recipient's mail server.", canCancel: false };
    case "sent": return { tone: "ok", title: "Delivered to the recipient's server", detail: [r.tls ? `Secured with ${r.tls}` : "", r.dkim ? "DKIM signed" : ""].filter(Boolean).join(" · "), canCancel: false };
    case "failed": return { tone: "bad", title: r.attempts > 0 && left > 0 ? "Failed, trying again" : "Failed", detail: [why, left > 0 ? `Next try in ${left}s.` : "", `Attempts: ${r.attempts}.`].filter(Boolean).join(" "), canCancel: true };
    case "cancelled": return { tone: "off", title: "Cancelled", detail: why || "You cancelled it, or it was cancelled by the server. The text is back in Drafts.", canCancel: false };
    case "undone": return { tone: "off", title: "Undone", detail: "Taken back before it left. The text is in Drafts.", canCancel: false };
    default: return { tone: "off", title: r.state, detail: why, canCancel: false };
  }
}
