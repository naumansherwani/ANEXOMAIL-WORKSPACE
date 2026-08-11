import { History, Info, RotateCcw, ShieldAlert, Users } from "lucide-react";
import { useState } from "react";

import { CardBody, StatSkeleton } from "@/components/app/dashboard/DashboardCard";
import type { Scope, Setting } from "@/lib/settings";
import {
  shortValue,
  useBlastRadius,
  useExplain,
  useSaveSetting,
  useSettingHistory,
  useSettings,
  useSimulate,
  useRevertSetting as useRevert,
} from "@/lib/settings";
import { cn } from "@/lib/utils";

/**
 * Phase 23 — one row rhythm for every setting. Har row 4 locked features carry
 * karta hai: Explain (Leo), Blast radius, Simulate (dry run), Time Machine.
 */
export function SettingsScope({ scope, title, blurb }: { scope: Scope; title: string; blurb: string }) {
  const q = useSettings(scope);

  return (
    <div className="min-h-0 flex-1 overflow-y-auto">
      <div className="mx-auto w-full max-w-3xl px-6 py-8 md:px-8">
        <h2 className="ax-h2 text-foreground">{title}</h2>
        <p className="ax-caption mt-1 text-muted-foreground">{blurb}</p>

        <div className="mt-ax-5">
          <CardBody
            query={{
              data: q.data,
              isPending: q.isPending,
              error: q.error ?? null,
              refetch: () => void q.refetch(),
            }}
            endpoint={`/api/settings/${scope}`}
            skeleton={<StatSkeleton rows={6} />}
          >
            {(d) => (
              <ul className="space-y-ax-3">
                {d.settings.map((s) => (
                  <SettingRow key={s.key} setting={s} />
                ))}
              </ul>
            )}
          </CardBody>
        </div>
      </div>
    </div>
  );
}

export function SettingRow({ setting }: { setting: Setting }) {
  const [open, setOpen] = useState<null | "explain" | "blast" | "history">(null);
  const explain = useExplain(open === "explain" ? setting.key : null);
  const blast = useBlastRadius(open === "blast" ? setting.key : null);
  const history = useSettingHistory(setting.key);
  const save = useSaveSetting();
  const simulate = useSimulate();
  const locked = Boolean(setting.locked_by_policy);

  return (
    <li className="ax-plane rounded-2xl p-ax-4">
      <div className="flex flex-wrap items-start gap-ax-3">
        <div className="min-w-0 flex-1">
          <p className="text-[13px] font-semibold text-foreground">{setting.label}</p>
          <p className="ax-caption mt-0.5 text-muted-foreground">{setting.help}</p>
          <div className="mt-2 flex flex-wrap items-center gap-2 text-[11px]">
            <span className="rounded-md bg-secondary px-2 py-0.5 font-semibold text-foreground">
              {shortValue(setting.value)}
            </span>
            {setting.drift && setting.drift !== "aligned" && (
              <span
                className={cn(
                  "rounded-md px-2 py-0.5 font-semibold",
                  setting.drift === "risky" ? "bg-destructive/10 text-destructive" : "bg-secondary text-steel",
                )}
              >
                {setting.drift === "risky" ? "Risky vs baseline" : "Looser than baseline"}
              </span>
            )}
            {locked && (
              <span className="rounded-md bg-secondary px-2 py-0.5 font-semibold text-steel">
                Locked by policy: {setting.locked_by_policy}
              </span>
            )}
          </div>
        </div>

        <div className="flex shrink-0 flex-wrap gap-1">
          <Chip icon={Info} label="Explain" active={open === "explain"} onClick={() => setOpen(open === "explain" ? null : "explain")} />
          <Chip icon={Users} label="Blast radius" active={open === "blast"} onClick={() => setOpen(open === "blast" ? null : "blast")} />
          <Chip icon={History} label="History" active={open === "history"} onClick={() => setOpen(open === "history" ? null : "history")} />
          {setting.kind === "toggle" && !locked && (
            <button
              type="button"
              className="ax-press rounded-lg bg-foreground px-2.5 py-1 text-[11px] font-semibold text-background"
              disabled={save.isPending}
              onClick={() => {
                const next = !setting.value;
                simulate.mutate({ key: setting.key, value: next });
                save.mutate({ key: setting.key, value: next });
              }}
            >
              {setting.value ? "Turn off" : "Turn on"}
            </button>
          )}
        </div>
      </div>

      {open === "explain" && (
        <Drawer endpoint="/api/settings/explain" q={explain}>
          {(e) => (
            <>
              <p className="text-[12px] text-foreground">{e.plain}</p>
              <p className="ax-caption mt-2 text-muted-foreground">Real example: {e.example}</p>
              {e.tradeoff && <p className="ax-caption mt-1 text-steel">Trade-off: {e.tradeoff}</p>}
            </>
          )}
        </Drawer>
      )}

      {open === "blast" && (
        <Drawer endpoint="/api/settings/blast-radius" q={blast}>
          {(b) => (
            <>
              <p className="flex items-center gap-2 text-[12px] font-semibold text-foreground">
                <ShieldAlert className="size-3.5" aria-hidden="true" />
                {b.members_affected} members · {b.mailboxes_affected} mailboxes · {b.automations_affected} automations
              </p>
              {b.breaks.length > 0 && (
                <ul className="ax-caption mt-2 list-disc space-y-0.5 pl-4 text-muted-foreground">
                  {b.breaks.map((x) => (
                    <li key={x}>{x}</li>
                  ))}
                </ul>
              )}
              <p className="ax-caption mt-2 text-steel">
                Severity {b.severity} · {b.reversible ? "reversible in one click" : "not reversible"}
              </p>
            </>
          )}
        </Drawer>
      )}

      {open === "history" && (
        <Drawer endpoint="/api/settings/history" q={history}>
          {(h) =>
            h.versions.length === 0 ? (
              <p className="ax-caption text-muted-foreground">No change recorded yet.</p>
            ) : (
              <ul className="space-y-1.5">
                {h.versions.map((v) => (
                  <li key={v.id} className="flex items-center gap-ax-3 text-[11px]">
                    <span className="text-muted-foreground">{new Date(v.changed_at).toLocaleString("en-GB")}</span>
                    <span className="text-foreground">
                      {v.from_value ?? "—"} → {v.to_value ?? "—"}
                    </span>
                    <span className="ml-auto text-steel">{v.changed_by}</span>
                    <RevertButton versionId={v.id} reverted={v.reverted} />
                  </li>
                ))}
              </ul>
            )
          }
        </Drawer>
      )}
    </li>
  );
}

function RevertButton({ versionId, reverted }: { versionId: string; reverted: boolean }) {
  const revert = useRevert();
  if (reverted) return <span className="text-steel">reverted</span>;
  return (
    <button
      type="button"
      className="ax-press flex items-center gap-1 rounded-md bg-secondary px-2 py-0.5 font-semibold text-foreground"
      disabled={revert.isPending}
      onClick={() => revert.mutate({ version_id: versionId })}
    >
      <RotateCcw className="size-3" aria-hidden="true" /> Revert
    </button>
  );
}

function Chip({
  icon: Icon,
  label,
  active,
  onClick,
}: {
  icon: typeof Info;
  label: string;
  active: boolean;
  onClick: () => void;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      className={cn(
        "ax-press flex items-center gap-1 rounded-lg px-2.5 py-1 text-[11px] font-semibold transition-colors",
        active ? "bg-foreground text-background" : "bg-secondary text-foreground",
      )}
    >
      <Icon className="size-3" aria-hidden="true" /> {label}
    </button>
  );
}

function Drawer<T>({
  endpoint,
  q,
  children,
}: {
  endpoint: string;
  q: { data: T | undefined; isPending: boolean; error: unknown; refetch: () => void };
  children: (data: T) => React.ReactNode;
}) {
  return (
    <div className="mt-ax-3 rounded-xl border border-border p-ax-3">
      <CardBody
        query={{
          data: q.data,
          isPending: q.isPending,
          error: (q.error as never) ?? null,
          refetch: () => q.refetch(),
        }}
        endpoint={endpoint}
        skeleton={<StatSkeleton rows={2} />}
      >
        {children}
      </CardBody>
    </div>
  );
}

export function Stat({ label, value, hint }: { label: string; value: string; hint?: string }) {
  return (
    <div className="ax-plane rounded-2xl p-ax-4">
      <p className="ax-caption text-muted-foreground">{label}</p>
      <p className="mt-1 text-[19px] font-bold text-foreground">{value}</p>
      {hint && <p className="ax-caption mt-0.5 text-steel">{hint}</p>}
    </div>
  );
}
