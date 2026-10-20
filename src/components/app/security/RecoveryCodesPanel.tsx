import { Check, Copy, Download } from "lucide-react";
import { useState } from "react";

import { Button } from "@/components/ui/button";
import { Checkbox } from "@/components/ui/checkbox";
import { notify } from "@/lib/notify";

/**
 * G35 — 10 recovery codes, sirf ek baar. Server mein sirf hash hai: kho jaye to dobara nahi dikhte, sirf naye bante hain.
 * User "maine save kar liye" tick kare tabhi aage.
 */
export function RecoveryCodesPanel({
  codes,
  onDone,
  doneLabel = "Continue",
}: {
  codes: string[];
  onDone: () => void;
  doneLabel?: string;
}) {
  const [saved, setSaved] = useState(false);
  const text = codes.join("\n");

  const copy = async () => {
    try {
      await navigator.clipboard.writeText(text);
      notify.done("Copied", "Keep these codes somewhere safe — not in your mailbox.");
    } catch {
      notify.failed("Could not copy", { description: "Select the codes and copy them by hand." });
    }
  };

  const download = () => {
    const blob = new Blob(
      [
        `ANEXOMAIL recovery codes\nEach code works once. Keep this file offline.\n\n${text}\n`,
      ],
      { type: "text/plain" },
    );
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = "anexomail-recovery-codes.txt";
    a.click();
    URL.revokeObjectURL(url);
  };

  return (
    <div className="text-left" data-testid="recovery-codes">
      <h2 className="ax-heading text-foreground">Save your recovery codes</h2>
      <p className="ax-caption mt-2">
        If you lose your phone and your passkeys, one of these codes signs you in. Each works once. We cannot show them
        again — we only keep a scrambled copy.
      </p>
      <ul className="mt-ax-3 grid grid-cols-2 gap-2 rounded-xl border border-border bg-secondary/40 p-ax-3 font-mono text-sm text-foreground">
        {codes.map((c) => (
          <li key={c} className="tabular-nums tracking-wider">
            {c}
          </li>
        ))}
      </ul>
      <div className="mt-ax-3 flex flex-wrap gap-2">
        <Button type="button" variant="outline" size="sm" onClick={copy}>
          <Copy className="size-4" /> Copy
        </Button>
        <Button type="button" variant="outline" size="sm" onClick={download}>
          <Download className="size-4" /> Download
        </Button>
      </div>
      <label
        htmlFor="codes-saved"
        className="mt-ax-3 flex cursor-pointer items-center gap-2.5 rounded-lg border border-border bg-secondary/40 px-3 py-2.5"
      >
        <Checkbox id="codes-saved" checked={saved} onCheckedChange={(v) => setSaved(v === true)} />
        <span className="ax-caption text-foreground">I have saved these codes somewhere safe.</span>
      </label>
      <Button type="button" className="ax-press mt-ax-3 w-full" disabled={!saved} onClick={onDone}>
        <Check className="size-4" /> {doneLabel}
      </Button>
    </div>
  );
}
