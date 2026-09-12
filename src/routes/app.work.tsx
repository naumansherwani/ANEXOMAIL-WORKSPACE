/**
 * /app/work — Plan-aware Work surface
 *
 * Basic     : Add task + TaskBoard (personal tasks only)
 * Pro+      : + Promises · Follow-through · Work chain · Decision ledger · Email bridge
 * Business+ : + Promise recovery · File card · Call record · Conversation truth · Receipts
 *
 * Feature gates via plan-surface.ts (no hard-coded plan strings here).
 * FeatureGate variant="wall" shows locked section with upgrade CTA for Basic users.
 * plans.ts / polar-payment — no-touch.
 */

import { createFileRoute } from "@tanstack/react-router";
import { motion } from "framer-motion";
import {
  CheckSquare,
  FileText,
  GitBranch,
  Link2,
  Lock,
  MessageSquare,
  Phone,
  Plus,
  ShieldCheck,
  Sparkles,
  Target,
  Zap,
} from "lucide-react";
import { useState } from "react";

import { FeatureGate } from "@/components/app/FeatureGate";
import { DetailPanel, ListPanel } from "@/components/app/Panel";
import { CallRecordPanel } from "@/components/app/work/CallRecordPanel";
import { ConversationTruth } from "@/components/app/work/ConversationTruth";
import { DecisionLedger } from "@/components/app/work/DecisionLedger";
import { EmailBridge } from "@/components/app/work/EmailBridge";
import { FileContextCard } from "@/components/app/work/FileContextCard";
import { FollowThroughTable } from "@/components/app/work/FollowThrough";
import { PromiseInbox } from "@/components/app/work/PromiseInbox";
import { PromiseRecovery } from "@/components/app/work/PromiseRecovery";
import { ReceiptsPanel } from "@/components/app/work/ReceiptsPanel";
import { TaskBoard } from "@/components/app/work/TaskBoard";
import { WorkChainBoard } from "@/components/app/work/WorkChainBoard";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { useAuth } from "@/lib/auth";
import { useCreateTask } from "@/lib/calendar";
import { useLocale } from "@/lib/i18n";
import { notify } from "@/lib/notify";
import {
  showProMailTools,
  showWorkBusinessRecord,
  surfaceFromSession,
} from "@/lib/plan-surface";
import { cn } from "@/lib/utils";

export const Route = createFileRoute("/app/work")({
  head: () => ({
    meta: [
      { title: "Work — ANEXOMAIL Workspace" },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: WorkPage,
});

// ── Section header inside the detail panel ─────────────────────────────────
function SectionHead({
  icon: Icon,
  label,
  badge,
  delay = 0,
}: {
  icon: typeof CheckSquare;
  label: string;
  badge?: string;
  delay?: number;
}) {
  return (
    <motion.div
      initial={{ opacity: 0, y: 4 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.22, ease: [0.25, 0.46, 0.45, 0.94], delay }}
      className="flex items-center gap-2 border-b border-border pb-2"
    >
      <span className="flex size-6 shrink-0 items-center justify-center rounded-lg bg-secondary">
        <Icon className="size-3 text-muted-foreground" />
      </span>
      <span className="text-[12px] font-semibold text-foreground">{label}</span>
      {badge && (
        <span className="ml-auto flex items-center gap-0.5 rounded-full bg-primary/15 px-1.5 py-0.5 text-[9px] font-semibold text-primary">
          <Sparkles className="size-2.5" />
          {badge}
        </span>
      )}
    </motion.div>
  );
}

// ── Animated section wrapper ────────────────────────────────────────────────
function WorkSection({
  children,
  delay = 0,
  className,
}: {
  children: React.ReactNode;
  delay?: number;
  className?: string;
}) {
  return (
    <motion.div
      initial={{ opacity: 0, y: 6 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.24, ease: [0.25, 0.46, 0.45, 0.94], delay }}
      className={cn("mt-ax-5", className)}
    >
      {children}
    </motion.div>
  );
}

// ── Business+ section with a subtle left-accent ─────────────────────────────
function BusinessSection({
  children,
  delay = 0,
}: {
  children: React.ReactNode;
  delay?: number;
}) {
  return (
    <motion.div
      initial={{ opacity: 0, y: 6 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.24, ease: [0.25, 0.46, 0.45, 0.94], delay }}
      className="relative mt-ax-5 border-l-2 border-primary/20 pl-3"
    >
      {children}
    </motion.div>
  );
}

// ── Locked Pro preview for Basic users ──────────────────────────────────────
function LockedProWorkPreview() {
  const { t } = useLocale();
  return (
    <motion.div
      initial={{ opacity: 0, y: 8 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.28, ease: [0.25, 0.46, 0.45, 0.94], delay: 0.1 }}
      className="mt-6 overflow-hidden rounded-2xl border border-border bg-card"
    >
      {/* Ghost preview rows */}
      <div aria-hidden="true" className="pointer-events-none select-none space-y-2 p-4 opacity-20 blur-[2px]">
        {["Promise — send proposal by Friday", "Follow-up — client review pending", "Decision — Q4 roadmap locked"].map((t) => (
          <div key={t} className="flex items-center gap-2 rounded-lg border border-border p-2.5">
            <div className="size-2 rounded-full bg-primary/40" />
            <span className="text-[11px] text-foreground">{t}</span>
          </div>
        ))}
      </div>

      {/* Lock overlay */}
      <div className="border-t border-border bg-card/95 p-5 text-center backdrop-blur-sm">
        <span className="mx-auto flex size-9 items-center justify-center rounded-xl bg-secondary">
          <Lock className="size-4 text-muted-foreground" />
        </span>
        <h3 className="mt-3 text-[13px] font-bold text-foreground">
          {t("Promises, follow-through & work chain")}
        </h3>
        <p className="mt-1.5 text-[11px] leading-relaxed text-muted-foreground/60">
          {t("Track commitments end-to-end — owner, deadline, evidence. Available on Pro.")}
        </p>
        <a
          href="/app/billing"
          className="mt-3 inline-flex items-center gap-1.5 rounded-xl bg-primary px-4 py-2 text-[11px] font-semibold text-primary-foreground transition-colors hover:bg-primary/90"
        >
          <Sparkles className="size-3" />
          {t("Upgrade to Pro")}
        </a>
      </div>
    </motion.div>
  );
}

// ── Main page ────────────────────────────────────────────────────────────────
type ListRail = "promises" | "score";

function WorkPage() {
  const { session, organisation } = useAuth();
  const { t } = useLocale();
  const { billed, kind } = surfaceFromSession(session?.user, organisation?.slug);
  const proWork = showProMailTools(billed, null, kind);          // Pro+: promises, boards, chain
  const businessRecord = showWorkBusinessRecord(billed, null, kind); // Business+: call/file records

  const [rail, setRail] = useState<ListRail>("promises");
  const [title, setTitle] = useState("");
  const create = useCreateTask();

  const add = () => {
    if (title.trim().length < 2) return;
    create.mutate(
      { title: title.trim() },
      {
        onSuccess: () => {
          setTitle("");
          notify.done("Task added", "It is on the board.");
        },
        onError: (error) =>
          notify.failed(error.isNotImplemented ? "Not wired yet" : "Could not add", {
            description: error.message,
          }),
      },
    );
  };

  return (
    <>
      {/* ── LIST PANEL — promises/follow-through (Pro+ only) ─────────── */}
      <ListPanel title="Work">
        {proWork ? (
          <>
            <div className="flex items-center gap-1 border-b border-border px-ax-3 py-ax-2">
              {(["promises", "score"] as const).map((r) => (
                <button
                  key={r}
                  type="button"
                  onClick={() => setRail(r)}
                  className={cn(
                    "ax-press ax-caption rounded-full border px-2.5 py-1 font-semibold transition-colors",
                    rail === r
                      ? "border-cyan-accent/50 bg-secondary text-foreground"
                      : "border-border text-muted-foreground",
                  )}
                >
                  {r === "promises" ? t("Promises") : t("Follow-through")}
                </button>
              ))}
            </div>
            <div className="p-ax-4">
              {rail === "promises" ? <PromiseInbox /> : <FollowThroughTable />}
            </div>
          </>
        ) : (
          /* Basic: tasks-only list view */
          <div className="p-ax-4">
            <div className="rounded-xl border border-border bg-card p-4 text-center">
              <CheckSquare className="mx-auto size-6 text-muted-foreground/30" />
              <p className="mt-2 text-[12px] font-semibold text-foreground">{t("Personal tasks")}</p>
              <p className="mt-1 text-[11px] text-muted-foreground/50">
                {t("Add tasks, track completion. Promises & follow-through on Pro.")}
              </p>
            </div>
          </div>
        )}
      </ListPanel>

      {/* ── DETAIL PANEL ─────────────────────────────────────────────── */}
      <DetailPanel>
        <div className="px-ax-6 py-ax-5">

          {/* ── 1. Add task — all plans ───────────────────────────────── */}
          <motion.div
            initial={{ opacity: 0, y: 6 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ duration: 0.2, ease: [0.25, 0.46, 0.45, 0.94] }}
          >
            <SectionHead icon={CheckSquare} label={t("Tasks")} delay={0} />
            <div className="mt-3 flex items-center gap-2">
              <Input
                value={title}
                onChange={(e) => setTitle(e.target.value)}
                onKeyDown={(e) => { if (e.key === "Enter") add(); }}
                placeholder={t("Add a task")}
                className="h-8 max-w-sm text-xs"
              />
              <Button size="sm" variant="outline" disabled={create.isPending} onClick={add}>
                <Plus className="size-3.5" />
                {t("Add")}
              </Button>
            </div>
            <div className="mt-4">
              <TaskBoard />
            </div>
          </motion.div>

          {/* ── 2. Pro work features — Basic sees locked preview ────────── */}
          {proWork ? (
            <>
              <WorkSection delay={0.06}>
                <SectionHead icon={Target} label={t("Work chain")} badge="Pro" delay={0.06} />
                <div className="mt-3">
                  <WorkChainBoard />
                </div>
              </WorkSection>

              <WorkSection delay={0.09}>
                <SectionHead icon={GitBranch} label={t("Decision ledger")} delay={0.09} />
                <div className="mt-3">
                  <DecisionLedger />
                </div>
              </WorkSection>

              <WorkSection delay={0.12}>
                <SectionHead icon={Link2} label={t("Email → Work bridge")} delay={0.12} />
                <div className="mt-3">
                  <EmailBridge />
                </div>
              </WorkSection>
            </>
          ) : (
            <LockedProWorkPreview />
          )}

          {/* ── 3. Business+ — promise recovery, file, call, truth ────── */}
          {businessRecord && (
            <>
              <BusinessSection delay={0.15}>
                <SectionHead
                  icon={Zap}
                  label={t("Promise recovery")}
                  badge="Business"
                  delay={0.15}
                />
                <div className="mt-3">
                  <PromiseRecovery />
                </div>
              </BusinessSection>

              <BusinessSection delay={0.18}>
                <SectionHead icon={FileText} label={t("File context")} delay={0.18} />
                <div className="mt-3">
                  <FileContextCard />
                </div>
              </BusinessSection>

              <BusinessSection delay={0.21}>
                <SectionHead icon={Phone} label={t("Call record")} delay={0.21} />
                <div className="mt-3">
                  <CallRecordPanel />
                </div>
              </BusinessSection>

              <BusinessSection delay={0.24}>
                <SectionHead icon={MessageSquare} label={t("Conversation truth")} delay={0.24} />
                <div className="mt-3">
                  <ConversationTruth />
                </div>
              </BusinessSection>

              <BusinessSection delay={0.27}>
                <SectionHead icon={ShieldCheck} label={t("Receipts")} delay={0.27} />
                <div className="mt-3">
                  <ReceiptsPanel />
                </div>
              </BusinessSection>
            </>
          )}

        </div>
      </DetailPanel>
    </>
  );
}
