import { Router } from "express";
import { admin } from "../lib/supa";

export const support = Router();

/* ── 3 · LEO CONFIDENCE GATE — legal shield ─────────────────────── */
const HUMAN_KEYWORDS = ["refund","legal","threat","lawsuit","cancel","fraud","chargeback"];
const MIN_CONFIDENCE = 0.72;

export function gate(text: string, confidence: number) {
  const hay = (text || "").toLowerCase();
  const hit = HUMAN_KEYWORDS.find((k) => hay.includes(k));
  if (hit) return { needs_human: true, reason: `keyword:${hit}` };
  if (confidence < MIN_CONFIDENCE) return { needs_human: true, reason: "low_confidence" };
  return { needs_human: false, reason: null as string | null };
}

/* ── 4 · LOOP GUARD — never reply to machines ────────────────────── */
export function isMachineMail(h: Record<string, string | undefined>) {
  const auto = (h["auto-submitted"] || "").toLowerCase();
  if (auto && auto !== "no") return true;
  if (h["x-auto-response-suppress"]) return true;
  if ((h["precedence"] || "").toLowerCase().match(/bulk|junk|list/)) return true;
  if (h["list-id"] || h["list-unsubscribe"]) return true;
  const from = (h["from"] || "").toLowerCase();
  return /(^|<)(noreply|no-reply|mailer-daemon|postmaster|bounce)/.test(from);
}

/* ── 2 · SEND-AS CROSS-DOMAIN LOCK — DKIM alignment ─────────────── */
export function alignedFrom(inbox: string, candidates: string[]) {
  const domain = inbox.split("@")[1]?.toLowerCase();
  return candidates.find((c) => c.split("@")[1]?.toLowerCase() === domain) ?? inbox;
}

/* GET /api/public/sla — real numbers for the landing page */
support.get("/public/sla", async (_req, res) => {
  const { data, error } = await admin.rpc("sla_public", { _days: 30 });
  if (error) return res.status(500).json({ error: error.message });
  const row = Array.isArray(data) ? data[0] : data;
  res.json({
    avg_first_reply_seconds: row?.avg_first_reply_seconds ? Number(row.avg_first_reply_seconds) : null,
    resolved_count: Number(row?.resolved_count ?? 0),
    window_days: Number(row?.window_days ?? 30),
    resolution_rate: row?.resolution_rate === null || row?.resolution_rate === undefined ? null : Number(row.resolution_rate),
  });
});

/* Drafts awaiting human (confidence gate) */
support.get("/support/drafts", async (req: any, res) => {
  const org = String(req.query.org_id || "");
  if (!org) return res.status(400).json({ error: "org_id_required" });
  const { data, error } = await admin.from("leo_email_drafts")
    .select("*").eq("org_id", org).eq("state", "pending")
    .order("created_at", { ascending: false }).limit(50);
  if (error) return res.status(500).json({ error: error.message });
  res.json({ drafts: data ?? [] });
});

support.post("/support/drafts/:id/discard", async (req, res) => {
  const { error } = await admin.from("leo_email_drafts")
    .update({ state: "discarded" }).eq("id", req.params.id);
  if (error) return res.status(500).json({ error: error.message });
  res.json({ ok: true });
});
