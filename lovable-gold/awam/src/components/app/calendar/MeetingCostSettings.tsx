import { Loader2, PoundSterling } from "lucide-react";
import { useEffect, useState } from "react";

import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { useMeetingRates, useSaveMeetingRates } from "@/lib/calendar";
import { notify } from "@/lib/notify";
import { useProCalendar } from "@/lib/use-pro-calendar";

const parse = (t: string): number | null => {
  const n = Number(t.replace(",", ".").trim());
  return t.trim() !== "" && Number.isFinite(n) && n >= 0 && n <= 10_000 ? n : null;
};

/**
 * Meeting cost (Pro+): what an hour of your time and of a typical guest is worth.
 * The server multiplies it by the meeting length and the people in it; the meter shows next to the invite.
 * 0 switches the meter off. Saved to the account over the WASM kernel (calendar.rates / calendar.rates.set).
 */
export function MeetingCostSettings() {
  const pro = useProCalendar();
  const rates = useMeetingRates(pro);
  const save = useSaveMeetingRates();
  const [mine, setMine] = useState("");
  const [guest, setGuest] = useState("");

  useEffect(() => {
    if (!rates.data) return;
    setMine(rates.data.self ? String(rates.data.self) : "");
    setGuest(rates.data.guest ? String(rates.data.guest) : "");
  }, [rates.data]);

  if (!pro) return null;
  if (rates.isPending) return null;
  if (rates.error) return null;

  const a = mine.trim() === "" ? 0 : parse(mine);
  const b = guest.trim() === "" ? 0 : parse(guest);
  const bad = a === null || b === null;
  const dirty = a !== (rates.data?.self ?? 0) || b !== (rates.data?.guest ?? 0);

  return (
    <section aria-labelledby="meeting-cost-h" className="space-y-ax-2">
      <h3 id="meeting-cost-h" className="ax-caption flex items-center gap-1.5 font-semibold uppercase tracking-wider text-muted-foreground">
        <PoundSterling className="size-3.5" aria-hidden="true" /> Meeting cost
      </h3>
      <p className="ax-caption text-muted-foreground">
        What an hour is worth, in pounds. Each meeting shows its price next to the invite. Leave blank to keep the meter off.
      </p>
      <div className="grid grid-cols-2 gap-ax-2">
        <label className="ax-caption space-y-1">
          <span className="font-semibold text-foreground">Your hourly rate</span>
          <Input inputMode="decimal" value={mine} onChange={(e) => setMine(e.target.value)} placeholder="e.g. 60" className="h-9 text-base sm:text-sm" />
        </label>
        <label className="ax-caption space-y-1">
          <span className="font-semibold text-foreground">Typical guest</span>
          <Input inputMode="decimal" value={guest} onChange={(e) => setGuest(e.target.value)} placeholder="e.g. 40" className="h-9 text-base sm:text-sm" />
        </label>
      </div>
      {bad && <p role="alert" className="ax-caption text-destructive">Use a number from 0 to 10,000.</p>}
      <Button
        size="sm"
        disabled={bad || !dirty || save.isPending}
        onClick={() =>
          save.mutate(
            { self: a ?? 0, guest: b ?? 0 },
            { onSuccess: () => notify.done("Meeting cost rates saved"), onError: (e) => notify.failed("Could not save rates", { description: e.message }) },
          )
        }
      >
        {save.isPending && <Loader2 className="mr-1.5 size-3.5 animate-spin" aria-hidden="true" />}
        Save rates
      </Button>
    </section>
  );
}
