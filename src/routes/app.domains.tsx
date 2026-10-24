import { BrandSpinner } from "@/components/state/BrandLoader";
import { Link, createFileRoute } from "@tanstack/react-router";
import {
  AlertTriangle,
  ArrowRight,
  AtSign,
  CheckCircle2,
  Circle,
  Clock,
  Copy,
  Globe,
  Lock,
  Mail,
  Plus,
  RefreshCw,
  Send,
  ShieldCheck,
  Trash2,
  X,
} from "lucide-react";
import { useCallback, useEffect, useMemo, useRef, useState, type ReactNode } from "react";

import { ComposeOverlay } from "@/components/app/ComposeOverlay";
import { Chip } from "@/components/app/org/OrgBits";
import { ErrorState } from "@/components/state/StateBlock";
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from "@/components/ui/alert-dialog";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import type { ApiError } from "@/lib/api";
import { useAnalytics, useSummary } from "@/lib/dashboard";
import {
  domainErrorText,
  useAddDomain,
  useAddresses,
  useCreateAddress,
  useDomains,
  useRemoveAddress,
  useRemoveDomain,
  useVerifyDomain,
  type AddressKind,
  type DnsRecord,
  type DnsRecordKey,
  type OrgAddress,
  type OrgDomain,
} from "@/lib/domains";
import { useLocale } from "@/lib/i18n";
import { notify } from "@/lib/notify";
import { normalizeWorkspacePlan, packageCopyName } from "@/lib/plan-surface";
import { cn } from "@/lib/utils";

export const Route = createFileRoute("/app/domains")({
  head: () => ({
    meta: [{ title: "Domains & addresses — ANEXOMAIL" }, { name: "robots", content: "noindex" }],
  }),
  component: DomainsPage,
});

/*
 * Cinematic standard (src/styles.css rules, docs/cursor-work/frontend/cinematic-ui-standard.md):
 * one light source (ax-keylight) · three depth layers (stage / plane / raised) · reveal, not slide
 * (ax-in, ax-stagger) · pacing (calm 380ms, stagger 45ms) · type as cinematography (locked six-step
 * scale: ax-title / ax-heading / ax-body / ax-label / ax-caption) · light angle on hover (ax-lift) ·
 * grain · silence (one confirming pulse, then still).
 */

/** Verify poll (D2, 20 Oct 2026): Rust ab domain ke APNE nameservers se seedha poochta hai (cache nahi, ~0.3s) — is liye
 *  har 3s; zyada se zyada 200 baar (~10 min), phir haath se "Check now". Tab chhupa ho to ruka rehta hai. */
const POLL_MS = 3_000;
const POLL_MAX = 200;

const CHECK_LABEL: Record<DnsRecordKey, { title: string; why: string }> = {
  txt: { title: "Ownership", why: "Proves the domain is yours." },
  mx: { title: "Mail delivery (MX)", why: "Sends incoming mail to ANEXOMAIL." },
  spf: { title: "Sender policy (SPF)", why: "Lets ANEXOMAIL send as your domain." },
  dkim: { title: "Signature (DKIM)", why: "Signs every message so it lands in the inbox." },
  dmarc: { title: "Policy (DMARC)", why: "Tells receivers how to treat your mail." },
};

type Registrar = { id: string; name: string; url: string; steps: string[] };

const REGISTRARS: Registrar[] = [
  {
    id: "namecheap",
    name: "Namecheap",
    url: "https://www.namecheap.com/myaccount/",
    steps: [
      "Domain List → Manage → Advanced DNS.",
      "Press Add New Record and pick the type shown below.",
      "Host = the Name column. Use @ for the root domain.",
    ],
  },
  {
    id: "godaddy",
    name: "GoDaddy",
    url: "https://dcc.godaddy.com/",
    steps: [
      "My Products → your domain → DNS.",
      "Press Add New Record and pick the type shown below.",
      "Name = the Name column. Use @ for the root domain.",
    ],
  },
  {
    id: "cloudflare",
    name: "Cloudflare",
    url: "https://dash.cloudflare.com/",
    steps: [
      "Select the domain → DNS → Records → Add record.",
      "Pick the type shown below and paste Name and Value.",
      "Leave proxy off (DNS only). MX and TXT are never proxied.",
    ],
  },
  {
    id: "other",
    name: "Other",
    url: "",
    steps: [
      "Open the DNS settings of your registrar or host.",
      "Add one record per row below. Name goes in Host/Name, Value in Value/Content.",
      "Enter only the Name — the registrar adds your domain automatically.",
    ],
  },
];

/** Nameserver naam -> registrar. Jo na pehchane woh "Other" (steps general rehte hain). */
const NS_HINTS: { test: RegExp; id: string; label: string }[] = [
  { test: /\.ns\.cloudflare\.com\.?$/, id: "cloudflare", label: "Cloudflare" },
  { test: /registrar-servers\.com\.?$/, id: "namecheap", label: "Namecheap" },
  { test: /domaincontrol\.com\.?$/, id: "godaddy", label: "GoDaddy" },
  { test: /awsdns-/, id: "other", label: "Amazon Route 53" },
  { test: /googledomains\.com\.?$|squarespacedns\.com\.?$/, id: "other", label: "Squarespace / Google Domains" },
];

/**
 * Domain ke NS records (DNS-over-HTTPS) dekh kar registrar pehchano. Sirf madad hai: lookup na ho
 * (network / CSP / timeout) to chup-chaap manual tabs rehte hain. Aage chal kar Rust proc.
 */
function useRegistrarHint(domain: string | null): { id: string; label: string } | null {
  const [hint, setHint] = useState<{ id: string; label: string } | null>(null);
  useEffect(() => {
    setHint(null);
    if (!domain) return;
    const ctl = new AbortController();
    const timer = setTimeout(() => ctl.abort(), 6000);
    const ask = async (name: string): Promise<string[]> => {
      const r = await fetch(`https://cloudflare-dns.com/dns-query?name=${encodeURIComponent(name)}&type=NS`, {
        headers: { accept: "application/dns-json" },
        signal: ctl.signal,
      });
      if (!r.ok) return [];
      const j = (await r.json()) as { Answer?: { type?: number; data?: string }[] };
      return (j.Answer ?? []).filter((a) => a.type === 2).map((a) => (a.data ?? "").toLowerCase());
    };
    void (async () => {
      // Subdomain (probuyer.axonetis.com) ke apne NS nahi hote — upar ka domain poochho.
      const labels = domain.split(".");
      for (let i = 0; i <= labels.length - 2 && i < 3; i += 1) {
        const names = await ask(labels.slice(i).join("."));
        if (names.length === 0) continue;
        const hit = NS_HINTS.find((h) => names.some((n) => h.test.test(n)));
        if (hit) setHint({ id: hit.id, label: hit.label });
        return;
      }
    })()
      .catch(() => undefined)
      .finally(() => clearTimeout(timer));
    return () => {
      ctl.abort();
      clearTimeout(timer);
    };
  }, [domain]);
  return hint;
}

/** `probuyer.axonetis.com` -> `axonetis.com` (DNS zone jahan records likhe jate hain). Seedha domain par null. */
const SECOND_LEVEL = new Set(["co", "com", "org", "net", "gov", "edu", "ac"]);
function parentZone(domain: string): string | null {
  const l = domain.toLowerCase().split(".");
  const keep = l.length >= 3 && l[l.length - 1]!.length === 2 && SECOND_LEVEL.has(l[l.length - 2]!) ? 3 : 2;
  return l.length > keep ? l.slice(-keep).join(".") : null;
}

/* ---- 8c: domain par pehle se mail hai? (asli user ka sab se bara khatra) ---- */

type ExistingMail = { provider: string | null; mx: string[]; spf: string | null };

const MX_PROVIDERS: { test: RegExp; name: string }[] = [
  { test: /(^|\.)(google|googlemail)\.com$/, name: "Google Workspace" },
  { test: /mail\.protection\.outlook\.com$/, name: "Microsoft 365" },
  { test: /(^|\.)zoho\.(com|eu|in|com\.au)$/, name: "Zoho Mail" },
  { test: /(^|\.)protonmail\.ch$/, name: "Proton Mail" },
  { test: /(^|\.)privateemail\.com$/, name: "Namecheap Private Email" },
  { test: /(^|\.)secureserver\.net$/, name: "GoDaddy email" },
];

async function doh(name: string, type: "MX" | "TXT", signal: AbortSignal): Promise<string[]> {
  const r = await fetch(`https://cloudflare-dns.com/dns-query?name=${encodeURIComponent(name)}&type=${type}`, {
    headers: { accept: "application/dns-json" },
    signal,
  });
  if (!r.ok) return [];
  const j = (await r.json()) as { Answer?: { type?: number; data?: string }[] };
  const code = type === "MX" ? 15 : 16;
  return (j.Answer ?? []).filter((a) => a.type === code).map((a) => a.data ?? "");
}

/**
 * Domain par pehle se MX (Google/Microsoft…) ya SPF ho to user ko pehle bata do: hamara MX lagane se
 * purane mailboxes ki mail band hoti hai, aur dusra SPF jorne se SPF toot jata hai. Sirf madad —
 * lookup na ho (network/timeout) to chup-chaap kuch nahi dikhta.
 */
function useExistingMail(domain: string | null): ExistingMail | null {
  const [found, setFound] = useState<ExistingMail | null>(null);
  useEffect(() => {
    setFound(null);
    if (!domain) return;
    const ctl = new AbortController();
    const timer = setTimeout(() => ctl.abort(), 6000);
    void (async () => {
      const [mxRaw, txtRaw] = await Promise.all([doh(domain, "MX", ctl.signal), doh(domain, "TXT", ctl.signal)]);
      const mx = mxRaw
        .map((d) => (d.trim().split(/\s+/).pop() ?? "").toLowerCase().replace(/\.$/, ""))
        .filter((h) => h.length > 0 && !/(^|\.)anexomail\.com$/.test(h));
      const spf =
        txtRaw
          .map((d) => d.replace(/"\s+"/g, "").replace(/^"|"$/g, ""))
          .find((d) => /^v=spf1(\s|$)/i.test(d) && !/anexomail\.com/i.test(d)) ?? null;
      if (mx.length === 0 && !spf) return;
      const provider = MX_PROVIDERS.find((m) => mx.some((h) => m.test.test(h)))?.name ?? null;
      setFound({ provider, mx, spf });
    })()
      .catch(() => undefined)
      .finally(() => clearTimeout(timer));
    return () => {
      ctl.abort();
      clearTimeout(timer);
    };
  }, [domain]);
  return found;
}

/** Mojooda SPF mein hamara token sab se aage jodo (ek domain par SPF ek hi ho sakta hai). */
function mergeSpf(current: string, token: string): string {
  if (current.includes(token)) return current;
  return current.replace(/^v=spf1\s*/i, `v=spf1 ${token} `).replace(/\s+/g, " ").trim();
}

function ExistingMailNotice({ domain, found, spfToken }: { domain: string; found: ExistingMail; spfToken: string }) {
  const { t } = useLocale();
  const who = found.provider ?? found.mx[0] ?? t("another provider");
  return (
    <div role="note" className="ax-in mt-4 rounded-2xl border border-warning/40 bg-warning/5 p-ax-4">
      <p className="ax-label inline-flex items-center gap-2 text-warning">
        <AlertTriangle className="size-4" aria-hidden="true" />
        {t("This domain already has email set up")}
      </p>
      {found.mx.length > 0 && (
        <p className="ax-body mt-2">
          <strong className="text-foreground">{who}</strong> {t("currently receives mail for")}{" "}
          <strong className="text-foreground">{domain}</strong>.{" "}
          {t("The MX record below sends new mail to ANEXOMAIL instead, so mailboxes there stop receiving. Move or back up those mailboxes first — or connect a different domain.")}
        </p>
      )}
      {found.spf && (
        <div className="mt-3">
          <p className="ax-body">
            {t("A domain can only have one SPF record. Don't add a second one — edit your current SPF and replace it with this:")}
          </p>
          <div className="mt-2">
            <Field label={t("SPF to use (replaces your current one)")} value={mergeSpf(found.spf, spfToken)} />
          </div>
          <p className="ax-caption mt-2">
            {t("Your current SPF:")} <code className="font-mono">{found.spf}</code>
          </p>
        </div>
      )}
    </div>
  );
}

function errText(e: unknown, fallback = "Couldn't do that. Try again."): string {
  const err = e as Partial<ApiError> | null;
  if (err?.status === 403) {
    return "Only the workspace owner or an admin can change domains and addresses.";
  }
  if (err?.status === 502 || err?.status === 503 || err?.status === 0) {
    return "The service didn't answer. Try again in a moment.";
  }
  return err?.code ? domainErrorText(err.code) : fallback;
}

function planLabel(plan: string | undefined): string {
  return packageCopyName(normalizeWorkspacePlan(plan), "business");
}

function capText(used: number, cap: number | null | undefined, noun: string): string {
  return cap == null ? `${used} ${noun} · unlimited` : `${used} of ${cap} ${noun}`;
}

function reducedMotion(): boolean {
  return (
    typeof window !== "undefined" &&
    window.matchMedia?.("(prefers-reduced-motion: reduce)").matches === true
  );
}

/**
 * Page ka scroll dabba + stage ki ek roshni. AppShell `h-screen overflow-hidden` hai — bina is
 * wrapper ke neeche ka hissa kat jata hai aur wizard ke 5 records tak pohanchna mumkin nahi
 * (founder ne 17 Oct 2026 ko pakda). `app.org` / `app.safety` bhi yehi dabba lagate hain.
 */
function PageScroll({ children }: { children: ReactNode }) {
  return (
    <div className="min-h-0 min-w-0 flex-1 overflow-y-auto">
      <div className="relative isolate overflow-hidden">
        <div className="ax-keylight" aria-hidden="true" />
        <div className="relative mx-auto w-full max-w-4xl space-y-ax-8 px-5 pb-28 pt-8 sm:px-6 md:px-10 md:pt-14">
          {children}
        </div>
      </div>
    </div>
  );
}

/** Loading par text nahi, wahi shakal jo aane wali hai (ax-shimmer). */
function PageSkeleton() {
  const { t } = useLocale();
  return (
    <PageScroll>
      <div role="status" className="space-y-ax-8">
        <span className="sr-only">{t("Loading domains…")}</span>
        <div className="space-y-3" aria-hidden="true">
          <div className="ax-shimmer h-3 w-28 rounded-full" />
          <div className="ax-shimmer h-10 w-80 max-w-full rounded-xl" />
          <div className="ax-shimmer h-4 w-[34rem] max-w-full rounded-full" />
        </div>
        <div className="ax-shimmer h-[26rem] rounded-3xl" aria-hidden="true" />
        <div className="space-y-3" aria-hidden="true">
          <div className="ax-shimmer h-5 w-40 rounded-full" />
          <div className="ax-shimmer h-16 rounded-2xl" />
        </div>
      </div>
    </PageScroll>
  );
}

/* ------------------------------ small pieces ------------------------------ */

/** Clipboard: pehle modern API, na chale (http / permission) to purana tareeqa. false = nahi hua. */
async function copyToClipboard(value: string): Promise<boolean> {
  try {
    await navigator.clipboard.writeText(value);
    return true;
  } catch {
    try {
      const ta = document.createElement("textarea");
      ta.value = value;
      ta.setAttribute("readonly", "");
      ta.style.position = "fixed";
      ta.style.opacity = "0";
      document.body.appendChild(ta);
      ta.select();
      const ok = document.execCommand("copy");
      document.body.removeChild(ta);
      return ok;
    } catch {
      return false;
    }
  }
}

function CopyButton({ value, label }: { value: string; label: string }) {
  const [copied, setCopied] = useState(false);
  const timer = useRef<ReturnType<typeof setTimeout> | null>(null);
  useEffect(
    () => () => {
      if (timer.current) clearTimeout(timer.current);
    },
    [],
  );
  const copy = async () => {
    if (!(await copyToClipboard(value))) {
      notify.failed("Couldn't copy", { description: "Select the text and copy it by hand." });
      return;
    }
    setCopied(true);
    if (timer.current) clearTimeout(timer.current);
    timer.current = setTimeout(() => setCopied(false), 1600);
  };
  return (
    <Button
      type="button"
      variant="outline"
      size="sm"
      className={cn(
        "ax-press ax-tap h-8 shrink-0 gap-1.5 px-2.5",
        copied && "border-success/50 text-success",
      )}
      onClick={() => void copy()}
      aria-label={`Copy ${label}`}
    >
      {copied ? (
        <CheckCircle2 className="size-3.5 text-success animate-in zoom-in-50 duration-200" aria-hidden="true" />
      ) : (
        <Copy className="size-3.5" aria-hidden="true" />
      )}
      <span aria-live="polite">{copied ? "Copied" : "Copy"}</span>
    </Button>
  );
}

/** Seedhi saadi zubaan mein poori list — IT wale ko bhejne ke liye (Zoho ka "Send to DNS admin", bina server ke). */
function instructionsText(d: OrgDomain, zone: string | null): string {
  const lines = [
    `Please add these ${d.records.length} DNS records for ${d.domain}.`,
    "Only add them — don't delete other records. Enter the Name exactly as shown (your DNS host adds the domain itself).",
    "",
  ];
  d.records.forEach((r, i) => {
    const long = zone && r.host.endsWith(`.${zone}`) ? r.host.slice(0, -(zone.length + 1)) : null;
    lines.push(`${i + 1}. ${CHECK_LABEL[r.key].title} - type ${r.type}`);
    lines.push(`   Name: ${r.name}${long && long !== r.name ? `   (if the DNS zone is ${zone}: ${long})` : ""}`);
    lines.push(`   Value: ${r.value ?? "(still being generated - ask again in a minute)"}`);
    if (r.type === "MX" && r.priority != null) lines.push(`   Priority: ${r.priority}`);
    lines.push("");
  });
  lines.push("Once saved, please tell me. ANEXOMAIL checks them automatically.");
  return lines.join("\n");
}

/** Asli user aksar DNS khud nahi chhoota — IT/web wale ko ek click mein bhejo. */
function HandoffCard({ domain, zone }: { domain: OrgDomain; zone: string | null }) {
  const { t } = useLocale();
  const text = useMemo(() => instructionsText(domain, zone), [domain, zone]);
  const subject = `DNS records to add for ${domain.domain}`;
  const full = `mailto:?subject=${encodeURIComponent(subject)}&body=${encodeURIComponent(text)}`;
  // Kuch mail apps lambe mailto kaat dete hain: lamba ho to chhota body + clipboard mein poori list.
  const tooLong = full.length > 1900;
  const href = tooLong
    ? `mailto:?subject=${encodeURIComponent(subject)}&body=${encodeURIComponent("Paste the DNS records here (copied to your clipboard).")}`
    : full;
  const [copied, setCopied] = useState(false);
  const timer = useRef<ReturnType<typeof setTimeout> | null>(null);
  useEffect(
    () => () => {
      if (timer.current) clearTimeout(timer.current);
    },
    [],
  );
  const flash = () => {
    setCopied(true);
    if (timer.current) clearTimeout(timer.current);
    timer.current = setTimeout(() => setCopied(false), 1600);
  };
  const copyAll = async () => {
    if (await copyToClipboard(text)) flash();
    else notify.failed("Couldn't copy", { description: "Select the text and copy it by hand." });
  };
  return (
    <div className="ax-plane mt-6 rounded-2xl p-ax-4">
      <div className="flex flex-wrap items-center gap-3">
        <span className="flex size-9 shrink-0 items-center justify-center rounded-xl border border-border bg-secondary text-steel">
          <Mail className="size-4" aria-hidden="true" />
        </span>
        <div className="min-w-[12rem] flex-1">
          <p className="ax-label">{t("Someone else manages your DNS?")}</p>
          <p className="ax-caption mt-0.5">
            {t("Send them these records in one click — your web developer, IT person or registrar support.")}
          </p>
        </div>
        <div className="flex w-full flex-col gap-2 sm:w-auto sm:flex-row sm:items-center">
          <Button asChild variant="outline" size="sm" className="ax-press ax-tap w-full gap-1.5 sm:w-auto">
            <a
              href={href}
              onClick={() => {
                if (tooLong) {
                  void copyToClipboard(text).then((ok) => {
                    if (ok) notify.info("Records copied", "Paste them into the email.");
                  });
                }
              }}
            >
              <Mail className="size-3.5" aria-hidden="true" />
              {t("Email these instructions")}
            </a>
          </Button>
          <Button
            type="button"
            variant="outline"
            size="sm"
            className={cn("ax-press ax-tap w-full gap-1.5 sm:w-auto", copied && "border-success/50 text-success")}
            onClick={() => void copyAll()}
          >
            {copied ? (
              <CheckCircle2 className="size-3.5 animate-in zoom-in-50 duration-200" aria-hidden="true" />
            ) : (
              <Copy className="size-3.5" aria-hidden="true" />
            )}
            <span aria-live="polite">{copied ? t("Copied") : t("Copy all as text")}</span>
          </Button>
        </div>
      </div>
    </div>
  );
}

function Tick({ ok, pending }: { ok: boolean; pending?: boolean }) {
  if (ok) {
    return (
      <span className="ax-label inline-flex items-center gap-1 text-success">
        <CheckCircle2 className="size-4 animate-in zoom-in-50 duration-300" aria-hidden="true" />
        Found
      </span>
    );
  }
  return (
    <span className="ax-label inline-flex items-center gap-1 text-muted-foreground">
      <Circle className="size-4" aria-hidden="true" />
      {pending ? "Key is being prepared" : "Not found yet"}
    </span>
  );
}

function Field({ label, value }: { label: string; value: string }) {
  // Lambi value (SPF, DKIM, verify token) phone par Copy ke saath ek line mein dabti thi — "co m ~all" jaisa beech se
  // toot kar parhna/milana mushkil. Isliye lambi value par phone mein dabba poori chaudai, Copy neeche (sm+ par pehle jaisa).
  const long = value.length > 24;
  return (
    <div className="min-w-0">
      <p className="ax-caption">{label}</p>
      <div className={cn("mt-1 flex gap-2", long ? "flex-col items-stretch sm:flex-row sm:items-center" : "items-center")}>
        <code className="min-w-0 flex-1 break-words rounded-lg border border-border bg-background/60 px-2.5 py-1.5 font-mono text-xs text-foreground">
          {value}
        </code>
        <CopyButton value={value} label={label} />
      </div>
    </div>
  );
}

function RecordCard({
  rec,
  n,
  of,
  zone,
}: {
  rec: DnsRecord;
  n: number;
  of: number;
  zone: string | null;
}) {
  const meta = CHECK_LABEL[rec.key];
  // Subdomain par agar DNS parent zone ka ho to Name lamba likhna parta hai (`_dmarc.probuyer`).
  const longName = zone && rec.host.endsWith(`.${zone}`) ? rec.host.slice(0, -(zone.length + 1)) : null;
  return (
    <li
      className={cn(
        "ax-plane rounded-2xl p-ax-4 transition-colors duration-500",
        rec.ok && "border-success/40",
      )}
    >
      <div className="flex flex-wrap items-center gap-2">
        <span className="ax-label flex size-6 items-center justify-center rounded-full border border-border bg-secondary">
          {n}
        </span>
        <p className="ax-label">{meta.title}</p>
        <Chip>{rec.type}</Chip>
        <span className="ax-caption">
          {n} / {of}
        </span>
        <span className="ml-auto">
          <Tick ok={rec.ok} {...(rec.pending ? { pending: true } : {})} />
        </span>
      </div>
      <p className="ax-caption mt-1">{meta.why}</p>
      <div
        className={cn(
          "mt-3 grid gap-3",
          longName && longName !== rec.name
            ? "md:grid-cols-[minmax(0,1.25fr)_minmax(0,1.75fr)]"
            : "md:grid-cols-[minmax(0,1fr)_minmax(0,2fr)]",
        )}
      >
        <div className="min-w-0 space-y-3">
          <Field label="Name / Host" value={rec.name} />
          {longName && longName !== rec.name && (
            <Field label={`If DNS zone is ${zone}`} value={longName} />
          )}
        </div>
        {rec.value ? (
          <Field label="Value" value={rec.value} />
        ) : (
          <div className="rounded-lg border border-dashed border-border p-3">
            <div className="flex items-center gap-2">
              <span className="size-1.5 rounded-full bg-warning ax-breathe" aria-hidden="true" />
              <p className="ax-caption">
                Your signing key is being generated — this row fills in by itself, usually within a minute.
              </p>
            </div>
            <div className="ax-shimmer mt-2 h-6 w-full rounded-md" aria-hidden="true" />
          </div>
        )}
      </div>
      {rec.type === "MX" && rec.priority != null && (
        <div className="mt-3 max-w-[10rem]">
          <Field label="Priority" value={String(rec.priority)} />
        </div>
      )}
    </li>
  );
}

/** Teen qadam, ek jud'ti hui lakeer — jo qadam ho chuka woh bharta jata hai. */
function StepRail({ step }: { step: 1 | 2 | 3 | 4 }) {
  const { t } = useLocale();
  const steps = [t("Your domain"), t("Add DNS records"), t("We check")];
  const fill = ((Math.min(step, 3) - 1) / 2) * 100;
  return (
    <ol className="relative grid grid-cols-3 gap-2" aria-label="Setup steps">
      <span aria-hidden="true" className="absolute inset-x-[16.667%] top-3 h-px bg-border">
        <span
          className="block h-full bg-[var(--cyan-accent)] motion-safe:transition-[width] motion-safe:duration-700"
          style={{ width: `${fill}%` }}
        />
      </span>
      {steps.map((label, i) => {
        const n = (i + 1) as 1 | 2 | 3;
        const state = n < step ? "done" : n === step ? "now" : "next";
        return (
          <li
            key={label}
            aria-current={state === "now" ? "step" : undefined}
            className="relative flex flex-col items-center gap-2 text-center"
          >
            <span
              className={cn(
                "ax-label flex size-6 items-center justify-center rounded-full border transition-colors duration-500",
                state === "done" && "border-success/50 bg-card text-success",
                state === "now" && "border-[var(--cyan-accent)] bg-card text-foreground shadow-[0_0_0_4px_oklch(0.735_0.121_213/14%)]",
                state === "next" && "border-border bg-card text-muted-foreground",
              )}
            >
              {state === "done" ? <CheckCircle2 className="size-3.5" aria-hidden="true" /> : n}
            </span>
            <span className={cn("ax-label", state === "next" && "text-muted-foreground")}>{label}</span>
          </li>
        );
      })}
    </ol>
  );
}

/** x/5 records mile — chhota gola, bharta hua. */
function Ring({ done, total, celebrate }: { done: number; total: number; celebrate?: boolean }) {
  const r = 26;
  const c = 2 * Math.PI * r;
  const off = c * (1 - (total > 0 ? done / total : 0));
  const full = total > 0 && done === total;
  return (
    <div
      className={cn("relative size-16 shrink-0 rounded-full", celebrate && "ax-confirm")}
      role="img"
      aria-label={`${done} of ${total} records found`}
    >
      <svg viewBox="0 0 64 64" className="size-16 -rotate-90" aria-hidden="true">
        <circle cx="32" cy="32" r={r} fill="none" strokeWidth="5" className="stroke-border" />
        <circle
          cx="32"
          cy="32"
          r={r}
          fill="none"
          strokeWidth="5"
          strokeLinecap="round"
          strokeDasharray={c}
          strokeDashoffset={off}
          className={cn(
            full ? "stroke-success" : "stroke-[var(--cyan-accent)]",
            "motion-safe:transition-[stroke-dashoffset] motion-safe:duration-700",
          )}
        />
      </svg>
      <span className="ax-label absolute inset-0 grid place-items-center">
        {done}/{total}
      </span>
    </div>
  );
}

/* --------------------------------- wizard --------------------------------- */

/** Server (`org_domain_add`) jaisa saaf: scheme/www/path hata kar chhota. Isse apna-vs-doosre ka farq pehle hi pata chal jata hai. */
function normaliseDomain(raw: string): string {
  return raw
    .trim()
    .toLowerCase()
    .replace(/^(https?:\/\/)?(www\.)?/, "")
    .replace(/[/:].*$/, "");
}

type WizardState = { step: 1 | 2 | 3; domainId: string | null; prefill?: string };

function Wizard({
  domains,
  state,
  setState,
  atCap,
  capLabel,
  suggestion,
  loginAddress,
  onClose,
  onDone,
}: {
  domains: OrgDomain[];
  state: WizardState;
  setState: (s: WizardState) => void;
  atCap: boolean;
  capLabel: string;
  suggestion: string | null;
  loginAddress: string | null;
  onClose: () => void;
  onDone: (domain: OrgDomain) => void;
}) {
  const { t } = useLocale();
  const add = useAddDomain();
  const verify = useVerifyDomain();
  const { refetch: refetchDomains } = useDomains();
  const rootRef = useRef<HTMLElement | null>(null);
  const [name, setName] = useState(state.prefill ?? "");
  const [problem, setProblem] = useState<string | null>(null);
  // 8e: "domain_taken" ka seedha matlab do alag halaat hain — yahin (is workspace mein pehle se) ya kisi aur ke paas.
  const [taken, setTaken] = useState<{ kind: "mine"; domain: OrgDomain } | { kind: "other"; name: string } | null>(null);
  const [registrar, setRegistrar] = useState("namecheap");
  const [polls, setPolls] = useState(0);
  const [nextIn, setNextIn] = useState(POLL_MS / 1000);
  // D2: kis nameserver se seedha dekha (null = purana public raasta)
  const [liveAt, setLiveAt] = useState<string[] | null>(null);
  const pollsRef = useRef(0);
  const domain = useMemo(
    () => domains.find((d) => d.id === state.domainId) ?? null,
    [domains, state.domainId],
  );
  const verifyRef = useRef(verify);
  verifyRef.current = verify;

  const hint = useRegistrarHint(state.step === 2 && domain ? domain.domain : null);
  const zone = domain ? parentZone(domain.domain) : null;
  const existing = useExistingMail(state.step === 2 && domain ? domain.domain : null);
  const spfToken =
    (domain?.records.find((r) => r.key === "spf")?.value ?? "").match(/\b(?:a|include|ip4|ip6):\S+/)?.[0] ??
    "a:mail.anexomail.com";
  useEffect(() => {
    if (hint && REGISTRARS.some((r) => r.id === hint.id)) setRegistrar(hint.id);
  }, [hint]);

  // Naya qadam khule to screen foran wahan pohanche (page scroll hota hai — neeche ka hissa chhup na jaye).
  useEffect(() => {
    rootRef.current?.scrollIntoView({ behavior: reducedMotion() ? "auto" : "smooth", block: "start" });
  }, [state.step, state.domainId]);

  const check = useCallback(
    (manual: boolean) => {
      if (!domain || verifyRef.current.isPending) return;
      verifyRef.current.mutate(domain.id, {
        onSuccess: (r) => {
          if (!r.ok) {
            setProblem(domainErrorText(r.error));
            return;
          }
          setProblem(null);
          setLiveAt(r.source === "authoritative" && r.nameservers?.length ? r.nameservers : null);
          if (r.ready) {
            notify.done(`${r.domain.domain} is verified`);
          } else if (manual) {
            const left = (Object.keys(r.checks) as DnsRecordKey[]).filter((k) => !r.checks[k]);
            notify.info(
              "Not all records found yet",
              `Still waiting for: ${left.map((k) => CHECK_LABEL[k].title).join(", ")}. DNS can take a few minutes.`,
            );
          }
        },
        onError: (e) => setProblem(errText(e)),
      });
    },
    [domain],
  );

  // Qadam 3: kholte hi ek check, phir har 20s jab tak verified na ho. Ghadi har second chalti hai (countdown).
  const pending = state.step === 3 && domain?.status === "pending";
  useEffect(() => {
    if (!pending) return;
    pollsRef.current = 0;
    setPolls(0);
    let left = POLL_MS / 1000;
    setNextIn(left);
    check(false);
    const id = setInterval(() => {
      if (typeof document !== "undefined" && document.hidden) return;
      if (pollsRef.current >= POLL_MAX) return;
      left -= 1;
      if (left <= 0) {
        left = POLL_MS / 1000;
        pollsRef.current += 1;
        setPolls(pollsRef.current);
        check(false);
      }
      setNextIn(left);
    }, 1000);
    return () => clearInterval(id);
    // eslint-disable-next-line react-hooks/exhaustive-deps -- naya domain/qadam hi dobara shuru kare
  }, [pending, domain?.id]);

  // Qadam 2: DKIM key abhi ban rahi ho to list khud taza hoti rahe (cron har minute chalta hai).
  const keyPending = state.step === 2 && Boolean(domain?.records.some((r) => r.pending));
  useEffect(() => {
    if (!keyPending) return;
    const id = setInterval(() => {
      if (typeof document !== "undefined" && document.hidden) return;
      void refetchDomains();
    }, 8000);
    return () => clearInterval(id);
  }, [keyPending, refetchDomains]);

  const submitName = () => {
    setProblem(null);
    setTaken(null);
    const clean = normaliseDomain(name);
    const mine = domains.find((d) => d.domain === clean);
    if (mine) {
      setTaken({ kind: "mine", domain: mine });
      return;
    }
    add.mutate(name, {
      onSuccess: (r) => {
        if (!r.ok || !r.domain) {
          if (r.error === "domain_taken") {
            setTaken({ kind: "other", name: clean });
            return;
          }
          setProblem(domainErrorText(r.error, { plan: planLabel(r.plan), limit: r.limit ?? null }));
          return;
        }
        setName("");
        setState({ step: 2, domainId: r.domain.id });
      },
      onError: (e) => setProblem(errText(e)),
    });
  };

  const found = domain ? domain.records.filter((r) => r.ok).length : 0;
  const total = domain ? domain.records.length : 5;
  const verified = domain?.status === "verified";
  const reg = REGISTRARS.find((r) => r.id === registrar) ?? REGISTRARS[3]!;

  return (
    <section
      ref={rootRef}
      className="ax-plane ax-grain ax-in scroll-mt-6 overflow-clip! rounded-3xl p-ax-5 md:p-ax-7"
      aria-label="Connect a domain"
    >
      <div className="relative z-10">
        <div className="flex items-start gap-3">
          <div className="min-w-0 flex-1">
            <StepRail step={state.step === 3 && domain?.status === "verified" ? 4 : state.step} />
          </div>
          <Button
            type="button"
            variant="ghost"
            size="sm"
            className="ax-press shrink-0 gap-1.5"
            onClick={onClose}
          >
            <X className="size-4" aria-hidden="true" />
            {t("Close")}
          </Button>
        </div>

        {state.step === 1 && (
          <div className="ax-in mt-ax-7">
            <h3 className="ax-title">{t("Which domain should mail use?")}</h3>
            <p className="ax-body mt-3 max-w-xl">
              {t("The one you own, like company.com. You will add five DNS records next — nothing changes until you do.")}
            </p>
            <form
              className="mt-6 flex max-w-xl flex-col gap-2 sm:flex-row"
              onSubmit={(e) => {
                e.preventDefault();
                if (!atCap && name.trim()) submitName();
              }}
            >
              <label className="sr-only" htmlFor="ax-domain-name">
                Domain name
              </label>
              <div className="relative sm:flex-1">
                <AtSign
                  className="pointer-events-none absolute left-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground"
                  aria-hidden="true"
                />
                <Input
                  id="ax-domain-name"
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                  placeholder="company.com"
                  autoComplete="off"
                  autoCapitalize="off"
                  spellCheck={false}
                  disabled={atCap || add.isPending}
                  className="h-11 pl-9 text-base"
                  autoFocus
                />
              </div>
              <Button
                type="submit"
                variant="seal"
                size="lg"
                className="ax-press ax-tap gap-1.5"
                disabled={atCap || add.isPending || !name.trim()}
              >
                {add.isPending ? <BrandSpinner className="size-4" aria-hidden="true" /> : null}
                {t("Continue")}
                {!add.isPending && <ArrowRight className="size-4" aria-hidden="true" />}
              </Button>
            </form>
            {suggestion && !name.trim() && !atCap && (
              <button
                type="button"
                onClick={() => setName(suggestion)}
                className="ax-focus ax-press ax-label mt-3 inline-flex items-center gap-2 rounded-full border border-border bg-secondary/50 px-3 py-1.5 transition-colors hover:border-[var(--cyan-accent)]/60"
              >
                <Globe className="size-3.5 text-steel" aria-hidden="true" />
                {t("Use")} {suggestion}
                <span className="font-normal text-muted-foreground">· {t("from your signup")}</span>
              </button>
            )}
            {problem && <p role="alert" className="ax-shake ax-label mt-3 text-danger">{problem}</p>}
            {taken?.kind === "mine" && (
              <div role="status" className="ax-plane mt-4 flex max-w-xl flex-wrap items-center gap-3 rounded-2xl p-ax-4">
                <Globe className="size-5 shrink-0 text-steel" aria-hidden="true" />
                <div className="min-w-[12rem] flex-1">
                  <p className="ax-label [overflow-wrap:anywhere]">
                    {taken.domain.domain} {t("is already in this workspace")}
                  </p>
                  <p className="ax-caption mt-0.5">
                    {taken.domain.status === "verified"
                      ? t("It is verified. Create its addresses next.")
                      : t("Pick up where you left off — your five records are waiting.")}
                  </p>
                </div>
                <Button
                  type="button"
                  variant="seal"
                  size="sm"
                  className="ax-press ax-tap w-full gap-1.5 sm:w-auto"
                  onClick={() => {
                    if (taken.domain.status === "verified") onDone(taken.domain);
                    else setState({ step: 2, domainId: taken.domain.id });
                  }}
                >
                  {taken.domain.status === "verified" ? t("Create an address") : t("Continue setup")}
                  <ArrowRight className="size-3.5" aria-hidden="true" />
                </Button>
              </div>
            )}
            {taken?.kind === "other" && (
              <div role="alert" className="ax-plane mt-4 max-w-xl rounded-2xl border border-warning/40 p-ax-4">
                <div className="flex items-start gap-3">
                  <AlertTriangle className="mt-0.5 size-5 shrink-0 text-warning" aria-hidden="true" />
                  <div className="min-w-0">
                    <p className="ax-label [overflow-wrap:anywhere]">
                      {taken.name} {t("is already connected to another ANEXOMAIL workspace")}
                    </p>
                    <p className="ax-caption mt-1">
                      {t("If it is yours — for example from an old or test sign-up — sign in to that account, remove the domain there, then connect it here.")}
                    </p>
                    <p className="ax-caption mt-2">
                      {t("Can't find that account?")}{" "}
                      <a
                        className="ax-focus font-medium text-foreground underline underline-offset-2"
                        href={`mailto:hello@anexomail.com?subject=${encodeURIComponent(`Domain already connected: ${taken.name}`)}&body=${encodeURIComponent(`Hello,\n\nI own ${taken.name} but it shows as already connected to another workspace. Please help me move it to my account.\n`)}`}
                      >
                        {t("Tell us at hello@anexomail.com")}
                      </a>{" "}
                      {t("and we will help you move it.")}
                    </p>
                  </div>
                </div>
              </div>
            )}
            {atCap && <p className="ax-caption mt-3 text-muted-foreground">{capLabel}</p>}
          </div>
        )}

        {state.step === 2 && domain && (
          <div className="ax-in mt-ax-7">
            <h3 className="ax-title">{t("Add these DNS records")}</h3>
            <p className="ax-body mt-3 max-w-2xl">
              {t("At your registrar, copy each Name and Value into the DNS settings for")}{" "}
              <strong className="text-foreground">{domain.domain}</strong>.{" "}
              {t("Enter only the Name — your registrar adds the domain itself.")}
            </p>

            {/* Sab se bara khatra (purani mail ruk sakti hai) registrar ke general steps se PEHLE dikhe — phone par neeche chhup jata tha. */}
            {existing && <ExistingMailNotice domain={domain.domain} found={existing} spfToken={spfToken} />}

            <div className="mt-6 rounded-2xl border border-border bg-background/40 p-ax-4">
              {hint && (
                <p className="ax-label ax-in mb-3 inline-flex items-center gap-2 text-success">
                  <ShieldCheck className="size-4" aria-hidden="true" />
                  {t("We found your DNS is at")} {hint.label}
                  {hint.id === "other" ? ` — ${t("general steps below")}` : ` — ${t("steps below match it")}`}
                </p>
              )}
              <div className="flex flex-wrap items-center gap-2" role="tablist" aria-label="Registrar">
                {REGISTRARS.map((r) => (
                  <button
                    key={r.id}
                    type="button"
                    role="tab"
                    aria-selected={registrar === r.id}
                    onClick={() => setRegistrar(r.id)}
                    className={cn(
                      "ax-focus ax-press ax-label rounded-full border px-3 py-1 transition-colors",
                      registrar === r.id
                        ? "border-[var(--cyan-accent)] bg-[var(--cyan-accent)]/10 text-foreground"
                        : "border-border text-muted-foreground hover:text-foreground",
                    )}
                  >
                    {r.name}
                    {hint?.id === r.id && <span className="sr-only"> ({t("detected")})</span>}
                  </button>
                ))}
                {reg.url && (
                  <a
                    href={reg.url}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="ax-focus ax-label ml-auto inline-flex items-center gap-1 text-steel hover:text-foreground"
                  >
                    {t("Open")} {reg.name}
                    <ArrowRight className="size-3.5" aria-hidden="true" />
                  </a>
                )}
              </div>
              <ol className="ax-body mt-3 list-decimal space-y-1 pl-5">
                {reg.steps.map((s) => (
                  <li key={s}>{s}</li>
                ))}
              </ol>
            </div>

            {zone && (
              <p className="ax-body ax-in mt-4 rounded-2xl border border-[var(--cyan-accent)]/30 bg-[var(--cyan-accent)]/5 p-ax-4">
                <strong className="text-foreground">{domain.domain}</strong> {t("is a subdomain of")}{" "}
                <strong className="text-foreground">{zone}</strong>.{" "}
                {t("If your DNS is hosted for")} {zone}, {t("use the longer name shown under each Name below (for example @ becomes")}{" "}
                <code className="font-mono text-xs text-foreground">{domain.domain.slice(0, -(zone.length + 1))}</code>).
              </p>
            )}

            <ul className="ax-stagger mt-4 space-y-3">
              {domain.records.map((rec, i) => (
                <RecordCard key={rec.key} rec={rec} n={i + 1} of={domain.records.length} zone={zone} />
              ))}
            </ul>

            <HandoffCard domain={domain} zone={zone} />

            <div className="mt-7 flex flex-wrap items-center gap-2">
              <Button
                type="button"
                variant="seal"
                size="lg"
                className="ax-press ax-tap gap-1.5"
                onClick={() => setState({ step: 3, domainId: domain.id })}
              >
                {t("I've added them — check now")}
                <ArrowRight className="size-4" aria-hidden="true" />
              </Button>
              <Button type="button" variant="ghost" className="ax-press" onClick={onClose}>
                {t("Finish later")}
              </Button>
            </div>
          </div>
        )}

        {state.step === 3 && domain && (
          <div className="ax-in mt-ax-7" role="status" aria-live="polite">
            {/* Phone: ring upar, heading poori chaudai mein; domain naam dots par tootta hai ("probuyer.axon/etis.com" nahi). */}
            <div className={cn("flex flex-col items-start gap-4 sm:flex-row sm:items-center", verified && "ax-celebrate")}>
              <Ring done={found} total={total} {...(verified ? { celebrate: true } : {})} />
              <div className="min-w-0">
                <h3 className="ax-title break-words">
                  {verified
                    ? `${domain.domain.replace(/\./g, ".\u200b")} ${t("is verified")}`
                    : `${t("Checking")} ${domain.domain.replace(/\./g, ".\u200b")}`}
                </h3>
                <p className="ax-body mt-2 max-w-2xl">
                  {verified
                    ? t("All five records are live. You can create addresses on this domain now.")
                    : t("Each tick turns green the moment its record is found. DNS can take a few minutes — you can leave this page open.")}
                </p>
              </div>
            </div>

            <ul className="ax-stagger mt-6 grid gap-2 sm:grid-cols-2">
              {domain.records.map((rec) => (
                <li
                  key={rec.key}
                  className={cn(
                    "flex items-center gap-3 rounded-2xl border p-3 transition-colors duration-500",
                    rec.ok ? "ax-confirm border-success/40 bg-success/5" : "border-border",
                  )}
                >
                  <span className="flex size-5 shrink-0 items-center justify-center">
                    {rec.ok ? (
                      <CheckCircle2
                        className="size-5 text-success animate-in zoom-in-50 duration-300"
                        aria-hidden="true"
                      />
                    ) : (
                      <span
                        className={cn(
                          "size-2 rounded-full",
                          rec.pending ? "bg-muted-foreground" : "bg-warning ax-breathe",
                        )}
                        aria-hidden="true"
                      />
                    )}
                  </span>
                  <div className="min-w-0 flex-1">
                    <p className="ax-label">{CHECK_LABEL[rec.key].title}</p>
                    <p className="ax-caption truncate">
                      {rec.type} · {rec.name}
                    </p>
                  </div>
                  <span className={cn("ax-label", rec.ok ? "text-success" : "text-muted-foreground")}>
                    {rec.ok ? t("Found") : rec.pending ? t("Key is being prepared") : t("Waiting")}
                  </span>
                </li>
              ))}
            </ul>

            {!verified && (
              <div className="ax-plane mt-5 flex flex-wrap items-center gap-3 rounded-2xl p-ax-4">
                <span className="flex size-9 shrink-0 items-center justify-center rounded-xl border border-border bg-secondary text-steel">
                  <Mail className="size-4" aria-hidden="true" />
                </span>
                <div className="min-w-[12rem] flex-1">
                  <p className="ax-label">{t("Your inbox already works while DNS updates")}</p>
                  <p className="ax-caption mt-0.5 [overflow-wrap:anywhere]">
                    {loginAddress
                      ? `${t("Mail sent to")} ${loginAddress} ${t("arrives now. Your company address starts working the moment all five ticks are green.")}`
                      : t("Your company address starts working the moment all five ticks are green.")}
                  </p>
                </div>
                <Button asChild variant="outline" size="sm" className="ax-press ax-tap w-full gap-1.5 sm:w-auto">
                  <Link to="/app/mail">
                    {t("Open your inbox")}
                    <ArrowRight className="size-3.5" aria-hidden="true" />
                  </Link>
                </Button>
              </div>
            )}

            {!verified && liveAt && (
              <p className="ax-caption mt-4 max-w-xl [overflow-wrap:anywhere]">
                <span className="mr-1.5 inline-block size-2 animate-pulse rounded-full bg-success align-middle" aria-hidden="true" />
                {t("Checking directly at your DNS host")} ({liveAt.slice(0, 2).join(", ")}){" "}
                {t("— no waiting for caches. The moment a record is saved there, it turns green here.")}
              </p>
            )}
            {!verified && (
              <p className="ax-caption mt-4 max-w-xl">
                {liveAt
                  ? t("You don't have to wait here — close this page and come back later; your inbox already works.")
                  : t("DNS usually updates within 5–60 minutes, rarely longer. You don't have to wait here — close this page and come back later; your inbox already works.")}
              </p>
            )}

            {!verified && polls >= POLL_MAX && (
              <div role="status" className="ax-plane mt-5 rounded-2xl border border-warning/40 p-ax-4">
                <p className="ax-label">{t("Still not found — let's check")}</p>
                <ul className="ax-caption mt-2 list-disc space-y-1.5 pl-5">
                  <li className="[overflow-wrap:anywhere]">
                    {t("Still missing:")}{" "}
                    {domain.records
                      .filter((r) => !r.ok)
                      .map((r) => CHECK_LABEL[r.key].title)
                      .join(", ") || t("nothing — press Check now")}
                  </li>
                  <li>
                    {t("Was each record saved? Many DNS pages need a separate Save or Publish click after you add them.")}
                  </li>
                  <li className="[overflow-wrap:anywhere]">
                    {t("In the Name box type only the part we show (like _dmarc). The DNS page adds your domain itself — if you see")}{" "}
                    <span className="font-mono">{`_dmarc.${domain.domain}.${domain.domain}`}</span> {t("the domain was doubled.")}
                  </li>
                  {hint && (
                    <li>
                      {t("Your DNS looks hosted at")} {hint.label}. {t("Records must be added there, not at another company.")}
                    </li>
                  )}
                </ul>
              </div>
            )}

            {problem && <p role="alert" className="ax-shake ax-label mt-3 text-danger">{problem}</p>}

            <div className="mt-7 flex flex-wrap items-center gap-2">
              {verified ? (
                <Button
                  type="button"
                  variant="seal"
                  size="lg"
                  className="ax-press ax-tap gap-1.5"
                  onClick={() => onDone(domain)}
                >
                  {t("Create your first address")}
                  <ArrowRight className="size-4" aria-hidden="true" />
                </Button>
              ) : (
                <>
                  <Button
                    type="button"
                    variant="seal"
                    size="lg"
                    className="ax-press ax-tap gap-1.5"
                    disabled={verify.isPending}
                    onClick={() => check(true)}
                  >
                    {verify.isPending ? (
                      <BrandSpinner className="size-4" aria-hidden="true" />
                    ) : (
                      <RefreshCw className="size-4" aria-hidden="true" />
                    )}
                    {t("Check now")}
                  </Button>
                  <Button
                    type="button"
                    variant="outline"
                    className="ax-press"
                    onClick={() => setState({ step: 2, domainId: domain.id })}
                  >
                    {t("Show the records again")}
                  </Button>
                  <span className="ax-caption inline-flex items-center gap-1.5">
                    <Clock className="size-3.5" aria-hidden="true" />
                    {polls >= POLL_MAX
                      ? t("Automatic checks paused — press Check now when your DNS is saved.")
                      : verify.isPending
                        ? t("Checking…")
                        : `${t("Next automatic check in")} ${nextIn}s`}
                  </span>
                </>
              )}
            </div>
          </div>
        )}
      </div>
    </section>
  );
}

/* -------------------------------- domains -------------------------------- */

const PREVIEW_STEPS: { icon: typeof Globe; title: string; body: string }[] = [
  { icon: Globe, title: "Name your domain", body: "Type the one you own, like company.com." },
  {
    icon: Copy,
    title: "Add five DNS records",
    body: "Copy each Name and Value. Steps for Namecheap, GoDaddy and Cloudflare.",
  },
  {
    icon: ShieldCheck,
    title: "Watch the ticks turn green",
    body: "We check live while you wait. DNS can take a few minutes.",
  },
];

/** Aane wali mail ka nateeja: "From" mein aap ka apna address. Sirf jhalak — asli data nahi. */
function MailPreview({ address }: { address: string }) {
  const { t } = useLocale();
  return (
    <div
      className="ax-drift relative rounded-2xl border border-border bg-background/70 p-ax-4 shadow-elev-2 backdrop-blur"
      aria-hidden="true"
    >
      <div className="flex items-center gap-1.5">
        <span className="size-2 rounded-full bg-border" />
        <span className="size-2 rounded-full bg-border" />
        <span className="size-2 rounded-full bg-border" />
        <span className="ax-caption ml-auto">{t("New message")}</span>
      </div>
      <div className="mt-4 space-y-3">
        <div className="flex items-center gap-3 border-b border-border pb-3">
          <span className="ax-caption w-14 shrink-0">{t("From")}</span>
          <span className="ax-label inline-flex min-w-0 items-center gap-1.5 rounded-full border border-success/40 bg-success/10 px-2.5 py-1">
            <span className="size-1.5 shrink-0 rounded-full bg-success ax-breathe" />
            <span className="truncate">{address}</span>
          </span>
        </div>
        <div className="flex items-center gap-3 border-b border-border pb-3">
          <span className="ax-caption w-14 shrink-0">{t("To")}</span>
          <span className="ax-shimmer h-3 w-36 rounded-full" />
        </div>
        <div className="flex items-center gap-3 border-b border-border pb-3">
          <span className="ax-caption w-14 shrink-0">{t("Subject")}</span>
          <span className="ax-label">{t("Your quote is ready")}</span>
        </div>
        <div className="space-y-2 pt-1">
          <span className="ax-shimmer block h-2.5 w-full rounded-full" />
          <span className="ax-shimmer block h-2.5 w-[88%] rounded-full" />
          <span className="ax-shimmer block h-2.5 w-[64%] rounded-full" />
        </div>
      </div>
      <p className="ax-caption mt-4 text-right">{t("Preview — how your mail will look")}</p>
    </div>
  );
}

/** Khali page ka pehla taassur: kya milega, kitna waqt lagega, ek hi bara button. */
function EmptyHero({
  suggestion,
  capNote,
  onStart,
}: {
  suggestion: string | null;
  capNote: string;
  onStart: (prefill?: string) => void;
}) {
  const { t } = useLocale();
  const shown = suggestion ?? "yourcompany.com";
  return (
    <section
      className="ax-plane ax-grain relative overflow-clip! rounded-3xl p-ax-5 md:p-ax-7"
      aria-label="Connect your first domain"
    >
      <div
        aria-hidden="true"
        className="pointer-events-none absolute -right-28 -top-32 size-96 rounded-full bg-[var(--cyan-accent)]/10 blur-3xl"
      />
      <div className="relative z-10">
        <div className="grid gap-ax-6 md:grid-cols-[minmax(0,1.05fr)_minmax(0,1fr)] md:items-center">
          <div className="min-w-0">
            <p className="ax-eyebrow">{t("Your name on every email")}</p>
            <h3 className="ax-title mt-4 [overflow-wrap:anywhere]">
              {suggestion ? t("Connect your domain") : t("Email from your own domain")}
            </h3>
            {suggestion && (
              <p className="ax-heading mt-4 inline-flex max-w-full items-center gap-2 rounded-full border border-border bg-background/50 py-1.5 pl-3 pr-4">
                <Globe className="size-4 shrink-0 text-steel" aria-hidden="true" />
                <span className="min-w-0 truncate">{suggestion}</span>
                <span className="ax-caption hidden shrink-0 sm:inline">· {t("from your signup")}</span>
              </p>
            )}
            <p className="ax-body mt-4 max-w-md">
              {suggestion
                ? t("Add the DNS records once and your team can send and receive on it.")
                : t("Until you connect one, your mail runs on your ANEXOMAIL address. Connecting takes about five minutes plus DNS time.")}
            </p>
            <div className="mt-6 flex flex-wrap items-center gap-3">
              <Button
                type="button"
                variant="seal"
                size="xl"
                className="ax-press ax-tap max-w-full gap-2"
                onClick={() => onStart(suggestion ?? undefined)}
              >
                <Plus className="size-4 shrink-0" aria-hidden="true" />
                <span className="truncate">
                  {suggestion ? `${t("Connect")} ${suggestion}` : t("Connect a domain")}
                </span>
              </Button>
              {suggestion && (
                <Button
                  type="button"
                  variant="outline"
                  size="lg"
                  className="ax-press gap-1.5"
                  onClick={() => onStart()}
                >
                  {t("Use a different domain")}
                  <ArrowRight className="size-4" aria-hidden="true" />
                </Button>
              )}
            </div>
            <p className="ax-caption mt-5">{capNote}</p>
          </div>
          <MailPreview address={`you@${shown}`} />
        </div>

        <div className="ax-hairline mt-ax-7 h-px" aria-hidden="true" />
        <ol className="ax-stagger mt-ax-5 grid gap-3 sm:grid-cols-3" aria-label="How it works">
          {PREVIEW_STEPS.map((s, i) => (
            <li
              key={s.title}
              className="ax-lift flex items-start gap-3 rounded-2xl border border-border bg-background/40 p-ax-4"
            >
              <span className="ax-label flex size-8 shrink-0 items-center justify-center rounded-xl border border-border bg-secondary text-steel">
                <s.icon className="size-4" aria-hidden="true" />
              </span>
              <div className="min-w-0">
                <p className="ax-label">
                  <span className="mr-1.5 text-muted-foreground">{i + 1}.</span>
                  {t(s.title)}
                </p>
                <p className="ax-caption mt-1">{t(s.body)}</p>
              </div>
            </li>
          ))}
        </ol>
      </div>
    </section>
  );
}

function DomainRow({
  d,
  onSetup,
  onAddAddress,
  onRemove,
}: {
  d: OrgDomain;
  onSetup: () => void;
  onAddAddress: () => void;
  onRemove: () => void;
}) {
  const { t } = useLocale();
  const verified = d.status === "verified";
  const done = d.records.filter((r) => r.ok).length;
  return (
    <li className={cn("ax-plane rounded-2xl p-ax-4", verified && "border-success/30")}>
      <div className="flex flex-wrap items-center gap-3">
        <Globe aria-hidden="true" className="size-4 text-steel" />
        <p className="ax-heading min-w-0 truncate">{d.domain}</p>
        <Chip tone={verified ? "good" : "warn"}>
          {verified ? t("Verified") : `${t("Needs DNS")} · ${done}/5`}
        </Chip>
        <div className="ml-auto flex flex-wrap items-center gap-2">
          {verified ? (
            <Button type="button" size="sm" className="ax-press gap-1.5" onClick={onAddAddress}>
              <Plus className="size-3.5" aria-hidden="true" />
              {t("Add address")}
            </Button>
          ) : (
            <Button type="button" size="sm" className="ax-press gap-1.5" onClick={onSetup}>
              {t("Continue setup")}
              <ArrowRight className="size-3.5" aria-hidden="true" />
            </Button>
          )}
          <Button
            type="button"
            size="sm"
            variant="ghost"
            className="ax-press text-muted-foreground hover:text-danger"
            onClick={onRemove}
            aria-label={`Remove ${d.domain}`}
          >
            <Trash2 className="size-4" aria-hidden="true" />
          </Button>
        </div>
      </div>
      <div className="mt-3 flex gap-1" aria-hidden="true">
        {d.records.map((r) => (
          <span
            key={r.key}
            className={cn(
              "h-1 flex-1 rounded-full transition-colors duration-500",
              r.ok ? "bg-success" : "bg-border",
            )}
          />
        ))}
      </div>
      <ul className="mt-3 flex flex-wrap gap-x-4 gap-y-1" aria-label="DNS checks">
        {d.records.map((r) => (
          <li key={r.key} className="ax-caption flex items-center gap-1.5">
            {r.ok ? (
              <CheckCircle2 className="size-3.5 text-success" aria-hidden="true" />
            ) : (
              <Circle className="size-3.5" aria-hidden="true" />
            )}
            <span className={r.ok ? "font-semibold text-foreground" : ""}>
              {CHECK_LABEL[r.key].title}
            </span>
            <span className="sr-only">{r.ok ? "found" : "not found yet"}</span>
          </li>
        ))}
      </ul>
    </li>
  );
}

/* -------------------------------- addresses ------------------------------- */

const KINDS: { id: AddressKind; title: string; body: string }[] = [
  { id: "mailbox", title: "Mailbox", body: "One person, one private inbox." },
  { id: "shared", title: "Shared", body: "sales@, support@ — a team inbox." },
  { id: "alias", title: "Alias", body: "Delivers to an existing address. No extra seat." },
];

/** Domain verify hone se pehle addresses ki jhalak: kya milega, abhi band kyun hai. */
function AddressesLocked() {
  const { t } = useLocale();
  return (
    <div className="ax-plane rounded-2xl p-ax-5">
      <div className="flex items-start gap-3">
        <span className="flex size-9 shrink-0 items-center justify-center rounded-xl border border-border bg-secondary text-steel">
          <Lock className="size-4" aria-hidden="true" />
        </span>
        <div className="min-w-0">
          <p className="ax-label">{t("Addresses unlock once your domain is verified")}</p>
          <p className="ax-caption mt-1">
            {t("Then create sales@, support@ or alex@yourcompany.com — mailboxes, shared inboxes and free aliases.")}
          </p>
        </div>
      </div>
      <ul className="mt-4 grid gap-2 opacity-70 sm:grid-cols-3" aria-hidden="true">
        {KINDS.map((k) => (
          <li key={k.id} className="rounded-xl border border-dashed border-border p-3">
            <span className="ax-label block">{t(k.title)}</span>
            <span className="ax-caption mt-0.5 block">{t(k.body)}</span>
          </li>
        ))}
      </ul>
    </div>
  );
}

function AddressForm({
  domains,
  preferredDomainId,
  disabledReason,
}: {
  domains: OrgDomain[];
  preferredDomainId: string | null;
  disabledReason: string | null;
}) {
  const { t } = useLocale();
  const create = useCreateAddress();
  const verified = useMemo(() => domains.filter((d) => d.status === "verified"), [domains]);
  const [domainId, setDomainId] = useState<string>(preferredDomainId ?? verified[0]?.id ?? "");
  const [local, setLocal] = useState("");
  const [kind, setKind] = useState<AddressKind>("mailbox");
  const [target, setTarget] = useState("");
  const [problem, setProblem] = useState<string | null>(null);

  useEffect(() => {
    if (preferredDomainId) setDomainId(preferredDomainId);
  }, [preferredDomainId]);
  useEffect(() => {
    if (!verified.some((d) => d.id === domainId)) setDomainId(verified[0]?.id ?? "");
  }, [verified, domainId]);

  if (verified.length === 0) return <AddressesLocked />;

  const dom = verified.find((d) => d.id === domainId);
  const blocked = Boolean(disabledReason) && kind !== "alias";

  const submit = () => {
    setProblem(null);
    create.mutate(
      {
        domain_id: domainId,
        local_part: local.trim().toLowerCase(),
        kind,
        ...(kind === "alias" ? { alias_target: target.trim() } : {}),
      },
      {
        onSuccess: (r) => {
          if (!r.ok) {
            setProblem(domainErrorText(r.error, { plan: planLabel(r.plan), limit: r.limit ?? null }));
            return;
          }
          notify.done(`${r.address?.address ?? local} is ready`);
          setLocal("");
          setTarget("");
        },
        onError: (e) => setProblem(errText(e)),
      },
    );
  };

  return (
    <form
      id="ax-address-form"
      className="ax-plane scroll-mt-6 rounded-2xl p-ax-4"
      onSubmit={(e) => {
        e.preventDefault();
        if (local.trim() && !blocked) submit();
      }}
    >
      <fieldset>
        <legend className="ax-caption">{t("Type")}</legend>
        <div className="mt-2 grid gap-2 sm:grid-cols-3" role="radiogroup" aria-label="Address type">
          {KINDS.map((k) => (
            <button
              key={k.id}
              type="button"
              role="radio"
              aria-checked={kind === k.id}
              onClick={() => setKind(k.id)}
              className={cn(
                "ax-focus ax-press rounded-xl border p-3 text-left transition-colors",
                kind === k.id
                  ? "border-[var(--cyan-accent)] bg-[var(--cyan-accent)]/10"
                  : "border-border hover:border-[var(--cyan-accent)]/40",
              )}
            >
              <span className="ax-label block">{t(k.title)}</span>
              <span className="ax-caption mt-0.5 block">{t(k.body)}</span>
            </button>
          ))}
        </div>
      </fieldset>

      <div className="mt-4 grid gap-3 md:grid-cols-[minmax(0,1fr)_auto_minmax(0,1fr)] md:items-end">
        <div>
          <label className="ax-caption" htmlFor="ax-address-local">
            {t("Address")}
          </label>
          <Input
            id="ax-address-local"
            value={local}
            onChange={(e) => setLocal(e.target.value)}
            placeholder={kind === "shared" ? "sales" : kind === "alias" ? "info" : "alex"}
            autoComplete="off"
            autoCapitalize="off"
            spellCheck={false}
            className="mt-1"
          />
        </div>
        <span className="ax-heading hidden pb-2 text-muted-foreground md:block" aria-hidden="true">@</span>
        <div>
          <label className="ax-caption" htmlFor="ax-address-domain">
            {t("Domain")}
          </label>
          <select
            id="ax-address-domain"
            value={domainId}
            onChange={(e) => setDomainId(e.target.value)}
            className="ax-focus mt-1 h-9 w-full rounded-md border border-input bg-transparent px-3 text-sm text-foreground"
          >
            {verified.map((d) => (
              <option key={d.id} value={d.id}>
                @{d.domain}
              </option>
            ))}
          </select>
        </div>
      </div>

      {kind === "alias" && (
        <div className="mt-3">
          <label className="ax-caption" htmlFor="ax-address-target">
            {t("Deliver to")}
          </label>
          <Input
            id="ax-address-target"
            value={target}
            onChange={(e) => setTarget(e.target.value)}
            placeholder={dom ? `alex@${dom.domain}` : "alex@company.com"}
            type="email"
            autoComplete="off"
            className="mt-1"
          />
        </div>
      )}

      {blocked && disabledReason && <p className="ax-caption mt-3 text-warning">{disabledReason}</p>}
      {problem && <p role="alert" className="ax-shake ax-label mt-3 text-danger">{problem}</p>}

      <div className="mt-4">
        <Button
          type="submit"
          className="ax-press ax-tap gap-1.5"
          disabled={create.isPending || !local.trim() || blocked || (kind === "alias" && !target.trim())}
        >
          {create.isPending ? (
            <BrandSpinner className="size-4" aria-hidden="true" />
          ) : (
            <Plus className="size-4" aria-hidden="true" />
          )}
          {t("Create address")}
        </Button>
      </div>
    </form>
  );
}

function AddressRow({ a, onRemove }: { a: OrgAddress; onRemove: () => void }) {
  const { t } = useLocale();
  return (
    <li className="ax-plane flex flex-wrap items-center gap-3 rounded-2xl p-ax-4">
      <p className="ax-label min-w-0 truncate">{a.address}</p>
      <Chip>{t(KINDS.find((k) => k.id === a.kind)?.title ?? a.kind)}</Chip>
      {a.kind === "alias" && a.alias_target && <span className="ax-caption">→ {a.alias_target}</span>}
      {!a.active && <Chip tone="warn">{t("Inactive")}</Chip>}
      <Button
        type="button"
        size="sm"
        variant="ghost"
        className="ax-press ml-auto text-muted-foreground hover:text-danger"
        onClick={onRemove}
        aria-label={`Remove ${a.address}`}
      >
        <Trash2 className="size-4" aria-hidden="true" />
      </Button>
    </li>
  );
}

/* --------------------------- 8f: pehli mail ka test --------------------------- */

/**
 * Verified domain + pehla address ban gaya? Ab "bas bhejo": From = naya address, To = aap ka apna login address
 * (poora raasta ek hi baar mein: bhejna -> DKIM -> Postfix -> wapas inbox mein aana). Zoho/Google yahan user ko
 * admin console par khali chhor dete hain. Koi nakli "sent" nahi — asli Compose, asli send; mail jaye tabhi card badalta hai.
 */
function FirstMailCard({
  address,
  to,
  sent,
  onWrite,
}: {
  address: string;
  to: string | null;
  sent: boolean;
  onWrite: () => void;
}) {
  const { t } = useLocale();
  return (
    <section
      className={cn(
        "ax-plane ax-in relative rounded-2xl p-ax-4",
        sent && "border border-success/40",
      )}
      aria-label={t("Send your first email")}
    >
      <div className="flex flex-wrap items-center gap-3">
        <span
          className={cn(
            "grid size-10 shrink-0 place-items-center rounded-xl border",
            sent ? "border-success/40 bg-success/10 text-success" : "border-border bg-secondary text-steel",
          )}
        >
          {sent ? <CheckCircle2 className="size-5" aria-hidden="true" /> : <Send className="size-5" aria-hidden="true" />}
        </span>
        <div className="min-w-[12rem] flex-1">
          <p className="ax-eyebrow">{sent ? t("Sent") : t("Try it now")}</p>
          <h4 className="ax-heading mt-1 [overflow-wrap:anywhere]">
            {sent ? t("Your first email is on its way") : t("Send your first email")}
          </h4>
          <p className="ax-caption mt-0.5 [overflow-wrap:anywhere]">
            {sent
              ? `${t("It leaves from")} ${address}${to ? ` ${t("and should land in")} ${to} ${t("within a minute — it is held for 30 seconds so you can still undo.")}` : "."}`
              : `${t("From")} ${address}${to ? ` ${t("to")} ${to}` : ""}. ${t("We fill it in — press Send and watch it arrive.")}`}
          </p>
        </div>
        {sent ? (
          <Button asChild variant="outline" size="sm" className="ax-press ax-tap w-full gap-1.5 sm:w-auto">
            <Link to="/app/mail">
              {t("Open your inbox")}
              <ArrowRight className="size-3.5" aria-hidden="true" />
            </Link>
          </Button>
        ) : (
          <Button type="button" variant="seal" className="ax-press ax-tap w-full gap-1.5 sm:w-auto" onClick={onWrite}>
            <Send className="size-4" aria-hidden="true" />
            {t("Write the test email")}
          </Button>
        )}
      </div>
    </section>
  );
}

/* ---------------------------------- page ---------------------------------- */

function DomainsPage() {
  const { t } = useLocale();
  const domainsQ = useDomains();
  const addressesQ = useAddresses();
  const summaryQ = useSummary(true);
  const analyticsQ = useAnalytics(true);
  const removeDomain = useRemoveDomain();
  const removeAddress = useRemoveAddress();
  const [wizard, setWizard] = useState<WizardState | null>(null);
  const [focusDomain, setFocusDomain] = useState<string | null>(null);
  const [testMail, setTestMail] = useState<"idle" | "composing" | "sent">("idle");
  const [confirm, setConfirm] = useState<
    { kind: "domain"; d: OrgDomain } | { kind: "address"; a: OrgAddress } | null
  >(null);

  const data = domainsQ.data;
  const addr = addressesQ.data;
  const domains = data?.domains ?? [];
  const cap = data?.domain_cap ?? null;
  const atCap = cap != null && domains.length >= cap;
  const capLabel = `${planLabel(data?.plan)} ${t("includes")} ${cap ?? 0} ${cap === 1 ? t("domain") : t("domains")} ${t("— all in use. To add another, upgrade or remove one.")}`;

  // Signup par jo company domain diya tha (dashboard par "Finish setup" wohi dikhata hai) —
  // yahan bhi wohi dikhe, taake dono jagah ek hi kahani ho.
  const sum = summaryQ.data;
  const suggestion =
    domains.length === 0 &&
    sum &&
    sum.domain_hosted === false &&
    sum.domain &&
    sum.domain_status !== "verified"
      ? sum.domain
      : null;

  const mailboxFull =
    addr != null && addr.mailbox_cap != null && addr.mailbox_used >= addr.mailbox_cap;
  const mailboxReason = mailboxFull
    ? `${t("Your")} ${planLabel(addr?.plan)} ${t("package allows")} ${addr?.mailbox_cap} ${t("mailboxes. Aliases don't count — or upgrade.")}`
    : null;

  // 8f: pehla asli company address (verified domain par, alias nahi) — usi se test mail.
  const firstAddress = useMemo(() => {
    const ok = new Set(domains.filter((d) => d.status === "verified").map((d) => d.id));
    return (addr?.addresses ?? []).find((a) => a.active && a.kind !== "alias" && ok.has(a.domain_id)) ?? null;
  }, [domains, addr]);

  const goAddress = useCallback((id: string | null) => {
    setFocusDomain(id);
    setWizard(null);
    window.setTimeout(() => {
      document
        .getElementById("ax-address-form")
        ?.scrollIntoView({ behavior: reducedMotion() ? "auto" : "smooth", block: "center" });
      document.getElementById("ax-address-local")?.focus({ preventScroll: true });
    }, 60);
  }, []);

  if (domainsQ.isLoading) return <PageSkeleton />;

  if (domainsQ.isError || !data) {
    return (
      <PageScroll>
        <ErrorState
          title={t("Domains didn't load")}
          body={t("The service didn't answer, so nothing is shown rather than something wrong.")}
          onRetry={() => void domainsQ.refetch()}
        />
      </PageScroll>
    );
  }

  const confirmText =
    confirm?.kind === "domain"
      ? {
          title: `Remove ${confirm.d.domain}?`,
          body: "Its addresses stop receiving mail through ANEXOMAIL. Your DNS records at the registrar are not touched.",
        }
      : confirm?.kind === "address"
        ? {
            title: `Remove ${confirm.a.address}?`,
            body: "This address stops working. Mail already received stays where it is.",
          }
        : null;

  const showHero = domains.length === 0 && !wizard;
  const capNote = `${planLabel(data.plan)} · ${cap == null ? t("unlimited domains") : `${t("up to")} ${cap} ${cap === 1 ? t("domain") : t("domains")}`}${
    addr
      ? ` · ${addr.mailbox_cap == null ? t("unlimited mailboxes") : `${addr.mailbox_cap} ${t("mailboxes")}`} · ${t("aliases are free")}`
      : ""
  }`;

  return (
    <PageScroll>
      <header className="ax-in">
        <p className="ax-eyebrow">{t("Company email")}</p>
        <h2 className="ax-title mt-3">{t("Domains & addresses")}</h2>
        <p className="ax-body mt-4 max-w-2xl">
          {t("Send and receive as you@yourcompany.com. Connect your domain once, then create as many addresses as your package includes.")}
        </p>
      </header>

      <section aria-labelledby="ax-domains-h" className="space-y-ax-3">
        <div className="flex flex-wrap items-center gap-3">
          <h3 id="ax-domains-h" className="ax-heading">
            {t("Domains")}
          </h3>
          <span className="ax-caption">
            {capText(domains.length, cap, (cap ?? domains.length) === 1 ? "domain" : "domains")} ·{" "}
            {planLabel(data.plan)}
          </span>
          {!wizard && !showHero && (
            <Button
              type="button"
              size="sm"
              className="ax-press ml-auto gap-1.5"
              disabled={atCap}
              onClick={() => setWizard({ step: 1, domainId: null })}
            >
              <Plus className="size-3.5" aria-hidden="true" />
              {t("Connect a domain")}
            </Button>
          )}
        </div>
        {atCap && !wizard && <p className="ax-caption text-muted-foreground">{capLabel}</p>}

        {wizard && (
          <Wizard
            domains={domains}
            state={wizard}
            setState={setWizard}
            atCap={atCap}
            capLabel={capLabel}
            suggestion={suggestion}
            loginAddress={addr?.login_address ?? null}
            onClose={() => setWizard(null)}
            onDone={(d) => goAddress(d.id)}
          />
        )}

        {showHero ? (
          <EmptyHero
            suggestion={suggestion}
            capNote={capNote}
            onStart={(prefill) =>
              setWizard({ step: 1, domainId: null, ...(prefill ? { prefill } : {}) })
            }
          />
        ) : (
          <ul className="ax-stagger space-y-3">
            {domains
              .filter((d) => d.id !== wizard?.domainId)
              .map((d) => (
              <DomainRow
                key={d.id}
                d={d}
                onSetup={() => setWizard({ step: 2, domainId: d.id })}
                onAddAddress={() => goAddress(d.id)}
                onRemove={() => setConfirm({ kind: "domain", d })}
              />
            ))}
          </ul>
        )}
      </section>

      <section aria-labelledby="ax-addresses-h" className="space-y-ax-3">
        <div className="flex flex-wrap items-center gap-3">
          <h3 id="ax-addresses-h" className="ax-heading">
            {t("Addresses")}
          </h3>
          {addr && (
            <span className="ax-caption">
              {capText(addr.mailbox_used, addr.mailbox_cap, "mailboxes")} · {t("aliases are free")}
            </span>
          )}
        </div>

        {firstAddress && ((analyticsQ.data?.sent ?? 0) === 0 || testMail !== "idle") && (
          <FirstMailCard
            address={firstAddress.address}
            to={addr?.login_address ?? null}
            sent={testMail === "sent"}
            onWrite={() => setTestMail("composing")}
          />
        )}

        {/* Pehle woh jo abhi hai (login + company addresses), phir jo bana sakte hain. */}
        {addressesQ.isError ? (
          <ErrorState
            title={t("Addresses didn't load")}
            body={t("The list is hidden rather than guessed. Try again.")}
            onRetry={() => void addressesQ.refetch()}
          />
        ) : (
          <ul className="ax-stagger space-y-3">
            {addr?.login_address && (
              <li className="ax-plane flex flex-wrap items-center gap-3 rounded-2xl p-ax-4">
                <p className="ax-label min-w-0 truncate">{addr.login_address}</p>
                <Chip tone="good">{t("Your login")}</Chip>
                <span className="ax-caption">{t("Always yours — not counted above.")}</span>
              </li>
            )}
            {(addr?.addresses ?? []).map((a) => (
              <AddressRow key={a.id} a={a} onRemove={() => setConfirm({ kind: "address", a })} />
            ))}
            {addr && addr.addresses.length === 0 && (
              <li className="ax-caption px-1">{t("No company addresses yet.")}</li>
            )}
          </ul>
        )}

        <AddressForm domains={domains} preferredDomainId={focusDomain} disabledReason={mailboxReason} />
      </section>

      {testMail === "composing" && firstAddress && (
        <ComposeOverlay
          initialIdentity={firstAddress.address}
          initialTo={addr?.login_address ?? ""}
          initialSubject="My first email from my own domain"
          initialBody={`Hello,\n\nThis is my first email from ${firstAddress.address}. If you can read it, my company email works.\n`}
          onSent={() => setTestMail("sent")}
          onClose={() => setTestMail((m) => (m === "sent" ? "sent" : "idle"))}
        />
      )}

      <AlertDialog open={Boolean(confirm)} onOpenChange={(o) => !o && setConfirm(null)}>
        <AlertDialogContent>
          <AlertDialogHeader>
            <AlertDialogTitle>{confirmText?.title}</AlertDialogTitle>
            <AlertDialogDescription>{confirmText?.body}</AlertDialogDescription>
          </AlertDialogHeader>
          <AlertDialogFooter>
            <AlertDialogCancel>{t("Keep it")}</AlertDialogCancel>
            <AlertDialogAction
              onClick={() => {
                const c = confirm;
                setConfirm(null);
                if (!c) return;
                if (c.kind === "domain") {
                  removeDomain.mutate(c.d.id, {
                    onSuccess: () => {
                      if (wizard?.domainId === c.d.id) setWizard(null);
                      notify.done(`${c.d.domain} removed`);
                    },
                    onError: (e) => notify.failed("Couldn't remove the domain", { description: errText(e) }),
                  });
                } else {
                  removeAddress.mutate(c.a.id, {
                    onSuccess: () => notify.done(`${c.a.address} removed`),
                    onError: (e) => notify.failed("Couldn't remove the address", { description: errText(e) }),
                  });
                }
              }}
            >
              {t("Remove")}
            </AlertDialogAction>
          </AlertDialogFooter>
        </AlertDialogContent>
      </AlertDialog>
    </PageScroll>
  );
}
