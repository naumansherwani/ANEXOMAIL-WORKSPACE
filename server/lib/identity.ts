/**
 * ANEXOMAIL — sender identity (From) check. Blueprint #3 (security).
 *
 * Pehle `identity` jo client ne likha wahi From ban jata tha (koi bhi user
 * hello@ ke naam se mail bhej sakta tha). Ab From sirf in mein se:
 *   - is user ke org ke mailboxes / mail_accounts / org_addresses (mailbox|shared)
 *   - user ka apna @anexomail.com login address
 * Alias (forward-only) kabhi From nahi. Koi query fail ho to us source ke baghair
 * chalta hai (fail-closed: kam addresses, zyada nahi).
 */
import { admin as supa } from "./supa";

type Row = { address?: string | null; box_type?: string | null; kind?: string | null; active?: boolean | null };

/** Pure: rows -> From ke liye jaiz lowercase addresses. */
export function sendableFrom(rows: Row[]): string[] {
  const out = new Set<string>();
  for (const r of rows) {
    const a = String(r?.address || "").trim().toLowerCase();
    if (!a || !a.includes("@")) continue;
    if (r.active === false) continue;
    const kind = String(r.box_type ?? r.kind ?? "mailbox").toLowerCase();
    if (kind === "alias") continue;
    out.add(a);
  }
  return [...out];
}

async function rowsOf(q: PromiseLike<{ data: any[] | null; error: any }>): Promise<Row[]> {
  try {
    const r = await q;
    return r.error ? [] : r.data || [];
  } catch {
    return [];
  }
}

export async function allowedSenderAddresses(orgId: string, userId: string): Promise<Set<string>> {
  const [boxes, accounts, company] = await Promise.all([
    rowsOf(supa.from("mailboxes").select("address,box_type,active").eq("org_id", orgId)),
    rowsOf(supa.from("mail_accounts").select("address").eq("org_id", orgId)),
    rowsOf(supa.from("org_addresses").select("address,kind,active").eq("org_id", orgId)),
  ]);
  const set = new Set(sendableFrom([...boxes, ...accounts, ...company]));
  try {
    const r: any = await supa.auth.admin.getUserById(userId);
    const own = String(r?.data?.user?.email || "").trim().toLowerCase();
    if (own.endsWith("@anexomail.com")) set.add(own);
  } catch {
    /* apna login nahi mila: baqi sources kaafi hain */
  }
  return set;
}
