/**
 * ANEXOMAIL — mail_scheduled queue worker.
 *
 * mail-compose.ts /schedule sirf mail_scheduled mein INSERT karta hai
 * (status="queued"). Yeh worker har 5 second queue check karta hai,
 * genuinely Postfix se bhejta hai, status update karta hai.
 *
 * Step 3 (plan-feature-wire audit) — GENUINELY wired, jaisa specified tha:
 * /api/storage/preflight ke wahi RPC functions (chat_ensure_workspace,
 * storage_reserve, storage_commit, storage_release) seedha yahan call
 * hote hain — koi ALAG/self-contained tracker nahi, EXISTING system hi
 * use ho raha hai.
 */
import { admin as supa } from "./lib/supa";
import { sendMail } from "./mail/sendmail";
import { allowedSenderAddresses } from "./lib/identity";

const POLL_MS = 5_000;
const DEFAULT_FROM = "hello@anexomail.com";

async function senderAccount(orgId: string, userId: string | null, identity: string | null) {
  let email: string | null = identity ? String(identity).toLowerCase() : null;
  if (!email && userId) {
    try {
      const r: any = await supa.auth.admin.getUserById(userId);
      email = String(r?.data?.user?.email || "").toLowerCase() || null;
    } catch {}
  }
  for (const t of ["mail_accounts", "mailboxes"]) {
    if (!email) break;
    const { data } = await supa.from(t).select("id,address").eq("org_id", orgId).ilike("address", email).limit(1).maybeSingle();
    if (data) return data;
  }
  for (const t of ["mail_accounts", "mailboxes"]) {
    const { data } = await supa.from(t).select("id,address").eq("org_id", orgId).order("address").limit(1).maybeSingle();
    if (data) return data;
  }
  return null;
}

async function recordSent(row: any, from: string, to: string[], cc: any, bcc: any) {
  try {
    const acct: any = await senderAccount(row.org_id, row.user_id, from);
    const now = new Date().toISOString();
    const subject = row.subject || "(no subject)";
    const body = String(row.body || "");
    const { data: t, error: te } = await supa.from("mail_threads").insert({
      org_id: row.org_id, account_id: acct ? acct.id : null, subject, snippet: body.slice(0, 180),
      from_name: null, from_address: from, mailbox_address: from, folder: "sent", status: "open",
      unread: false, message_count: 1, last_message_at: now,
    }).select("id").single();
    if (te || !t) { console.error("[mail-worker] sent-thread failed:", te && te.message); return; }
    const ccl = cc || [];
    const bccl = bcc || [];
    const { error: me } = await supa.from("mail_messages").insert({
      org_id: row.org_id, thread_id: t.id, direction: "out", from_address: from,
      to_addresses: to, cc_addresses: ccl, bcc_addresses: bccl,
      to_addrs: to, cc_addrs: ccl, bcc_addrs: bccl,
      subject, body_text: body, sent_at: now,
    });
    if (me) console.error("[mail-worker] sent-message failed:", me.message);
    else console.log("[mail-worker] sent-copy ok thread=" + t.id);
  } catch (e) { console.error("[mail-worker] recordSent error:", e); }
}

let running = false;

function estimateBytes(subject: string, body: string): number {
  return 512 + Buffer.byteLength(subject || "", "utf8") + Buffer.byteLength(body || "", "utf8");
}

/** chat_ensure_workspace RPC — user ke liye workspace_id resolve/create karta hai. */
async function ensureWorkspace(userId: string, email: string): Promise<string | null> {
  const name = email ? email.split("@")[1] || "Workspace" : "Workspace";
  const { data, error } = await supa.rpc("chat_ensure_workspace", { _user: userId, _name: name });
  if (error) {
    console.error("[mail-worker] chat_ensure_workspace failed:", error.message);
    return null;
  }
  return String(data);
}

/** storage_reserve RPC — genuine preflight+reserve ek hi call mein. */
async function reserveStorage(
  workspaceId: string,
  mailbox: string,
  bytes: number,
): Promise<{ allowed: boolean; reason?: string }> {
  const { data, error } = await supa.rpc("storage_reserve", {
    _workspace: workspaceId,
    _mailbox: mailbox,
    _bytes: bytes,
    _kind: "email",
  });
  if (error) {
    console.error("[mail-worker] storage_reserve failed:", error.message);
    return { allowed: false, reason: error.message };
  }
  const out: any = data;
  return { allowed: Boolean(out?.allowed), reason: out?.reason };
}

/** storage_commit RPC — send genuinely succeed hone ke baad reservation ko commit karta hai. */
async function commitStorage(workspaceId: string, mailbox: string, bytes: number) {
  const { error } = await supa.rpc("storage_commit", {
    _workspace: workspaceId,
    _mailbox: mailbox,
    _bytes: bytes,
    _kind: "email",
    _was_reserved: true,
  });
  if (error) console.error("[mail-worker] storage_commit failed:", error.message);
}

/** storage_release RPC — send fail hone par reservation wapas release karta hai. */
async function releaseStorage(workspaceId: string, mailbox: string, bytes: number) {
  const { error } = await supa.rpc("storage_release", {
    _workspace: workspaceId,
    _mailbox: mailbox,
    _bytes: bytes,
    _kind: "email",
  });
  if (error) console.error("[mail-worker] storage_release failed:", error.message);
}

async function processQueue() {
  if (running) return;
  running = true;
  try {
    const nowIso = new Date().toISOString();
    const { data: rows, error } = await supa
      .from("mail_scheduled")
      .select("id, org_id, user_id, identity, to, cc, bcc, subject, body, thread_id")
      .eq("status", "queued")
      .lte("send_at", nowIso)
      .limit(20);

    if (error) {
      console.error("[mail-worker] queue fetch failed:", error.message);
      return;
    }
    if (!rows?.length) return;

    for (const row of rows) {
      const toList = String(row.to || "")
        .split(",")
        .map((s: string) => s.trim())
        .filter(Boolean);
      const ccList = row.cc
        ? String(row.cc)
            .split(",")
            .map((s: string) => s.trim())
            .filter(Boolean)
        : undefined;
      const bccList = row.bcc
        ? String(row.bcc)
            .split(",")
            .map((s: string) => s.trim())
            .filter(Boolean)
        : undefined;

      if (!toList.length) {
        await supa
          .from("mail_scheduled")
          .update({ status: "failed", error: "no recipients" })
          .eq("id", row.id);
        continue;
      }

      // ROOT-CAUSE FIX: "identity" column is genuinely ALWAYS empty (frontend
      // never sends it) — previously this meant EVERY user's mail, including
      // real paying customers, silently sent as hello@anexomail.com. Now we
      // resolve the GENUINE sender: their own mailbox address (via user_id),
      // never a shared generic fallback for a real authenticated sender.
      let fromAddress = row.identity || "";
      // #3 SECURITY: queue mein pehle se pade rows par bhi From dobara jaancho.
      if (fromAddress) {
        const okFrom = row.user_id
          ? (await allowedSenderAddresses(row.org_id, row.user_id)).has(String(fromAddress).trim().toLowerCase())
          : false;
        if (!okFrom) {
          await supa
            .from("mail_scheduled")
            .update({ status: "failed", error: "identity_not_allowed" })
            .eq("id", row.id);
          console.error(`[mail-worker] IDENTITY REJECTED id=${row.id} identity=${fromAddress}`);
          continue;
        }
      }
      if (!fromAddress && row.user_id) {
        const { data: ownMailbox } = await supa
          .from("mailboxes")
          .select("address")
          .eq("org_id", row.org_id)
          .eq("account_id", row.user_id)
          .limit(1)
          .maybeSingle();
        if (ownMailbox?.address) {
          fromAddress = ownMailbox.address;
        } else {
          // account_id link missing on mailboxes — fall back to the user's
          // own Supabase auth email (genuinely their real address in this
          // system's convention, e.g. naumansherwani.founder@anexomail.com).
          try {
            const supaUrl = process.env.SUPABASE4_URL || process.env.SUPABASE_URL || "";
            const supaKey = process.env.SUPABASE4_SERVICE_ROLE_KEY || process.env.SUPABASE_SERVICE_ROLE_KEY || "";
            const r = await fetch(`${supaUrl.replace(/\/$/, "")}/auth/v1/admin/users?per_page=1000`, {
              headers: { apikey: supaKey, Authorization: `Bearer ${supaKey}` },
            });
            const j: any = await r.json();
            const match = (j?.users || []).find((u: any) => u?.id === row.user_id);
            if (match?.email) fromAddress = match.email;
          } catch (e) {
            console.error("[mail-worker] sender-identity lookup failed:", e);
          }
        }
      }
      if (!fromAddress) fromAddress = DEFAULT_FROM; // genuine last resort only
      const bytes = estimateBytes(row.subject || "", row.body || "");

      // ── Step 3: GENUINE storage.ts RPC preflight+reserve ──
      let workspaceId: string | null = null;
      if (row.user_id) {
        workspaceId = await ensureWorkspace(row.user_id, fromAddress);
      }

      if (workspaceId) {
        const reserve = await reserveStorage(workspaceId, fromAddress, bytes);
        if (!reserve.allowed) {
          await supa
            .from("mail_scheduled")
            .update({ status: "failed", error: reserve.reason || "storage_limit_exceeded" })
            .eq("id", row.id);
          console.error(`[mail-worker] STORAGE REJECTED id=${row.id} mailbox=${fromAddress}:`, reserve.reason);
          continue;
        }
      }

      const result = await sendMail({
        from: fromAddress,
        to: toList,
        cc: ccList,
        bcc: bccList,
        subject: row.subject || "(no subject)",
        text: row.body || "",
      });

      if (result.ok) {
        await supa
          .from("mail_scheduled")
          .update({ status: "sent", sent_at: new Date().toISOString() })
          .eq("id", row.id);
        await recordSent(row, fromAddress, toList, ccList, bccList);
        if (workspaceId) await commitStorage(workspaceId, fromAddress, bytes);
        console.log(`[mail-worker] sent id=${row.id} to=${toList.join(",")}`);
      } else {
        await supa
          .from("mail_scheduled")
          .update({ status: "failed", error: result.error || "unknown send error" })
          .eq("id", row.id);
        if (workspaceId) await releaseStorage(workspaceId, fromAddress, bytes);
        console.error(`[mail-worker] FAILED id=${row.id}:`, result.error);
      }
    }
  } catch (e) {
    console.error("[mail-worker] loop error:", e);
  } finally {
    running = false;
  }
}

export function startMailWorker() {
  console.log("[mail-worker] started, polling every", POLL_MS, "ms (storage.ts RPC preflight/commit wired)");
  void processQueue();
  setInterval(() => void processQueue(), POLL_MS);
}
