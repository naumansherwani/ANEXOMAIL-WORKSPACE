import { useState } from "react";
import { LocateFixed, MapPin, X } from "lucide-react";

import { Button } from "@/components/ui/button";
import { useCalPrefs, useSaveCalPrefs } from "@/lib/calprefs";
import { notify } from "@/lib/notify";
import { nearestPlace, placeLabel, searchPlaces, type Place } from "@/lib/places";
import { zoneCity } from "@/lib/timeFormat";

type Found = { place: Place; km: number };

function geoMessage(code: number): string {
  if (code === 1)
    return "Location is blocked for this site. Allow it in the browser's address bar, or search for your city below.";
  if (code === 2) return "Your device could not work out where it is. Search for your city below.";
  if (code === 3) return "That took too long. Try again, or search for your city below.";
  return "Could not detect your city. Search for it below.";
}

/**
 * Home city — one place that the greeting (sunset-aware), the clock's name and the working-hours zone all follow.
 * Detect asks the browser once; the nearest city of a bundled list is picked ON THIS DEVICE and only that city is saved.
 * The exact position is never sent and never stored.
 */
export function HomePlaceCard() {
  const prefs = useCalPrefs();
  const save = useSaveCalPrefs();
  const [query, setQuery] = useState("");
  const [busy, setBusy] = useState(false);
  const [found, setFound] = useState<Found | null>(null);
  const [problem, setProblem] = useState<string | null>(null);

  const device = zoneCity();
  const hits = searchPlaces(query);

  const choose = (p: Place) =>
    save.mutate(
      { home: { city: p.city, country: p.country, iana: p.iana, lat: p.lat, lon: p.lon } },
      {
        onSuccess: () => {
          setFound(null);
          setQuery("");
          setProblem(null);
          notify.done("Home city saved", `${placeLabel(p)} — your greeting and clock follow it.`);
        },
        onError: (e) =>
          notify.failed(e.isNotImplemented ? "Not wired yet" : "Could not save", {
            description: e.message,
          }),
      },
    );

  const remove = () =>
    save.mutate(
      { home: null },
      {
        onSuccess: () => notify.done("Home city removed", "Your device's time zone is used again."),
        onError: (e) => notify.failed("Could not save", { description: e.message }),
      },
    );

  const detect = () => {
    setProblem(null);
    setFound(null);
    if (!("geolocation" in navigator)) {
      setProblem("This browser cannot detect your location. Search for your city below.");
      return;
    }
    setBusy(true);
    navigator.geolocation.getCurrentPosition(
      (pos) => {
        setBusy(false);
        const n = nearestPlace(pos.coords.latitude, pos.coords.longitude);
        if (!n) setProblem("Could not work out a city from that. Search for it below.");
        else setFound(n);
      },
      (err) => {
        setBusy(false);
        setProblem(geoMessage(err.code));
      },
      { enableHighAccuracy: false, timeout: 12_000, maximumAge: 10 * 60_000 },
    );
  };

  return (
    <section
      className="mx-auto mt-ax-6 w-full max-w-3xl px-ax-4 sm:px-ax-6"
      aria-labelledby="home-city"
    >
      <div className="rounded-xl border border-border p-ax-4">
        <div className="flex items-start gap-3">
          <MapPin className="mt-0.5 size-4 shrink-0 text-muted-foreground" aria-hidden="true" />
          <div className="min-w-0 flex-1">
            <h2 id="home-city" className="text-[14px] font-bold text-foreground">
              Home city
            </h2>
            <p className="ax-caption mt-0.5 text-muted-foreground">
              {prefs.home ? (
                <>
                  <span className="font-semibold text-foreground">{placeLabel(prefs.home)}</span> —
                  your greeting follows its sunset and your clock is named after it.
                </>
              ) : (
                <>
                  Not set. Your device says {device.city}; pick your own city so the greeting
                  follows its sunset.
                </>
              )}
            </p>
            {prefs.home && prefs.home.iana !== device.iana && (
              <p className="ax-caption mt-1 text-amber-400">
                This device is currently in {device.city}. The clock keeps showing the place the
                device really is in.
              </p>
            )}
          </div>
          {prefs.home && (
            <button
              type="button"
              aria-label="Remove home city"
              disabled={save.isPending}
              onClick={remove}
              className="ax-focus ax-press grid size-11 shrink-0 place-items-center rounded-md text-muted-foreground sm:size-8"
            >
              <X className="size-4" />
            </button>
          )}
        </div>

        <div className="mt-ax-3 flex flex-wrap items-center gap-2">
          <Button
            type="button"
            size="sm"
            variant="outline"
            className="min-h-11 sm:min-h-8"
            disabled={busy || save.isPending}
            onClick={detect}
          >
            <LocateFixed className="size-4" />
            {busy ? "Detecting…" : "Detect my city"}
          </Button>
          <p className="ax-caption min-w-0 flex-1 text-muted-foreground">
            Asks your browser once. The nearest city is chosen on your device — your exact position
            is never sent or saved.
          </p>
        </div>

        {found && (
          <div
            className="mt-ax-3 rounded-lg border border-border bg-secondary/40 p-ax-3"
            role="status"
          >
            <p className="text-[13px] text-foreground">
              Closest city we have: <span className="font-semibold">{placeLabel(found.place)}</span>
              {found.km >= 1 ? ` (about ${Math.round(found.km)} km away)` : ""}.
            </p>
            {found.km > 150 && (
              <p className="ax-caption mt-1 text-amber-400">
                That is far from where you are — if your city is not in our list, search below and
                pick the nearest.
              </p>
            )}
            <div className="mt-2 flex gap-2">
              <Button
                type="button"
                size="sm"
                className="min-h-11 sm:min-h-8"
                disabled={save.isPending}
                onClick={() => choose(found.place)}
              >
                Use {found.place.city}
              </Button>
              <Button
                type="button"
                size="sm"
                variant="ghost"
                className="min-h-11 sm:min-h-8"
                onClick={() => setFound(null)}
              >
                Not this
              </Button>
            </div>
          </div>
        )}
        {problem && (
          <p className="ax-caption mt-ax-3 text-amber-400" role="alert">
            {problem}
          </p>
        )}

        <label className="mt-ax-3 block text-[11px] font-semibold text-muted-foreground">
          Or search your city
          <input
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder="Lahore, Dubai, London…"
            autoComplete="off"
            maxLength={40}
            className="ax-focus mt-1 h-10 w-full rounded-md border border-border bg-background px-2 text-base text-foreground sm:text-sm"
          />
        </label>
        {query.trim() && (
          <ul className="mt-2 divide-y divide-border rounded-md border border-border">
            {hits.length === 0 ? (
              <li className="ax-caption px-3 py-2 text-muted-foreground">
                No city by that name in our list. Try a bigger city nearby.
              </li>
            ) : (
              hits.map((p) => (
                <li key={`${p.city}-${p.country}`}>
                  <button
                    type="button"
                    disabled={save.isPending}
                    onClick={() => choose(p)}
                    className="ax-focus flex min-h-11 w-full items-center justify-between gap-3 px-3 py-2 text-left text-[13px] text-foreground hover:bg-secondary/50 sm:min-h-9"
                  >
                    <span className="truncate">{p.city}</span>
                    <span className="ax-caption shrink-0 text-muted-foreground">{p.country}</span>
                  </button>
                </li>
              ))
            )}
          </ul>
        )}
      </div>
    </section>
  );
}
