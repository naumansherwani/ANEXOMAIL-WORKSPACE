/**
 * Contact import — the server's half. The browser parses the file (src/lib/contacts-import.ts) but is never trusted:
 * every row is validated, trimmed, size-capped and de-duplicated here before anything touches a table.
 * Keep the limits in step with the client (500 rows per request, same field caps).
 */

export const MAX_IMPORT_ROWS = 500;

export type CleanRow = {
  email: string;
  display_name: string | null;
  company: string | null;
  title: string | null;
  phone: string | null;
};

export type CleanResult = {
  rows: CleanRow[];
  invalid: number;
  duplicate: number;
  /** More than MAX_IMPORT_ROWS were sent: the extra rows were ignored, not stored. */
  tooMany: boolean;
};

const EMAIL_RE = /^[^\s@<>()[\],;:"\\]{1,64}@[^\s@<>()[\],;:"\\]+\.[A-Za-z]{2,}$/;

// eslint-disable-next-line no-control-regex
const CONTROL = /[\u0000-\u001f\u007f]+/g;

function text(v: unknown, max: number): string | null {
  if (typeof v !== "string") return null;
  const s = v.replace(CONTROL, " ").replace(/\s+/g, " ").trim();
  return s ? s.slice(0, max) : null;
}

export function cleanEmail(v: unknown): string | null {
  if (typeof v !== "string") return null;
  const e = v.trim().toLowerCase();
  if (e.length > 254 || !EMAIL_RE.test(e)) return null;
  return e;
}

export function cleanImport(input: unknown): CleanResult {
  const out: CleanResult = { rows: [], invalid: 0, duplicate: 0, tooMany: false };
  if (!Array.isArray(input)) return out;
  const seen = new Set<string>();
  for (let i = 0; i < input.length; i++) {
    if (i >= MAX_IMPORT_ROWS) {
      out.tooMany = true;
      break;
    }
    const r = input[i];
    if (!r || typeof r !== "object") {
      out.invalid++;
      continue;
    }
    const o = r as Record<string, unknown>;
    const email = cleanEmail(o.email);
    if (!email) {
      out.invalid++;
      continue;
    }
    if (seen.has(email)) {
      out.duplicate++;
      continue;
    }
    seen.add(email);
    out.rows.push({
      email,
      display_name: text(o.display_name, 200),
      company: text(o.company, 200),
      title: text(o.title, 200),
      phone: text(o.phone, 40),
    });
  }
  return out;
}

/** Webmail domains are not "a company": a contact on gmail.com must not get gmail.com as its company. */
const FREE_MAIL = new Set([
  "gmail.com", "googlemail.com", "outlook.com", "hotmail.com", "hotmail.co.uk", "live.com", "msn.com",
  "yahoo.com", "yahoo.co.uk", "ymail.com", "icloud.com", "me.com", "mac.com", "aol.com", "proton.me",
  "protonmail.com", "pm.me", "gmx.com", "gmx.net", "mail.com", "zoho.com", "yandex.com", "fastmail.com",
  "anexomail.com",
]);

export function companyDomainOf(email: string): string | null {
  const d = email.split("@")[1]?.toLowerCase() ?? "";
  return d && !FREE_MAIL.has(d) ? d : null;
}

/** What goes in `contacts.notes` for an imported person: the facts the contacts table has no column for. */
export function importNotes(r: { company?: string | null; phone?: string | null }): string | null {
  const parts = [r.company ? `Company: ${r.company}` : "", r.phone ? `Phone: ${r.phone}` : ""].filter(Boolean);
  return parts.length ? parts.join(" · ") : null;
}

export function chunk<T>(items: T[], size: number): T[][] {
  const out: T[][] = [];
  for (let i = 0; i < items.length; i += size) out.push(items.slice(i, i + size));
  return out;
}

type PersonIn = {
  email: string;
  display_name?: string | null;
  title?: string | null;
  company?: string | null;
  phone?: string | null;
};

/**
 * Adds people to `contacts` for ONE organisation, never touching anyone who is already there (an imported name must not
 * overwrite what mail taught us). `client` is the service-role Supabase client (injected so tests can fake it).
 * Returns how many were really new; the rest already existed.
 */
export async function insertNewContacts(
  client: any,
  orgId: string,
  rows: PersonIn[],
): Promise<{ created: number; existing: number }> {
  let created = 0;
  for (const part of chunk(rows, 200)) {
    const emails = part.map((r) => r.email);
    const have = await client.from("contacts").select("primary_address").eq("org_id", orgId).in("primary_address", emails);
    if (have.error) throw new Error(have.error.message || "contacts_lookup_failed");
    const known = new Set<string>((have.data ?? []).map((r: any) => String(r.primary_address || "").toLowerCase()));
    const fresh = part.filter((r) => !known.has(r.email));
    if (!fresh.length) continue;
    const ins = await client
      .from("contacts")
      .upsert(
        fresh.map((r) => ({
          org_id: orgId,
          display_name: r.display_name ?? null,
          primary_address: r.email,
          addresses: [r.email],
          title: r.title ?? null,
          company_domain: companyDomainOf(r.email),
          notes: importNotes(r),
        })),
        { onConflict: "org_id,primary_address", ignoreDuplicates: true },
      )
      .select("id");
    if (ins.error) throw new Error(ins.error.message || "contacts_insert_failed");
    created += (ins.data ?? []).length;
  }
  return { created, existing: rows.length - created };
}
