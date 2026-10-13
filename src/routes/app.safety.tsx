/**
 * /app/safety — Business Pro safety centre (awam surface)
 *
 * Card promises wired here (plans.ts Business Pro — no-touch):
 *   - Safety review queue — new → under review → action → resolved
 *   - Sealed report evidence: opening it is logged with a reason
 *   - Enforcement history (your standing)
 *   - Device block appeals — one device only, never your network
 *
 * Backend (already live, no new API):
 *   Rust PRIMARY /rpc/chat.safety.* + chat.device.appeal.*
 *   Bun FALLBACK  /api/chat/safety/* + /api/chat/devices/appeal*
 *   SQL truth: safety_queue, safety_report_advance, safety_report_reveal,
 *              safety_my_standing, device_appeal_queue, device_appeal_decide
 *
 * Gate: plan-surface showSafety() = business_pro power (Personal Premium too).
 * Backend bhi khud 403 deta hai — UI sirf honest surface hai.
 */

import { createFileRoute } from "@tanstack/react-router";
import { motion } from "framer-motion";
import { Gavel, Loader2, ShieldCheck, Smartphone } from "lucide-react";
import { useState } from "react";

import { MyStanding, SafetyReviewQueue } from "@/components/app/safety/SafetyPanels";
import { Button } from "@/components/ui/button";
import {
  useDecideDeviceAppeal,
  useDeviceAppealQueue,
  type DeviceAppeal,
} from "@/lib/promise-engine";
import { useLocale } from "@/lib/i18n";
import { relativeTime } from "@/lib/mail";
import { notify } from "@/lib/notify";
import { cn } from "@/lib/utils";

export const Route = createFileRoute("/app/safety")({
  head: () => ({
    meta: [
      { title: "Safety — ANEXOMAIL Workspace" },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: SafetyPage,
});

/* ── Device appeal queue — Business Pro reviewers ────────────────── */
function DeviceAppealsPanel() {
  const { t } = useLocale();
  const [filter, setFilter] = useState<DeviceAppeal["state"] | "all">("new");
  const queue = useDeviceAppealQueue(filter);
  const decide = useDecideDeviceAppeal();

  if (queue.isPending)
    return <p className="ax-caption text-muted-foreground">{t("Loading appeals…")}</p>;
  if (queue.error)
    return <p className="ax-caption text-amber-400">{queue.error.message}</p>;
  if (queue.data && queue.data.allowed === false)
    return (
      <p className="ax-caption text-muted-foreground">
        {t("Device appeals open on Business Pro and founder accounts.")}
      </p>
    );

  const appeals = queue.data?.appeals ?? [];

  const act = (appeal_id: string, decision: "reviewing" | "granted" | "denied") => {
    const reason =
      decision === "reviewing"
        ? undefined
        : (window.prompt(t("Decision reason (logged, min 8 characters)")) ?? "").trim();
    if (decision !== "reviewing" && reason.length < 8) return;
    decide.mutate(
      { appeal_id, decision, reason: reason || undefined },
      {
        onSuccess: () => notify.done(t("Decision recorded"), t("The appeal moved forward.")),
        onError: (e) => notify.failed(t("Could not decide"), { description: e.message }),
      },
    );
  };

  return (
    <section className="space-y-ax-3">
      <div className="flex flex-wrap gap-2">
        {(["new", "reviewing", "granted", "denied", "all"] as const).map((s) => (
          <button
            key={s}
            type="button"
            onClick={() => setFilter(s)}
            className={cn(
              "ax-press ax-caption rounded-full border px-2.5 py-1 font-semibold",
              filter === s
                ? "border-cyan-accent/50 bg-secondary text-foreground"
                : "border-border text-muted-foreground",
            )}
          >
            {s}
          </button>
        ))}
      </div>

      {appeals.length === 0 ? (
        <p className="ax-caption text-muted-foreground">{t("No appeals in this state.")}</p>
      ) : (
        <ul className="space-y-ax-3">
          {appeals.map((a, i) => (
            <motion.li
              key={a.id}
              initial={{ opacity: 0, y: 6 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ duration: 0.2, delay: i * 0.04 }}
              className="ax-plane rounded-2xl p-ax-4"
            >
              <div className="flex flex-wrap items-center gap-ax-3 text-[12px]">
                <span className="flex items-center gap-1.5 font-semibold text-foreground">
                  <Smartphone className="size-3.5 text-cyan-accent" />
                  {t("device")} {a.device_hash.slice(0, 12)}…
                </span>
                <span
                  className={cn(
                    "rounded-full px-2 py-0.5 text-[10px] font-semibold",
                    a.state === "granted"
                      ? "bg-emerald-500/15 text-emerald-400"
                      : a.state === "denied"
                        ? "bg-red-500/15 text-red-400"
                        : "bg-amber-500/15 text-amber-400",
                  )}
                >
                  {a.state}
                </span>
                <span className="ml-auto text-steel">{relativeTime(a.created_at)}</span>
              </div>
              <p className="ax-caption mt-2 text-muted-foreground">“{a.statement}”</p>
              {a.decision_reason && (
                <p className="ax-caption mt-1 text-steel">
                  {t("decision")}: {a.decision_reason}
                </p>
              )}
              {(a.state === "new" || a.state === "reviewing") && (
                <div className="mt-ax-3 flex flex-wrap gap-2">
                  {a.state === "new" && (
                    <Button
                      size="sm"
                      variant="secondary"
                      disabled={decide.isPending}
                      onClick={() => act(a.id, "reviewing")}
                    >
                      {decide.isPending && <Loader2 className="size-3.5 animate-spin" />}
                      {t("Start review")}
                    </Button>
                  )}
                  <Button
                    size="sm"
                    variant="secondary"
                    disabled={decide.isPending}
                    onClick={() => act(a.id, "granted")}
                  >
                    <Gavel className="size-3.5" />
                    {t("Grant — unblock this device")}
                  </Button>
                  <Button
                    size="sm"
                    variant="ghost"
                    disabled={decide.isPending}
                    onClick={() => act(a.id, "denied")}
                  >
                    {t("Deny")}
                  </Button>
                </div>
              )}
            </motion.li>
          ))}
        </ul>
      )}
    </section>
  );
}

/* ── Page ─────────────────────────────────────────────────────────── */
function SafetyPage() {
  const { t } = useLocale();
  return (
    <div className="min-h-0 flex-1 overflow-y-auto">
      <div className="mx-auto w-full max-w-4xl space-y-ax-6 px-6 py-8 md:px-8">
        <motion.header
          initial={{ opacity: 0, y: 6 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.22 }}
        >
          <p className="ax-eyebrow flex items-center gap-2">
            <ShieldCheck className="size-3.5 text-cyan-accent" />
            {t("Business Pro")}
          </p>
          <h2 className="ax-h2 mt-1 text-foreground">{t("Safety centre")}</h2>
          <p className="ax-caption mt-2 text-muted-foreground">
            {t(
              "Review queue, sealed evidence and device appeals. Every action is logged with a reason — nothing is silent.",
            )}
          </p>
        </motion.header>

        <motion.section
          initial={{ opacity: 0, y: 6 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.22, delay: 0.05 }}
          className="space-y-ax-3"
        >
          <h3 className="ax-heading text-foreground">{t("Your standing")}</h3>
          <MyStanding />
        </motion.section>

        <motion.section
          initial={{ opacity: 0, y: 6 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.22, delay: 0.1 }}
          className="space-y-ax-3"
        >
          <h3 className="ax-heading text-foreground">{t("Review queue")}</h3>
          <p className="ax-caption text-muted-foreground">
            {t("New → under review → action → resolved. No step can be skipped.")}
          </p>
          <SafetyReviewQueue />
        </motion.section>

        <motion.section
          initial={{ opacity: 0, y: 6 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.22, delay: 0.15 }}
          className="space-y-ax-3"
        >
          <h3 className="ax-heading text-foreground">{t("Device block appeals")}</h3>
          <p className="ax-caption text-muted-foreground">
            {t("A ban sits on one device, never the network. Appeals are decided with a logged reason.")}
          </p>
          <DeviceAppealsPanel />
        </motion.section>
      </div>
    </div>
  );
}
