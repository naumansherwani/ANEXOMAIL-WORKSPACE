import { createFileRoute, useSearch } from "@tanstack/react-router";
import { useEffect, useState } from "react";
import { Button } from "@/components/ui/button";
import { BrandMark } from "@/components/site/BrandMark";
import { reportGlitch } from "@/lib/telemetry";
import { api } from "@/lib/api";

export const Route = createFileRoute("/checkout/done")({
  component: CheckoutDonePage,
  head: () => ({
    title: "Checkout — ANEXOMAIL",
    meta: [
      { name: "description", content: "ANEXOMAIL checkout confirmation." },
      { property: "og:title", content: "Checkout — ANEXOMAIL" },
      { property: "og:description", content: "ANEXOMAIL checkout confirmation." },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary" },
    ],
  }),
});

function CheckoutDonePage() {
  const search = useSearch({ from: "/checkout/done" }) as { checkout_id?: string };
  const checkoutId = search.checkout_id;
  const [status, setStatus] = useState<"loading" | "success" | "failed" | "missing">("loading");
  const [detail, setDetail] = useState<string>("");

  useEffect(() => {
    if (!checkoutId) {
      setStatus("missing");
      return;
    }
    let cancelled = false;
    let timer: ReturnType<typeof setTimeout> | undefined;
    let attempts = 0;
    const verify = async () => {
      try {
        const data = await api<{ status: string }>(`/api/billing/checkout/${checkoutId}`);
        if (cancelled) return;
        setDetail(data.status);
        if (data.status === "confirmed" || data.status === "succeeded") {
          setStatus("success");
          return;
        }
        attempts += 1;
        if (attempts < 20) timer = setTimeout(() => void verify(), 3000);
        else setStatus("failed");
      } catch (e) {
        if (cancelled) return;
        console.error("checkout verify", e);
        // Phase 47 — checkout ka koi bhi glitch founder ke WhatsApp tak jata hai.
        reportGlitch("checkout_error", `checkout verify failed: ${String(e?.message ?? e)}`, {
          severity: "critical",
          fingerprint: "checkout_error|verify",
          meta: { checkout_id: checkoutId },
        });
        setStatus("failed");
      }
    };
    void verify();
    return () => {
      cancelled = true;
      if (timer) clearTimeout(timer);
    };
  }, [checkoutId]);

  return (
    <main className="min-h-screen flex flex-col items-center justify-center px-6">
      <div className="w-full max-w-md space-y-8 text-center">
        <BrandMark className="mx-auto h-12 w-12" />
        <h1 className="text-2xl font-semibold tracking-tight">ANEXOMAIL Checkout</h1>

        {status === "loading" && (
          <div className="space-y-2">
            <p className="text-muted-foreground">Payment confirmation check kar rahe hain…</p>
            {detail && <p className="text-xs text-muted-foreground">Status: {detail}</p>}
          </div>
        )}

        {status === "success" && (
          <div className="space-y-4 rounded-xl border p-6 bg-green-500/5 border-green-500/20">
            <p className="text-lg font-medium text-green-600">Payment confirmed ✅</p>
            <p className="text-sm text-muted-foreground">
              Receipt aur next steps aapke email par bhej diye gaye hain.
            </p>
            <Button asChild className="w-full">
              <a href="/app">Open workspace</a>
            </Button>
          </div>
        )}

        {status === "failed" && (
          <div className="space-y-4 rounded-xl border p-6 bg-destructive/5 border-destructive/20">
            <p className="text-lg font-medium text-destructive">Confirmation failed</p>
            <p className="text-sm text-muted-foreground">
              Agar payment kat gaya hai toh 2–3 min wait kar ke refresh karein. Problem rehti hai
              toh <a href="mailto:hello@anexomail.com" className="underline">hello@anexomail.com</a>{" "}
              par likhein.
            </p>
            <Button asChild variant="outline" className="w-full">
              <a href="/">Back to home</a>
            </Button>
          </div>
        )}

        {status === "missing" && (
          <div className="space-y-4 rounded-xl border p-6">
            <p className="text-muted-foreground">Checkout ID missing hai.</p>
            <Button asChild variant="outline" className="w-full">
              <a href="/">Back to home</a>
            </Button>
          </div>
        )}
      </div>
    </main>
  );
}
