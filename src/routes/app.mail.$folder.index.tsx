import { createFileRoute } from "@tanstack/react-router";
import { motion } from "framer-motion";
import { MailOpen } from "lucide-react";

import { EmptyState } from "@/components/app/Panel";

export const Route = createFileRoute("/app/mail/$folder/")({
  head: () => ({
    meta: [
      { title: "Mail — ANEXOMAIL Workspace" },
      { name: "robots", content: "noindex" },
    ],
  }),
  component: () => (
    <motion.div
      className="flex h-full min-h-[16rem] items-center justify-center"
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      transition={{ duration: 0.35 }}
    >
      <EmptyState
        icon={<MailOpen className="size-5" />}
        title="Nothing selected"
        body="Pick a thread from the list. j/k to move, Enter to open. Owner, status and notes stay on the thread."
      />
    </motion.div>
  ),
});
