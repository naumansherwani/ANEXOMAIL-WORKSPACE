import { Clock, Loader2, Send } from "lucide-react";
import { useState } from "react";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { notify } from "@/lib/notify";
import { useSendMail, type MailThread } from "@/lib/mail";

/**
 * Locked behaviour: a reply NEVER leaves the thread. It renders inline at the
 * bottom of the conversation, so context never breaks (Superhuman style).
 * Schedule send is the same call with `send_at`.
 */
export function InlineReply({ thread }: { thread: MailThread }) {
  const last = thread.messages[thread.messages.length - 1];
  const [to, setTo] = useState(last?.from_address ?? "");
  const [body, setBody] = useState("");
  const [sendAt, setSendAt] = useState("");
  const [scheduling, setScheduling] = useState(false);
  const send = useSendMail();

  const submit = () => {
    send.mutate(
      {
        to,
        subject: thread.subject,
        body,
        thread_id: thread.id,
        ...(last ? { in_reply_to: last.id } : {}),
        ...(scheduling && sendAt ? { send_at: new Date(sendAt).toISOString() } : {}),
      },
      {
        onSuccess: () => {
          setBody("");
          setSendAt("");
          setScheduling(false);
          notify.done(
            scheduling && sendAt ? "Scheduled" : "Sent",
            scheduling && sendAt
              ? `Leaves at ${new Date(sendAt).toLocaleString()}.`
              : "The reply left your workspace.",
          );
        },
        onError: (error) =>
          notify.failed(error.isNotImplemented ? "Sending is not wired yet" : "Not sent", {
            description: error.isNotImplemented
              ? "Your draft stays here. POST /api/mail/send is pending on the server."
              : error.message,
          }),
      },
    );
  };

  return (
    <form
      className="ax-plane flex flex-col gap-ax-3 rounded-2xl p-ax-4"
      onSubmit={(event) => {
        event.preventDefault();
        submit();
      }}
    >
      <div className="flex flex-col gap-1.5">
        <Label htmlFor="reply-to">Reply to</Label>
        <Input
          id="reply-to"
          type="email"
          required
          value={to}
          onChange={(e) => setTo(e.target.value)}
        />
      </div>
      <Textarea
        aria-label="Reply message"
        required
        rows={5}
        value={body}
        onChange={(e) => setBody(e.target.value)}
        placeholder="Write your reply — it stays in this thread."
        onKeyDown={(e) => {
          if ((e.metaKey || e.ctrlKey) && e.key === "Enter") {
            e.preventDefault();
            submit();
          }
        }}
      />

      {scheduling && (
        <div className="flex flex-col gap-1.5">
          <Label htmlFor="reply-schedule">Send at</Label>
          <Input
            id="reply-schedule"
            type="datetime-local"
            required
            value={sendAt}
            onChange={(e) => setSendAt(e.target.value)}
          />
        </div>
      )}

      <div className="flex items-center gap-ax-2">
        <Button type="submit" className="ax-press ax-tap" disabled={send.isPending}>
          {send.isPending ? <Loader2 className="size-4 animate-spin" /> : <Send className="size-4" />}
          <span>{scheduling ? "Schedule" : "Send"}</span>
        </Button>
        <Button
          type="button"
          variant="ghost"
          className="ax-press"
          onClick={() => setScheduling((v) => !v)}
        >
          <Clock className="size-4" />
          {scheduling ? "Send now instead" : "Schedule send"}
        </Button>
        <span className="ml-auto text-[10px] text-steel">⌘↵ to send</span>
      </div>
    </form>
  );
}
