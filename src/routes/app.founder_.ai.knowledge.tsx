import { createFileRoute } from "@tanstack/react-router";
import { BookOpen, Pin, Quote, Search, Trash2 } from "lucide-react";
import { useState } from "react";

import { CardBody, StatSkeleton } from "@/components/app/dashboard/DashboardCard";
import {
  useAddDocument,
  useAskKnowledge,
  useDeleteDocument,
  useKnowledgeDocs,
  useKnowledgeSearch,
  useKnowledgeSpaces,
  usePinDocument,
  type KnowledgeScope,
} from "@/lib/knowledge";
import { relativeTime } from "@/lib/mail";
import { notify } from "@/lib/notify";

export const Route = createFileRoute("/app/founder_/ai/knowledge")({
  component: FounderKnowledge;
});

function FounderKnowledge() {
  return null;
}
