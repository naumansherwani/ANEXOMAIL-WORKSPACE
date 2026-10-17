/**
 * Contacts import — switching from Google Contacts / Outlook / Zoho / Apple / LinkedIn.
 *
 * Everything here is pure and runs in the browser: the file is read and understood on the person's own device and only
 * the rows they confirm are sent to the workspace (never the raw file). Two formats:
 *   - vCard  (.vcf, versions 2.1 / 3.0 / 4.0 — Apple Contacts, Google "vCard", Outlook, Android)
 *   - CSV    (Google Contacts, Outlook, Zoho, LinkedIn connections, hand-made sheets; , ; or tab separated)
 *
 * Every row that is dropped is COUNTED (no email, not a valid email, duplicate inside the file) so the confirm screen can
 * tell the truth; nothing disappears silently. The server re-validates every row again — this file is a convenience, not
 * a trust boundary (server/lib/import-rows.ts is the other half and must keep the same limits).
 */

export type ImportRow = {
  email: string;
  display_name?: string;
  company?: string;
  title?: string;
  phone?: string;
};

export type ImportStats = {
  /** Cards / data rows seen in the file. */
  found: number;
  /** Rows kept (valid email, first time seen). */
  kept: number;
  noEmail: number;
  invalidEmail: number;
  /** Same address twice inside the file — the first one is kept. */
  duplicate: number;
  /** Extra addresses on a person beyond the first — only the first is imported. */
  extraEmails: number;
  /** File had more people than IMPORT_MAX_ROWS — the rest were left out. */
  capped: boolean;
};

export type ImportPlan = {
  format: "vcf" | "csv" | "unknown";
  rows: ImportRow[];
  stats: ImportStats;
};

/** A person's whole address book is a few thousand at most; this keeps a wrong file from freezing the tab. */
export const IMPORT_MAX_ROWS = 5000;
/** Rows sent to the server per request (the server enforces the same ceiling). */
export const IMPORT_BATCH = 500;

const MAX_NAME = 200;
const MAX_FIELD = 200;
const MAX_PHONE = 40;

// Deliberately plain: one @, something on both sides, a dot-separated domain. The mail server is the real judge.
const EMAIL_RE = /^[^\s@<>()[\],;:"\\]{1,64}@[^\s@<>()[\],;:"\\]+\.[A-Za-z]{2,}$/;

export function normaliseEmail(raw: string): string | null {
  let v = raw.trim();
  // "Name <a@b.co>" or "mailto:a@b.co"
  const angle = v.match(/<([^>]+)>/);
  if (angle) v = angle[1]!;
  v = v.replace(/^mailto:/i, "").trim().toLowerCase();
  if (v.length > 254 || !EMAIL_RE.test(v)) return null;
  return v;
}

const clean = (v: string | undefined, max: number): string | undefined => {
  // eslint-disable-next-line no-control-regex
  const s = (v ?? "").replace(/[\u0000-\u001f\u007f]+/g, " ").replace(/\s+/g, " ").trim();
  return s ? s.slice(0, max) : undefined;
};

function emptyStats(): ImportStats {
  return { found: 0, kept: 0, noEmail: 0, invalidEmail: 0, duplicate: 0, extraEmails: 0, capped: false };
}

/** Collects people one by one, applying the same bookkeeping for every format. */
class Collector {
  rows: ImportRow[] = [];
  stats = emptyStats();
  private seen = new Set<string>();

  add(candidates: string[], row: Omit<ImportRow, "email">) {
    this.stats.found++;
    const real = candidates.map((c) => c.trim()).filter(Boolean);
    if (real.length === 0) {
      this.stats.noEmail++;
      return;
    }
    let email: string | null = null;
    for (const c of real) {
      email = normaliseEmail(c);
      if (email) break;
    }
    if (!email) {
      this.stats.invalidEmail++;
      return;
    }
    if (real.length > 1) this.stats.extraEmails += real.length - 1;
    if (this.seen.has(email)) {
      this.stats.duplicate++;
      return;
    }
    if (this.rows.length >= IMPORT_MAX_ROWS) {
      this.stats.capped = true;
      return;
    }
    this.seen.add(email);
    const out: ImportRow = { email };
    const name = clean(row.display_name, MAX_NAME);
    const company = clean(row.company, MAX_FIELD);
    const title = clean(row.title, MAX_FIELD);
    const phone = clean(row.phone, MAX_PHONE);
    if (name && name.toLowerCase() !== email) out.display_name = name;
    if (company) out.company = company;
    if (title) out.title = title;
    if (phone) out.phone = phone;
    this.rows.push(out);
    this.stats.kept++;
  }
}

/* ------------------------------------------------------------------ vCard */

function decodeQuotedPrintable(v: string, charset: string): string {
  const bytes: number[] = [];
  for (let i = 0; i < v.length; i++) {
    const ch = v[i]!;
    if (ch === "=" && /^[0-9A-Fa-f]{2}$/.test(v.slice(i + 1, i + 3))) {
      bytes.push(parseInt(v.slice(i + 1, i + 3), 16));
      i += 2;
    } else {
      for (const b of new TextEncoder().encode(ch)) bytes.push(b);
    }
  }
  try {
    return new TextDecoder(charset || "utf-8").decode(new Uint8Array(bytes));
  } catch {
    return new TextDecoder("utf-8").decode(new Uint8Array(bytes));
  }
}

const unescapeVcf = (v: string) =>
  v.replace(/\\([nN,;\\])/g, (_m, c: string) => (c === "n" || c === "N" ? " " : c));

/** Splits "a;b\;c" on UNESCAPED semicolons. */
const splitUnescaped = (v: string, sep: string) => {
  const out: string[] = [];
  let cur = "";
  for (let i = 0; i < v.length; i++) {
    const ch = v[i]!;
    if (ch === "\\" && i + 1 < v.length) {
      cur += ch + v[i + 1];
      i++;
    } else if (ch === sep) {
      out.push(cur);
      cur = "";
    } else cur += ch;
  }
  out.push(cur);
  return out;
};

type VProp = { name: string; params: string[]; value: string };

function parseVcfLine(line: string): VProp | null {
  const colon = (() => {
    // the first colon that is not inside a quoted parameter value
    let q = false;
    for (let i = 0; i < line.length; i++) {
      if (line[i] === '"') q = !q;
      else if (line[i] === ":" && !q) return i;
    }
    return -1;
  })();
  if (colon < 1) return null;
  const head = line.slice(0, colon);
  let value = line.slice(colon + 1);
  const parts = head.split(";");
  // "item1.EMAIL" — Apple / Google prefix a property with a group name
  let name = parts[0]!.trim();
  const dot = name.lastIndexOf(".");
  if (dot >= 0) name = name.slice(dot + 1);
  name = name.toUpperCase();
  const params = parts.slice(1).map((p) => p.trim().toUpperCase());
  if (params.some((p) => p === "ENCODING=QUOTED-PRINTABLE" || p === "QUOTED-PRINTABLE")) {
    const cs = params.find((p) => p.startsWith("CHARSET="))?.slice(8) ?? "utf-8";
    value = decodeQuotedPrintable(value, cs.toLowerCase());
  }
  return { name, params, value };
}

export function parseVcf(text: string): ImportPlan {
  const col = new Collector();
  // Unfold: a line that starts with a space or tab continues the previous one. Quoted-printable soft breaks ("=" at the
  // end of a line) continue it too.
  const raw = text.replace(/^\uFEFF/, "").replace(/\r\n?/g, "\n").split("\n");
  const lines: string[] = [];
  for (const l of raw) {
    const prev = lines[lines.length - 1];
    if (prev !== undefined && (/^[ \t]/.test(l) || (/ENCODING=QUOTED-PRINTABLE/i.test(prev) && /=$/.test(prev)))) {
      lines[lines.length - 1] = (/=$/.test(prev) && !/^[ \t]/.test(l) ? prev.slice(0, -1) : prev) + l.replace(/^[ \t]/, "");
    } else lines.push(l);
  }

  let inCard = false;
  let props: VProp[] = [];
  const flush = () => {
    const emails: { v: string; pref: boolean }[] = [];
    let fn = "";
    let n = "";
    let org = "";
    let title = "";
    let tel = "";
    for (const p of props) {
      if (p.name === "EMAIL") emails.push({ v: unescapeVcf(p.value), pref: p.params.some((x) => x.includes("PREF")) });
      else if (p.name === "FN" && !fn) fn = unescapeVcf(p.value);
      else if (p.name === "N" && !n) {
        const [family = "", given = "", additional = "", prefix = "", suffix = ""] = splitUnescaped(p.value, ";").map(unescapeVcf);
        n = [prefix, given, additional, family, suffix].filter((s) => s.trim()).join(" ");
      } else if (p.name === "ORG" && !org) org = unescapeVcf(splitUnescaped(p.value, ";")[0] ?? "");
      else if (p.name === "TITLE" && !title) title = unescapeVcf(p.value);
      else if (p.name === "TEL" && !tel) tel = unescapeVcf(p.value);
    }
    emails.sort((a, b) => Number(b.pref) - Number(a.pref));
    col.add(
      emails.map((e) => e.v),
      { display_name: fn || n, company: org, title, phone: tel },
    );
  };
  for (const line of lines) {
    const t = line.trim();
    if (/^BEGIN:VCARD$/i.test(t)) {
      inCard = true;
      props = [];
    } else if (/^END:VCARD$/i.test(t)) {
      if (inCard) flush();
      inCard = false;
    } else if (inCard) {
      const p = parseVcfLine(line);
      if (p) props.push(p);
    }
  }
  return { format: "vcf", rows: col.rows, stats: col.stats };
}

/* -------------------------------------------------------------------- CSV */

/** RFC 4180 reader: quoted fields may hold the delimiter, quotes ("" = ") and line breaks. */
export function readCsv(text: string, delimiter: string): string[][] {
  const out: string[][] = [];
  let row: string[] = [];
  let cur = "";
  let q = false;
  const s = text.replace(/^\uFEFF/, "");
  for (let i = 0; i < s.length; i++) {
    const ch = s[i]!;
    if (q) {
      if (ch === '"') {
        if (s[i + 1] === '"') {
          cur += '"';
          i++;
        } else q = false;
      } else cur += ch;
    } else if (ch === '"') q = true;
    else if (ch === delimiter) {
      row.push(cur);
      cur = "";
    } else if (ch === "\n" || ch === "\r") {
      if (ch === "\r" && s[i + 1] === "\n") i++;
      row.push(cur);
      cur = "";
      if (row.some((c) => c.trim() !== "")) out.push(row);
      row = [];
    } else cur += ch;
  }
  row.push(cur);
  if (row.some((c) => c.trim() !== "")) out.push(row);
  return out;
}

function sniffDelimiter(text: string): string {
  const head = text.replace(/^\uFEFF/, "").split(/\r?\n/, 1)[0] ?? "";
  let best = ",";
  let bestN = -1;
  for (const d of [",", ";", "\t"]) {
    let n = 0;
    let q = false;
    for (const ch of head) {
      if (ch === '"') q = !q;
      else if (ch === d && !q) n++;
    }
    if (n > bestN) {
      best = d;
      bestN = n;
    }
  }
  return best;
}

const norm = (h: string) =>
  h
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, " ")
    .trim();

type Cols = { email: number[]; name: number[]; first: number[]; last: number[]; company: number[]; title: number[]; phone: number[] };

function mapHeader(header: string[]): Cols {
  const cols: Cols = { email: [], name: [], first: [], last: [], company: [], title: [], phone: [] };
  header.forEach((raw, i) => {
    const h = norm(raw);
    if (!h) return;
    const isLabel = /\b(type|label|status)\b/.test(h);
    if (/(^| )e ?mail( |$)/.test(h) && !isLabel) cols.email.push(i);
    else if (/^(first name|given name|firstname|forename)$/.test(h)) cols.first.push(i);
    else if (/^(last name|family name|lastname|surname)$/.test(h)) cols.last.push(i);
    else if (/^(name|full name|display name|contact name|fn)$/.test(h)) cols.name.push(i);
    else if (/(^| )(company|organization|organisation|account name|employer|org)( name)?( |$)/.test(h) && !/title|department/.test(h)) cols.company.push(i);
    else if (/(^| )title$|^position$|^role$|^job role$/.test(h)) cols.title.push(i);
    else if (/(phone|mobile|tel\b|telephone)/.test(h) && !isLabel) cols.phone.push(i);
  });
  return cols;
}

export function parseCsv(text: string): ImportPlan {
  const col = new Collector();
  const rows = readCsv(text, sniffDelimiter(text));
  if (rows.length === 0) return { format: "csv", rows: [], stats: col.stats };
  const header = rows[0]!;
  const cols = mapHeader(header);
  // A file with no recognisable e-mail column is not a contacts file — say so instead of guessing.
  if (cols.email.length === 0) return { format: "unknown", rows: [], stats: { ...col.stats, found: rows.length - 1 } };
  const at = (r: string[], idx: number[]) => idx.map((i) => (r[i] ?? "").trim()).find(Boolean) ?? "";
  for (const r of rows.slice(1)) {
    // Google keeps several addresses in one cell, separated by " ::: "; others use ; or ,
    const emails = cols.email.flatMap((i) => (r[i] ?? "").split(/\s*(?::::|;|,)\s*/));
    const full = at(r, cols.name);
    const joined = [at(r, cols.first), at(r, cols.last)].filter(Boolean).join(" ");
    col.add(emails, {
      display_name: full || joined,
      company: at(r, cols.company),
      title: at(r, cols.title),
      phone: at(r, cols.phone),
    });
  }
  return { format: "csv", rows: col.rows, stats: col.stats };
}

/* ------------------------------------------------------------------ entry */

export function parseContacts(text: string, fileName = ""): ImportPlan {
  const looksVcf = /(^|\n)\s*BEGIN:VCARD/i.test(text.slice(0, 4096)) || /\.vcf$/i.test(fileName);
  if (looksVcf) return parseVcf(text);
  return parseCsv(text);
}

/** Splits rows into server-sized requests. */
export function batches<T>(rows: T[], size = IMPORT_BATCH): T[][] {
  const out: T[][] = [];
  for (let i = 0; i < rows.length; i += size) out.push(rows.slice(i, i + size));
  return out;
}
