import { Check, Copy, ExternalLink, Link2, Loader2, Trash2 } from "lucide-react";
import { useState } from "react";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import {
  feedUrl,
  googleAddUrl,
  keyAge,
  MAX_FEED_LINKS,
  useCreateFeedLink,
  useFeedLinks,
  useRevokeFeedLink,
} from "@/lib/caldav";
import { notify } from "@/lib/notify";

/**
 * "No app" way: a secret, read-only calendar link for Google Calendar (Add by URL).
 * Works on every Android/iPhone without installing anything. The link is shown ONCE (only its hash is stored); remove it any time.
 */
export function PhoneFeed() {
  const list = useFeedLinks();
  const create = useCreateFeedLink();
  const revoke = useRevokeFeedLink();
  const [label, setLabel] = useState("");
  const [fresh, setFresh] = useState<string | null>(null);
  const [copied, setCopied] = useState(false);
  const links = list.data?.keys ?? [];
  const full = links.length >= MAX_FEED_LINKS;

  const copy = async (text: string) => {
    try {
      await navigator.clipboard.writeText(text);
      setCopied(true);
      setTimeout(() => setCopied(false), 1500);
    } catch {
      notify.failed("Could not copy", { description: "Select the link and copy it by hand." });
    }
  };

  const make = () => {
    if (create.isPending || full) return;
    create.mutate(
      { label: label.trim() || "Google Calendar" },
      {
        onSuccess: (r) => {
          const u = feedUrl(r.path);
          if (!u) {
            notify.failed("Could not create the link", {
              description: "Unexpected answer from the server.",
            });
            return;
          }
          setFresh(u);
          setLabel("");
        },
        onError: (e) => notify.failed("Could not create the link", { description: e.message }),
      },
    );
  };

  if (list.error) {
    return (
      <p role="alert" className="mt-2 text-[12px] text-muted-foreground">
        Calendar link is not switched on for this workspace yet.
      </p>
    );
  }

  return (
    <div>
      <p className="ax-caption mt-1 text-muted-foreground">
        The simplest way. No app to install: you get a private link and add it once in Google
        Calendar. Your meetings then show up in the Google Calendar app on your phone. It is
        read-only, and Google refreshes it about once or twice a day, so a new meeting can take many
        hours to appear.
      </p>

      {fresh && (
        <div className="mt-3 rounded-md border border-border bg-muted/40 p-3" role="status">
          <p className="text-[12px] font-medium">
            Copy this link now. It is shown only once, and it works like a password.
          </p>
          <div className="mt-2 flex items-center gap-2">
            <code className="min-w-0 flex-1 break-all rounded bg-background px-2 py-1 text-[12px]">
              {fresh}
            </code>
            <Button
              type="button"
              variant="ghost"
              size="sm"
              className="ax-tap shrink-0"
              aria-label="Copy link"
              onClick={() => void copy(fresh)}
            >
              {copied ? <Check className="h-4 w-4" /> : <Copy className="h-4 w-4" />}
            </Button>
          </div>
          <a
            href={googleAddUrl(fresh)}
            target="_blank"
            rel="noopener noreferrer"
            className="ax-press ax-focus ax-tap mt-3 inline-flex min-h-11 items-center gap-1.5 rounded-md border border-border px-3 text-[12px] font-semibold text-foreground"
          >
            <ExternalLink className="h-4 w-4" aria-hidden /> Add to Google Calendar
          </a>
          <ol className="mt-3 list-decimal space-y-1.5 pl-5 text-[12px] text-muted-foreground">
            <li>Tap “Add to Google Calendar”. Google asks to add the calendar: confirm.</li>
            <li>
              If it does not ask: on a computer open calendar.google.com, then Other calendars (+) →
              From URL, paste the link and press Add calendar.
            </li>
            <li>
              On your Android phone open the Google Calendar app (same Google account). Menu →
              Settings → find “ANEXOMAIL” and make sure it is switched on.
            </li>
          </ol>
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
          placeholder="Name, e.g. My Google Calendar"
          aria-label="Link name"
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
            <Link2 className="h-4 w-4" />
          )}
          <span className="ml-1">Create link</span>
        </Button>
      </div>
      {full && (
        <p className="ax-caption mt-1 text-muted-foreground">
          Limit of {MAX_FEED_LINKS} links reached. Remove one first.
        </p>
      )}

      {links.length > 0 && (
        <ul className="mt-3 divide-y divide-border rounded-md border border-border">
          {links.map((k) => (
            <li key={k.id} className="flex items-center gap-2 px-3 py-2">
              <Link2 className="h-4 w-4 shrink-0 text-muted-foreground" aria-hidden />
              <div className="min-w-0 flex-1">
                <p className="truncate text-[13px]">{k.label || "Calendar link"}</p>
                <p className="text-[11px] text-muted-foreground">
                  {keyAge(k.last_used_at).replace("Used", "Last read")}
                </p>
              </div>
              <Button
                type="button"
                variant="ghost"
                size="sm"
                className="ax-tap shrink-0"
                aria-label={`Remove ${k.label || "calendar"} link`}
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
      {links.length > 0 && (
        <p className="ax-caption mt-2 text-muted-foreground">
          Removing a link stops it at once. Also remove the calendar inside Google Calendar, or it
          keeps showing the old meetings. The link cannot be shown again: if you lose it, create a
          new one.
        </p>
      )}
    </div>
  );
}
