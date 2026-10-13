// ANEXOMAIL — Phase 10 Contacts & Communication Intelligence API
// Owns: contacts (auto-derived from real mail), companies rollup, tags,
// communication timeline, relationship intelligence, universal search.
// NO MOCK: sab kuch Supabase 4 ke real mail data se banta hai.
import { Router } from "express";
import { admin as supa } from "../lib/supa";

type Ctx = { userId: string; orgId: string };

async function ctx(req: any, res: any): Promise<Ctx | null> {
  const bearer = (req.headers.authorization || "").replace(/^Bearer\s+/i, "");
  const token = bearer || req.cookies?.ax_session || "";
  if (!token) { res.status(401).json({ error: "unauthenticated" }); return null; }
  const { data, error } = await supa.auth.getUser(token);
  if (error || !data?.user) { res.status(401).json({ error: "unauthenticated" }); return null; }
  const userId = data.user.id;
  const requested = (req.header("x-org-id") || req.query.org_id || "") as string;
  const { data: rows } = await supa.from("org_members").select("org_id").eq("user_id", userId);
  const ids = (rows || []).map((r: any) => r.org_id);
  if (!ids.length) { res.status(409).json({ error: "no_workspace" }); return null; }
  const orgId = requested && ids.includes(requested) ? requested : ids[0];
  return { userId, orgId };
}

/* ------------------------------------------------------------ derivation */
// Contacts real mail se derive hote hain. Har list read se pehle ek sasta
// rebuild chalta hai (throttled), taake founder ko kabhi stale list na mile.
const lastBuild = new Map<string, number>();
const BUILD_EVERY_MS = 60_000;

async function ensureFresh(orgId: string) {
  const now = Date.now();
  const prev = lastBuild.get(orgId) || 0;
  if (now - prev < BUILD_EVERY_MS) return;
  lastBuild.set(orgId, now);
  const { error } = await supa.rpc("anexo_rebuild_contacts", { p_org: orgId });
  if (error) console.error("[contacts.rebuild]", error.message);
}

/* ----------------------------------------------------------------- shape */

function relationshipOf(row: any): string {
  const r = row?.relationship || row?.stats?.relationship;
  if (r) return r;
  return "new";
}

function shapeContact(row: any, tagNames: string[] = []): any {
  const s = row.stats || {};
  return {
    id: row.id,
    display_name: row.display_name ?? null,
    primary_address: row.primary_address,
    addresses: Array.isArray(row.addresses) && row.addresses.length ? row.addresses : [row.primary_address],
    title: row.title ?? null,
    company_domain: row.company_domain ?? null,
    company_name: row.company_name ?? row.company?.name ?? null,
    tags: tagNames,
    vip: Boolean(row.vip),
    relationship: relationshipOf({ ...row, stats: s }),
    health_score: s.health_score ?? row.health_score ?? null,
    last_contact_at: s.last_contact_at ?? row.last_contact_at ?? null,
    messages_in: s.messages_in ?? 0,
    messages_out: s.messages_out ?? 0,
    avg_reply_minutes: s.avg_reply_minutes ?? null,
    open_threads: s.open_threads ?? 0,
    notes: row.notes ?? null,
  };
}

// No PostgREST `company:companies(...)` embed. Live DB often has company_domain
// without a contacts→companies FK in the schema cache (PGRST200). Names come
// from a second query on `companies.domain`.
const SELECT_CONTACT =
  "id, display_name, primary_address, addresses, title, company_domain, vip, notes, " +
  "stats:contact_stats(messages_in, messages_out, avg_reply_minutes, open_threads, " +
  "last_contact_at, relationship, health_score)";

const SELECT_CONTACT_PLAIN =
  "id, display_name, primary_address, addresses, title, company_domain, vip, notes";

async function withCompanyNames(orgId: string, rows: any[]): Promise<any[]> {
  const domains = [
    ...new Set(
      rows
        .map((r) => String(r.company_domain || "").trim().toLowerCase())
        .filter(Boolean),
    ),
  ];
  if (!domains.length) return rows;
  const { data } = await supa
    .from("companies")
    .select("domain, name")
    .eq("org_id", orgId)
    .in("domain", domains);
  const names = new Map<string, string>();
  for (const c of data || []) {
    const d = String((c as any).domain || "").trim().toLowerCase();
    const n = String((c as any).name || "").trim();
    if (d && n) names.set(d, n);
  }
  return rows.map((r) => {
    const d = String(r.company_domain || "").trim().toLowerCase();
    const name = names.get(d);
    if (!name) return r;
    return { ...r, company: { name }, company_name: r.company_name || name };
  });
}

function isSchemaCacheError(message: string | undefined): boolean {
  return /schema cache|PGRST200|relationship between/i.test(String(message || ""));
}

async function tagsFor(orgId: string, contactIds: string[]) {
  const map = new Map<string, string[]>();
  if (!contactIds.length) return map;
  const { data } = await supa
    .from("contact_tag_map")
    .select("contact_id, tag:contact_tags(name)")
    .eq("org_id", orgId)
    .in("contact_id", contactIds);
  for (const r of data || []) {
    const name = (r as any).tag?.name;
    if (!name) continue;
    const arr = map.get((r as any).contact_id) || [];
    arr.push(name);
    map.set((r as any).contact_id, arr);
  }
  return map;
}

export const contactsRouter = Router();

/* ------------------------------------------------------------ list + tags */

contactsRouter.get("/contacts/tags", async (req, res) => {
  const c = await ctx(req, res); if (!c) return;
  const { data, error } = await supa
    .from("contact_tags")
    .select("id, name, colour")
    .eq("org_id", c.orgId)
    .order("name");
  if (error) return res.status(500).json({ error: error.message });

  const counts = new Map<string, number>();
  const { data: links } = await supa
    .from("contact_tag_map")
    .select("tag_id")
    .eq("org_id", c.orgId);
  for (const l of links || []) {
    const k = (l as any).tag_id;
    counts.set(k, (counts.get(k) || 0) + 1);
  }
  res.json({
    tags: (data || []).map((t: any) => ({ ...t, count: counts.get(t.id) || 0 })),
  });
});

contactsRouter.get("/contacts", async (req, res) => {
  const c = await ctx(req, res); if (!c) return;
  await ensureFresh(c.orgId);

  const q = String(req.query.q || "").trim();
  const filter = String(req.query.filter || "all");
  const tag = String(req.query.tag || "").trim();

  const applyFilters = (select: string) => {
    let query = supa.from("contacts").select(select).eq("org_id", c.orgId);
    if (q) {
      const like = `%${q}%`;
      query = query.or(
        `display_name.ilike.${like},primary_address.ilike.${like},company_domain.ilike.${like}`,
      );
    }
    if (filter === "vip") query = query.eq("vip", true);
    return query.limit(500);
  };

  let { data, error } = await applyFilters(SELECT_CONTACT);
  if (error && isSchemaCacheError(error.message)) {
    ({ data, error } = await applyFilters(SELECT_CONTACT_PLAIN));
  }
  if (error) return res.status(500).json({ error: error.message });

  let rows = await withCompanyNames(c.orgId, data || []);

  // relationship / behaviour filters (stats side)
  const rel = (r: any) => r.stats?.relationship || "new";
  if (filter === "at_risk") rows = rows.filter((r: any) => rel(r) === "at_risk");
  if (filter === "dormant") rows = rows.filter((r: any) => rel(r) === "dormant");
  if (filter === "unanswered") rows = rows.filter((r: any) => (r.stats?.open_threads || 0) > 0);

  const tagMap = await tagsFor(c.orgId, rows.map((r: any) => r.id));

  // tag-driven filters (customer / vendor / investor are just owned tags)
  const wantTag =
    tag || (["customer", "vendor", "investor"].includes(filter) ? filter : "");
  if (wantTag) {
    rows = rows.filter((r: any) =>
      (tagMap.get(r.id) || []).some((n) => n.toLowerCase() === wantTag.toLowerCase()),
    );
  }

  const contacts = rows
    .map((r: any) => shapeContact(r, tagMap.get(r.id) || []))
    .sort((a, b) => String(b.last_contact_at || "").localeCompare(String(a.last_contact_at || "")));

  res.json({ contacts });
});

/* --------------------------------------------------------------- one + edit */

contactsRouter.get("/contacts/:id", async (req, res) => {
  const c = await ctx(req, res); if (!c) return;
  let { data, error } = await supa
    .from("contacts")
    .select(SELECT_CONTACT)
    .eq("org_id", c.orgId)
    .eq("id", req.params.id)
    .maybeSingle();
  if (error && isSchemaCacheError(error.message)) {
    ({ data, error } = await supa
      .from("contacts")
      .select(SELECT_CONTACT_PLAIN)
      .eq("org_id", c.orgId)
      .eq("id", req.params.id)
      .maybeSingle());
  }
  if (error) return res.status(500).json({ error: error.message });
  if (!data) return res.status(404).json({ error: "not_found" });
  const [row] = await withCompanyNames(c.orgId, [data]);
  const tagMap = await tagsFor(c.orgId, [req.params.id]);
  res.json({ contact: shapeContact(row, tagMap.get(req.params.id) || []) });
});

contactsRouter.patch("/contacts/:id", async (req, res) => {
  const c = await ctx(req, res); if (!c) return;
  const b = req.body || {};
  const patch: any = {};
  if (typeof b.display_name === "string") patch.display_name = b.display_name.slice(0, 200);
  if (typeof b.title === "string") patch.title = b.title.slice(0, 200);
  if (typeof b.notes === "string") patch.notes = b.notes.slice(0, 5000);
  if (typeof b.vip === "boolean") patch.vip = b.vip;
  if (!Object.keys(patch).length) return res.status(400).json({ error: "nothing_to_update" });

  const { error } = await supa
    .from("contacts")
    .update(patch)
    .eq("org_id", c.orgId)
    .eq("id", req.params.id);
  if (error) return res.status(500).json({ error: error.message });
  res.json({ ok: true });
});

/* ----------------------------------------------------------------- tagging */

contactsRouter.post("/contacts/:id/tags", async (req, res) => {
  const c = await ctx(req, res); if (!c) return;
  const add: string[] = Array.isArray(req.body?.add) ? req.body.add : [];
  const remove: string[] = Array.isArray(req.body?.remove) ? req.body.remove : [];
  const contactId = req.params.id;

  for (const raw of add) {
    const name = String(raw).trim().slice(0, 60);
    if (!name) continue;
    let tagId: string | null = null;
    const { data: found } = await supa
      .from("contact_tags")
      .select("id")
      .eq("org_id", c.orgId)
      .ilike("name", name)
      .maybeSingle();
    if (found?.id) tagId = found.id;
    else {
      const { data: made, error } = await supa
        .from("contact_tags")
        .insert({ org_id: c.orgId, name, created_by: c.userId })
        .select("id")
        .maybeSingle();
      if (error) return res.status(500).json({ error: error.message });
      tagId = made?.id ?? null;
    }
    if (!tagId) continue;
    await supa
      .from("contact_tag_map")
      .upsert({ org_id: c.orgId, contact_id: contactId, tag_id: tagId }, { onConflict: "contact_id,tag_id" });
  }

  for (const raw of remove) {
    const name = String(raw).trim();
    if (!name) continue;
    const { data: found } = await supa
      .from("contact_tags")
      .select("id")
      .eq("org_id", c.orgId)
      .ilike("name", name)
      .maybeSingle();
    if (!found?.id) continue;
    await supa
      .from("contact_tag_map")
      .delete()
      .eq("org_id", c.orgId)
      .eq("contact_id", contactId)
      .eq("tag_id", found.id);
  }

  res.json({ ok: true });
});

/* ---------------------------------------------------------------- timeline */

async function timelineForAddresses(orgId: string, addresses: string[]) {
  if (!addresses.length) return [];
  const ors = addresses
    .flatMap((a) => [`from_address.ilike.%${a}%`, `to_addresses.ilike.%${a}%`])
    .join(",");
  const { data, error } = await supa
    .from("mail_messages")
    .select("id, thread_id, subject, snippet, from_address, to_addresses, direction, sent_at")
    .eq("org_id", orgId)
    .or(ors)
    .order("sent_at", { ascending: false })
    .limit(200);
  if (error) { console.error("[contacts.timeline]", error.message); return []; }

  return (data || []).map((m: any) => ({
    id: m.id,
    kind: m.direction === "out" ? "message_out" : "message_in",
    at: m.sent_at,
    title: m.subject || "(no subject)",
    detail: m.snippet || null,
    thread_id: m.thread_id || null,
    actor: m.from_address || null,
  }));
}

contactsRouter.get("/contacts/:id/timeline", async (req, res) => {
  const c = await ctx(req, res); if (!c) return;
  const { data: row } = await supa
    .from("contacts")
    .select("primary_address, addresses")
    .eq("org_id", c.orgId)
    .eq("id", req.params.id)
    .maybeSingle();
  if (!row) return res.status(404).json({ error: "not_found" });
  const addresses = Array.isArray(row.addresses) && row.addresses.length
    ? row.addresses
    : [row.primary_address];
  res.json({ events: await timelineForAddresses(c.orgId, addresses) });
});

/* --------------------------------------------------------------- companies */

function shapeCompany(row: any, people: any[]): any {
  const inSum = people.reduce((n, p) => n + (p.messages_in || 0), 0);
  const outSum = people.reduce((n, p) => n + (p.messages_out || 0), 0);
  const open = people.reduce((n, p) => n + (p.open_threads || 0), 0);
  const last = people
    .map((p) => p.last_contact_at)
    .filter(Boolean)
    .sort()
    .pop() || null;
  const risky = people.some((p) => p.relationship === "at_risk");
  const scores = people.map((p) => p.health_score).filter((n) => typeof n === "number");
  return {
    domain: row.domain,
    name: row.name ?? null,
    people_count: people.length,
    messages_total: inSum + outSum,
    open_threads: open,
    relationship: risky ? "at_risk" : people[0]?.relationship || "new",
    health_score: scores.length ? Math.round(scores.reduce((a, b) => a + b, 0) / scores.length) : null,
    last_contact_at: last,
  };
}

async function peopleOfDomain(orgId: string, domain: string) {
  let { data, error } = await supa
    .from("contacts")
    .select(SELECT_CONTACT)
    .eq("org_id", orgId)
    .eq("company_domain", domain)
    .limit(500);
  if (error && isSchemaCacheError(error.message)) {
    ({ data } = await supa
      .from("contacts")
      .select(SELECT_CONTACT_PLAIN)
      .eq("org_id", orgId)
      .eq("company_domain", domain)
      .limit(500));
  }
  const rows = await withCompanyNames(orgId, data || []);
  const tagMap = await tagsFor(orgId, rows.map((r: any) => r.id));
  return rows.map((r: any) => shapeContact(r, tagMap.get(r.id) || []));
}

contactsRouter.get("/companies", async (req, res) => {
  const c = await ctx(req, res); if (!c) return;
  await ensureFresh(c.orgId);
  const q = String(req.query.q || "").trim();

  let query = supa.from("companies").select("domain, name").eq("org_id", c.orgId);
  if (q) query = query.or(`domain.ilike.%${q}%,name.ilike.%${q}%`);
  const { data, error } = await query.limit(300);
  if (error) return res.status(500).json({ error: error.message });

  const companies: any[] = [];
  for (const row of data || []) {
    companies.push(shapeCompany(row, await peopleOfDomain(c.orgId, (row as any).domain)));
  }
  companies.sort((a, b) => String(b.last_contact_at || "").localeCompare(String(a.last_contact_at || "")));
  res.json({ companies });
});

contactsRouter.get("/companies/:domain", async (req, res) => {
  const c = await ctx(req, res); if (!c) return;
  const domain = String(req.params.domain).toLowerCase();
  const { data } = await supa
    .from("companies")
    .select("domain, name")
    .eq("org_id", c.orgId)
    .eq("domain", domain)
    .maybeSingle();
  if (!data) return res.status(404).json({ error: "not_found" });
  const people = await peopleOfDomain(c.orgId, domain);
  res.json({ company: shapeCompany(data, people), people });
});

contactsRouter.get("/companies/:domain/timeline", async (req, res) => {
  const c = await ctx(req, res); if (!c) return;
  const domain = String(req.params.domain).toLowerCase();
  res.json({ events: await timelineForAddresses(c.orgId, [`@${domain}`]) });
});

/* ------------------------------------------------------- universal search */

contactsRouter.get("/search/universal", async (req, res) => {
  const c = await ctx(req, res); if (!c) return;
  const q = String(req.query.q || "").trim();
  if (q.length < 2) {
    return res.json({ people: [], companies: [], threads: [], attachments: [] });
  }
  const like = `%${q}%`;

  let peopleRes = await supa
    .from("contacts")
    .select(SELECT_CONTACT)
    .eq("org_id", c.orgId)
    .or(`display_name.ilike.${like},primary_address.ilike.${like}`)
    .limit(8);
  if (peopleRes.error && isSchemaCacheError(peopleRes.error.message)) {
    peopleRes = await supa
      .from("contacts")
      .select(SELECT_CONTACT_PLAIN)
      .eq("org_id", c.orgId)
      .or(`display_name.ilike.${like},primary_address.ilike.${like}`)
      .limit(8);
  }

  const [companyRes, threadRes, attachRes] = await Promise.all([
    supa
      .from("companies")
      .select("domain, name")
      .eq("org_id", c.orgId)
      .or(`domain.ilike.${like},name.ilike.${like}`)
      .limit(6),
    supa
      .from("mail_threads")
      .select("id, subject, snippet, from_address, folder, last_message_at")
      .eq("org_id", c.orgId)
      .or(`subject.ilike.${like},snippet.ilike.${like},from_address.ilike.${like}`)
      .order("last_message_at", { ascending: false })
      .limit(10),
    supa
      .from("mail_attachments")
      .select("id, filename, size_bytes, thread_id, sent_at")
      .eq("org_id", c.orgId)
      .ilike("filename", like)
      .order("sent_at", { ascending: false })
      .limit(8),
  ]);

  const peopleRows = await withCompanyNames(c.orgId, peopleRes.data || []);
  const tagMap = await tagsFor(c.orgId, peopleRows.map((r: any) => r.id));

  const companies: any[] = [];
  for (const row of companyRes.data || []) {
    companies.push(shapeCompany(row, await peopleOfDomain(c.orgId, (row as any).domain)));
  }

  res.json({
    people: peopleRows.map((r: any) => shapeContact(r, tagMap.get(r.id) || [])),
    companies,
    threads: (threadRes.data || []).map((t: any) => ({
      id: t.id,
      subject: t.subject || "(no subject)",
      snippet: t.snippet ?? null,
      from_address: t.from_address || "",
      folder: t.folder || "inbox",
      last_message_at: t.last_message_at,
    })),
    attachments: (attachRes.data || []).map((a: any) => ({
      id: a.id,
      filename: a.filename,
      size_bytes: a.size_bytes || 0,
      thread_id: a.thread_id ?? null,
      folder: "inbox",
      sent_at: a.sent_at,
    })),
  });
});

export default contactsRouter;
