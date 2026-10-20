import { Forward, Reply, ReplyAll, X } from "lucide-react";
import { useEffect, useMemo, useRef, useState } from "react";

import { ComposeStudio } from "@/components/app/compose/ComposeStudio";
import { Button } from "@/components/ui/button";
import { type MailThread, useIdentities } from "@/lib/mail";

/**
 * Reading first, writing on request (founder, 20 Oct 2026: "mail pe click karay sirf mail open ho, compose open nahi").
 * Gmail / Zoho jaisa: thread padhne ki jagah; neeche Reply · Reply all · Forward. Button dabane par hi composer
 * khulta hai — wahin thread ke andar (locked: reply thread se bahar nahi jata), aur X se band.
 * Keyboard (Gmail jaisa, sirf jab kuch type na ho raha ho): r = reply, a = reply all, f = forward.
 */
type Mode = "reply" | "all" | "forward";

const uniq = (xs: string[]) => {
  const seen = new Set<string>();
  return xs.filter((x) => {
    const k = x.trim().toLowerCase();
    if (!k || seen.has(k)) return false;
    seen.add(k);
    return true;
  });
};

const withPrefix = (prefix: "Re:" | "Fwd:", subject: string) => {
  const s = (subject || "").trim();
  const re = prefix === "Re:" ? /^re:\s*/i : /^(fwd?|fw):\s*/i;
  return re.test(s) ? s : `${prefix} ${s || "(no subject)"}`.trim();
};

function quoteForForward(m: MailThread["messages"][number] | undefined): string {
  if (!m) return "";
  const when = new Date(m.sent_at).toLocaleString();
  const head = [
    "",
    "",
    "---------- Forwarded message ----------",
    `From: ${m.from_name ? `${m.from_name} <${m.from_address}>` : m.from_address}`,
    `Date: ${when}`,
    `Subject: ${m.subject ?? ""}`,
    m.to.length ? `To: ${m.to.join(", ")}` : "",
    "",
  ].filter((l, i, a) => l !== "" || i < 2 || a[i - 1] !== "");
  return `${head.join("\n")}\n${m.body_text ?? ""}`;
}

export function InlineReply({ thread }: { thread: MailThread }) {
  const [mode, setMode] = useState<Mode | null>(null);
  const [round, setRound] = useState(0); // naya composer har dafa (purana draft state na chipke)
  const identities = useIdentities(true);
  const boxRef = useRef<HTMLDivElement | null>(null);

  const last = thread.messages[thread.messages.length - 1];
  // "Reply" us ko jata hai jis ne aakhri mail bheji — agar aakhri mail meri hi thi, to us ko jis ko maine bheji thi.
  const mine = useMemo(() => {
    const own = new Set((identities.data?.identities ?? []).map((i) => i.address.toLowerCase()));
    if (thread.account_address) own.add(thread.account_address.toLowerCase());
    return own;
  }, [identities.data, thread.account_address]);

  const target = useMemo(() => {
    if (!last) return { to: "", all: "" };
    const fromMe = last.direction === "out" || mine.has((last.from_address ?? "").toLowerCase());
    const replyTo = fromMe ? uniq(last.to) : uniq([last.from_address ?? ""]);
    // Reply all = poori guftagu ke sab log (Gmail jaisa), mere apne pate chhod kar.
    const everyone = uniq(
      thread.messages.flatMap((m) => [m.from_address ?? "", ...m.to, ...m.cc]),
    ).filter((a) => !mine.has(a.toLowerCase()));
    return { to: replyTo.join(", "), all: (everyone.length ? everyone : replyTo).join(", ") };
  }, [last, mine, thread.messages]);

  const open = (m: Mode) => {
    setMode(m);
    setRound((r) => r + 1);
  };

  // Composer khulte hi us tak scroll (lambi thread mein bhi nazar aaye).
  useEffect(() => {
    if (mode) boxRef.current?.scrollIntoView({ behavior: "smooth", block: "nearest" });
  }, [mode, round]);

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.metaKey || e.ctrlKey || e.altKey || e.defaultPrevented) return;
      const el = e.target as HTMLElement | null;
      if (el && (el.isContentEditable || /^(INPUT|TEXTAREA|SELECT)$/.test(el.tagName))) return;
      if (mode) return;
      const k = e.key.toLowerCase();
      if (k === "r") open("reply");
      else if (k === "a") open("all");
      else if (k === "f") open("forward");
      else return;
      e.preventDefault();
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [mode]);

  if (!mode) {
    return (
      <div className="flex flex-wrap items-center gap-2 pt-ax-1" role="toolbar" aria-label="Reply options">
        <Button type="button" variant="outline" className="ax-press ax-tap gap-2 rounded-full" onClick={() => open("reply")}>
          <Reply className="size-4" aria-hidden="true" /> Reply
        </Button>
        {target.all && target.all !== target.to && (
          <Button type="button" variant="outline" className="ax-press ax-tap gap-2 rounded-full" onClick={() => open("all")}>
            <ReplyAll className="size-4" aria-hidden="true" /> Reply all
          </Button>
        )}
        <Button type="button" variant="outline" className="ax-press ax-tap gap-2 rounded-full" onClick={() => open("forward")}>
          <Forward className="size-4" aria-hidden="true" /> Forward
        </Button>
        <span className="ax-caption ml-auto hidden text-muted-foreground lg:inline">r reply · a all · f forward</span>
      </div>
    );
  }

  const title = mode === "forward" ? "Forward" : mode === "all" ? "Reply all" : "Reply";
  return (
    <div ref={boxRef} className="flex flex-col gap-2">
      <div className="flex items-center justify-between px-1">
        <p className="ax-eyebrow">{title}</p>
        <button
          type="button"
          onClick={() => setMode(null)}
          aria-label={`Close ${title.toLowerCase()}`}
          title="Close"
          className="ax-press ax-tap ax-focus grid size-9 place-items-center rounded-lg text-muted-foreground transition-colors hover:bg-muted hover:text-foreground"
        >
          <X className="size-4" aria-hidden="true" />
        </button>
      </div>
      <ComposeStudio
        key={`${mode}-${round}`}
        variant="inline"
        {...(mode === "forward" ? {} : { threadId: thread.id })}
        initialTo={mode === "forward" ? "" : mode === "all" ? target.all : target.to}
        initialSubject={withPrefix(mode === "forward" ? "Fwd:" : "Re:", thread.subject)}
        {...(mode === "forward" ? { initialBody: quoteForForward(last) } : {})}
        {...(thread.account_address ? { initialIdentity: thread.account_address } : {})}
        {...(last && mode !== "forward" ? { inReplyTo: last.id } : {})}
        onSent={() => setMode(null)}
      />
    </div>
  );
}
