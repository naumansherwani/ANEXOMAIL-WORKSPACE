import { useState } from "react";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { useSubmitLead, type LeadKind, type LeadPayload } from "@/lib/revenue";

type Props = {
  kind: LeadKind;
  cta: string;
  quoteGbp?: number;
  detail?: Record<string, unknown>;
  seats?: number;
  note?: string;
};

/** One real form for all three money roads — writes a real lead row, no mock. */
export function LeadForm({ kind, cta, quoteGbp, detail, seats, note }: Props) {
  const [company, setCompany] = useState("");
  const [email, setEmail] = useState("");
  const [domain, setDomain] = useState("");
  const [message, setMessage] = useState("");
  const submit = useSubmitLead();

  const onSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    const payload: LeadPayload = { kind, company, email, domain, message, quote_gbp: quoteGbp, seats, detail };
    submit.mutate(payload);
  };

  if (submit.isSuccess) {
    return (
      <div className="ax-plane rounded-2xl p-6">
        <p className="ax-heading text-foreground">Got it — reference {submit.data.reference}</p>
        <p className="mt-2 text-sm leading-relaxed text-muted-foreground">
          A human replies from hello@anexomail.com within 4 hours with the plan, the fixed price and the cut-over
          window. No sales sequence, no bot.
        </p>
      </div>
    );
  }

  return (
    <form onSubmit={onSubmit} className="ax-plane rounded-2xl p-6">
      <div className="grid gap-4 sm:grid-cols-2">
        <div>
          <Label htmlFor={`${kind}-company`}>Company</Label>
          <Input id={`${kind}-company`} required value={company} onChange={(e) => setCompany(e.target.value)} placeholder="NEXATECT Global Ltd" className="mt-2" />
        </div>
        <div>
          <Label htmlFor={`${kind}-email`}>Work email</Label>
          <Input id={`${kind}-email`} type="email" required value={email} onChange={(e) => setEmail(e.target.value)} placeholder="you@yourcompany.com" className="mt-2" />
        </div>
        <div>
          <Label htmlFor={`${kind}-domain`}>Domain</Label>
          <Input id={`${kind}-domain`} value={domain} onChange={(e) => setDomain(e.target.value)} placeholder="yourcompany.com" className="mt-2" />
        </div>
        <div>
          <Label htmlFor={`${kind}-message`}>Anything we should know</Label>
          <Input id={`${kind}-message`} value={message} onChange={(e) => setMessage(e.target.value)} placeholder="Optional" className="mt-2" />
        </div>
      </div>

      {quoteGbp != null && (
        <p className="mt-4 text-xs text-muted-foreground">
          Your quote of £{quoteGbp.toLocaleString("en-GB")} is attached to this request and held for 30 days.
        </p>
      )}
      {note && <p className="mt-2 text-xs text-muted-foreground">{note}</p>}

      {submit.isError && (
        <p className="mt-4 text-sm text-destructive">
          {submit.error.isNotImplemented
            ? "This request line is not wired on the server yet — email hello@anexomail.com and it gets handled the same hour."
            : submit.error.message}
        </p>
      )}

      <Button type="submit" size="lg" className="mt-6 w-full sm:w-auto" disabled={submit.isPending}>
        {submit.isPending ? "Sending…" : cta}
      </Button>
    </form>
  );
}
