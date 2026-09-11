import { useState, type FormEvent } from "react";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { useLocale } from "@/lib/i18n";
import { notify } from "@/lib/notify";
import { useCreateDeal, useCreateLead } from "@/lib/crm";

export function CaptureLead() {
  const { t } = useLocale();
  const create = useCreateLead();
  const [email, setEmail] = useState("");
  const [name, setName] = useState("");
  const [company, setCompany] = useState("");

  const submit = (e: FormEvent) => {
    e.preventDefault();
    const address = email.trim().toLowerCase();
    if (!address.includes("@")) {
      notify.failed("Email needed", { description: "A lead starts with a real address." });
      return;
    }
    create.mutate(
      {
        email: address,
        ...(name.trim() ? { display_name: name.trim() } : {}),
        ...(company.trim() ? { company: company.trim() } : {}),
      },
      {
        onSuccess: () => {
          setEmail("");
          setName("");
          setCompany("");
          notify.done("Lead captured", "They are on your book.");
        },
        onError: (err) =>
          notify.failed(err.isNotImplemented ? "Lead capture not wired yet" : "Could not save lead", {
            description: err.message,
          }),
      },
    );
  };

  return (
    <form
      onSubmit={submit}
      className="mb-ax-4 grid gap-2 rounded-2xl border border-border/80 bg-card/80 p-ax-3 shadow-elev-1 sm:grid-cols-[1fr_1fr_1fr_auto]"
    >
      <Input
        type="email"
        required
        value={email}
        onChange={(e) => setEmail(e.target.value)}
        placeholder="name@company.com"
        aria-label={t("Lead email")}
      />
      <Input value={name} onChange={(e) => setName(e.target.value)} placeholder={t("Name")} aria-label={t("Lead name")} />
      <Input
        value={company}
        onChange={(e) => setCompany(e.target.value)}
        placeholder={t("Company")}
        aria-label={t("Company")}
      />
      <Button type="submit" disabled={create.isPending} className="ax-press">
        {t("Capture lead")}
      </Button>
    </form>
  );
}

export function OpenDealForm({ onDone }: { onDone?: () => void }) {
  const { t } = useLocale();
  const create = useCreateDeal();
  const [title, setTitle] = useState("");
  const [company, setCompany] = useState("");
  const [email, setEmail] = useState("");
  const [value, setValue] = useState("");
  const [next, setNext] = useState("");

  const submit = (e: FormEvent) => {
    e.preventDefault();
    if (title.trim().length < 2) {
      notify.failed("Name the deal", { description: "Two characters at least." });
      return;
    }
    const amount = Number(value);
    create.mutate(
      {
        title: title.trim(),
        ...(company.trim() ? { company: company.trim() } : {}),
        ...(email.trim() ? { contact_email: email.trim().toLowerCase() } : {}),
        ...(Number.isFinite(amount) && amount > 0 ? { value: amount } : {}),
        ...(next.trim() ? { next_step: next.trim() } : {}),
      },
      {
        onSuccess: () => {
          setTitle("");
          setCompany("");
          setEmail("");
          setValue("");
          setNext("");
          notify.done("Deal opened", "It is on the New column.");
          onDone?.();
        },
        onError: (err) =>
          notify.failed(err.isNotImplemented ? "Deal create not wired yet" : "Could not open deal", {
            description: err.message,
          }),
      },
    );
  };

  return (
    <form onSubmit={submit} className="flex flex-col gap-3">
      <Input required value={title} onChange={(e) => setTitle(e.target.value)} placeholder={t("Deal title")} aria-label={t("Deal title")} />
      <Input value={company} onChange={(e) => setCompany(e.target.value)} placeholder={t("Company")} aria-label={t("Company")} />
      <Input
        type="email"
        value={email}
        onChange={(e) => setEmail(e.target.value)}
        placeholder={t("Contact email")}
        aria-label={t("Contact email")}
      />
      <Input
        type="number"
        min={0}
        step={1}
        value={value}
        onChange={(e) => setValue(e.target.value)}
        placeholder={t("Value (£)")}
        aria-label={t("Deal value")}
      />
      <Input value={next} onChange={(e) => setNext(e.target.value)} placeholder={t("Next step")} aria-label={t("Next step")} />
      <Button type="submit" disabled={create.isPending} className="ax-press mt-1">
        {t("Open deal")}
      </Button>
    </form>
  );
}
