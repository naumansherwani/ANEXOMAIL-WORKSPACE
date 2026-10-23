import { Check, Copy, KeyRound, Loader2, Smartphone, Trash2 } from "lucide-react";
import { useState } from "react";

import { PhoneFeed } from "@/components/app/calendar/PhoneFeed";
import { cn } from "@/lib/utils";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import {
  DAV_SERVER,
  DAV_URL,
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
  const [method, setMethod] = useState<"link" | "app">("link");
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
        See your ANEXOMAIL meetings in the calendar on your phone or computer. Read-only for now:
        changes made there are not sent back. Choose how you want to connect.
      </p>
      <div role="tablist" aria-label="How to connect" className="mt-2 grid gap-1.5 sm:grid-cols-2">
        {(
          [
            [
              "link",
              "No app (Google Calendar)",
              "Easiest. A private link. Updates once or twice a day.",
            ],
            ["app", "Calendar app", "DAVx5, iPhone or Thunderbird. Updates within minutes."],
          ] as const
        ).map(([k, title, sub]) => (
          <button
            key={k}
            type="button"
            role="tab"
            aria-selected={method === k}
            onClick={() => setMethod(k)}
            className={cn(
              "ax-press ax-focus ax-tap rounded-md border p-2.5 text-left",
              method === k ? "border-cyan-accent/50 bg-secondary" : "border-border",
            )}
          >
            <span className="block text-[13px] font-semibold text-foreground">{title}</span>
            <span className="mt-0.5 block text-[11px] text-muted-foreground">{sub}</span>
          </button>
        ))}
      </div>

      {method === "link" ? <PhoneFeed /> : null}

      {method !== "app" ? null : list.error ? (
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
                    ["Link", DAV_URL],
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

          <HowTo />

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

type Device = "android" | "iphone" | "computer";

const STEPS: Record<Device, { title: string; steps: string[] }> = {
  android: {
    title: "Android phone",
    steps: [
      "Install the app DAVx5. It is free from F-Droid (f-droid.org) and a paid app on the Play Store. Your phone's own Calendar app cannot add this kind of account by itself.",
      "Open DAVx5, tap the + button, then choose \u201cLogin with URL and user name\u201d.",
      "Base URL: the Link shown above. User name: your email. Password: the 30-letter password. Tap Login.",
      "Switch the calendar on in the list and tap the refresh icon. Allow Calendar access if it asks.",
      "Open your phone's Calendar app. Your ANEXOMAIL meetings appear there.",
    ],
  },
  iphone: {
    title: "iPhone / iPad",
    steps: [
      "Settings \u2192 Calendar \u2192 Accounts \u2192 Add Account \u2192 Other \u2192 Add CalDAV Account.",
      "Server: anexomail.com. User name: your email. Password: the 30-letter password. Tap Next.",
      "Open the Calendar app. Your ANEXOMAIL meetings appear there.",
    ],
  },
  computer: {
    title: "Computer",
    steps: [
      "Thunderbird: Calendar \u2192 New Calendar \u2192 On the Network \u2192 CalDAV.",
      "Location: the Link shown above. Then your email and the 30-letter password.",
      "Mac: Calendar \u2192 Add Account \u2192 Other CalDAV Account.",
    ],
  },
};

/** Plain-language steps, always visible, so nobody has to guess what to do with the password. */
function HowTo() {
  const [d, setD] = useState<Device>("android");
  return (
    <div className="mt-3 rounded-md border border-border p-3">
      <p className="text-[12px] font-medium">How to connect</p>
      <p className="ax-caption mt-1 text-muted-foreground">
        The password below is not your login password. It only lets a calendar app read your
        meetings. If you open the link in a browser you will just see “Sign in with your email and a
        CalDAV app password”: that is normal, the link is for apps, not for people.
      </p>
      <div role="tablist" aria-label="Device" className="mt-2 flex flex-wrap gap-1">
        {(Object.keys(STEPS) as Device[]).map((k) => (
          <button
            key={k}
            type="button"
            role="tab"
            aria-selected={d === k}
            onClick={() => setD(k)}
            className={cn(
              "ax-press ax-tap rounded-md border px-3 text-[12px] font-semibold",
              d === k
                ? "border-cyan-accent/50 bg-secondary text-foreground"
                : "border-border text-muted-foreground",
            )}
          >
            {STEPS[k].title}
          </button>
        ))}
      </div>
      <ol className="mt-2 list-decimal space-y-1.5 pl-5 text-[12px] text-muted-foreground">
        {STEPS[d].steps.map((t) => (
          <li key={t}>{t}</li>
        ))}
      </ol>
    </div>
  );
}
