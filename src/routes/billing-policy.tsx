import { createFileRoute } from "@tanstack/react-router";

export const Route = createFileRoute("/billing-policy")({
  head: () => ({
    meta: [
      { title: "Billing policy — ANEXOMAIL Workspace" },
      {
        name: "description",
        content:
          "Changing package means paying the new package's full price. No credit or refund for the old one. How cancelling works.",
      },
      { property: "og:title", content: "Billing policy — ANEXOMAIL Workspace" },
      { property: "og:type", content: "website" },
    ],
  }),
  component: BillingPolicyPage,
});

function BillingPolicyPage() {
  return (
    <main className="ax-container py-16">
      <p className="text-xs font-semibold tracking-wider text-muted-foreground uppercase">Policy</p>
      <h1 className="ax-display mt-3 text-foreground">Billing policy</h1>

      <section className="mt-10 max-w-3xl space-y-4">
        <h2 className="ax-heading text-foreground">Changing your package</h2>
        <p className="text-sm leading-relaxed text-muted-foreground">
          When you move to another package — for example from Basic to Pro — you pay the{" "}
          <strong className="text-foreground">full price of the new package</strong>. What you
          already paid for your current package is{" "}
          <strong className="text-foreground">not credited, not adjusted and not refunded</strong>.
        </p>
        <ul className="space-y-3 text-sm leading-relaxed text-muted-foreground">
          <li>
            Your new package starts as soon as its payment succeeds. Only then is your previous
            subscription closed, so you are never charged for both going forward.
          </li>
          <li>
            If the new payment does not go through, nothing changes: your current package keeps
            running.
          </li>
          <li>There are no usage meters and no surprise line items — one flat price per package.</li>
        </ul>
      </section>

      <section className="mt-12 max-w-3xl space-y-4">
        <h2 className="ax-heading text-foreground">Cancelling, card and VAT</h2>
        <ul className="space-y-3 text-sm leading-relaxed text-muted-foreground">
          <li>
            You can cancel, change your card or download VAT invoices yourself at any time from{" "}
            <strong className="text-foreground">Billing &rarr; Manage billing</strong>, in Polar&apos;s
            secure portal. We never see or store your card details.
          </li>
          <li>
            Payments are processed by Polar, who acts as the seller of record and issues your
            receipts.
          </li>
        </ul>
        <p className="text-sm leading-relaxed text-muted-foreground">
          Every charge, receipt and VAT invoice is in <strong className="text-foreground">Billing &rarr; Manage billing</strong>, and Polar emails a receipt automatically after each payment.
        </p>
      </section>
    </main>
  );
}
