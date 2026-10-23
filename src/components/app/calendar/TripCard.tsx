import { Plane, X } from "lucide-react";
import { useMemo, useState } from "react";

import { useCalPrefs, useSaveCalPrefs } from "@/lib/calprefs";
import { searchPlaces, type Place } from "@/lib/places";
import { buildTrip, tripLine, tripPhase } from "@/lib/travel";
import { cn } from "@/lib/utils";

const fmtMine = (iso: string) =>
  new Date(iso).toLocaleString(undefined, {
    weekday: "short",
    day: "numeric",
    month: "short",
    hour: "2-digit",
    minute: "2-digit",
  });
const fmtThere = (iso: string, zone: string) => {
  try {
    return new Date(iso).toLocaleTimeString(undefined, {
      timeZone: zone,
      hour: "2-digit",
      minute: "2-digit",
    });
  } catch {
    return "";
  }
};

/**
 * "Travelling" (opt-in). The person TYPES the destination and the two times — nothing is tracked, no flight or location data is read.
 * While in transit, in-app reminder pop-ups wait until landing; mail is never held. Universal UI (Rule 37): same for every package.
 */
export function TripCard({ here, className }: { here: string; className?: string }) {
  const prefs = useCalPrefs();
  const save = useSaveCalPrefs();
  const [open, setOpen] = useState(false);
  const [q, setQ] = useState("");
  const [dest, setDest] = useState<Place | null>(null);
  const [dep, setDep] = useState("");
  const [arr, setArr] = useState("");
  const [err, setErr] = useState("");
  const results = useMemo(
    () => (q.trim().length >= 2 && !dest ? searchPlaces(q, 5) : []),
    [q, dest],
  );

  const trip = prefs.travel;
  const now = Date.now();
  const phase = trip ? tripPhase(trip, now) : "over";
  const line = trip && phase !== "over" ? tripLine(trip, now, fmtMine, fmtThere) : "";

  const submit = () => {
    const r = buildTrip(
      { city: dest?.city ?? "", zone: dest?.iana ?? "", departLocal: dep, arriveLocal: arr },
      here,
      Date.now(),
    );
    if (!r.ok) {
      setErr(r.error);
      return;
    }
    setErr("");
    save.mutate(
      { travel: r.trip },
      {
        onSuccess: () => {
          setOpen(false);
          setDest(null);
          setQ("");
          setDep("");
          setArr("");
        },
        onError: (e) => setErr(e.message || "Could not save the trip."),
      },
    );
  };

  return (
    <div className={cn("rounded-md border border-border px-2.5 py-2 text-[12px]", className)}>
      <div className="flex items-center gap-1.5">
        <Plane className="size-3.5 shrink-0 text-muted-foreground" aria-hidden="true" />
        <span className="font-semibold text-foreground">Travelling</span>
        {trip && phase !== "over" ? (
          <button
            type="button"
            aria-label="Remove trip"
            onClick={() => save.mutate({ travel: null })}
            disabled={save.isPending}
            className="ax-press ax-focus ml-auto rounded p-0.5 text-muted-foreground hover:text-foreground"
          >
            <X className="size-3.5" aria-hidden="true" />
          </button>
        ) : (
          !open && (
            <button
              type="button"
              onClick={() => setOpen(true)}
              className="ax-press ax-focus ml-auto rounded px-1 font-semibold text-foreground underline-offset-4 hover:underline"
            >
              Add a trip
            </button>
          )
        )}
      </div>

      {trip && phase !== "over" && (
        <>
          <p className="mt-1 text-foreground">{line}</p>
          {phase === "transit" && (
            <p className="mt-0.5 text-muted-foreground">
              Reminder pop-ups wait until you land. Mail still arrives as usual.
            </p>
          )}
        </>
      )}
      {!trip && !open && (
        <p className="mt-1 text-muted-foreground">
          Optional. Tell us where you are going and when; we only show the time there. Nothing is
          tracked.
        </p>
      )}

      {open && (
        <div className="mt-2 space-y-2">
          <label className="block text-muted-foreground">
            Going to
            {dest ? (
              <span className="mt-1 flex items-center gap-2 rounded-md border border-border px-2 py-1.5 text-foreground">
                <span className="min-w-0 flex-1 truncate font-semibold">
                  {dest.city}
                  <span className="ml-1 font-normal text-muted-foreground">{dest.country}</span>
                </span>
                <button
                  type="button"
                  aria-label="Change destination"
                  onClick={() => setDest(null)}
                  className="ax-press ax-focus rounded p-0.5"
                >
                  <X className="size-3.5" aria-hidden="true" />
                </button>
              </span>
            ) : (
              <input
                value={q}
                onChange={(e) => setQ(e.target.value)}
                placeholder="City (Tokyo, London…)"
                className="mt-1 w-full rounded-md border border-border bg-background px-2.5 py-1.5 text-[13px] text-foreground outline-none focus-visible:ring-2 focus-visible:ring-ring"
              />
            )}
          </label>
          {results.length > 0 && (
            <ul className="max-h-36 overflow-y-auto rounded-md border border-border">
              {results.map((p) => (
                <li key={`${p.city}-${p.iana}`}>
                  <button
                    type="button"
                    onClick={() => setDest(p)}
                    className="ax-press flex w-full items-center gap-2 px-2.5 py-1.5 text-left text-[13px] hover:bg-secondary"
                  >
                    <span className="min-w-0 flex-1 truncate">
                      {p.city}
                      <span className="ml-1 text-muted-foreground">{p.country}</span>
                    </span>
                  </button>
                </li>
              ))}
            </ul>
          )}
          <label className="block text-muted-foreground">
            Leaves — your local time
            <input
              type="datetime-local"
              value={dep}
              onChange={(e) => setDep(e.target.value)}
              className="mt-1 w-full rounded-md border border-border bg-background px-2.5 py-1.5 text-base text-foreground outline-none focus-visible:ring-2 focus-visible:ring-ring"
            />
          </label>
          <label className="block text-muted-foreground">
            Arrives — local time in {dest?.city ?? "the destination"}
            <input
              type="datetime-local"
              value={arr}
              onChange={(e) => setArr(e.target.value)}
              className="mt-1 w-full rounded-md border border-border bg-background px-2.5 py-1.5 text-base text-foreground outline-none focus-visible:ring-2 focus-visible:ring-ring"
            />
          </label>
          {err && (
            <p role="alert" className="text-danger">
              {err}
            </p>
          )}
          <div className="flex items-center gap-2">
            <button
              type="button"
              onClick={submit}
              disabled={save.isPending}
              className="ax-press ax-focus ax-tap rounded-md bg-primary px-3 py-1.5 font-semibold text-primary-foreground disabled:opacity-60"
            >
              {save.isPending ? "Saving…" : "Save trip"}
            </button>
            <button
              type="button"
              onClick={() => {
                setOpen(false);
                setErr("");
              }}
              className="ax-press ax-focus ax-tap rounded-md px-2 py-1.5 text-muted-foreground hover:text-foreground"
            >
              Cancel
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
