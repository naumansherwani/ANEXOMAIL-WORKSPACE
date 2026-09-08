#!/usr/bin/env bun
/**
 * ANEXOMAIL — Postfix pipe → Supabase (`mail_ingest` RPC).
 *
 * Postfix master.cf mein:
 *   anexomail unix - n n - 10 pipe
 *     flags=DRhu user=vmail argv=/usr/local/bin/anexomail-deliver ${sender} ${recipient}
 *
 * Raw mail stdin par aati hai. Yeh script sirf parse karta hai aur ek RPC call
 * karta hai — threading/dedupe ka faisla Postgres karta hai (NO DUPLICATE rule).
 *
 * Exit codes (Postfix ke liye):
 *   0  = deliver ho gayi
 *   75 = temporary failure → Postfix queue mein rakh kar dobara koshish karega
 *        (mail kabhi khoyegi nahi; Supabase down ho to bhi safe)
 */

import { createHash } from "node:crypto";

const ENV_FILE = process.env["ANEXOMAIL_MAIL_ENV"] ?? "/etc/anexomail/mail.env";

function loadEnv(): Record<string, string> {
  const out: Record<string, string> = { ...process.env } as Record<string, string>;
  try {
    const text = require("node:fs").readFileSync(ENV_FILE, "utf8") as string;
    for (const line of text.split("\n")) {
      const m = line.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*)\s*$/);
      if (!m) continue;
      out[m[1]!] = m[2]!.replace(/^['"]|['"]$/g, "");
    }
  } catch {
    /* env file optional agar process env set ho */
  }
  return out;
}

async function readStdin(): Promise<string> {
  const chunks: Uint8Array[] = [];
  for await (const chunk of Bun.stdin.stream()) chunks.push(chunk);
  return Buffer.concat(chunks).toString("utf8");
}

/** RFC822: headers unfold karke key→value map. */
function parseHeaders(head: string): Record<string, string> {
  const unfolded = head.replace(/\r?\n[ \t]+/g, " ");
  const headers: Record<string, string> = {};
  for (const line of unfolded.split(/\r?\n/)) {
    const i = line.indexOf(":");
    if (i < 1) continue;
    const key = line.slice(0, i).trim().toLowerCase();
    const value = line.slice(i + 1).trim();
    headers[key] = headers[key] ? `${headers[key]}, ${value}` : value;
  }
  return headers;
}

function decodeBody(
  body: string,
  headers: Record<string, string>,
): { text: string; html: string | null } {
  const ctype = (headers["content-type"] ?? "text/plain").toLowerCase();
  const enc = (headers["content-transfer-encoding"] ?? "7bit").toLowerCase();

  const decode = (raw: string) => {
    if (enc === "base64") {
      try {
        return Buffer.from(raw.replace(/\s+/g, ""), "base64").toString("utf8");
      } catch {
        return raw;
      }
    }
    if (enc === "quoted-printable") {
      return raw
        .replace(/=\r?\n/g, "")
        .replace(/=([0-9A-Fa-f]{2})/g, (_m, h) => String.fromCharCode(parseInt(h, 16)));
    }
    return raw;
  };

  // multipart: pehla text/plain part, plus pehla text/html part
  const boundary = ctype.match(/boundary="?([^";]+)"?/)?.[1];
  if (boundary) {
    const parts = body.split(
      new RegExp(`--${boundary.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}(?:--)?`),
    );
    let text = "";
    let html: string | null = null;
    for (const part of parts) {
      const idx = part.search(/\r?\n\r?\n/);
      if (idx < 0) continue;
      const ph = parseHeaders(part.slice(0, idx));
      const pb = part.slice(idx).replace(/^\r?\n\r?\n/, "");
      const pct = (ph["content-type"] ?? "").toLowerCase();
      const decoded = decodeBody(pb, ph);
      if (pct.startsWith("text/plain") && !text) text = decoded.text;
      else if (pct.startsWith("text/html") && !html) html = decoded.text;
    }
    return { text, html };
  }

  const decoded = decode(body);
  if (ctype.startsWith("text/html"))
    return { text: decoded.replace(/<[^>]+>/g, " ").trim(), html: decoded };
  return { text: decoded, html: null };
}

function addr(value: string | undefined): { name: string | null; address: string } {
  if (!value) return { name: null, address: "unknown" };
  const angle = value.match(/^\s*(.*?)\s*<([^>]+)>\s*$/);
  if (angle) {
    const name = angle[1]!.replace(/^["']|["']$/g, "").trim();
    return { name: name || null, address: angle[2]!.toLowerCase() };
  }
  return { name: null, address: value.trim().toLowerCase() };
}

function addrList(value: string | undefined): string[] {
  if (!value) return [];
  return value
    .split(",")
    .map((v) => addr(v).address)
    .filter((v) => v && v !== "unknown");
}

function authResult(headers: Record<string, string>, kind: "spf" | "dkim"): string | null {
  const ar = headers["authentication-results"];
  if (!ar) return null;
  return ar.match(new RegExp(`${kind}=([a-z]+)`, "i"))?.[1]?.toLowerCase() ?? null;
}

async function main() {
  const env = loadEnv();
  const url = env["SUPABASE_URL"];
  const key = env["SUPABASE_SERVICE_ROLE_KEY"];
  const envelopeFrom = (process.argv[2] ?? "").toLowerCase();
  const envelopeTo = (process.argv[3] ?? "").toLowerCase();

  if (!url || !key) {
    console.error(
      "anexomail-deliver: SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY missing in " + ENV_FILE,
    );
    process.exit(75);
  }

  const raw = await readStdin();
  const split = raw.search(/\r?\n\r?\n/);
  const headers = parseHeaders(split > 0 ? raw.slice(0, split) : raw);
  const body = split > 0 ? raw.slice(split).replace(/^\r?\n\r?\n/, "") : "";
  const { text, html } = decodeBody(body, headers);
  const from = addr(headers["from"]);

  const sentAt = (() => {
    const d = headers["date"] ? new Date(headers["date"]) : new Date();
    return Number.isNaN(d.getTime()) ? new Date().toISOString() : d.toISOString();
  })();

  const payload = {
    envelope_from: envelopeFrom || from.address,
    envelope_to: envelopeTo,
    message_id: headers["message-id"]?.replace(/[<>]/g, "") ?? null,
    in_reply_to: headers["in-reply-to"]?.replace(/[<>]/g, "") ?? null,
    from_name: from.name,
    from_address: from.address,
    to: addrList(headers["to"]).length ? addrList(headers["to"]) : [envelopeTo],
    cc: addrList(headers["cc"]),
    subject: headers["subject"] ?? null,
    body_text: text.slice(0, 200_000),
    body_html: html ? html.slice(0, 400_000) : null,
    spf: authResult(headers, "spf"),
    dkim: authResult(headers, "dkim"),
    sent_at: sentAt,
    raw_size: Buffer.byteLength(raw),
    raw_sha256: createHash("sha256").update(raw).digest("hex"),
    headers: {
      subject: headers["subject"] ?? null,
      from: headers["from"] ?? null,
      to: headers["to"] ?? null,
      "message-id": headers["message-id"] ?? null,
      "authentication-results": headers["authentication-results"] ?? null,
    },
  };

  try {
    const res = await fetch(`${url.replace(/\/$/, "")}/rest/v1/rpc/mail_ingest`, {
      method: "POST",
      headers: {
        apikey: key,
        Authorization: `Bearer ${key}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({ payload }),
    });
    const out = await res.text();
    if (!res.ok) {
      console.error(`anexomail-deliver: supabase ${res.status} ${out}`);
      process.exit(75); // Postfix dobara koshish karega
    }
    console.error(`anexomail-deliver: OK ${envelopeTo} ${out}`);
    process.exit(0);
  } catch (error) {
    console.error(`anexomail-deliver: network error ${(error as Error).message}`);
    process.exit(75);
  }
}

void main();
