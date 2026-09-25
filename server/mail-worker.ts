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

const POLL_MS = 5_000;
const DEFAULT_FROM = "hello@anexomail.com";

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

      const fromAddress = row.identity || DEFAULT_FROM;
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
