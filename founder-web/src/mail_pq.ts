// DK4 (20 Nov 2026): open a post-quantum sealed mail on THIS device. The server cannot read it (seal_mode recipient_pq); the sealed parts come to the browser, the KERNEL opens them
// (kemopen@1) with the device key (unlocked by one key touch, mail_keys.ts) and parses the mail (mailparse@1). The answer has the SAME shape as a server-opened mail, so the read pane,
// Reply, Reply all and Forward stay exactly as they are (additive). Nothing here sends the plain text anywhere.
import { kemOpen, mailParse } from "./kernel";
import { openMaterial, unlockDeviceKey } from "./mail_keys";
import { kemInputs, type SealedMail } from "./mail_pq_pure";
import type { Opened } from "./mail_api";

export async function openSealedMail(box: string, mail: SealedMail & Record<string, unknown>, touched: boolean): Promise<Opened | { error: string }> {
  const inp = kemInputs(box, mail);
  if (!inp) return { error: "The sealed message arrived in a shape this device cannot read. It is kept, not shown." };
  let mat = openMaterial(box, mail.key_id);
  if (!mat) {
    const u = await unlockDeviceKey(box, mail.key_id);
    if (!u.ok) return { error: u.error };
    mat = openMaterial(box, mail.key_id);
    if (!mat) return { error: "The device key is not available." };
  }
  const m = await kemOpen({ ...(inp.meta as any), ...mat });
  if (!m) return { error: "The security kernel could not run, so the message stays sealed." };
  if (!m.ok) return { error: `This message does not open on this device (${m.reason}). It is kept, not shown.` };
  let sum: Opened["sum"] = {};
  try { sum = JSON.parse(new TextDecoder().decode(m.plain)); } catch { return { error: "The sealed summary is not valid. It is kept, not shown." }; }
  let view: Opened["view"] = { text: "", had_html: false, remote_content_blocked: false, attachments: [] };
  if (inp.body) {
    const b = await kemOpen({ ...(inp.body as any), ...mat });
    if (!b || !b.ok) return { error: "The sealed message does not verify on this device. It is kept, not shown." };
    const p = await mailParse(b.plain);
    if (!p) return { error: "The security kernel could not read the message." };
    // the kernel's reading is the truth for the headers a reply needs (References, Reply-To): it replaces the sealed summary's fields
    sum = { ...sum, ...p.summary };
    view = { text: p.view.text, had_html: p.view.had_html, remote_content_blocked: !!p.view.remote_content_blocked, attachments: p.view.attachments ?? [] };
  }
  const facts: Record<string, unknown> = { ...mail }; for (const k of ["meta", "nonce_meta", "key_wrap", "aad_hash", "msgid_blind", "body", "nonce_body"]) delete facts[k];
  return { opened: true, touched, facts: facts as Opened["facts"], sum, view };
}
