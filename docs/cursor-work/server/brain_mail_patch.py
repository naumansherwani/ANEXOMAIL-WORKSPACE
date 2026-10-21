#!/usr/bin/env python3
"""B3: Bun mail-worker.ts + routes/mail-compose.ts ko claim-based banata hai (Rust worker ke saath dono chal sakein, mail ek hi baar jaye).
   python3 -I brain_mail_patch.py <live mail-worker.ts> <live mail-compose.ts> <out-worker.ts> <out-compose.ts>  -> "same" | "update" | exit 3
E54 abhi na laga ho to bhi mail rukti nahi: rpc 'function nahi' kahe to purana select / purana cancel chalta hai."""
import sys
wsrc, csrc, wout, cout = sys.argv[1:5]
w = open(wsrc).read(); c = open(csrc).read()
W_OLD = ('    const nowIso = new Date().toISOString();\n'
 '    const { data: rows, error } = await supa\n'
 '      .from("mail_scheduled")\n'
 '      .select("id, org_id, user_id, identity, to, cc, bcc, subject, body, thread_id, attachment_ids")\n'
 '      .eq("status", "queued")\n'
 '      .lte("send_at", nowIso)\n'
 '      .limit(20);\n')
W_NEW = ('    // B3: ek row ek hi worker (Bun ya Rust) uthaye — mail_queue_claim (E54, FOR UPDATE SKIP LOCKED). E54 na ho to purana tareeqa.\n'
 '    let { data: rows, error }: { data: any[] | null; error: any } = (await supa.rpc("mail_queue_claim", { _limit: 20, _stale_minutes: 10 })) as any;\n'
 '    if (error && /mail_queue_claim|PGRST202|schema cache/i.test(String(error.message || error.code || ""))) {\n'
 '      ({ data: rows, error } = (await supa\n'
 '        .from("mail_scheduled")\n'
 '        .select("id, org_id, user_id, identity, to, cc, bcc, subject, body, thread_id, attachment_ids")\n'
 '        .eq("status", "queued")\n'
 '        .lte("send_at", new Date().toISOString())\n'
 '        .limit(20)) as any);\n'
 '    }\n')
C_OLD = ('mailComposeRouter.post("/schedule/:id/cancel", async (req, res) => {\n'
 '  const c = await ctx(req, res); if (!c) return;\n')
C_NEW = C_OLD + ('  // B3 (E54): jo row kisi worker ne utha li woh cancel nahi hoti (mail nikal rahi hai). E54 na ho to neeche purana tareeqa.\n'
 '  const rc: any = await supa.rpc("mail_queue_cancel", { _id: req.params.id, _user: c.userId, _org: c.orgId });\n'
 '  if (!rc.error) return rc.data === true ? res.json({ ok: true }) : res.status(409).json({ error: "already_sent" });\n')
w_has = "mail_queue_claim" in w; c_has = "mail_queue_cancel" in c
if w_has and c_has:
    open(wout, "w").write(w); open(cout, "w").write(c); print("same"); sys.exit(0)
if not w_has:
    if w.count(W_OLD) != 1: print("STOP: mail-worker.ts ka select marker nahi mila (%d)" % w.count(W_OLD)); sys.exit(3)
    w = w.replace(W_OLD, W_NEW)
if not c_has:
    if c.count(C_OLD) != 1: print("STOP: mail-compose.ts ka cancel marker nahi mila (%d)" % c.count(C_OLD)); sys.exit(3)
    c = c.replace(C_OLD, C_NEW)
open(wout, "w").write(w); open(cout, "w").write(c); print("update")
