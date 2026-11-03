/**
 * Awam locale overlay + preference.
 * Missing ui_copy row = English at runtime. No dummy strings.
 */
import { Router } from "express";
import { admin } from "../lib/supa";

export const localeRouter = Router();

const TAGS = new Set([
  "en-GB",
  "hi-IN",
  "ur-PK",
  "ar-SA",
  "es-ES",
  "fr-FR",
  "de-DE",
  "de-CH",
  "pt-BR",
  "zh-CN",
  "ja-JP",
  "ko-KR",
  "tr-TR",
  "it-IT",
  "ro-RO",
  "ru-RU",
  "nl-NL",
  "pl-PL",
  "uk-UA",
  "id-ID",
  "ms-MY",
  "vi-VN",
  "th-TH",
  "bn-BD",
  "pa-IN",
  "fa-IR",
  "el-GR",
  "sv-SE",
]);

async function userOf(req: any) {
  const h = String(req.headers["authorization"] || "");
  const token = h.startsWith("Bearer ") ? h.slice(7) : "";
  if (!token) return null;
  const { data } = await admin.auth.getUser(token);
  return data?.user ?? null;
}

localeRouter.get("/locale/registry", async (_req, res) => {
  try {
    const { data, error } = await admin
      .from("locale_registry")
      .select("tag,english,native,dir,sort_n")
      .order("sort_n", { ascending: true });
    if (error) return res.json({ locales: [...TAGS].map((tag) => ({ tag })) });
    res.json({ locales: data ?? [] });
  } catch {
    res.json({ locales: [...TAGS].map((tag) => ({ tag })) });
  }
});

localeRouter.get("/locale/bundle", async (req, res) => {
  const tag = String(req.query.tag || "en-GB");
  if (!TAGS.has(tag)) return res.json({ tag: "en-GB", bundle: {} });
  try {
    const rpc = await admin.rpc("ui_copy_bundle", { p_tag: tag });
    if (!rpc.error && rpc.data && typeof rpc.data === "object") {
      return res.json({ tag, bundle: rpc.data });
    }
    const { data, error } = await admin.from("ui_copy").select("english_key,text").eq("locale_tag", tag);
    if (error) return res.json({ tag, bundle: {} });
    const bundle: Record<string, string> = {};
    for (const row of data || []) {
      const key = String(row.english_key || "");
      const text = String(row.text || "");
      if (!key || !text) continue;
      if (tag !== "en-GB" && text === key) continue;
      bundle[key] = text;
    }
    res.json({ tag, bundle });
  } catch {
    res.json({ tag, bundle: {} });
  }
});

localeRouter.get("/locale/pref", async (req, res) => {
  try {
    const user = await userOf(req);
    if (!user) return res.status(401).json({ error: "unauthorized" });
    const { data, error } = await admin
      .from("awam_locale_pref")
      .select("locale_tag,updated_at")
      .eq("user_id", user.id)
      .maybeSingle();
    if (error) return res.json({ tag: null });
    const tag = data?.locale_tag && TAGS.has(data.locale_tag) ? data.locale_tag : null;
    res.json({ tag });
  } catch {
    res.json({ tag: null });
  }
});

localeRouter.put("/locale/pref", async (req, res) => {
  try {
    const user = await userOf(req);
    if (!user) return res.status(401).json({ error: "unauthorized" });
    const tag = String(req.body?.tag || "");
    if (!TAGS.has(tag)) return res.status(400).json({ error: "locale_not_allowed" });
    const up = await admin.from("awam_locale_pref").upsert(
      { user_id: user.id, locale_tag: tag, updated_at: new Date().toISOString() },
      { onConflict: "user_id" },
    );
    if (up.error) return res.status(500).json({ error: "pref_failed" });
    res.json({ ok: true, tag });
  } catch (e: any) {
    console.error("[locale]", e?.message || e);
    res.status(500).json({ error: "locale_failed" });
  }
});

export default localeRouter;
