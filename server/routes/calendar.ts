// ANEXOMAIL — Phase 11: Calendar + Work (Express, port 3100)
// Tables: calendar_events, calendar_attendees, calendar_focus_windows,
//         work_tasks, work_promises, work_notes, mail_events, mail_thread_events
import { Router } from "express";
import { admin as supa } from "../lib/supa";

export const calendar = Router();

/* --------------------------------------------------------------- session */
async function ctx(req: any) {
  const raw = String(req.headers.authorization || "");
  const token = raw.toLowerCase().startsWith("bearer ") ? raw.slice(7).trim() : "";
  if (!token) return null;
  const { data, error } = await supa.auth.getUser(token);
  if (error || !data?.user) return null;
  const user = data.user;
  const { data: mem } = await supa
    .from("org_members")
    .select("org_id, role")
    .eq("user_id", user.id)
    .limit(1)
    .maybeSingle();
  // Personal users (no org) still get calendar — filtered by created_by = userId.
  // orgId null = personal mode. Routes check c.orgId before querying.
  return { userId: user.id, email: user.email || "", orgId: mem?.org_id ?? null, role: mem?.role ?? "member" };
}

/** org filter helper — business: by org_id; personal: by created_by */
function orgFilter(q: any, c: { orgId: string | null; userId: string }) {
  return c.orgId ? q.eq("org_id", c.orgId) : q.eq("created_by", c.userId);
}

function guard(handler: (c: any, req: any, res: any) => Promise<any>) {
  return async (req: any, res: any) => {
    try {
      const c = await ctx(req);
      if (!c) return res.status(401).json({ error: { code: "unauthorized", message: "Sign in required" } });
      await handler(c, req, res);
    } catch (e: any) {
      console.error("[calendar]", e?.message || e);
      res.status(500).json({ error: { code: "server_error", message: "Calendar failed" } });
    }
  };
}

/* ----------------------------------------------------------------- utils */
const MIN = 60_000;
const iso = (d: Date) => d.toISOString();
const mins = (a: string, b: string) => Math.max(0, (new Date(b).getTime() - new Date(a).getTime()) / MIN);

function localFor(startIso: string, tz: string | null) {
  if (!tz) return { local: null, unsociable: false };
  try {
    const s = new Date(startIso).toLocaleString("en-GB", { timeZone: tz, hour12: false });
    const hour = Number(
      new Date(startIso).toLocaleString("en-GB", { timeZone: tz, hour: "2-digit", hour12: false }),
    );
    return { local: s, unsociable: hour < 8 || hour >= 19 };
  } catch {
    return { local: null, unsociable: false };
  }
}

// Meeting cost: server truth only. No rates configured => hourly_total null.
function cost(attendeeCount: number, minutes: number, rates: number[]) {
  const hourly = rates.length ? rates.reduce((a, b) => a + b, 0) : 0;
  const total = hourly ? (hourly * minutes) / 60 : 0;
  return {
    currency: "GBP",
    total: Number(total.toFixed(2)),
    attendees: attendeeCount,
    minutes: Math.round(minutes),
    hourly_total: hourly || null,
  };
}

async function shapeEvents(orgId: string, rows: any[]) {
  const ids = rows.map((r) => r.id);
  const { data: att } = ids.length
    ? await supa.from("calendar_attendees").select("*").in("event_id", ids)
    : { data: [] as any[] };
  const { data: windows } = await supa
    .from("calendar_focus_windows")
    .select("*")
    .eq("org_id", orgId);

  const sorted = [...rows].sort(
    (a, b) => new Date(a.starts_at).getTime() - new Date(b.starts_at).getTime(),
  );

  return sorted.map((e) => {
    const mine = (att || []).filter((a: any) => a.event_id === e.id);
    const duration = mins(e.starts_at, e.ends_at);
    const attendees = mine.map((a: any) => {
      const l = localFor(e.starts_at, a.timezone ?? null);
      return {
        address: a.address,
        display_name: a.display_name ?? null,
        timezone: a.timezone ?? null,
        local_start: l.local,
        unsociable: l.unsociable,
      };
    });
    const conflict = sorted.some(
      (o) =>
        o.id !== e.id &&
        new Date(o.starts_at) < new Date(e.ends_at) &&
        new Date(o.ends_at) > new Date(e.starts_at),
    );
    const start = new Date(e.starts_at);
    const weekday = (start.getUTCDay() + 6) % 7;
    const startMin = start.getUTCHours() * 60 + start.getUTCMinutes();
    const endMin = startMin + duration;
    const shield = (windows || []).some(
      (w: any) =>
        w.protected && w.weekday === weekday && startMin < w.end_minute && endMin > w.start_minute,
    );
    return {
      id: e.id,
      title: e.title,
      starts_at: e.starts_at,
      ends_at: e.ends_at,
      all_day: Boolean(e.all_day),
      location: e.location ?? null,
      agenda: e.agenda ?? null,
      organiser: e.organiser ?? null,
      attendees,
      thread_id: e.thread_id ?? null,
      thread_subject: e.thread_subject ?? null,
      kind: e.kind || "meeting",
      status: e.status || "confirmed",
      cost: cost(
        attendees.length,
        duration,
        mine.map((a: any) => Number(a.hourly_rate || 0)).filter((n: number) => n > 0),
      ),
      conflict,
      shield_conflict: shield,
    };
  });
}

/* ------------------------------------------------------------ /events */
calendar.get(
  "/calendar/events",
  guard(async (c, req, res) => {
    const from = String(req.query.from || iso(new Date(Date.now() - 7 * 24 * 60 * MIN)));
    const to = String(req.query.to || iso(new Date(Date.now() + 21 * 24 * 60 * MIN)));
    const base = supa.from("calendar_events").select("*").gte("starts_at", from).lt("starts_at", to).order("starts_at", { ascending: true });
    const { data, error } = await orgFilter(base, c);
    if (error) throw error;
    res.json({ events: await shapeEvents(c.orgId ?? c.userId, data || []) });
  }),
);

calendar.get(
  "/calendar/events/:id",
  guard(async (c, req, res) => {
    const base = supa.from("calendar_events").select("*").eq("id", req.params.id);
    const { data: e } = await orgFilter(base, c).maybeSingle();
    if (!e) return res.status(404).json({ error: { code: "not_found", message: "Event not found" } });
    const [event] = await shapeEvents(c.orgId ?? c.userId, [e]);
    const taskBase = supa.from("work_tasks").select("*").eq("event_id", e.id);
    const { data: tasks } = await orgFilter(taskBase, c);
    res.json({
      event,
      outcome: e.outcome
        ? {
            id: e.id,
            event_id: e.id,
            decisions: e.outcome.decisions || [],
            action_items: e.outcome.action_items || [],
            posted_to_thread: Boolean(e.outcome_posted_at),
            created_at: e.outcome.created_at || e.updated_at || e.created_at,
          }
        : null,
      tasks: (tasks || []).map(shapeTask),
    });
  }),
);

// Agenda gate (locked): purpose ke bina meeting create nahi hoti.
calendar.post(
  "/calendar/events",
  guard(async (c, req, res) => {
    const b = req.body || {};
    const title = String(b.title || "").trim();
    const agenda = String(b.agenda || "").trim();
    const startsAt = b.starts_at ? new Date(b.starts_at) : null;
    const duration = Number(b.duration_minutes || 30);
    if (title.length < 2)
      return res.status(400).json({ error: { code: "bad_title", message: "Title is required" } });
    if (agenda.length < 5)
      return res
        .status(400)
        .json({ error: { code: "agenda_required", message: "A meeting needs a purpose" } });
    if (!startsAt || Number.isNaN(startsAt.getTime()))
      return res.status(400).json({ error: { code: "bad_time", message: "Start time is invalid" } });

    const ends = new Date(startsAt.getTime() + duration * MIN);
    const { data: e, error } = await supa
      .from("calendar_events")
      .insert({
        org_id: c.orgId || null,
        title,
        agenda,
        starts_at: iso(startsAt),
        ends_at: iso(ends),
        all_day: false,
        location: b.location || null,
        organiser: c.email,
        thread_id: b.thread_id || null,
        thread_subject: b.thread_subject || null,
        kind: "meeting",
        status: "confirmed",
        created_by: c.userId,
      })
      .select("*")
      .single();
    if (error) throw error;

    const list: string[] = Array.isArray(b.attendees) ? b.attendees : [];
    const rows = [...new Set([c.email, ...list].filter(Boolean))].map((address: string) => ({
      event_id: e.id,
      org_id: c.orgId,
      address,
      timezone: b.timezone || null,
      response: address === c.email ? "accepted" : "needs_action",
    }));
    if (rows.length) await supa.from("calendar_attendees").insert(rows);

    if (b.thread_id) {
      await supa.from("mail_thread_events").insert({
        org_id: c.orgId,
        thread_id: b.thread_id,
        kind: "meeting_created",
        actor: c.email,
        payload: { event_id: e.id, title },
      });
    }
    const [event] = await shapeEvents(c.orgId, [e]);
    res.json({ event });
  }),
);

/* ----------------------------------------------------- availability */
calendar.get(
  "/calendar/availability",
  guard(async (c, req, res) => {
    const day = String(req.query.date || new Date().toISOString().slice(0, 10));
    const start = new Date(`${day}T00:00:00.000Z`);
    const end = new Date(start.getTime() + 24 * 60 * MIN);
    const evBase = supa.from("calendar_events").select("starts_at, ends_at, title, kind").gte("starts_at", iso(start)).lt("starts_at", iso(end));
    const { data: events } = await orgFilter(evBase, c);
    const winBase = supa.from("calendar_focus_windows").select("*");
    const { data: windows } = c.orgId ? winBase.eq("org_id", c.orgId) : winBase.eq("created_by", c.userId);

    const weekday = (start.getUTCDay() + 6) % 7;
    const slots: any[] = [];
    for (let m = 8 * 60; m < 19 * 60; m += 30) {
      const s = new Date(start.getTime() + m * MIN);
      const e = new Date(s.getTime() + 30 * MIN);
      const busy = (events || []).find(
        (ev: any) => new Date(ev.starts_at) < e && new Date(ev.ends_at) > s,
      );
      const buffer = (events || []).find((ev: any) => {
        const gapStart = new Date(new Date(ev.ends_at).getTime());
        const gapEnd = new Date(gapStart.getTime() + 15 * MIN);
        return gapStart <= s && gapEnd > s;
      });
      const focus = (windows || []).find(
        (w: any) => w.weekday === weekday && m < w.end_minute && m + 30 > w.start_minute,
      );
      const state = busy ? "busy" : focus ? "focus" : buffer ? "travel_buffer" : "free";
      if (state === "free" || state === "focus" || state === "travel_buffer")
        slots.push({
          starts_at: iso(s),
          ends_at: iso(e),
          state,
          label: focus ? focus.label : busy ? busy.title : null,
        });
    }
    res.json({ slots, share_url: `/api/calendar/availability?date=${day}` });
  }),
);

calendar.get(
  "/calendar/focus",
  guard(async (c, _req, res) => {
    const base = supa.from("calendar_focus_windows").select("*").order("weekday", { ascending: true });
    const { data } = c.orgId ? await base.eq("org_id", c.orgId) : await base.eq("created_by", c.userId);
    res.json({
      windows: (data || []).map((w: any) => ({
        id: w.id,
        label: w.label,
        weekday: w.weekday,
        start_minute: w.start_minute,
        end_minute: w.end_minute,
        protected: Boolean(w.protected),
      })),
    });
  }),
);

/* ------------------------------------------------------------ team load */
calendar.get(
  "/calendar/load",
  guard(async (c, req, res) => {
    const from = String(req.query.from || iso(new Date()));
    const to = String(req.query.to || iso(new Date(Date.now() + 7 * 24 * 60 * MIN)));
    const evBase = supa.from("calendar_events").select("id, starts_at, ends_at").gte("starts_at", from).lt("starts_at", to);
    const { data: events } = await orgFilter(evBase, c);
    const ids = (events || []).map((e: any) => e.id);
    const { data: att } = ids.length
      ? await supa.from("calendar_attendees").select("event_id, address, display_name").in("event_id", ids)
      : { data: [] as any[] };
    const taskBase = supa.from("work_tasks").select("owner, status").neq("status", "done");
    const { data: tasks } = await orgFilter(taskBase, c);

    const byMinutes = new Map<string, { name: string | null; minutes: number }>();
    for (const a of att || []) {
      const ev = (events || []).find((e: any) => e.id === a.event_id);
      if (!ev) continue;
      const cur = byMinutes.get(a.address) || { name: a.display_name ?? null, minutes: 0 };
      cur.minutes += mins(ev.starts_at, ev.ends_at);
      byMinutes.set(a.address, cur);
    }
    const load = [...byMinutes.entries()]
      .map(([member, v]) => ({
        member,
        display_name: v.name,
        meeting_minutes: Math.round(v.minutes),
        open_tasks: (tasks || []).filter((t: any) => t.owner === member).length,
        overloaded: v.minutes > 15 * 60,
      }))
      .sort((a, b) => b.meeting_minutes - a.meeting_minutes);
    res.json({ load });
  }),
);

/* --------------------------------------------------------------- export */
calendar.get(
  "/calendar/export",
  guard(async (c, req, res) => {
    const base = supa.from("calendar_events").select("*").order("starts_at", { ascending: true });
    const { data } = await orgFilter(base, c);
    if (String(req.query.format) === "json") return res.json({ events: data || [] });
    const stamp = (s: string) => new Date(s).toISOString().replace(/[-:]/g, "").split(".")[0] + "Z";
    const lines = [
      "BEGIN:VCALENDAR",
      "VERSION:2.0",
      "PRODID:-//ANEXOMAIL//Workspace//EN",
      ...(data || []).flatMap((e: any) => [
        "BEGIN:VEVENT",
        `UID:${e.id}@anexomail.com`,
        `DTSTART:${stamp(e.starts_at)}`,
        `DTEND:${stamp(e.ends_at)}`,
        `SUMMARY:${String(e.title || "").replace(/\r?\n/g, " ")}`,
        e.agenda ? `DESCRIPTION:${String(e.agenda).replace(/\r?\n/g, "\\n")}` : "",
        e.location ? `LOCATION:${e.location}` : "",
        "END:VEVENT",
      ]),
      "END:VCALENDAR",
    ].filter(Boolean);
    res.setHeader("content-type", "text/calendar; charset=utf-8");
    res.setHeader("content-disposition", 'attachment; filename="anexomail.ics"');
    res.send(lines.join("\r\n"));
  }),
);

/* ------------------------------------------------------- meeting outcome */
calendar.post(
  "/calendar/events/:id/outcome",
  guard(async (c, req, res) => {
    const outBase = supa.from("calendar_events").select("*").eq("id", req.params.id);
    const { data: e } = await orgFilter(outBase, c).maybeSingle();
    if (!e) return res.status(404).json({ error: { code: "not_found", message: "Event not found" } });
    if (!e.outcome)
      return res
        .status(409)
        .json({ error: { code: "no_outcome", message: "No outcome recorded for this meeting yet" } });

    const items = (e.outcome.action_items || []) as any[];
    if (items.length) {
      await supa.from("work_tasks").insert(
        items.map((i) => ({
          org_id: c.orgId || null,
          title: i.title,
          owner: i.owner || null,
          due_at: i.due_at || null,
          status: "todo",
          event_id: e.id,
          thread_id: e.thread_id || null,
          source: "meeting_outcome",
          created_by: c.userId,
        })),
      );
    }
    if (e.thread_id) {
      await supa.from("mail_thread_events").insert({
        org_id: c.orgId,
        thread_id: e.thread_id,
        kind: "meeting_outcome_posted",
        actor: c.email,
        payload: { event_id: e.id, decisions: e.outcome.decisions || [] },
      });
    }
    await supa
      .from("calendar_events")
      .update({ outcome_posted_at: iso(new Date()) })
      .eq("id", e.id);
    res.json({ ok: true, tasks_created: items.length });
  }),
);

/* ================================================================ WORK */
function shapeTask(t: any) {
  return {
    id: t.id,
    title: t.title,
    status: t.status || "todo",
    owner: t.owner ?? null,
    due_at: t.due_at ?? null,
    thread_id: t.thread_id ?? null,
    thread_subject: t.thread_subject ?? null,
    event_id: t.event_id ?? null,
    source: t.source || "manual",
    created_at: t.created_at,
    completed_at: t.completed_at ?? null,
    late: Boolean(t.completed_at && t.due_at && new Date(t.completed_at) > new Date(t.due_at)),
  };
}

calendar.get(
  "/work/tasks",
  guard(async (c, req, res) => {
    let q = orgFilter(supa.from("work_tasks").select("*"), c);
    if (req.query.thread_id) q = q.eq("thread_id", String(req.query.thread_id));
    if (req.query.event_id) q = q.eq("event_id", String(req.query.event_id));
    if (req.query.view === "mine") q = q.eq("owner", c.email);
    const { data, error } = await q.order("created_at", { ascending: false }).limit(400);
    if (error) throw error;
    res.json({ tasks: (data || []).map(shapeTask) });
  }),
);

calendar.post(
  "/work/tasks",
  guard(async (c, req, res) => {
    const title = String(req.body?.title || "").trim();
    if (title.length < 2)
      return res.status(400).json({ error: { code: "bad_title", message: "Title is required" } });
    const { data, error } = await supa
      .from("work_tasks")
      .insert({
        org_id: c.orgId || null,
        title,
        status: "todo",
        owner: req.body?.owner ?? c.email,
        due_at: req.body?.due_at ?? null,
        thread_id: req.body?.thread_id ?? null,
        event_id: req.body?.event_id ?? null,
        source: "manual",
        created_by: c.userId,
      })
      .select("*")
      .single();
    if (error) throw error;
    res.json({ task: shapeTask(data) });
  }),
);

calendar.patch(
  "/work/tasks/:id",
  guard(async (c, req, res) => {
    const patch: any = {};
    if (req.body?.status) {
      patch.status = req.body.status;
      patch.completed_at = req.body.status === "done" ? iso(new Date()) : null;
    }
    if ("owner" in (req.body || {})) patch.owner = req.body.owner;
    if ("due_at" in (req.body || {})) patch.due_at = req.body.due_at;
    const patchQ = orgFilter(supa.from("work_tasks").update(patch).eq("id", req.params.id), c);
    const { data, error } = await patchQ
      .select("*")
      .maybeSingle();
    if (error) throw error;
    if (!data) return res.status(404).json({ error: { code: "not_found", message: "Task not found" } });
    res.json({ task: shapeTask(data) });
  }),
);

/* ----------------------------------------------------------- promises */
calendar.get(
  "/work/promises",
  guard(async (c, _req, res) => {
    const pBase = supa.from("work_promises").select("*").eq("status", "suggested");
    const { data, error } = await orgFilter(pBase, c)
      .order("detected_at", { ascending: false })
      .limit(100);
    if (error) throw error;
    res.json({
      promises: (data || []).map((p: any) => ({
        id: p.id,
        quote: p.quote,
        suggested_title: p.suggested_title,
        suggested_due_at: p.suggested_due_at ?? null,
        thread_id: p.thread_id,
        thread_subject: p.thread_subject ?? null,
        detected_at: p.detected_at || p.created_at,
        confidence: Number(p.confidence || 0),
      })),
    });
  }),
);

calendar.post(
  "/work/promises/:id/commit",
  guard(async (c, req, res) => {
    const pBase2 = supa.from("work_promises").select("*").eq("id", req.params.id);
    const { data: p } = await orgFilter(pBase2, c).maybeSingle();
    if (!p) return res.status(404).json({ error: { code: "not_found", message: "Promise not found" } });
    const { data: task } = await supa
      .from("work_tasks")
      .insert({
        org_id: c.orgId || null,
        title: p.suggested_title,
        status: "todo",
        owner: p.owner || c.email,
        due_at: p.suggested_due_at ?? null,
        thread_id: p.thread_id,
        thread_subject: p.thread_subject ?? null,
        source: "promise",
        created_by: c.userId,
      })
      .select("*")
      .single();
    await supa
      .from("work_promises")
      .update({ status: "committed", task_id: task?.id ?? null })
      .eq("id", p.id);
    res.json({ ok: true, task: task ? shapeTask(task) : null });
  }),
);

calendar.post(
  "/work/promises/:id/dismiss",
  guard(async (c, req, res) => {
    await orgFilter(supa.from("work_promises").update({ status: "dismissed" }).eq("id", req.params.id), c);
    res.json({ ok: true });
  }),
);

/* --------------------------------------------------- follow-through score */
calendar.get(
  "/work/follow-through",
  guard(async (c, req, res) => {
    const scope = String(req.query.scope || "person") === "team" ? "team" : "person";
    const ftBase = supa.from("work_tasks").select("owner, status, due_at, completed_at").not("due_at", "is", null);
    const { data } = await orgFilter(ftBase, c);

    const bucket = new Map<string, { made: number; onTime: number; late: number; broken: number }>();
    for (const t of data || []) {
      const key = scope === "team" ? "team" : t.owner || "unassigned";
      const b = bucket.get(key) || { made: 0, onTime: 0, late: 0, broken: 0 };
      b.made += 1;
      if (t.completed_at) {
        if (new Date(t.completed_at) <= new Date(t.due_at)) b.onTime += 1;
        else b.late += 1;
      } else if (new Date(t.due_at) < new Date()) b.broken += 1;
      bucket.set(key, b);
    }
    const rows = [...bucket.entries()]
      .map(([subject, b]) => ({
        scope,
        subject,
        display_name: null,
        promises_made: b.made,
        kept_on_time: b.onTime,
        kept_late: b.late,
        broken: b.broken,
        score: b.made ? Math.round(((b.onTime + b.late * 0.5) / b.made) * 100) : null,
      }))
      .sort((a, b) => (b.score ?? 0) - (a.score ?? 0));
    res.json({ rows });
  }),
);

/* ------------------------------------------------------------------ notes */
calendar.get(
  "/work/notes",
  guard(async (c, req, res) => {
    let q = orgFilter(supa.from("work_notes").select("*"), c);
    if (req.query.thread_id) q = q.eq("thread_id", String(req.query.thread_id));
    else if (req.query.event_id) q = q.eq("event_id", String(req.query.event_id));
    else return res.json({ note: null });
    const { data } = await q.order("updated_at", { ascending: false }).limit(1).maybeSingle();
    res.json({
      note: data
        ? {
            id: data.id,
            body: data.body || "",
            thread_id: data.thread_id ?? null,
            event_id: data.event_id ?? null,
            updated_at: data.updated_at || data.created_at,
            updated_by: data.updated_by ?? null,
          }
        : null,
    });
  }),
);

calendar.post(
  "/work/notes",
  guard(async (c, req, res) => {
    const body = String(req.body?.body ?? "");
    const threadId = req.body?.thread_id ?? null;
    const eventId = req.body?.event_id ?? null;
    if (!threadId && !eventId)
      return res
        .status(400)
        .json({ error: { code: "no_target", message: "A note belongs to a thread or a meeting" } });
    let q = supa.from("work_notes").select("id").eq("org_id", c.orgId);
    q = threadId ? q.eq("thread_id", threadId) : q.eq("event_id", eventId);
    const { data: existing } = await q.limit(1).maybeSingle();
    if (existing) {
      await supa
        .from("work_notes")
        .update({ body, updated_at: iso(new Date()), updated_by: c.email })
        .eq("id", existing.id);
      return res.json({ ok: true, id: existing.id });
    }
    const { data, error } = await supa
      .from("work_notes")
      .insert({
        org_id: c.orgId || null,
        body,
        thread_id: threadId,
        event_id: eventId,
        updated_by: c.email,
        created_by: c.userId,
      })
      .select("id")
      .single();
    if (error) throw error;
    res.json({ ok: true, id: data.id });
  }),
);

export default calendar;
