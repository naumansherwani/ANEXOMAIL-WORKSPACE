import { createFileRoute } from "@tanstack/react-router";
import { useMutation, useQuery } from "@tanstack/react-query";
import { useRef, useState } from "react";

import { BrandMark } from "@/components/site/BrandMark";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import type { ApiError } from "@/lib/api";
import { getPublicForm, submitPublicForm, type FormField } from "@/lib/crm-setup";

/**
 * /f/<slug> — a customer's web form. Public on purpose (the visitor has no account).
 * The slug is a random 16-hex id; the page shows only the form name and its fields. Submitting creates a lead
 * for the form's owner. Spam: a hidden trap field plus a minimum fill time are checked on the server, and the
 * server rate-limits each form. No CAPTCHA is bypassed or faked.
 */
export const Route = createFileRoute("/f/$slug")({
  ssr: false,
  head: () => ({
    meta: [
      { title: "Contact form" },
      { name: "robots", content: "noindex, nofollow" },
      { name: "referrer", content: "no-referrer" },
    ],
  }),
  component: PublicFormPage,
});

function PublicFormPage() {
  const { slug } = Route.useParams();
  const opened = useRef(Date.now());
  const [values, setValues] = useState<Record<string, string>>({});
  const [trap, setTrap] = useState("");
  const form = useQuery({ queryKey: ["public-form", slug], queryFn: () => getPublicForm(slug), retry: false, staleTime: 60_000 });
  const send = useMutation<{ received: true }, ApiError, void>({
    mutationFn: () => submitPublicForm(slug, values, trap, Date.now() - opened.current),
  });

  return (
    <main className="min-h-[100dvh] bg-background px-4 py-8 pb-[max(2rem,env(safe-area-inset-bottom))] sm:px-6 sm:py-12">
      <div className="mx-auto w-full max-w-md">
        <BrandMark />
        <div className="mt-8">
          {form.isPending ? (
            <p className="text-sm text-muted-foreground" aria-busy="true">Opening the form…</p>
          ) : form.error ? (
            <Notice title="This form is not available" body="The link may be old, or the form is paused. Please contact the sender directly." />
          ) : send.isSuccess ? (
            <Notice title="Thank you" body={form.data.success_message} />
          ) : (
            <form
              className="space-y-4"
              onSubmit={(e) => {
                e.preventDefault();
                send.mutate();
              }}
            >
              <h1 className="text-xl font-bold text-foreground">{form.data.name}</h1>
              {form.data.fields.map((f) => (
                <FieldInput key={f.key} f={f} value={values[f.key] ?? ""} onChange={(v) => setValues((s) => ({ ...s, [f.key]: v }))} />
              ))}
              {/* Trap: real people never see or fill this. */}
              <div aria-hidden="true" className="absolute -start-[9999px] h-0 w-0 overflow-hidden">
                <label>
                  Leave this empty
                  <input tabIndex={-1} autoComplete="off" value={trap} onChange={(e) => setTrap(e.target.value)} />
                </label>
              </div>
              {send.error && (
                <p role="alert" className="text-sm text-danger">
                  {send.error.status === 429 ? "Too many submissions right now. Please try again in a few minutes." : send.error.message}
                </p>
              )}
              <Button type="submit" disabled={send.isPending} className="w-full">
                {send.isPending ? "Sending…" : "Send"}
              </Button>
            </form>
          )}
        </div>
      </div>
    </main>
  );
}

function FieldInput({ f, value, onChange }: { f: FormField; value: string; onChange: (v: string) => void }) {
  const id = `f-${f.key}`;
  const common = { id, required: f.required, value, name: f.key };
  return (
    <div className="space-y-1">
      <label htmlFor={id} className="text-[13px] font-semibold text-foreground">
        {f.label}
        {f.required && <span aria-hidden="true"> *</span>}
      </label>
      {f.kind === "textarea" ? (
        <textarea {...common} rows={4} maxLength={500} onChange={(e) => onChange(e.target.value)} className="w-full rounded-md border border-border bg-background px-3 py-2 text-sm text-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring" />
      ) : f.kind === "select" ? (
        <select {...common} onChange={(e) => onChange(e.target.value)} className="h-10 w-full rounded-md border border-border bg-background px-2 text-sm text-foreground focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring">
          <option value="">Choose…</option>
          {(f.options ?? []).map((o) => (
            <option key={o} value={o}>{o}</option>
          ))}
        </select>
      ) : (
        <Input {...common} type={f.kind === "text" ? "text" : f.kind} maxLength={500} autoComplete={f.kind === "email" ? "email" : "off"} onChange={(e) => onChange(e.target.value)} />
      )}
    </div>
  );
}

function Notice({ title, body }: { title: string; body: string }) {
  return (
    <div role="status" className="rounded-2xl border border-border p-5">
      <h1 className="text-lg font-bold text-foreground">{title}</h1>
      <p className="mt-2 text-sm text-muted-foreground">{body}</p>
    </div>
  );
}
