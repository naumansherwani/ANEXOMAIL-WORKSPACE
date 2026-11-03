import { AlertTriangle, ChevronDown, Circle, ShieldAlert, ShieldCheck } from "lucide-react";
import { useState } from "react";

import { useAuth } from "@/lib/auth";
import { useExpiryWatch, type ExpiryItem, type ExpiryStatus } from "@/lib/expiry";
import { useLocale } from "@/lib/i18n";
import { cn } from "@/lib/utils";

/**
 * Founder-only "Expiry watch" (8o). Cert ki halat pehle sirf email mein aati thi; ab dashboard par bhi:
 * headline "Mail TLS: N days" + (kuch bhi expire hone wala / kharab ho to) poori list. Sab theek ho to chhoti, khamosh
 * patti. Data sirf server ki report se (`founder.expiry.watch`) — frontend kuch hisaab nahi karta. Founder na ho,
 * report na aaye ya Rust abhi build na ho => kuch nahi dikhta (galat dar nahi).
 */

const RANK: Record<ExpiryStatus, number> = { crit: 0, warn: 1, unknown: 2, ok: 3 };

function ago(secs: number | null): string {
  if (secs == null) return "—";
  const m = Math.round(secs / 60);
  if (m < 2) return "just now";
  if (m < 60) return `${m}m ago`;
  const h = Math.round(m / 60);
  if (h < 48) return `${h}h ago`;
  return `${Math.round(h / 24)}d ago`;
}

function daysText(n: number | null | undefined): string {
  if (n == null) return "";
  if (n < 0) return "expired";
  return `${n} ${n === 1 ? "day" : "days"}`;
}

function StatusIcon({ status, className }: { status: ExpiryStatus; className?: string }) {
  const c = cn("size-4 shrink-0", className);
  if (status === "ok") return <ShieldCheck className={cn(c, "text-success")} aria-hidden="true" />;
  if (status === "crit") return <ShieldAlert className={cn(c, "text-destructive")} aria-hidden="true" />;
  if (status === "warn") return <AlertTriangle className={cn(c, "text-warning")} aria-hidden="true" />;
  return <Circle className={cn(c, "text-muted-foreground")} aria-hidden="true" />;
}

const STATUS_WORD: Record<ExpiryStatus, string> = {
  ok: "OK",
  warn: "Warning",
  crit: "Critical",
  unknown: "Could not check",
};

function Row({ item }: { item: ExpiryItem }) {
  const { t } = useLocale();
  return (
    <li className="flex items-start gap-3 py-2.5">
      <span className="mt-0.5">
        <StatusIcon status={item.status} />
        <span className="sr-only">{t(STATUS_WORD[item.status])}</span>
      </span>
      <div className="min-w-0 flex-1">
        <p className="ax-label [overflow-wrap:anywhere]">
          {t(item.label)} <span className="font-normal text-muted-foreground">· {item.target}</span>
        </p>
        <p className="ax-caption mt-0.5 text-muted-foreground [overflow-wrap:anywhere]">{item.detail}</p>
      </div>
      {item.days_left != null && (
        <span
          className={cn(
            "ax-label shrink-0 rounded-full border px-2 py-0.5 tabular-nums",
            item.status === "crit" && "border-destructive/50 text-destructive",
            item.status === "warn" && "border-warning/50 text-warning",
            (item.status === "ok" || item.status === "unknown") && "border-border text-muted-foreground",
          )}
        >
          {item.days_left < 0 ? t("expired") : `${item.days_left}d`}
        </span>
      )}
    </li>
  );
}

export function ExpiryWatch({ enabled }: { enabled: boolean }) {
  const { t } = useLocale();
  const { session } = useAuth();
  const isFounder = Boolean(session?.user.is_founder);
  const q = useExpiryWatch(enabled && isFounder);
  const [openAll, setOpenAll] = useState(false);

  const r = q.data;
  if (!isFounder || !r) return null;

  if (!r.available) {
    return (
      <section className="ax-plane ax-in mt-ax-4 flex items-center gap-3 rounded-2xl p-ax-4" aria-label={t("Expiry watch")}>
        <StatusIcon status="unknown" />
        <p className="ax-caption text-muted-foreground">
          {t("Expiry watch has not reported yet. It runs twice a day once installed on the server.")}
        </p>
      </section>
    );
  }

  const items = [...r.items].sort((a, b) => RANK[a.status] - RANK[b.status]);
  const bad = items.filter((i) => i.status === "crit" || i.status === "warn");
  const unknown = items.filter((i) => i.status === "unknown");
  const okCount = items.filter((i) => i.status === "ok").length;
  // Ek hi "tone": monitor ruk gaya (stale) = warn; warna sab se bura item; sirf unknown = neutral; warna ok.
  const tone: ExpiryStatus = r.stale
    ? bad.some((i) => i.status === "crit")
      ? "crit"
      : "warn"
    : bad.some((i) => i.status === "crit")
      ? "crit"
      : bad.length > 0
        ? "warn"
        : unknown.length > 0
          ? "unknown"
          : "ok";
  const hd = r.headline;
  const hdDays = hd.days_left;

  const pill = r.stale
    ? t("Monitor stopped")
    : bad.length > 0
      ? `${bad.length} ${t("need attention")}`
      : unknown.length > 0
        ? `${unknown.length} ${t("could not be checked")}`
        : t("All clear");

  const shown = openAll ? items : [...bad, ...unknown];

  return (
    <section
      className={cn(
        "ax-plane ax-in mt-ax-4 rounded-2xl p-ax-4",
        tone === "crit" && "border-destructive/50",
        tone === "warn" && "border-warning/50",
      )}
      aria-label={t("Expiry watch")}
    >
      <div className="flex flex-wrap items-center gap-x-4 gap-y-2">
        <span
          aria-hidden="true"
          className={cn(
            "grid size-10 shrink-0 place-items-center rounded-xl",
            tone === "crit" && "bg-destructive/10",
            tone === "warn" && "bg-warning/10",
            tone === "unknown" && "bg-muted",
            tone === "ok" && "bg-success/10",
          )}
        >
          <StatusIcon status={tone} className="size-5" />
        </span>
        <div className="min-w-[10rem] flex-1">
          <p className="ax-eyebrow">{t("Expiry watch")}</p>
          <h3 className="ax-heading mt-0.5">
            {t(hd.label)}:{" "}
            <span
              className={cn(
                hd.status === "crit" && "text-destructive",
                hd.status === "warn" && "text-warning",
              )}
            >
              {hdDays == null ? t("not readable") : daysText(hdDays)}
            </span>
            {r.stale && <span className="ax-caption font-normal text-muted-foreground"> · {t("last known")}</span>}
          </h3>
          <p className="ax-caption mt-0.5 text-muted-foreground">
            {okCount}/{items.length} {t("checks fine")} · {t("checked")} {ago(r.age_secs)}
          </p>
        </div>
        <span
          className={cn(
            "ax-label rounded-full border px-2.5 py-1",
            tone === "crit" && "border-destructive/50 text-destructive",
            tone === "warn" && "border-warning/50 text-warning",
            tone === "unknown" && "border-border text-muted-foreground",
            tone === "ok" && "border-success/40 text-success",
          )}
        >
          {pill}
        </span>
      </div>

      {r.stale && (
        <p className="ax-caption mt-3 rounded-lg border border-warning/40 bg-warning/5 px-3 py-2 [overflow-wrap:anywhere]">
          {t("The monitor has not reported for over 36 hours — it may have stopped. On the server:")}{" "}
          <code className="rounded bg-secondary px-1 py-0.5 text-[11px]">systemctl status anexomail-expiry-watch.timer</code>
        </p>
      )}

      {shown.length > 0 && (
        <ul className="mt-3 divide-y divide-border border-t border-border">
          {shown.map((i) => (
            <Row key={i.id} item={i} />
          ))}
        </ul>
      )}

      <button
        type="button"
        onClick={() => setOpenAll((v) => !v)}
        aria-expanded={openAll}
        className="ax-press ax-tap mt-3 inline-flex items-center gap-1 text-xs font-semibold text-foreground underline-offset-4 hover:underline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-[var(--cyan-accent)]"
      >
        {openAll ? t("Hide details") : t("Show all checks")}
        <ChevronDown className={cn("size-4 transition-transform", openAll && "rotate-180")} aria-hidden="true" />
      </button>
    </section>
  );
}
