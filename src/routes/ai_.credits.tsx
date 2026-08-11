import { createFileRoute } from "@tanstack/react-router";
import { Gauge, Receipt, Wallet } from "lucide-react";

import { ComingSoonGate } from "@/components/site/ComingSoonGate";

export const Route = createFileRoute("/ai_/credits")({
  head: () => ({
    meta: [
      { title: "AI Credits — Coming Soon | ANEXOMAIL AI" },
      {
        name: "description",
        content:
          "AI credits, wallet and top-ups belong to the separate ANEXOMAIL AI product. Not open to the public yet.",
      },
      { property: "og:title", content: "AI Credits — Coming Soon | ANEXOMAIL AI" },
      {
        property: "og:description",
        content: "Wallet, credit history and top-ups — part of the separate AI product.",
      },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
    ],
  }),
  component: () => (
    <ComingSoonGate
      title="AI credits are not open yet."
      body="Credits, wallet and top-ups belong to the separate AI product. Your email plan stays a flat monthly price with no AI billing attached to it."
      cards={[
        { icon: Wallet, title: "One wallet", body: "Monthly credits, complimentary credits and top-ups in a single balance." },
        { icon: Gauge, title: "Live burn", body: "Spend today, spend this month and how many days your balance really lasts." },
        { icon: Receipt, title: "Receipt per answer", body: "Model, tokens, latency and exact cost recorded for every single answer." },
      ]}
    />
  ),
});
