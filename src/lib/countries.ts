/**
 * Country list for create-account (PX2c, founder 2 Nov 2026). ISO 3166-1 alpha-2 + E.164 calling code.
 * Names come from the browser (Intl.DisplayNames), so they follow the page language and nothing is typed twice.
 * Afghanistan (AF), Israel (IL) and North Korea (KP) are NOT in this list: ANEXOMAIL is not available there (GEO1). The Rust door signx.policy
 * says the same and is applied on top (see filterBlocked), so the list can never drift from the server's rule.
 * +1 is shared by the NANP countries; the number the person types after the code is checked by the server (E.164, 7-15 digits).
 */
const RAW =
  "AL:355,DZ:213,AS:1,AD:376,AO:244,AI:1,AG:1,AR:54,AM:374,AW:297,AU:61,AT:43,AZ:994,BS:1,BH:973,BD:880,BB:1,BY:375,BE:32,BZ:501,BJ:229,BM:1,BT:975,BO:591,BQ:599,BA:387,BW:267,BR:55," +
  "IO:246,VG:1,BN:673,BG:359,BF:226,BI:257,KH:855,CM:237,CA:1,CV:238,KY:1,CF:236,TD:235,CL:56,CN:86,CO:57,KM:269,CG:242,CD:243,CK:682,CR:506,CI:225,HR:385,CU:53,CW:599,CY:357,CZ:420," +
  "DK:45,DJ:253,DM:1,DO:1,EC:593,EG:20,SV:503,GQ:240,ER:291,EE:372,SZ:268,ET:251,FK:500,FO:298,FJ:679,FI:358,FR:33,GF:594,PF:689,GA:241,GM:220,GE:995,DE:49,GH:233,GI:350,GR:30,GL:299," +
  "GD:1,GP:590,GU:1,GT:502,GG:44,GN:224,GW:245,GY:592,HT:509,HN:504,HK:852,HU:36,IS:354,IN:91,ID:62,IR:98,IQ:964,IE:353,IM:44,IT:39,JM:1,JP:81,JE:44,JO:962,KZ:7,KE:254,KI:686,XK:383," +
  "KW:965,KG:996,LA:856,LV:371,LB:961,LS:266,LR:231,LY:218,LI:423,LT:370,LU:352,MO:853,MG:261,MW:265,MY:60,MV:960,ML:223,MT:356,MH:692,MQ:596,MR:222,MU:230,YT:262,MX:52,FM:691,MD:373," +
  "MC:377,MN:976,ME:382,MS:1,MA:212,MZ:258,MM:95,NA:264,NR:674,NP:977,NL:31,NC:687,NZ:64,NI:505,NE:227,NG:234,NU:683,MK:389,MP:1,NO:47,OM:968,PK:92,PW:680,PS:970,PA:507,PG:675,PY:595," +
  "PE:51,PH:63,PL:48,PT:351,PR:1,QA:974,RE:262,RO:40,RU:7,RW:250,WS:685,SM:378,ST:239,SA:966,SN:221,RS:381,SC:248,SL:232,SG:65,SX:1,SK:421,SI:386,SB:677,SO:252,ZA:27,KR:82,SS:211,ES:34," +
  "LK:94,BL:590,SH:290,KN:1,LC:1,MF:590,PM:508,VC:1,SD:249,SR:597,SE:46,CH:41,SY:963,TW:886,TJ:992,TZ:255,TH:66,TL:670,TG:228,TK:690,TO:676,TT:1,TN:216,TR:90,TM:993,TC:1,TV:688,UG:256," +
  "UA:380,AE:971,GB:44,US:1,UY:598,UZ:998,VU:678,VA:39,VE:58,VN:84,VI:1,WF:681,EH:212,YE:967,ZM:260,ZW:263,AX:358";

export const LOCAL_BLOCKED = ["AF", "IL", "KP"] as const;

export type Country = { iso2: string; dial: string; name: string; flag: string };

export function flagOf(iso2: string): string {
  return iso2.toUpperCase().replace(/./g, (c) => String.fromCodePoint(127397 + c.charCodeAt(0)));
}

/** Drop any country the server says is not available (the server list wins). */
export function filterBlocked<T extends { iso2: string }>(list: T[], blocked: readonly string[]): T[] {
  const b = new Set(blocked.map((x) => x.toUpperCase()));
  return list.filter((c) => !b.has(c.iso2.toUpperCase()));
}

export function countryList(locale = "en", blocked: readonly string[] = LOCAL_BLOCKED): Country[] {
  let names: Intl.DisplayNames | null = null;
  try {
    names = new Intl.DisplayNames([locale], { type: "region" });
  } catch {
    names = null;
  }
  const list = RAW.split(",").map((p) => {
    const [iso2, dial] = p.split(":") as [string, string];
    return { iso2, dial, name: names?.of(iso2) ?? iso2, flag: flagOf(iso2) };
  });
  return filterBlocked(list, blocked).sort((a, b) => a.name.localeCompare(b.name, locale));
}

/** "+92" + "0300 1234567" -> "+923001234567". Returns null when it cannot be a real number (server checks again). */
export function toE164(dial: string, national: string): string | null {
  const digits = national.replace(/[^0-9]/g, "").replace(/^0+/, "");
  const full = `+${dial}${digits}`;
  return /^\+[1-9][0-9]{6,14}$/.test(full) ? full : null;
}

/** Country calling codes of the blocked countries (client-side mirror of signx.policy, used only to give a friendly message early). */
export const LOCAL_BLOCKED_DIALS = ["93", "972", "850"] as const;
