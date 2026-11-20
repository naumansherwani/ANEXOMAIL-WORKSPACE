// QC3-B: the schedule presets in Karachi time: Later today, Tonight, Tomorrow, Monday, Custom. A preset fills the same datetime-local box the mail already had ("Custom" is that box),
// so nothing about how a scheduled mail is sent changes. Pure rules = presend_pure.presets (bun-tested). The server keeps UTC.
import { useEffect, useMemo, useRef, useState } from "react";
import { describeWhen, fromLocalInput, presets, toLocalInput } from "./presend_pure";
import "./presend.css";

export function SchedulePresets({ value, onChange }: { value: string; onChange: (v: string) => void }) {
  const [now, setNow] = useState(() => Date.now());
  const custom = useRef<HTMLInputElement>(null);
  useEffect(() => { const t = window.setInterval(() => setNow(Date.now()), 30_000); return () => window.clearInterval(t); }, []);
  const list = useMemo(() => presets(now), [Math.floor(now / 60_000)]);   // eslint-disable-line react-hooks/exhaustive-deps
  const at = value ? fromLocalInput(value) : null;
  return (
    <div className="sp" role="group" aria-label="Send later (Karachi time)">
      <div className="sp-row">
        {list.map((p) => {
          const v = toLocalInput(Date.parse(p.at));
          return <button key={p.key} type="button" className="sp-b" aria-pressed={value === v} onClick={() => onChange(value === v ? "" : v)}><b>{p.label}</b><span>{p.when}</span></button>;
        })}
        <label className="sp-b sp-custom" aria-pressed={!!value && !list.some((p) => toLocalInput(Date.parse(p.at)) === value)}>
          <b>Custom</b>
          <input ref={custom} type="datetime-local" value={value} onChange={(e) => onChange(e.target.value)} aria-label="Pick a date and time (Karachi time)" />
        </label>
      </div>
      {value && <p className="sp-pick" role="status">{at ? <>Will send <b>{describeWhen(at, now)}</b> Karachi time.</> : "That date and time does not exist."} <button type="button" className="mc-link" onClick={() => onChange("")}>Send now instead</button></p>}
    </div>
  );
}
