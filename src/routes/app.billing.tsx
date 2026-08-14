import { createFileRoute } from "@tanstack/react-router";
import { CreditCard, FileText, Receipt, ShieldCheck } from "lucide-react";
import { useState } from "react";

import { CardBody, StatSkeleton } from "@/components/app/dashboard/DashboardCard";
import {
  PLAN_LABEL,
  gbp,
  useChangePlan,
  useInvoices,
  usePaymentMethods,
  usePreviewPlanChange,
  useSaveTaxProfile,
  useSubscription,
  useTaxProfile,
  type WorkspacePlanId,
} from "@/lib/billing-platform";
import { relativeTime } from "@/lib/mail";
import { notify } from "@/lib/notify";

export const Route = createFileRoute("/app/billing")({
  component: WorkspaceBilling,
});

const PLANS: WorkspacePlanId[] = ["basic", "pro", "business", "business_pro"];

/**
 * Phase 21 — Billing platform, awam surface.
 * Sirf workspace plans (£20/£40/£85). AI credits ka is page se koi taalluq nahi.
 */
function WorkspaceBilling() {
  const [plan, setPlan] = useState<WorkspacePlanId>("pro");
  const [seats, setSeats] = useState(1);

  const sub = useSubscription();
  const invoices = useInvoices();
  const tax = useTaxProfile();
  const methods = usePaymentMethods();
  const preview = usePreviewPlanChange();
  const change = useChangePlan();
  const saveTax = useSaveTaxProfile();

  const fail = (endpoint: string) => (err: { isNotImplemented: boolean; message: string }) =>
    notify.failed(err.isNotImplemented ? "Not wired yet" : "Failed", {
      description: err.isNotImplemented ? `${endpoint} is pending on the server.` : err.message,
    });

  return (
    <div className="min-h-0 flex-1 overflow-y-auto">
      <div className="mx-auto w-full max-w-4xl px-6 py-8 md:px-8">
        <p className="ax-eyebrow flex items-center gap-2">
          <Receipt className="size-3.5" aria-hidden="true" /> Billing
        </p>
        <h2 className="ax-h2 mt-1 text-foreground">Your plan and invoices</h2>
        <p className="ax-caption mt-2 text-muted-foreground">
          One flat monthly price per mailbox. No usage meter, no surprise line items.
        </p>

        <section className="mt-ax-5">
          <CardBody
            query={{
              data: sub.data,
              isPending: sub.isPending,
              error: sub.error ?? null,
              refetch: () => void sub.refetch(),
            }}
            endpoint="/api/billing/subscription"
            skeleton={<StatSkeleton rows={4} />}
          >
            {(s) => (
              <div className="ax-plane rounded-2xl p-ax-4">
                <div className="grid gap-ax-3 sm:grid-cols-4">
                  <Cell label="Plan" value={s.plan ? PLAN_LABEL[s.plan] : "No plan"} />
                  <Cell label="Status" value={s.state} />
                  <Cell label="Seats" value={`${s.seats_used} / ${s.seats}`} />
                  <Cell
                    label="Renews"
                    value={s.renews_at ? relativeTime(s.renews_at) : s.cancel_at ? "cancelling" : "—"}
                  />
                </div>
                <p className="ax-caption mt-ax-3 text-steel">
                  {gbp(s.price_per_seat)} per mailbox / {s.interval}
                  {s.storage_per_mailbox_gb ? ` · ${s.storage_per_mailbox_gb}GB per mailbox` : ""}
                </p>
              </div>
            )}
          </CardBody>
        </section>

        <section className="mt-ax-6">
          <h3 className="ax-heading text-foreground">Change plan</h3>
          <div className="mt-ax-3 flex flex-wrap items-center gap-2">
            {PLANS.map((p) => (
              <button
                key={p}
                type="button"
                onClick={() => setPlan(p)}
                data-on={plan === p ? "true" : "false"}
                className="ax-press rounded-xl border border-border px-3 py-2 text-[12px] font-semibold text-muted-foreground data-[on=true]:border-primary data-[on=true]:text-foreground"
              >
                {PLAN_LABEL[p]}
              </button>
            ))}
            <label className="ax-caption flex items-center gap-2 text-muted-foreground">
              Seats
              <input
                aria-label="Seats"
                type="number"
                min={1}
                value={seats}
                onChange={(e) => setSeats(Math.max(1, Number(e.target.value) || 1))}
                className="h-9 w-16 rounded-lg border border-border bg-card px-2 text-[12px] text-foreground"
              />
            </label>
            <button
              type="button"
              disabled={preview.isPending}
              onClick={() => preview.mutate({ plan, seats }, { onError: fail("POST /api/billing/preview") })}
              className="ax-press rounded-xl border border-border px-3 py-2 text-[12px] font-semibold text-foreground disabled:opacity-50"
            >
              Preview cost
            </button>
          </div>

          {preview.data && (
            <div className="ax-plane mt-ax-3 rounded-2xl p-ax-4">
              <p className="text-[13px] text-foreground">
                Charge now {gbp(preview.data.charge_now)} · credit back {gbp(preview.data.credit_back)} ·
                next invoice {gbp(preview.data.next_total)}
              </p>
              <p className="ax-caption mt-1 text-steel">
                Effective {relativeTime(preview.data.effective_at)} — pro-rated by the server, not guessed here.
              </p>
              <button
                type="button"
                disabled={change.isPending}
                onClick={() =>
                  change.mutate(
                    { plan: preview.data!.plan, seats: preview.data!.seats },
                    {
                      onSuccess: () => notify.done("Plan updated", "Invoice will show the pro-ration."),
                      onError: fail("POST /api/billing/change"),
                    },
                  )
                }
                className="ax-press mt-ax-3 rounded-xl bg-primary px-3 py-2 text-[12px] font-semibold text-primary-foreground disabled:opacity-50"
              >
                Confirm change
              </button>
            </div>
          )}
        </section>

        <section className="mt-ax-6">
          <h3 className="ax-heading flex items-center gap-2 text-foreground">
            <FileText className="size-4" aria-hidden="true" /> Invoices
          </h3>
          <div className="mt-ax-3">
            <CardBody
              query={{
                data: invoices.data,
                isPending: invoices.isPending,
                error: invoices.error ?? null,
                refetch: () => void invoices.refetch(),
              }}
              endpoint="/api/billing/invoices"
              skeleton={<StatSkeleton rows={4} />}
            >
              {(d) =>
                d.invoices.length === 0 ? (
                  <p className="ax-caption text-muted-foreground">No invoices yet.</p>
                ) : (
                  <ul className="space-y-1.5">
                    {d.invoices.map((inv) => (
                      <li
                        key={inv.id}
                        className="ax-plane flex flex-wrap items-center gap-ax-3 rounded-xl px-ax-4 py-ax-3 text-[12px]"
                      >
                        <span className="font-semibold text-foreground">{inv.number}</span>
                        <span className="rounded-md bg-secondary px-1.5 py-0.5 text-[10px] font-semibold uppercase text-muted-foreground">
                          {inv.state}
                        </span>
                        <span className="text-foreground">{gbp(inv.total)}</span>
                        <span className="text-steel">tax {gbp(inv.tax)}</span>
                        <span className="text-steel">{relativeTime(inv.issued_at)}</span>
                        {inv.pdf_url && (
                          <a
                            href={inv.pdf_url}
                            className="ml-auto font-semibold text-primary underline-offset-2 hover:underline"
                          >
                            PDF
                          </a>
                        )}
                      </li>
                    ))}
                  </ul>
                )
              }
            </CardBody>
          </div>
        </section>

        <section className="mt-ax-6 grid gap-ax-4 md:grid-cols-2">
          <div>
            <h3 className="ax-heading flex items-center gap-2 text-foreground">
              <ShieldCheck className="size-4" aria-hidden="true" /> Tax details
            </h3>
            <div className="mt-ax-3">
              <CardBody
                query={{
                  data: tax.data,
                  isPending: tax.isPending,
                  error: tax.error ?? null,
                  refetch: () => void tax.refetch(),
                }}
                endpoint="/api/billing/tax"
                skeleton={<StatSkeleton rows={3} />}
              >
                {(t) => (
                  <form
                    className="ax-plane flex flex-col gap-2 rounded-2xl p-ax-4"
                    onSubmit={(e) => {
                      e.preventDefault();
                      const form = new FormData(e.currentTarget);
                      saveTax.mutate(
                        {
                          legal_name: String(form.get("legal_name") ?? ""),
                          country: String(form.get("country") ?? ""),
                          vat_number: String(form.get("vat_number") ?? ""),
                          address: String(form.get("address") ?? ""),
                        },
                        {
                          onSuccess: () => notify.done("Saved", "Next invoice uses these details."),
                          onError: fail("POST /api/billing/tax"),
                        },
                      );
                    }}
                  >
                    <input
                      name="legal_name"
                      aria-label="Legal name"
                      defaultValue={t.legal_name ?? ""}
                      placeholder="Legal name"
                      className="h-9 rounded-lg border border-border bg-card px-2 text-[12px] text-foreground"
                    />
                    <input
                      name="country"
                      aria-label="Country"
                      defaultValue={t.country ?? ""}
                      placeholder="Country"
                      className="h-9 rounded-lg border border-border bg-card px-2 text-[12px] text-foreground"
                    />
                    <input
                      name="vat_number"
                      aria-label="VAT number"
                      defaultValue={t.vat_number ?? ""}
                      placeholder="VAT number"
                      className="h-9 rounded-lg border border-border bg-card px-2 text-[12px] text-foreground"
                    />
                    <textarea
                      name="address"
                      aria-label="Billing address"
                      defaultValue={t.address ?? ""}
                      rows={3}
                      placeholder="Billing address"
                      className="rounded-lg border border-border bg-card px-2 py-1.5 text-[12px] text-foreground"
                    />
                    <p className="ax-caption text-steel">
                      {t.vat_validated ? "VAT validated" : "VAT not validated"}
                      {t.reverse_charge ? " · reverse charge applies" : ""}
                    </p>
                    <button
                      type="submit"
                      disabled={saveTax.isPending}
                      className="ax-press self-start rounded-xl bg-primary px-3 py-2 text-[12px] font-semibold text-primary-foreground disabled:opacity-50"
                    >
                      Save
                    </button>
                  </form>
                )}
              </CardBody>
            </div>
          </div>

          <div>
            <h3 className="ax-heading flex items-center gap-2 text-foreground">
              <CreditCard className="size-4" aria-hidden="true" /> Payment methods
            </h3>
            <div className="mt-ax-3">
              <CardBody
                query={{
                  data: methods.data,
                  isPending: methods.isPending,
                  error: methods.error ?? null,
                  refetch: () => void methods.refetch(),
                }}
                endpoint="/api/billing/methods"
                skeleton={<StatSkeleton rows={2} />}
              >
                {(d) =>
                  d.methods.length === 0 ? (
                    <p className="ax-caption text-muted-foreground">No card on file.</p>
                  ) : (
                    <ul className="space-y-1.5">
                      {d.methods.map((m) => (
                        <li
                          key={m.id}
                          className="ax-plane flex items-center gap-ax-3 rounded-xl px-ax-4 py-ax-3 text-[12px]"
                        >
                          <span className="font-semibold text-foreground">
                            {m.brand} ···· {m.last4}
                          </span>
                          <span className="text-steel">exp {m.exp}</span>
                          {m.default && <span className="ml-auto text-primary">default</span>}
                        </li>
                      ))}
                    </ul>
                  )
                }
              </CardBody>
            </div>
          </div>
        </section>
      </div>
    </div>
  );
}

function Cell({ label, value }: { label: string; value: string }) {
  return (
    <div>
      <p className="ax-caption text-muted-foreground">{label}</p>
      <p className="mt-1 text-[15px] font-bold text-foreground">{value}</p>
    </div>
  );
}
