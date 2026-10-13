import { Outlet, createFileRoute } from "@tanstack/react-router";

import { CrmStage } from "@/components/app/crm/CrmStage";

export const Route = createFileRoute("/app/crm")({
  head: () => ({
    meta: [
      { title: "CRM — ANEXOMAIL Workspace" },
      {
        name: "description",
        content:
          "Leads and pipeline that live next to mail — every number comes from real people and deals, not a second product.",
      },
      { property: "og:title", content: "CRM — ANEXOMAIL Workspace" },
      {
        property: "og:description",
        content: "A CRM built beside your inbox: leads, pipeline, shared work.",
      },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: CrmLayout,
});

/**
 * CRM shell — secondary nav (236px) lives in CrmStage; har page ka apna
 * title content ke andar hota hai. Top header yahan nahi.
 */
function CrmLayout() {
  return (
    <CrmStage>
      <Outlet />
    </CrmStage>
  );
}
