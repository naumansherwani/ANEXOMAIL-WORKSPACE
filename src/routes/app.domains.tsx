import { createFileRoute } from "@tanstack/react-router";
import {
  ArrowRight,
  AtSign,
  CheckCircle2,
  Circle,
  Clock,
  Copy,
  Globe,
  Loader2,
  Lock,
  Mail,
  Plus,
  RefreshCw,
  ShieldCheck,
  Trash2,
  X,
} from "lucide-react";
import { useCallback, useEffect, useMemo, useRef, useState, type ReactNode } from "react";

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
import { useSummary } from "@/lib/dashboard";
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

/** Verify poll: har 20s, zyada se zyada 30 baar (~10 min). Uske baad haath se "Check now". */
const POLL_MS = 20_000;
const POLL_MAX = 30;

const CHECK_LABEL: Record<DnsRecordKey, { title: string; why: string }> = {
  txt: { title: "Ownership", why: "Proves the domain is yours." },
  mx: { title: "Mail delivery (MX)", why: "Sends incoming mail to ANEXOMAIL." },
  spf: { title: "Sender policy (SPF)", why: "Lets ANEXOMAIL send as your domain." },
  dkim: { title: "Signature (DKIM)", why: "Signs every message so it lands in the inbox." },
  dmarc: { title: "Policy (DMARC)", why: "Tells receivers how to treat your mail." },
};

const REGISTRARS: { id: string; name: string; steps: string[] }[] = [
  {
    id: "namecheap",
    name: "Namecheap",
    steps: [
      "Domain List → Manage → Advanced DNS.",
      "Press Add New Record and pick the type shown below.",
      "Host = the Name column. Use @ for the root domain.",
    ],
  },
  {
    id: "godaddy",
    name: "GoDaddy",
    steps: [
      "My Products → your domain → DNS.",
      "Press Add New Record and pick the type shown below.",
      "Name = the Name column. Use @ for the root domain.",
    ],
  },
  {
    id: "cloudflare",
    name: "Cloudflare",
    steps: [
      "Select the domain → DNS → Records → Add record.",
      "Pick the type shown below and paste Name and Value.",
      "Leave proxy off (DNS only). MX and TXT are never proxied.",
    ],
  },
  {
    id: "other",
    name: "Other",
    steps: [
      "Open the DNS settings of your registrar or host.",
      "Add one record per row below. Name goes in Host/Name, Value in Value/Content.",
      "Enter only the Name — the registrar adds your domain automatically.",
    ],
  },
];

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
  return typeof window !== "undefined" && window.matchMedia?.("(prefers-reduced-motion: reduce)").matches === true;
}

/**
 * Page ka scroll dabba. AppShell `h-screen overflow-hidden` hai — bina is wrapper ke
 * neeche ka hissa kat jata hai aur wizard ke 5 records tak pohanchna mumkin nahi
 * (founder ne 17 Oct 2026 ko pakda). Baqi pages (`app.org`, `app.safety`) wahi dabba lagate hain.
 */
function PageScroll({ children }: { children: ReactNode }) {
  return (
    <div className="min-h-0 min-w-0 flex-1 overflow-y-auto">
      <div className="mx-auto w-full max-w-4xl space-y-ax-8 px-5 pb-28 pt-8 sm:px-6 md:px-10 md:pt-12">
        {children}
      </div>
    </div>
  );
}

/* ------------------------------ small pieces ------------------------------ */

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
    try {
      await navigator.clipboard.writeText(value);
    } catch {
      // Clipboard API band ho (http / permission): purana tareeqa.
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
        if (!ok) throw new Error("copy_failed");
      } catch {
        notify.failed("Couldn't copy", { description: "Select the text and copy it by hand." });
        return;
      }
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

function Tick({ ok, pending }: { ok: boolean; pending?: boolean }) {
  if (ok) {
    return (
      <span className="inline-flex items-center gap-1 text-xs font-semibold text-success">
        <CheckCircle2 className="size-4 animate-in zoom-in-50 duration-300" aria-hidden="true" />
        Found
      </span>
    );
  }
  return (
    <span className="inline-flex items-center gap-1 text-xs font-semibold text-muted-foreground">
      <Circle className="size-4" aria-hidden="true" />
      {pending ? "Key is being prepared" : "Not found yet"}
    </span>
  );
}

function Field({ label, value, mono = true }: { label: string; value: string; mono?: boolean }) {
  return (
    <div className="min-w-0">
      <p className="ax-caption text-muted-foreground">{label}</p>
      <div className="mt-1 flex items-center gap-2">
        <code
          className={cn(
            "min-w-0 flex-1 break-all rounded-lg border border-border bg-secondary/60 px-2.5 py-1.5 text-xs text-foreground",
            !mono && "font-sans",
          )}
        >
          {value}
        </code>
        <CopyButton value={value} label={label} />
      </div>
    </div>
  );
}

function RecordCard({ rec, n, of }: { rec: DnsRecord; n: number; of: number }) {
  const meta = CHECK_LABEL[rec.key];
  return (
    <li
      className={cn(
        "ax-plane rounded-2xl p-ax-4 transition-colors duration-500",
        rec.ok && "border-success/40",
      )}
    >
      <div className="flex flex-wrap items-center gap-2">
        <span className="flex size-6 items-center justify-center rounded-full border border-border bg-secondary text-xs font-bold text-foreground">
          {n}
        </span>
        <p className="text-sm font-bold text-foreground">{meta.title}</p>
        <Chip>{rec.type}</Chip>
        <span className="ax-caption text-muted-foreground">
          {n} / {of}
        </span>
        <span className="ml-auto">
          <Tick ok={rec.ok} {...(rec.pending ? { pending: true } : {})} />
        </span>
      </div>
      <p className="ax-caption mt-1 text-muted-foreground">{meta.why}</p>
      <div className="mt-3 grid gap-3 md:grid-cols-[minmax(0,1fr)_minmax(0,2fr)]">
        <Field label="Name / Host" value={rec.name} />
        {rec.value ? (
          <Field label="Value" value={rec.value} />
        ) : (
          <div className="flex items-center gap-2 rounded-lg border border-dashed border-border px-3 py-2">
            <Loader2 className="size-4 shrink-0 animate-spin text-muted-foreground" aria-hidden="true" />
            <p className="ax-caption text-muted-foreground">
              Your signing key is being generated — this row fills in by itself, usually within a minute.
            </p>
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
function StepRail({ step }: { step: 1 | 2 | 3 }) {
  const { t } = useLocale();
  const steps = [t("Your domain"), t("Add DNS records"), t("We check")];
  const fill = ((step - 1) / 2) * 100;
  return (
    <ol className="relative grid grid-cols-3 gap-2" aria-label="Setup steps">
      <span aria-hidden="true" className="absolute inset-x-[16.667%] top-3 h-px bg-border">
        <span
          className="block h-full bg-primary motion-safe:transition-[width] motion-safe:duration-700"
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
                "flex size-6 items-center justify-center rounded-full border text-xs font-bold transition-colors duration-500",
                state === "done" && "border-success/50 bg-card text-success",
                state === "now" && "border-primary bg-primary text-primary-foreground",
                state === "next" && "border-border bg-card text-muted-foreground",
              )}
            >
              {state === "done" ? <CheckCircle2 className="size-3.5" aria-hidden="true" /> : n}
            </span>
            <span
              className={cn(
                "text-xs font-semibold",
                state === "next" ? "text-muted-foreground" : "text-foreground",
              )}
            >
              {label}
            </span>
          </li>
        );
      })}
    </ol>
  );
}

/** x/5 records mile — chhota gola, bharta hua. */
function Ring({ done, total }: { done: number; total: number }) {
  const r = 26;
  const c = 2 * Math.PI * r;
  const off = c * (1 - (total > 0 ? done / total : 0));
  const full = total > 0 && done === total;
  return (
    <div className="relative size-16 shrink-0" role="img" aria-label={`${done} of ${total} records found`}>
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
            full ? "stroke-success" : "stroke-primary",
            "motion-safe:transition-[stroke-dashoffset] motion-safe:duration-700",
          )}
        />
      </svg>
      <span className="absolute inset-0 grid place-items-center text-sm font-bold text-foreground">
        {done}/{total}
      </span>
    </div>
  );
}

/* --------------------------------- wizard --------------------------------- */

type WizardState = { step: 1 | 2 | 3; domainId: string | null; prefill?: string };

function Wizard({
  domains,
  state,
  setState,
  atCap,
  capLabel,
  suggestion,
  onClose,
  onDone,
}: {
  domains: OrgDomain[];
  state: WizardState;
  setState: (s: WizardState) => void;
  atCap: boolean;
  capLabel: string;
  suggestion: string | null;
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
  const [registrar, setRegistrar] = useState("namecheap");
  const [polls, setPolls] = useState(0);
  const [nextIn, setNextIn] = useState(POLL_MS / 1000);
  const pollsRef = useRef(0);
  const domain = useMemo(
    () => domains.find((d) => d.id === state.domainId) ?? null,
    [domains, state.domainId],
  );
  const verifyRef = useRef(verify);
  verifyRef.current = verify;

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
    add.mutate(name, {
      onSuccess: (r) => {
        if (!r.ok || !r.domain) {
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

  return (
    <section
      ref={rootRef}
      className="ax-plane ax-in scroll-mt-6 rounded-3xl p-ax-5 md:p-ax-6"
      aria-label="Connect a domain"
    >
      <div className="flex items-start gap-3">
        <div className="min-w-0 flex-1">
          <StepRail step={state.step} />
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
        <div className="ax-in mt-ax-6">
          <h3 className="text-2xl font-bold text-foreground">{t("Which domain should mail use?")}</h3>
          <p className="mt-2 max-w-xl text-sm leading-relaxed text-muted-foreground">
            {t("The one you own, like company.com. You will add five DNS records next — nothing changes until you do.")}
          </p>
          <form
            className="mt-5 flex max-w-xl flex-col gap-2 sm:flex-row"
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
              size="lg"
              className="ax-press ax-tap gap-1.5"
              disabled={atCap || add.isPending || !name.trim()}
            >
              {add.isPending ? (
                <Loader2 className="size-4 animate-spin" aria-hidden="true" />
              ) : null}
              {t("Continue")}
              {!add.isPending && <ArrowRight className="size-4" aria-hidden="true" />}
            </Button>
          </form>
          {suggestion && !name.trim() && !atCap && (
            <button
              type="button"
              onClick={() => setName(suggestion)}
              className="ax-focus ax-press mt-3 inline-flex items-center gap-2 rounded-full border border-border bg-secondary/50 px-3 py-1.5 text-xs font-semibold text-foreground transition-colors hover:border-primary/50"
            >
              <Globe className="size-3.5 text-steel" aria-hidden="true" />
              {t("Use")} {suggestion}
              <span className="font-normal text-muted-foreground">· {t("from your signup")}</span>
            </button>
          )}
          {problem && <p className="mt-3 text-sm text-danger">{problem}</p>}
          {atCap && <p className="ax-caption mt-3 text-warning">{capLabel}</p>}
        </div>
      )}

      {state.step === 2 && domain && (
        <div className="ax-in mt-ax-6">
          <h3 className="text-2xl font-bold text-foreground">
            {t("Add these records at your registrar")}
          </h3>
          <p className="mt-2 max-w-2xl text-sm leading-relaxed text-muted-foreground">
            {t("Copy each Name and Value into the DNS settings for")}{" "}
            <strong className="text-foreground">{domain.domain}</strong>.{" "}
            {t("Enter only the Name — your registrar adds the domain itself.")}
          </p>

          <div className="mt-5 rounded-2xl border border-border bg-secondary/30 p-ax-4">
            <div className="flex flex-wrap gap-2" role="tablist" aria-label="Registrar">
              {REGISTRARS.map((r) => (
                <button
                  key={r.id}
                  type="button"
                  role="tab"
                  aria-selected={registrar === r.id}
                  onClick={() => setRegistrar(r.id)}
                  className={cn(
                    "ax-focus ax-press rounded-full border px-3 py-1 text-xs font-semibold transition-colors",
                    registrar === r.id
                      ? "border-primary bg-primary/10 text-foreground"
                      : "border-border text-muted-foreground hover:text-foreground",
                  )}
                >
                  {r.name}
                </button>
              ))}
            </div>
            <ol className="mt-3 list-decimal space-y-1 pl-5 text-sm text-muted-foreground">
              {(REGISTRARS.find((r) => r.id === registrar) ?? REGISTRARS[3]!).steps.map((s) => (
                <li key={s}>{s}</li>
              ))}
            </ol>
          </div>

          <ul className="mt-4 space-y-3">
            {domain.records.map((rec, i) => (
              <RecordCard key={rec.key} rec={rec} n={i + 1} of={domain.records.length} />
            ))}
          </ul>

          <div className="mt-6 flex flex-wrap items-center gap-2">
            <Button
              type="button"
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
        <div className="ax-in mt-ax-6" role="status" aria-live="polite">
          <div className="flex items-center gap-4">
            <Ring done={found} total={total} />
            <div className="min-w-0">
              <h3 className="text-2xl font-bold text-foreground">
                {domain.status === "verified"
                  ? `${domain.domain} ${t("is verified")}`
                  : `${t("Checking")} ${domain.domain}`}
              </h3>
              <p className="mt-1 max-w-2xl text-sm leading-relaxed text-muted-foreground">
                {domain.status === "verified"
                  ? t("All five records are live. You can create addresses on this domain now.")
                  : t("Each tick turns green the moment its record is found. DNS can take a few minutes — you can leave this page open.")}
              </p>
            </div>
          </div>

          <ul className="mt-5 grid gap-2 sm:grid-cols-2">
            {domain.records.map((rec) => (
              <li
                key={rec.key}
                className={cn(
                  "flex items-center gap-3 rounded-2xl border p-3 transition-colors duration-500",
                  rec.ok ? "border-success/40 bg-success/5" : "border-border",
                )}
              >
                {rec.ok ? (
                  <CheckCircle2
                    className="size-5 shrink-0 text-success animate-in zoom-in-50 duration-300"
                    aria-hidden="true"
                  />
                ) : verify.isPending ? (
                  <Loader2 className="size-5 shrink-0 animate-spin text-muted-foreground" aria-hidden="true" />
                ) : (
                  <Circle className="size-5 shrink-0 text-muted-foreground motion-safe:animate-pulse" aria-hidden="true" />
                )}
                <div className="min-w-0 flex-1">
                  <p className="text-sm font-bold text-foreground">{CHECK_LABEL[rec.key].title}</p>
                  <p className="ax-caption truncate text-muted-foreground">
                    {rec.type} · {rec.name}
                  </p>
                </div>
                <span
                  className={cn(
                    "text-xs font-semibold",
                    rec.ok ? "text-success" : "text-muted-foreground",
                  )}
                >
                  {rec.ok ? t("Found") : rec.pending ? t("Key is being prepared") : t("Waiting")}
                </span>
              </li>
            ))}
          </ul>

          {problem && <p className="mt-3 text-sm text-danger">{problem}</p>}

          <div className="mt-6 flex flex-wrap items-center gap-2">
            {domain.status === "verified" ? (
              <Button type="button" size="lg" className="ax-press ax-tap gap-1.5" onClick={() => onDone(domain)}>
                {t("Create an address")}
                <ArrowRight className="size-4" aria-hidden="true" />
              </Button>
            ) : (
              <>
                <Button
                  type="button"
                  size="lg"
                  className="ax-press ax-tap gap-1.5"
                  disabled={verify.isPending}
                  onClick={() => check(true)}
                >
                  {verify.isPending ? (
                    <Loader2 className="size-4 animate-spin" aria-hidden="true" />
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
                <span className="ax-caption inline-flex items-center gap-1.5 text-muted-foreground">
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
    </section>
  );
}

/* -------------------------------- domains -------------------------------- */

const PREVIEW_STEPS: { icon: typeof Globe; title: string; body: string }[] = [
  { icon: Globe, title: "Name your domain", body: "Type the one you own, like company.com." },
  {
    icon: Copy,
    title: "Add five DNS records",
    body: "Copy each Name and Value. Hints for Namecheap, GoDaddy and Cloudflare.",
  },
  {
    icon: ShieldCheck,
    title: "Watch the ticks turn green",
    body: "We check live while you wait. DNS can take a few minutes.",
  },
];

/** Khali page ka pehla taassur: kya milega, kitna waqt lagega, ek bara button. */
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
  return (
    <section className="ax-plane relative rounded-3xl p-ax-6 md:p-ax-7" aria-label="Connect your first domain">
      <div
        aria-hidden="true"
        className="pointer-events-none absolute -right-24 -top-28 size-80 rounded-full bg-primary/15 blur-3xl"
      />
      <div className="relative grid gap-ax-7 md:grid-cols-[1.1fr_1fr] md:items-center">
        <div>
          <p className="ax-eyebrow">{t("Your name on every email")}</p>
          <h3 className="mt-3 text-3xl font-bold leading-tight text-foreground">
            {suggestion ? `${t("Finish connecting")} ${suggestion}` : t("Send as you@yourcompany.com")}
          </h3>
          <div className="mt-4 inline-flex items-center gap-2 rounded-full border border-border bg-secondary/60 px-3 py-1.5 text-sm">
            <Mail className="size-4 text-steel" aria-hidden="true" />
            <span className="font-semibold text-foreground">you</span>
            <span className="text-muted-foreground">@{suggestion ?? "yourcompany.com"}</span>
          </div>
          <p className="mt-4 max-w-md text-sm leading-relaxed text-muted-foreground">
            {suggestion
              ? t("This is the domain you gave when you signed up. Add the DNS records once and your team can send and receive on it.")
              : t("Until you connect one, your mail runs on your ANEXOMAIL address. Connecting takes about five minutes plus DNS time.")}
          </p>
          <div className="mt-6 flex flex-wrap items-center gap-3">
            <Button
              type="button"
              size="lg"
              className="ax-press ax-tap gap-2"
              onClick={() => onStart(suggestion ?? undefined)}
            >
              <Plus className="size-4" aria-hidden="true" />
              {suggestion ? `${t("Connect")} ${suggestion}` : t("Connect a domain")}
            </Button>
            {suggestion && (
              <Button type="button" variant="ghost" className="ax-press" onClick={() => onStart()}>
                {t("Use a different domain")}
              </Button>
            )}
          </div>
          <p className="ax-caption mt-4 text-muted-foreground">{capNote}</p>
        </div>

        <ol className="space-y-3" aria-label="How it works">
          {PREVIEW_STEPS.map((s, i) => (
            <li
              key={s.title}
              className="flex items-start gap-3 rounded-2xl border border-border bg-background/40 p-ax-4"
            >
              <span className="flex size-9 shrink-0 items-center justify-center rounded-xl border border-border bg-secondary text-steel">
                <s.icon className="size-4" aria-hidden="true" />
              </span>
              <div className="min-w-0">
                <p className="text-sm font-bold text-foreground">
                  <span className="mr-1.5 text-muted-foreground">{i + 1}.</span>
                  {t(s.title)}
                </p>
                <p className="ax-caption mt-0.5 text-muted-foreground">{t(s.body)}</p>
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
        <p className="min-w-0 truncate text-base font-bold text-foreground">{d.domain}</p>
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
            className="ax-press text-danger"
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
          <li key={r.key} className="flex items-center gap-1.5 text-xs text-muted-foreground">
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
          <p className="text-sm font-bold text-foreground">
            {t("Addresses unlock once your domain is verified")}
          </p>
          <p className="ax-caption mt-0.5 text-muted-foreground">
            {t("Then create sales@, support@ or alex@yourcompany.com — mailboxes, shared inboxes and free aliases.")}
          </p>
        </div>
      </div>
      <ul className="mt-4 grid gap-2 opacity-70 sm:grid-cols-3" aria-hidden="true">
        {KINDS.map((k) => (
          <li key={k.id} className="rounded-xl border border-dashed border-border p-3">
            <span className="block text-sm font-bold text-foreground">{t(k.title)}</span>
            <span className="ax-caption mt-0.5 block text-muted-foreground">{t(k.body)}</span>
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
        <legend className="ax-caption text-muted-foreground">{t("Type")}</legend>
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
                kind === k.id ? "border-primary bg-primary/10" : "border-border hover:border-primary/40",
              )}
            >
              <span className="block text-sm font-bold text-foreground">{t(k.title)}</span>
              <span className="ax-caption mt-0.5 block text-muted-foreground">{t(k.body)}</span>
            </button>
          ))}
        </div>
      </fieldset>

      <div className="mt-4 grid gap-3 md:grid-cols-[minmax(0,1fr)_auto_minmax(0,1fr)] md:items-end">
        <div>
          <label className="ax-caption text-muted-foreground" htmlFor="ax-address-local">
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
        <span className="hidden pb-2 text-sm font-bold text-muted-foreground md:block">@</span>
        <div>
          <label className="ax-caption text-muted-foreground" htmlFor="ax-address-domain">
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
          <label className="ax-caption text-muted-foreground" htmlFor="ax-address-target">
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
      {problem && <p className="mt-3 text-sm text-danger">{problem}</p>}

      <div className="mt-4">
        <Button
          type="submit"
          className="ax-press ax-tap gap-1.5"
          disabled={create.isPending || !local.trim() || blocked || (kind === "alias" && !target.trim())}
        >
          {create.isPending ? (
            <Loader2 className="size-4 animate-spin" aria-hidden="true" />
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
      <p className="min-w-0 truncate text-sm font-bold text-foreground">{a.address}</p>
      <Chip>{t(KINDS.find((k) => k.id === a.kind)?.title ?? a.kind)}</Chip>
      {a.kind === "alias" && a.alias_target && (
        <span className="ax-caption text-muted-foreground">→ {a.alias_target}</span>
      )}
      {!a.active && <Chip tone="warn">{t("Inactive")}</Chip>}
      <Button
        type="button"
        size="sm"
        variant="ghost"
        className="ax-press ml-auto text-danger"
        onClick={onRemove}
        aria-label={`Remove ${a.address}`}
      >
        <Trash2 className="size-4" aria-hidden="true" />
      </Button>
    </li>
  );
}

/* ---------------------------------- page ---------------------------------- */

function DomainsPage() {
  const { t } = useLocale();
  const domainsQ = useDomains();
  const addressesQ = useAddresses();
  const summaryQ = useSummary(true);
  const removeDomain = useRemoveDomain();
  const removeAddress = useRemoveAddress();
  const [wizard, setWizard] = useState<WizardState | null>(null);
  const [focusDomain, setFocusDomain] = useState<string | null>(null);
  const [confirm, setConfirm] = useState<
    { kind: "domain"; d: OrgDomain } | { kind: "address"; a: OrgAddress } | null
  >(null);

  const data = domainsQ.data;
  const addr = addressesQ.data;
  const domains = data?.domains ?? [];
  const cap = data?.domain_cap ?? null;
  const atCap = cap != null && domains.length >= cap;
  const capLabel = `${t("Your")} ${planLabel(data?.plan)} ${t("package allows")} ${cap ?? 0} ${t("domains. Remove one or upgrade.")}`;

  // Signup par jo company domain diya tha (dashboard par "Finish setup" wohi dikhata hai) —
  // yahan bhi wohi dikhe, taake dono jagah ek hi kahani ho.
  const sum = summaryQ.data;
  const suggestion =
    domains.length === 0 && sum && sum.domain_hosted === false && sum.domain && sum.domain_status !== "verified"
      ? sum.domain
      : null;

  const mailboxFull =
    addr != null && addr.mailbox_cap != null && addr.mailbox_used >= addr.mailbox_cap;
  const mailboxReason = mailboxFull
    ? `${t("Your")} ${planLabel(addr?.plan)} ${t("package allows")} ${addr?.mailbox_cap} ${t("mailboxes. Aliases don't count — or upgrade.")}`
    : null;

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

  if (domainsQ.isLoading) {
    return (
      <PageScroll>
        <p className="ax-caption text-muted-foreground" role="status">
          {t("Loading domains…")}
        </p>
      </PageScroll>
    );
  }

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
    addr ? ` · ${addr.mailbox_cap == null ? t("unlimited mailboxes") : `${addr.mailbox_cap} ${t("mailboxes")}`} · ${t("aliases are free")}` : ""
  }`;

  return (
    <PageScroll>
      <header>
        <p className="ax-eyebrow">{t("Company email")}</p>
        <h2 className="mt-3 text-3xl text-foreground">{t("Domains & addresses")}</h2>
        <p className="mt-4 max-w-2xl text-sm leading-relaxed text-muted-foreground">
          {t("Send and receive as you@yourcompany.com. Connect your domain once, then create as many addresses as your package includes.")}
        </p>
      </header>

      <section aria-labelledby="ax-domains-h" className="space-y-ax-3">
        <div className="flex flex-wrap items-center gap-3">
          <h3 id="ax-domains-h" className="ax-heading text-foreground">
            {t("Domains")}
          </h3>
          <span className="ax-caption text-muted-foreground">
            {capText(domains.length, cap, domains.length === 1 ? "domain" : "domains")} ·{" "}
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
        {atCap && !wizard && <p className="ax-caption text-warning">{capLabel}</p>}

        {wizard && (
          <Wizard
            domains={domains}
            state={wizard}
            setState={setWizard}
            atCap={atCap}
            capLabel={capLabel}
            suggestion={suggestion}
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
          <ul className="space-y-3">
            {domains.map((d) => (
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
          <h3 id="ax-addresses-h" className="ax-heading text-foreground">
            {t("Addresses")}
          </h3>
          {addr && (
            <span className="ax-caption text-muted-foreground">
              {capText(addr.mailbox_used, addr.mailbox_cap, "mailboxes")} · {t("aliases are free")}
            </span>
          )}
        </div>

        <AddressForm domains={domains} preferredDomainId={focusDomain} disabledReason={mailboxReason} />

        {addressesQ.isError ? (
          <ErrorState
            title={t("Addresses didn't load")}
            body={t("The list is hidden rather than guessed. Try again.")}
            onRetry={() => void addressesQ.refetch()}
          />
        ) : (
          <ul className="space-y-3">
            {addr?.login_address && (
              <li className="ax-plane flex flex-wrap items-center gap-3 rounded-2xl p-ax-4">
                <p className="min-w-0 truncate text-sm font-bold text-foreground">
                  {addr.login_address}
                </p>
                <Chip tone="good">{t("Your login")}</Chip>
                <span className="ax-caption text-muted-foreground">{t("Always yours — not counted above.")}</span>
              </li>
            )}
            {(addr?.addresses ?? []).map((a) => (
              <AddressRow key={a.id} a={a} onRemove={() => setConfirm({ kind: "address", a })} />
            ))}
            {addr && addr.addresses.length === 0 && (
              <li className="ax-caption px-1 text-muted-foreground">{t("No company addresses yet.")}</li>
            )}
          </ul>
        )}
      </section>

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
