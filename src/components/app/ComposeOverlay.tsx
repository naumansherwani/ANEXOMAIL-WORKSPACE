import { useMutation } from "@tanstack/react-query";
import { Loader2, Minus, Send, X } from "lucide-react";
import { useState } from "react";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { api, ApiError } from "@/lib/api";
import { notify } from "@/lib/notify";

/**
 * Compose overlay — locked behaviour: a new email never takes over the
 * surface. It floats bottom-right so the panel behind it keeps its context.
 * (Replies inside a thread stay inline; that lives in the thread view.)
 *
 * Sending is the backend's job: POST /api/mail/send. Until that route exists
 * the failure is shown honestly — the draft is never silently dropped.
 */
export function ComposeOverlay({ onClose }: { onClose: () => void }) {
  const [minimised, setMinimised] = useState(false);
  const [to, setTo] = useState("");
  const [subject, setSubject] = useState("");
  const [body, setBody] = useState("");

  const send = useMutation({
    mutationFn: () =>
      api("/api/mail/send", {
        method: "POST",
        body: JSON.stringify({ to, subject, body }),
      }),
    onSuccess: () => {
      notify.done("Sent", "The message left your workspace.");
      onClose();
    },
    onError: (error: ApiError) =>
      notify.failed(
        error.isNotImplemented ? "Sending is not wired yet" : "Not sent",
        {
          description: error.isNotImplemented
            ? "Your draft is still here. POST /api/mail/send is pending on the server."
            : error.message,
        },
      ),
  });

  return (
    <aside
      aria-label="New email"
      className="ax-in fixed bottom-4 right-4 z-50 w-[min(30rem,calc(100vw-2rem))] overflow-hidden rounded-2xl border border-border bg-card shadow-2xl"
    >
      <header className="flex items-center gap-ax-2 border-b border-border px-ax-4 py-ax-3">
        <h2 className="ax-label text-foreground">New email</h2>
        <div className="ml-auto flex items-center gap-1">
          <button
            type="button"
            aria-label={minimised ? "Expand compose" : "Minimise compose"}
            onClick={() => setMinimised((v) => !v)}
            className="ax-press ax-tap rounded-lg p-1.5 text-steel hover:bg-secondary"
          >
            <Minus className="size-4" />
          </button>
          <button
            type="button"
            aria-label="Close compose"
            onClick={onClose}
            className="ax-press ax-tap rounded-lg p-1.5 text-steel hover:bg-secondary"
          >
            <X className="size-4" />
          </button>
        </div>
      </header>

      {!minimised && (
        <form
          className="flex flex-col gap-ax-3 p-ax-4"
          onSubmit={(event) => {
            event.preventDefault();
            send.mutate();
          }}
        >
          <div className="flex flex-col gap-1.5">
            <Label htmlFor="compose-to">To</Label>
            <Input
              id="compose-to"
              type="email"
              required
              autoComplete="off"
              value={to}
              onChange={(e) => setTo(e.target.value)}
              placeholder="name@company.com"
            />
          </div>
          <div className="flex flex-col gap-1.5">
            <Label htmlFor="compose-subject">Subject</Label>
            <Input
              id="compose-subject"
              required
              value={subject}
              onChange={(e) => setSubject(e.target.value)}
            />
          </div>
          <div className="flex flex-col gap-1.5">
            <Label htmlFor="compose-body">Message</Label>
            <Textarea
              id="compose-body"
              required
              rows={7}
              value={body}
              onChange={(e) => setBody(e.target.value)}
            />
          </div>
          <Button type="submit" className="ax-press ax-tap self-end" disabled={send.isPending}>
            {send.isPending ? (
              <Loader2 className="size-4 animate-spin" />
            ) : (
              <Send className="size-4" />
            )}
            <span>Send</span>
          </Button>
        </form>
      )}
    </aside>
  );
}