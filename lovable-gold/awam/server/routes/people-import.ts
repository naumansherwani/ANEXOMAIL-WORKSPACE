// ANEXOMAIL — bring your address book with you (Google Contacts / Outlook / Zoho / Apple / LinkedIn).
//
// Three routes, one rule: an import only ever touches the caller's OWN organisation.
//   POST /api/contacts/import               rows -> People (every plan)
//   POST /api/crm/leads/import              rows -> Leads (plans that have CRM; default for them — nobody is "a person you
//                                           know" until you say so)
//   POST /api/crm/leads/move-to-people      confirmed leads -> People (plans that have CRM)
//
// Nothing here sends mail, invites anyone or contacts anyone: it only writes rows. The browser reads the file; this side
// re-validates every row (server/lib/import-rows.ts) and never trusts the client.
//
// Kept in its own file on purpose: it is mounted with one line in index.ts, so the live crm.ts / contacts.ts are untouched.
import { Router } from "express";
import { admin } from "../lib/supa";
import { chunk, cleanImport, insertNewContacts, MAX_IMPORT_ROWS } from "../lib/import-rows";
import { resolvePlan, type PlanTier } from "../lib/plan";

export const peopleImport = Router();

type Ctx = {
  userId: string;
  email: string;
  orgId: string;
  role: string;
  tier: PlanTier;
  /** Same scoping as the CRM page: Pro = my own leads, Business = everyone in my organisation. */
  owners: string[];
};

async function ctx(req: any, res: any): Promise<Ctx | null> {
  const h = String(req.headers?.authorization || "");
  const token = h.startsWith("Bearer ") ? h.slice(7) : String(req.cookies?.ax_session || "");
  if (!token) {
    res.status(401).json({ error: "unauthorized" });
    return null;
  }
  const { data } = await admin.auth.getUser(token);
  const user = data?.user;
  if (!user) {
    res.status(401).json({ error: "unauthorized" });
    return null;
  }
  const email = String(user.email || "").trim().toLowerCase();
  const { data: mine } = await admin.from("org_members").select("org_id,role,status").eq("user_id", user.id);
  const live = (mine || []).filter((m: any) => m.org_id && m.status !== "revoked");
  if (!live.length) {
    res.status(409).json({ error: "no_workspace" });
    return null;
  }
  const requested = String(req.header?.("x-org-id") || req.query?.org_id || "");
  const pick = live.find((m: any) => m.org_id === requested) ?? live[0];
  if (String(pick.role || "") === "viewer") {
    res.status(403).json({ error: "read_only", message: "Your role in this workspace is read-only." });
    return null;
  }
  const orgId = String(pick.org_id);
  const { data: members } = await admin.from("org_members").select("email").eq("org_id", orgId);
  const ownerSet = new Set<string>([email]);
  for (const m of (members || []) as { email?: string | null }[]) {
    const e = String(m.email || "").trim().toLowerCase();
    if (e) ownerSet.add(e);
  }
  const owners: string[] = Array.from(ownerSet);
  const tier = await resolvePlan(user.id, email);
  return { userId: user.id, email, orgId, role: String(pick.role || "member"), tier, owners };
}

const hasCrm = (c: Ctx) => c.tier !== "basic";

function crmRequired(res: any) {
  return res.status(403).json({
    error: "package_required",
    message: "Leads are part of CRM, which starts on Pro. On your package, import straight into People.",
  });
}

const ipOf = (req: any) =>
  String(req.headers?.["x-forwarded-for"] || req.socket?.remoteAddress || "").split(",")[0]!.trim() || null;

/** Who sees which leads — identical to routes/crm.ts so an imported lead shows up on the page that owns it. */
function scopedLeads(c: Ctx) {
  const base = admin.from("crm_leads").select("*");
  return c.tier === "pro" ? base.in("owner", [c.email]) : base.in("owner", c.owners);
}

async function record(c: Ctx, req: any, decision: string, why: string, action: string, result: string) {
  // Evidence + audit are best-effort (tables optional on older databases) and must never fail an import.
  try {
    const row = { org_id: c.orgId, actor: c.email, decision, why, source_table: "crm_leads", source_id: why, action, result };
    const first = await admin.from("crm_evidence").insert(row);
    if (first.error) {
      const { org_id: _o, ...slim } = row;
      await admin.from("crm_evidence").insert(slim);
    }
  } catch {
    /* optional */
  }
  try {
    await admin.from("crm_audit").insert({ actor: c.email, action, target: why, ip: ipOf(req) });
  } catch {
    /* optional */
  }
}

/* ---------------------------------------------------------------- People */
peopleImport.post("/contacts/import", async (req: any, res: any) => {
  try {
    const c = await ctx(req, res);
    if (!c) return;
    const clean = cleanImport(req.body?.rows);
    if (clean.tooMany) return res.status(413).json({ error: "too_many_rows", max: MAX_IMPORT_ROWS });
    if (!clean.rows.length) {
      return res.status(400).json({ error: "no_valid_rows", invalid: clean.invalid, duplicate: clean.duplicate });
    }
    const r = await insertNewContacts(admin, c.orgId, clean.rows);
    return res.json({
      ok: true,
      created: r.created,
      already_in_people: r.existing,
      invalid: clean.invalid,
      duplicate: clean.duplicate,
    });
  } catch (e: any) {
    console.error("[people-import] contacts", e?.message || e);
    return res.status(500).json({ error: "import_failed" });
  }
});

/* ----------------------------------------------------------------- Leads */
peopleImport.post("/crm/leads/import", async (req: any, res: any) => {
  try {
    const c = await ctx(req, res);
    if (!c) return;
    if (!hasCrm(c)) return crmRequired(res);
    const clean = cleanImport(req.body?.rows);
    if (clean.tooMany) return res.status(413).json({ error: "too_many_rows", max: MAX_IMPORT_ROWS });
    if (!clean.rows.length) {
      return res.status(400).json({ error: "no_valid_rows", invalid: clean.invalid, duplicate: clean.duplicate });
    }

    // Anyone who is already a lead (in my scope) or already a person in this organisation is left alone.
    const emails = clean.rows.map((r) => r.email);
    const isLead = new Set<string>();
    const isPerson = new Set<string>();
    for (const part of chunk(emails, 200)) {
      const leads = await scopedLeads(c).in("email", part);
      for (const l of leads.data ?? []) isLead.add(String((l as any).email || "").toLowerCase());
      const people = await admin.from("contacts").select("primary_address").eq("org_id", c.orgId).in("primary_address", part);
      for (const p of people.data ?? []) isPerson.add(String((p as any).primary_address || "").toLowerCase());
    }
    const fresh = clean.rows.filter((r) => !isLead.has(r.email) && !isPerson.has(r.email));

    let created = 0;
    for (const part of chunk(fresh, 200)) {
      const payload = part.map((r) => ({
        email: r.email,
        display_name: r.display_name,
        company: r.company,
        source: "import",
        owner: c.email,
        state: "new",
        org_id: c.orgId,
      }));
      let ins: any = await admin.from("crm_leads").insert(payload).select("id");
      if (ins.error) {
        // Older databases without crm_leads.org_id: same fallback routes/crm.ts uses (scoping is by owner there).
        ins = await admin.from("crm_leads").insert(payload.map(({ org_id: _o, ...rest }) => rest)).select("id");
      }
      if (ins.error) return res.status(500).json({ error: "import_failed", created });
      created += (ins.data ?? []).length;
    }

    if (created) await record(c, req, "Leads imported from a file", `${created} lead${created === 1 ? "" : "s"}`, "lead.import", "new");
    return res.json({
      ok: true,
      created,
      already_leads: clean.rows.filter((r) => isLead.has(r.email)).length,
      already_in_people: clean.rows.filter((r) => !isLead.has(r.email) && isPerson.has(r.email)).length,
      invalid: clean.invalid,
      duplicate: clean.duplicate,
    });
  } catch (e: any) {
    console.error("[people-import] leads", e?.message || e);
    return res.status(500).json({ error: "import_failed" });
  }
});

peopleImport.post("/crm/leads/move-to-people", async (req: any, res: any) => {
  try {
    const c = await ctx(req, res);
    if (!c) return;
    if (!hasCrm(c)) return crmRequired(res);

    // Either an explicit list of lead ids, or "everything I imported that is still new". Never "all leads".
    const ids = Array.isArray(req.body?.ids)
      ? (req.body.ids as unknown[]).map((v) => String(v)).filter(Boolean).slice(0, MAX_IMPORT_ROWS)
      : [];
    const importedOnly = req.body?.source === "import";
    if (!ids.length && !importedOnly) return res.status(400).json({ error: "ids_or_source_required" });

    let q: any = scopedLeads(c).eq("state", "new");
    q = ids.length ? q.in("id", ids) : q.eq("source", "import");
    const found = await q.limit(MAX_IMPORT_ROWS);
    // Only rows that came back from the scoped query are ever written — an id from another organisation is simply absent.
    const leads: any[] = (found.data ?? []).filter((l: any) => l?.email);
    if (!leads.length) return res.json({ ok: true, moved: 0, added_to_people: 0, already_in_people: 0 });

    const people = leads.map((l) => ({
      email: String(l.email).trim().toLowerCase(),
      display_name: l.display_name ?? null,
      company: l.company ?? null,
    }));
    const r = await insertNewContacts(admin, c.orgId, people);
    const done = await admin.from("crm_leads").update({ state: "moved" }).in("id", leads.map((l) => l.id));
    if (done.error) return res.status(500).json({ error: "move_failed", added_to_people: r.created });

    await record(c, req, "Leads moved to People", `${leads.length} lead${leads.length === 1 ? "" : "s"}`, "lead.move_to_people", "moved");
    return res.json({ ok: true, moved: leads.length, added_to_people: r.created, already_in_people: r.existing });
  } catch (e: any) {
    console.error("[people-import] move", e?.message || e);
    return res.status(500).json({ error: "move_failed" });
  }
});

export default peopleImport;
