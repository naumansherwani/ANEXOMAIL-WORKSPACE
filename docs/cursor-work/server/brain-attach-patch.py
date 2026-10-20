#!/usr/bin/env python3
"""G38 — Brain (Bun) ke 4 files mein attachments jodna. Anchor-based, idempotent, ya sab ya kuch nahi.

  python3 brain-attach-patch.py <SRC>      # SRC = jahan index.ts, routes/, mail/, mail-worker.ts hain

Kya badalta hai (har tabdeeli par marker `G38` hota hai, doosri baar chalane par kuch nahi badalta):
  mail/sendmail.ts        SendMailInput.attachments + message ko multipart/mixed mein lapetna + header mein CR/LF band
  routes/mail.ts          /send: attachment_ids parakhna, bhejna, Sent mein asli rows; thread read: server ka path nahi (storage_path column hai hi nahi)
  routes/mail-compose.ts  /schedule: attachment_ids parakh kar mail_scheduled mein
  mail-worker.ts          queue se bhejte waqt files jodna; Sent copy ke saath commit
Koi anchor na mile to EXIT 4 aur KUCH NAHI badalta (live file mojooda repo se alag ho sakti hai).
"""
import os
import re
import sys

src = sys.argv[1]


def rd(rel):
    with open(os.path.join(src, rel)) as f:
        return f.read()


def need(cond, msg):
    if not cond:
        print("PATCH FAIL: " + msg)
        sys.exit(4)


out = {}
log = []

# ───────────── mail/sendmail.ts ─────────────
s = rd("mail/sendmail.ts")
if "G38" in s:
    log.append("sendmail.ts: pehle se")
else:
    a = "  /** header + log ke liye; na do to bana diya jayega */\n  messageId?: string;\n};"
    need(a in s, "sendmail.ts: SendMailInput ka anchor nahi mila")
    s = s.replace(
        a,
        "  /** header + log ke liye; na do to bana diya jayega */\n  messageId?: string;\n"
        "  /** G38: disk par parakhi hui files (server/mail/attachments.ts: toOutAttachments) */\n"
        "  attachments?: { filename: string; mimeType: string; path: string; sha256: string; size: number }[];\n};",
        1,
    )
    b = "  const data = buildMessage(input, messageId);\n"
    need(b in s, "sendmail.ts: `const data = buildMessage(input, messageId);` nahi mila")
    s = s.replace(
        b,
        "  // G38: attachments hon to message multipart/mixed ban jata hai; file badli/kharab/gayab ho to mail NAHI jati (saaf error)\n"
        "  let data: string;\n"
        "  try {\n"
        "    if (input.attachments?.length) {\n"
        '      const att = await import("./attachments");\n'
        "      data = att.wrapWithAttachments(buildMessage(input, messageId), await att.readAttachments(input.attachments));\n"
        "    } else {\n"
        "      data = buildMessage(input, messageId);\n"
        "    }\n"
        "  } catch (error) {\n"
        "    const message = (error as Error).message;\n"
        '    await recordProof(input, messageId, false, "", message);\n'
        '    return { ok: false, messageId, smtpResponse: "", error: message };\n'
        "  }\n",
        1,
    )
    c = "function encodeHeader(value: string) {\n"
    need(c in s, "sendmail.ts: encodeHeader nahi mila")
    s = s.replace(c, c + "  value = String(value).replace(/[\\r\\n]+/g, \" \"); // G38: header injection band (subject/naam mein CR/LF)\n", 1)
    log.append("sendmail.ts: lagaya")
out["mail/sendmail.ts"] = s

# ───────────── routes/mail.ts ─────────────
s = rd("routes/mail.ts")
if "G38" in s:
    log.append("mail.ts: pehle se")
else:
    imp = 'import { sendMail } from "../mail/sendmail";\n'
    need(imp in s, "mail.ts: sendmail import nahi mila")
    s = s.replace(imp, imp + 'import { loadStaged, toOutAttachments, commitAttached } from "../mail/attachments"; // G38\n', 1)
    st = s.find('mailRouter.post("/send"')
    need(st >= 0, 'mail.ts: mailRouter.post("/send" nahi mila')
    nx = s.find("\nmailRouter.", st + 10)
    nx2 = s.find("\nasync function ", st + 10)
    ends = [x for x in (nx, nx2) if x > 0]
    en = min(ends) if ends else len(s)
    seg = s[st:en]
    a = '  if (!to.length) return res.status(400).json({ error: "to_required" });\n'
    need(a in seg, "mail.ts: /send mein to_required anchor nahi mila")
    seg = seg.replace(
        a,
        a
        + "\n  // G38 — attachments: sab ids isi user/org ki, limit ke andar, disk par maujood aur sha256 mel khata hua (kuch bhi galat => mail bani hi nahi)\n"
        + "  const att = await loadStaged(supa, c.orgId, c.userId, b.attachment_ids);\n"
        + "  if (!att.ok) return res.status(att.status).json({ error: att.error, ...(att.detail || {}) });\n"
        + "  if (att.files.length && b.send_at && new Date(b.send_at).getTime() > Date.now()) {\n"
        + '    return res.status(400).json({ error: "use_schedule_for_attachments" });\n'
        + "  }\n"
        + "  let outAtt: Awaited<ReturnType<typeof toOutAttachments>> = [];\n"
        + "  try { outAtt = await toOutAttachments(att.files); }\n"
        + '  catch (e) { return res.status(409).json({ error: "attachment_unavailable", detail: String((e as Error).message).slice(0, 200) }); }\n',
        1,
    )
    r = "    replyTo: b.reply_to || undefined,\n  });\n"
    need(r in seg, "mail.ts: /send mein sendMail ka replyTo anchor nahi mila")
    seg = seg.replace(r, "    replyTo: b.reply_to || undefined,\n    attachments: outAtt.length ? outAtt : undefined, // G38\n  });\n", 1)
    f = '  if (!sent.ok) return res.status(502).json({ error: "smtp_failed", detail: sent.error });\n'
    need(f in seg, "mail.ts: /send mein smtp_failed anchor nahi mila")
    seg = seg.replace(f, f + "  await commitAttached(supa, c.orgId, c.userId, att.files.map((x) => x.id), msg.id); // G38: Sent mein asli rows\n", 1)
    s = s[:st] + seg + s[en:]
    # thread read: `storage_path` is table mein hai hi nahi (poora select 400 deta)
    t1 = "mail_attachments(id,filename,mime_type,size_bytes,storage_path)"
    if t1 in s:
        s = s.replace(t1, "mail_attachments(id,filename,mime_type,size_bytes,sha256)")
        t2 = "size_bytes: a.size_bytes ?? 0, url: a.storage_path ?? null,"
        need(t2 in s, "mail.ts: thread attachments ka url anchor nahi mila")
        s = s.replace(t2, "size_bytes: a.size_bytes ?? 0, url: null, stored: !!a.sha256, // G38: server path kabhi client ko nahi", 1)
    log.append("mail.ts: lagaya")
out["routes/mail.ts"] = s

# ───────────── routes/mail-compose.ts ─────────────
s = rd("routes/mail-compose.ts")
if "G38" in s:
    log.append("mail-compose.ts: pehle se")
else:
    m = list(re.finditer(r"^import .*;\s*$", s, re.M))
    need(bool(m), "mail-compose.ts: import line nahi mili")
    s = s[: m[-1].end()] + '\nimport { loadStaged } from "../mail/attachments"; // G38' + s[m[-1].end():]
    a = '    return res.status(403).json({ error: "identity_not_allowed", identity: wantedFrom });\n  }\n'
    st = s.find('mailComposeRouter.post("/schedule"')
    need(st >= 0, 'mail-compose.ts: mailComposeRouter.post("/schedule" nahi mila')
    i = s.find(a, st)
    need(i >= 0, "mail-compose.ts: /schedule mein identity_not_allowed anchor nahi mila")
    i += len(a)
    s = (
        s[:i]
        + "\n  // G38 — attachments: ids parakh kar hi queue mein (limit/ownership/blocked sab SQL E48 dekhta hai)\n"
        + "  const att = await loadStaged(supa, c.orgId, c.userId, b.attachment_ids);\n"
        + "  if (!att.ok) return res.status(att.status).json({ error: att.error, ...(att.detail || {}) });\n"
        + s[i:]
    )
    j = s.find('    status: "holding",\n', st)
    need(j >= 0, 'mail-compose.ts: /schedule insert mein status: "holding" anchor nahi mila')
    j += len('    status: "holding",\n')
    s = s[:j] + "    attachment_ids: att.files.length ? att.files.map((x) => x.id) : null, // G38\n" + s[j:]
    log.append("mail-compose.ts: lagaya")
out["routes/mail-compose.ts"] = s

# ───────────── mail-worker.ts ─────────────
s = rd("mail-worker.ts")
if "G38" in s:
    log.append("mail-worker.ts: pehle se")
else:
    imp = 'import { sendMail } from "./mail/sendmail";\n'
    need(imp in s, "mail-worker.ts: sendmail import nahi mila")
    s = s.replace(imp, imp + 'import { loadStaged, toOutAttachments, commitAttached } from "./mail/attachments"; // G38\n', 1)
    q = '.select("id, org_id, user_id, identity, to, cc, bcc, subject, body, thread_id")'
    need(q in s, "mail-worker.ts: queue select anchor nahi mila")
    s = s.replace(q, '.select("id, org_id, user_id, identity, to, cc, bcc, subject, body, thread_id, attachment_ids")', 1)
    pre = "      const result = await sendMail({\n"
    need(pre in s, "mail-worker.ts: `const result = await sendMail({` nahi mila")
    s = s.replace(
        pre,
        "      // G38 — attachments: dobara parakho (schedule ke baad file badli/gayab ho sakti hai) — kuch galat => row failed, mail nahi jati\n"
        "      let outAtt: Awaited<ReturnType<typeof toOutAttachments>> = [];\n"
        "      const attIds: string[] = Array.isArray(row.attachment_ids) ? row.attachment_ids : [];\n"
        "      if (attIds.length) {\n"
        "        try {\n"
        "          const ld = await loadStaged(supa, row.org_id, row.user_id, attIds);\n"
        "          if (!ld.ok) throw new Error(ld.error);\n"
        "          outAtt = await toOutAttachments(ld.files);\n"
        "        } catch (e) {\n"
        '          await supa.from("mail_scheduled").update({ status: "failed", error: "attachments: " + String((e as Error).message).slice(0, 200) }).eq("id", row.id);\n'
        "          if (workspaceId) await releaseStorage(workspaceId, fromAddress, bytes);\n"
        '          console.error(`[mail-worker] ATTACHMENTS REJECTED id=${row.id}:`, (e as Error).message);\n'
        "          continue;\n"
        "        }\n"
        "      }\n\n" + pre,
        1,
    )
    tx = '        text: row.body || "",\n      });\n'
    k = s.find(tx, s.find(pre))
    need(k >= 0, "mail-worker.ts: sendMail call ka text anchor nahi mila")
    s = s[:k] + '        text: row.body || "",\n        attachments: outAtt.length ? outAtt : undefined, // G38\n      });\n' + s[k + len(tx):]
    # recordSent: message id pakadna aur commit
    r1 = '    const { error: me } = await supa.from("mail_messages").insert({\n'
    need(r1 in s, "mail-worker.ts: recordSent insert anchor nahi mila")
    s = s.replace(r1, '    const { data: msgRow, error: me } = await supa.from("mail_messages").insert({\n', 1)
    r2 = "      subject, body_text: body, sent_at: now,\n    });\n"
    need(r2 in s, "mail-worker.ts: recordSent insert ka end anchor nahi mila")
    s = s.replace(r2, '      subject, body_text: body, sent_at: now,\n    }).select("id").single();\n', 1)
    r3 = '    else console.log("[mail-worker] sent-copy ok thread=" + t.id);\n'
    need(r3 in s, "mail-worker.ts: recordSent ka log anchor nahi mila")
    s = s.replace(
        r3,
        "    else {\n"
        '      console.log("[mail-worker] sent-copy ok thread=" + t.id);\n'
        "      if (Array.isArray(row.attachment_ids) && row.attachment_ids.length && msgRow) {\n"
        "        await commitAttached(supa, row.org_id, row.user_id, row.attachment_ids, msgRow.id); // G38: Sent mein asli rows\n"
        "      }\n"
        "    }\n",
        1,
    )
    log.append("mail-worker.ts: lagaya")
out["mail-worker.ts"] = s

for rel, text in out.items():
    with open(os.path.join(src, rel), "w") as f:
        f.write(text)
print("; ".join(log))
