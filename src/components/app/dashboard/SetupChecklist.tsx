import { Link } from "@tanstack/react-router";
import { ArrowRight, CheckCircle2, MailPlus, X } from "lucide-react";
import { useEffect, useMemo, useState } from "react";

import { Button } from "@/components/ui/button";
import { useAnalytics } from "@/lib/dashboard";
import { useAddresses, useDomains } from "@/lib/domains";
import { useLocale } from "@/lib/i18n";
import { cn } from "@/lib/utils";

/**
 * "Finish setup" ka asli rasta (8k). Google ka setup tool aur Zoho ka flow user ko admin console par
 * chhor dete hain; yahan har qadam asli data se tick hota hai (domain jura? DNS verified? address bana?
 * pehli mail gayi?) — koi nakli progress nahi. Sab poora ho to card khamosh ho jata hai (kuch nahi dikhta).
 * Data na aaye / plan mein Domains na ho to bhi chup (galat nag nahi).
 */

const STORE = "ax-setup-checklist";

/** Per-viewer convenience only (never truth): "hide" ya "poora ho chuka". Storage na chale to bhi page theek. */
function readFlag(): boolean {
  try {
    return window.localStorage.getItem(STORE) === "off";
  } catch {
    return false;
  }
}
function writeFlag() {
  try {
    window.localStorage.setItem(STORE, "off");
  } catch {
    /* private window / blocked storage — card bas is session mein hide rahega */
  }
}

type Step = {
  id: "account" | "domain" | "dns" | "address" | "mail";
  title: string;
  hint: string;
  done: boolean;
};

function MiniRing({ done, total }: { done: number; total: number }) {
  const r = 20;
  const c = 2 * Math.PI * r;
  const off = c * (1 - (total > 0 ? done / total : 0));
  return (
    <div className="relative size-12 shrink-0" role="img" aria-label={`${done} of ${total} steps done`}>
      <svg viewBox="0 0 48 48" className="size-12 -rotate-90" aria-hidden="true">
        <circle cx="24" cy="24" r={r} fill="none" strokeWidth="4" className="stroke-border" />
        <circle
          cx="24"
          cy="24"
          r={r}
          fill="none"
          strokeWidth="4"
          strokeLinecap="round"
          strokeDasharray={c}
          strokeDashoffset={off}
          className="stroke-[var(--cyan-accent)] motion-safe:transition-[stroke-dashoffset] motion-safe:duration-700"
        />
      </svg>
      <span className="ax-label absolute inset-0 grid place-items-center">
        {done}/{total}
      </span>
    </div>
  );
}

export function SetupChecklist({ enabled, onCompose }: { enabled: boolean; onCompose: () => void }) {
  const { t } = useLocale();
  const domainsQ = useDomains();
  const addressesQ = useAddresses();
  const analyticsQ = useAnalytics(enabled);
  const [hidden, setHidden] = useState(false);
  useEffect(() => setHidden(readFlag()), []);

  const steps = useMemo<Step[] | null>(() => {
    if (!enabled || !domainsQ.data || !addressesQ.data) return null;
    // Plan mein domains hi nahi (cap 0) to is card ka matlab nahi — galat nag nahi.
    if (domainsQ.data.domain_cap === 0) return null;
    const domains = domainsQ.data.domains;
    const hasDomain = domains.length > 0;
    const verified = domains.some((d) => d.status === "verified");
    const hasAddress = addressesQ.data.addresses.length > 0;
    const list: Step[] = [
      { id: "account", title: "Create your account", hint: "Done — you're in.", done: true },
      {
        id: "domain",
        title: "Connect your domain",
        hint: "The one you own, like company.com.",
        done: hasDomain,
      },
      {
        id: "dns",
        title: "Add the DNS records",
        hint: "Five records. We check them live.",
        done: verified,
      },
      {
        id: "address",
        title: "Create a company address",
        hint: "sales@, support@ or your own name.",
        done: hasAddress,
      },
    ];
    // Pehli mail ka qadam sirf tab jab analytics ka asli jawab aaya (warna galat nag).
    if (analyticsQ.data) {
      list.push({
        id: "mail",
        title: "Send your first email",
        hint: "Watch it arrive — the loop works.",
        done: analyticsQ.data.sent > 0,
      });
    }
    return list;
  }, [enabled, domainsQ.data, addressesQ.data, analyticsQ.data]);

  const finished = steps ? steps.every((s) => s.done) : false;
  // Sab poora (pehli mail ke asli jawab ke saath) ho gaya to yaad rakho: analytics ki 30-din ki window baad
  // sent=0 dikhaye to card wapas na aaye. Analytics na aaye to flag nahi — pehli mail ka qadam baad mein bhi dikh sake.
  const mailKnown = steps ? steps.some((s) => s.id === "mail") : false;
  useEffect(() => {
    if (finished && mailKnown) writeFlag();
  }, [finished, mailKnown]);

  if (!steps || hidden || finished) return null;
  const done = steps.filter((s) => s.done).length;
  const active = steps.find((s) => !s.done) ?? steps[0]!;

  return (
    <section className="ax-plane ax-in relative mt-ax-6 rounded-2xl p-ax-5" aria-label="Setup checklist">
      <button
        type="button"
        onClick={() => {
          writeFlag();
          setHidden(true);
        }}
        className="ax-press absolute right-3 top-3 grid size-8 place-items-center rounded-full text-muted-foreground hover:bg-muted hover:text-foreground focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-[var(--cyan-accent)]"
        aria-label={t("Hide setup checklist")}
      >
        <X className="size-4" aria-hidden="true" />
      </button>
      <div className="flex flex-wrap items-center gap-4 pr-8">
        <MiniRing done={done} total={steps.length} />
        <div className="min-w-[12rem] flex-1">
          <p className="ax-eyebrow">{t("Finish setup")}</p>
          <h3 className="ax-heading mt-1">{t("Get your company email working")}</h3>
          <p className="ax-caption mt-0.5">
            {t("Next:")} {t(active.title)}
          </p>
        </div>
        {active.id === "mail" ? (
          <Button type="button" variant="seal" className="ax-press ax-tap w-full gap-1.5 sm:w-auto" onClick={onCompose}>
            <MailPlus className="size-4" aria-hidden="true" />
            {t("New email")}
          </Button>
        ) : (
          <Button asChild variant="seal" className="ax-press ax-tap w-full gap-1.5 sm:w-auto">
            <Link to="/app/domains">
              {t(active.id === "domain" ? "Connect a domain" : "Continue")}
              <ArrowRight className="size-4" aria-hidden="true" />
            </Link>
          </Button>
        )}
      </div>

      <ol className="ax-stagger mt-ax-4 grid gap-2 sm:grid-cols-2 lg:grid-cols-5">
        {steps.map((s, i) => (
          <li
            key={s.id}
            aria-current={s.id === active.id ? "step" : undefined}
            className={cn(
              "flex items-start gap-3 rounded-xl border p-3 transition-colors duration-500",
              s.done && "border-success/30 bg-success/5",
              !s.done && s.id === active.id && "border-[var(--cyan-accent)]/60 bg-[var(--cyan-accent)]/5",
              !s.done && s.id !== active.id && "border-border",
            )}
          >
            <span className="mt-0.5 flex size-5 shrink-0 items-center justify-center">
              {s.done ? (
                <CheckCircle2 className="size-5 text-success" aria-hidden="true" />
              ) : (
                <span
                  className={cn(
                    "ax-label flex size-5 items-center justify-center rounded-full border",
                    s.id === active.id ? "border-[var(--cyan-accent)]" : "border-border text-muted-foreground",
                  )}
                  aria-hidden="true"
                >
                  {i + 1}
                </span>
              )}
              <span className="sr-only">{s.done ? t("Done") : t("To do")}</span>
            </span>
            <div className="min-w-0">
              <p className={cn("ax-label", !s.done && s.id !== active.id && "text-muted-foreground")}>
                {t(s.title)}
              </p>
              <p className="ax-caption mt-0.5">{t(s.hint)}</p>
            </div>
          </li>
        ))}
      </ol>
    </section>
  );
}
