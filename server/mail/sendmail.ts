/**
 * ANEXOMAIL — outbound mail via LOCAL Postfix (127.0.0.1:25).
 *
 * Rule: app ke andar koi SMTP username/password nahi. Local Postfix
 * `mynetworks = 127.0.0.0/8` par relay karta hai, DKIM sign karta hai,
 * aur Internet par bhejta hai. Koi external provider nahi.
 *
 * Use (Express/Bun route ke andar):
 *   import { sendMail } from "../mail/sendmail";
 *   const r = await sendMail({ from: "hello@anexomail.com", to: ["x@y.com"],
 *                              subject: "Hi", text: "..." });
 *   if (!r.ok) throw new Error(r.error);
 *
 * Har send ka proof Supabase `mail_outbox_log` mein jata hai (mail_outbox_record RPC).
 */

import net from "node:net";
import { randomUUID } from "node:crypto";

export type SendMailInput = {
  from: string;
  to: string[];
  cc?: string[];
  bcc?: string[];
  subject: string;
  text: string;
  html?: string;
  replyTo?: string;
  fromName?: string;
  /** header + log ke liye; na do to bana diya jayega */
  messageId?: string;
};

export type SendMailResult = {
  ok: boolean;
  messageId: string;
  smtpResponse: string;
  error?: string;
};

const HOST = process.env["MAIL_SMTP_HOST"] ?? "127.0.0.1";
const PORT = Number(process.env["MAIL_SMTP_PORT"] ?? 25);
const DOMAIN = "anexomail.com";

function encodeHeader(value: string) {
  // non-ASCII subject/name ko RFC 2047 base64 mein
  // eslint-disable-next-line no-control-regex
  if (!/[^\x00-\x7F]/.test(value)) return value;
  return `=?UTF-8?B?${Buffer.from(value, "utf8").toString("base64")}?=`;
}

function buildMessage(input: SendMailInput, messageId: string): string {
  const boundary = `ax_${randomUUID().replace(/-/g, "")}`;
  const fromHeader = input.fromName
    ? `${encodeHeader(input.fromName)} <${input.from}>`
    : input.from;

  const headers = [
    `From: ${fromHeader}`,
    `To: ${input.to.join(", ")}`,
    input.cc?.length ? `Cc: ${input.cc.join(", ")}` : null,
    input.replyTo ? `Reply-To: ${input.replyTo}` : null,
    `Subject: ${encodeHeader(input.subject)}`,
    `Message-ID: <${messageId}>`,
    `Date: ${new Date().toUTCString()}`,
    "MIME-Version: 1.0",
    input.html
      ? `Content-Type: multipart/alternative; boundary="${boundary}"`
      : 'Content-Type: text/plain; charset="UTF-8"',
    input.html ? null : "Content-Transfer-Encoding: 8bit",
  ].filter(Boolean) as string[];

  const body = input.html
    ? [
        `--${boundary}`,
        'Content-Type: text/plain; charset="UTF-8"',
        "Content-Transfer-Encoding: 8bit",
        "",
        input.text,
        `--${boundary}`,
        'Content-Type: text/html; charset="UTF-8"',
        "Content-Transfer-Encoding: 8bit",
        "",
        input.html,
        `--${boundary}--`,
        "",
      ].join("\r\n")
    : `${input.text}\r\n`;

  return `${headers.join("\r\n")}\r\n\r\n${body}`;
}

/** Chhota SMTP client — sirf local, plaintext, no auth. */
function smtpSend(envelopeFrom: string, rcpts: string[], data: string): Promise<string> {
  return new Promise((resolve, reject) => {
    const socket = net.createConnection({ host: HOST, port: PORT });
    socket.setTimeout(30_000);
    let buffer = "";
    const log: string[] = [];

    const steps: string[] = [
      `EHLO ${DOMAIN}`,
      `MAIL FROM:<${envelopeFrom}>`,
      ...rcpts.map((r) => `RCPT TO:<${r}>`),
      "DATA",
    ];
    let stage = -1; // -1 = greeting ka intezar
    let sentData = false;

    const fail = (msg: string) => {
      socket.destroy();
      reject(new Error(msg));
    };

    socket.on("timeout", () => fail("SMTP timeout"));
    socket.on("error", (e) => fail(`SMTP socket: ${e.message}`));

    socket.on("data", (chunk) => {
      buffer += chunk.toString("utf8");
      // multi-line reply: aakhri line "250 " jaisi honi chahiye
      if (!/\r\n$/.test(buffer)) return;
      const lines = buffer.trim().split(/\r\n/);
      const last = lines[lines.length - 1] ?? "";
      if (/^\d{3}-/.test(last)) return;
      log.push(last);
      buffer = "";
      const code = Number(last.slice(0, 3));

      if (stage === -1) {
        if (code !== 220) return fail(`SMTP greeting: ${last}`);
        stage = 0;
        socket.write(`${steps[0]}\r\n`);
        return;
      }

      if (!sentData) {
        if (steps[stage] === "DATA") {
          if (code !== 354) return fail(`DATA refused: ${last}`);
          sentData = true;
          const dotStuffed = data.replace(/\r?\n/g, "\r\n").replace(/\r\n\./g, "\r\n..");
          socket.write(`${dotStuffed}\r\n.\r\n`);
          return;
        }
        if (code >= 400) return fail(`${steps[stage]} → ${last}`);
        stage += 1;
        socket.write(`${steps[stage]}\r\n`);
        return;
      }

      // DATA ke baad final reply
      if (code >= 400) return fail(`message refused: ${last}`);
      socket.write("QUIT\r\n");
      socket.end();
      resolve(log.join(" | "));
    });
  });
}

async function recordProof(input: SendMailInput, messageId: string, ok: boolean, smtpResponse: string, error?: string) {
  const url = process.env["SUPABASE_URL"];
  const key = process.env["SUPABASE_SERVICE_ROLE_KEY"];
  if (!url || !key) return; // proof optional — mail rukni nahi chahiye
  try {
    await fetch(`${url.replace(/\/$/, "")}/rest/v1/rpc/mail_outbox_record`, {
      method: "POST",
      headers: { apikey: key, Authorization: `Bearer ${key}`, "Content-Type": "application/json" },
      body: JSON.stringify({
        payload: {
          from_address: input.from,
          to: [...input.to, ...(input.cc ?? []), ...(input.bcc ?? [])],
          subject: input.subject,
          message_id: messageId,
          smtp_response: smtpResponse,
          ok,
          error: error ?? null,
        },
      }),
    });
  } catch {
    /* proof fail ho to bhi mail bhej di gayi */
  }
}

export async function sendMail(input: SendMailInput): Promise<SendMailResult> {
  const messageId = input.messageId ?? `${randomUUID()}@${DOMAIN}`;
  const rcpts = [...input.to, ...(input.cc ?? []), ...(input.bcc ?? [])].map((r) => r.toLowerCase());
  if (!rcpts.length) return { ok: false, messageId, smtpResponse: "", error: "no recipients" };

  const data = buildMessage(input, messageId);
  try {
    const smtpResponse = await smtpSend(input.from.toLowerCase(), rcpts, data);
    await recordProof(input, messageId, true, smtpResponse);
    return { ok: true, messageId, smtpResponse };
  } catch (error) {
    const message = (error as Error).message;
    await recordProof(input, messageId, false, "", message);
    return { ok: false, messageId, smtpResponse: "", error: message };
  }
}
