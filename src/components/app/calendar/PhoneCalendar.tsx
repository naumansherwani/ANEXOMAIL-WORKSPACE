import { Check, Copy, KeyRound, Loader2, Smartphone, Trash2 } from "lucide-react";
import { useState } from "react";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import {
  DAV_SERVER,
  keyAge,
  MAX_APP_KEYS,
  useAppKeys,
  useCreateAppKey,
  useRevokeAppKey,
  type NewKey,
} from "@/lib/caldav";
import { notify } from "@/lib/notify";

/**
 * Phone calendar (CalDAV, read-only): your phone's calendar app shows your ANEXOMAIL events.
 * Each device gets its own app password — shown once, revocable. Nothing you do on the phone is written back (yet).
 */
export function PhoneCalendar() {
  const list = useAppKeys();
  const create = useCreateAppKey();
  const revoke = useRevokeAppKey();
  const [label, setLabel] = useState("");
  const [fresh, setFresh] = useState<NewKey | null>(null);
  const [copied, setCopied] = useState<string | null>(null);
  const keys = list.data?.keys ?? [];
  const full = keys.length >= MAX_APP_KEYS;

  const copy = async (what: string, text: string) => {
    try {
      await navigator.clipboard.writeText(text);
      setCopied(what);
      setTimeout(() => setCopied(null), 1500);
    } catch {
      notify.failed("Could not copy", { description: "Select the text and copy it by hand." });
    }
  };

  const make = () => {
    if (create.isPending || full) return;
    create.mutate(
      { label: label.trim() || "My phone" },
      {
        onSuccess: (r) => {
          setFresh(r);
          setLabel("");
        },
        onError: (e) => notify.failed("Could not create the password", { description: e.message }),
      },
    );
  };

  return (
    <section aria-labelledby="cs-phone">
      <p id="cs-phone" className="ax-eyebrow">
        Phone calendar
      </p>
      <p className="ax-caption mt-1 text-muted-foreground">
        See your ANEXOMAIL meetings in the calendar app on your phone or computer. Read-only for
        now: changes made there are not sent back. Each device gets its own password, which you can
        remove at any time.
      </p>

      {list.error ? (
        <p role="alert" className="mt-2 text-[12px] text-muted-foreground">
          Phone calendar is not switched on for this workspace yet.
        </p>
      ) : (
        <>
          {fresh && (
            <div className="mt-3 rounded-md border border-border bg-muted/40 p-3" role="status">
              <p className="text-[12px] font-medium">
                Copy this password now. It is shown only once.
              </p>
              <div className="mt-2 grid gap-2">
                {(
                  [
                    ["Server", DAV_SERVER],
                    ["Username", fresh.username],
                    ["Password", fresh.key],
                  ] as const
                ).map(([k, v]) => (
                  <div key={k} className="flex items-center gap-2">
                    <span className="w-16 shrink-0 text-[11px] text-muted-foreground">{k}</span>
                    <code className="min-w-0 flex-1 break-all rounded bg-background px-2 py-1 text-[12px]">
                      {v}
                    </code>
                    <Button
                      type="button"
                      variant="ghost"
                      size="sm"
                      className="ax-tap shrink-0"
                      aria-label={`Copy ${k.toLowerCase()}`}
                      onClick={() => void copy(k, v)}
                    >
                      {copied === k ? <Check className="h-4 w-4" /> : <Copy className="h-4 w-4" />}
                    </Button>
                  </div>
                ))}
              </div>
              <ul className="mt-3 list-disc space-y-1 pl-4 text-[12px] text-muted-foreground">
                <li>
                  iPhone / Mac: Settings → Calendar → Accounts → Add → Other → Add CalDAV Account.
                </li>
                <li>
                  Android: install DAVx5 and add an account with the server, username and password
                  above.
                </li>
                <li>
                  Thunderbird: New Calendar → On the Network → CalDAV, then the username and
                  password.
                </li>
              </ul>
              <Button
                type="button"
                variant="outline"
                size="sm"
                className="ax-tap mt-3"
                onClick={() => setFresh(null)}
              >
                I have copied it
              </Button>
            </div>
          )}

          <div className="mt-3 flex flex-wrap items-center gap-2">
            <Input
              value={label}
              maxLength={40}
              onChange={(e) => setLabel(e.target.value)}
              placeholder="Device name, e.g. My iPhone"
              aria-label="Device name"
              className="min-w-0 flex-1"
              disabled={full}
              onKeyDown={(e) => e.key === "Enter" && make()}
            />
            <Button
              type="button"
              size="sm"
              className="ax-tap"
              onClick={make}
              disabled={create.isPending || full}
            >
              {create.isPending ? (
                <Loader2 className="h-4 w-4 animate-spin" />
              ) : (
                <KeyRound className="h-4 w-4" />
              )}
              <span className="ml-1">Create password</span>
            </Button>
          </div>
          {full && (
            <p className="ax-caption mt-1 text-muted-foreground">
              Limit of {MAX_APP_KEYS} passwords reached. Remove one first.
            </p>
          )}

          {keys.length > 0 && (
            <ul className="mt-3 divide-y divide-border rounded-md border border-border">
              {keys.map((k) => (
                <li key={k.id} className="flex items-center gap-2 px-3 py-2">
                  <Smartphone className="h-4 w-4 shrink-0 text-muted-foreground" aria-hidden />
                  <div className="min-w-0 flex-1">
                    <p className="truncate text-[13px]">{k.label || "Device"}</p>
                    <p className="text-[11px] text-muted-foreground">{keyAge(k.last_used_at)}</p>
                  </div>
                  <Button
                    type="button"
                    variant="ghost"
                    size="sm"
                    className="ax-tap shrink-0"
                    aria-label={`Remove ${k.label || "device"} password`}
                    disabled={revoke.isPending}
                    onClick={() =>
                      revoke.mutate(
                        { id: k.id },
                        {
                          onError: (e) =>
                            notify.failed("Could not remove it", { description: e.message }),
                        },
                      )
                    }
                  >
                    <Trash2 className="h-4 w-4" />
                  </Button>
                </li>
              ))}
            </ul>
          )}
        </>
      )}
    </section>
  );
}
