import { useEffect, useMemo, useState } from "react";
import { DeskRefused, deskCall } from "./desk_kernel";
import { UNAVAILABLE_TEXT } from "./desk_lookup_pure";
import { UNVERIFIED_TEXT } from "./desk_bind_pure";
import { DeskCombobox, COMBO_CSS } from "./DeskCombobox";
import { bannedNote, buildNumber, checkWords, lookupWords, numberOk, parseCheck, parseCountries, parseLookup, parseRegisters, registerLabel, NUMBER_MAX, type Country, type Lookup, type Register, type ComboItem } from "./desk_registry_pure";

/** ADMIN DESK B13 T4i (25 Nov 2026): find a company by its REGISTRATION NUMBER. Staff choose the country and the register from the GLEIF list the database holds (the Desk searchable list, DeskCombobox: WAI-ARIA APG combobox with listbox),
 *  type the number, and the Desk answers which company holds it. Read only: nothing is written here. A number shape is only checked when the database has proven one for that register; otherwise the screen says so and uses what was typed.
 *  The company name comes from the Control Plane (signed); a register website is shown as text, never as a link. Every answer is kernel-verified (Rule 52); one that cannot be trusted shows "Data unavailable". Same code on 390 / 820 / 1200+. */
export function DeskRegistryPicker({ onCompany }: { onCompany: (tenantId: string) => void }) {
  const [countries, setCountries] = useState<Country[] | null>(null), [bad, setBad] = useState(false);
  const [country, setCountry] = useState(""), [registers, setRegisters] = useState<Register[] | null>(null), [regId, setRegId] = useState<number | null>(null), [num, setNum] = useState("");
  const [busy, setBusy] = useState(false), [msg, setMsg] = useState(""), [found, setFound] = useState<Lookup | null>(null);
  const fail = (e: unknown) => setMsg(e instanceof DeskRefused ? UNVERIFIED_TEXT : "The Desk could not be reached. Try again.");
  useEffect(() => {
    let live = true;
    deskCall("POST", "/desk/v1/registry/countries", {}).then((r) => { if (!live) return; const c = r.status === 200 ? parseCountries(r.json) : null; if (c) { setCountries(c); setBad(false); } else setBad(true); }).catch(() => { if (live) setBad(true); });
    return () => { live = false; };
  }, []);
  useEffect(() => {
    setRegisters(null); setRegId(null); setMsg(""); setFound(null);
    if (!/^[A-Z]{2}$/.test(country)) return;
    let live = true;
    deskCall("POST", "/desk/v1/registry/pick", { country }).then((r) => { if (!live) return; const g = r.status === 200 ? parseRegisters(r.json) : null; if (g) { setRegisters(g); setRegId(g.length === 1 ? g[0].id : null); } else setMsg(UNAVAILABLE_TEXT); }).catch((e) => { if (live) fail(e); });
    return () => { live = false; };
  }, [country]);
  const countryItems = useMemo<ComboItem[]>(() => (countries ?? []).map((c) => ({ key: c.code, label: c.country, hint: c.code, note: undefined })), [countries]);
  const registerItems = useMemo<ComboItem[]>(() => (registers ?? []).map((r) => ({ key: String(r.id), label: r.name || r.authority || r.raCode, hint: undefined, note: `${r.authority && r.authority !== r.name ? r.authority + " · " : ""}${r.raCode}${r.shapeKnown ? "" : " · number shape not proven"}` })), [registers]);
  const body = buildNumber(regId, num), chosen = registers?.find((r) => r.id === regId) ?? null;
  async function run(path: string, then: (j: unknown, status: number) => void) {
    if (!body) return; setBusy(true); setMsg(""); setFound(null);
    try { const r = await deskCall("POST", path, body); then(r.json, r.status); } catch (e) { fail(e); }
    setBusy(false);
  }
  const check = () => void run("/desk/v1/registry/check", (j, st) => setMsg(checkWords(st === 200 ? parseCheck(j) : null)));
  const find = () => void run("/desk/v1/registry/lookup", (j, st) => { const l = st === 200 ? parseLookup(j) : null; setFound(l); setMsg(lookupWords(l)); });
  return (
    <section className="dbx-box" aria-labelledby="dbx-reg-h"><style>{COMBO_CSS + ".dbx-f{display:grid;gap:6px;min-width:0;font-size:13px;color:var(--mute)}"}</style><h3 id="dbx-reg-h">Find the company by its registration number</h3>
      {bad && <p role="status"><b>{UNAVAILABLE_TEXT}</b> The list of registers could not be verified.</p>}
      {!bad && countries === null && <small>Loading…</small>}
      {countries && <>
        <div className="dbx-grid">
          <div className="dbx-f"><span id="dbx-c-l">Country</span><DeskCombobox label="Country" placeholder="Choose a country" emptyWords="No country matches." searchWords="Search countries" items={countryItems} value={country || null} onPick={setCountry} /></div>
          <div className="dbx-f"><span id="dbx-r-l">Register</span><DeskCombobox label="Register" placeholder={registers === null ? "Choose a country first" : "Choose a register"} emptyWords="No register is listed for this country." searchWords="Search registers" items={registerItems} value={regId === null ? null : String(regId)} onPick={(k) => setRegId(Number(k))} disabled={!registers || registers.length === 0} /></div>
          <label>Registration number <input value={num} maxLength={NUMBER_MAX} onChange={(e) => setNum(e.target.value)} autoComplete="off" spellCheck={false} inputMode="text" /></label>
        </div>
        <p style={{ margin: "10px 0 0" }}><small>{bannedNote()}</small></p>
        {chosen && <p style={{ margin: "8px 0 0" }}><small>{chosen.authority || chosen.name}{chosen.website ? ` · ${chosen.website}` : ""}{chosen.shapeKnown ? "" : " · No number shape has been proven for this register, so the Desk cannot check the shape."}</small></p>}
        <div className="dbx-act" style={{ marginTop: 12 }}>
          <button type="button" className="dbx-btn" disabled={busy || !body} onClick={check}>Check the shape</button>
          <button type="button" className="dbx-btn" disabled={busy || !body} onClick={find}>Find the company</button>
          {found && found.state === "found" && found.nameState !== "missing" && <button type="button" className="dbx-btn" onClick={() => onCompany(found.tenantId)}>Use this company</button>}
        </div>
        {num !== "" && !numberOk(num) && <p role="status"><small>Write the number without line breaks, at most {NUMBER_MAX} characters.</small></p>}
        {msg && <p role="status">{msg}{found && found.state === "found" && <><br /><small>Company ID <code>{found.tenantId}</code></small></>}</p>}
      </>}
    </section>
  );
}
