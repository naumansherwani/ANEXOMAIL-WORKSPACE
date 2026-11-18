// Generates web-wasm/src/contacts_vectors.json FROM book.ts (the TypeScript twin). The Rust kernel test reads the same file, so the two implementations are held equal.
// Run: bun sim/gen_contacts_vectors.ts   (then cargo test in web-wasm). Never edit the JSON by hand.
import { kernelInput, suggest, type Contact } from "../src/book";
const NOW = Date.parse("2026-11-18T00:00:00Z"), D = 86_400_000;
const iso = (days: number) => new Date(NOW - days * D).toISOString();
const c = (addr: string, name: string, sent: number, recv: number, ls: number | null, lr: number | null, pinned = false): Contact => ({ id: addr, addr, name, sent, recv, last_sent: ls === null ? null : iso(ls), last_recv: lr === null ? null : iso(lr), pinned });
const book: Contact[] = [
  c("zoya.khan@anexomail.com", "Zoyá Khan", 12, 30, 1, 0), c("ali@gmail.com", "Ali Raza", 3, 9, 20, 5), c("alina@work.org", "Alina Shah", 0, 4, null, 40), c("ahmed.ali@corp.com", "Ahmed Ali", 40, 10, 2, 2),
  c("noreply@github.com", "", 0, 100, null, 0), c("müller@example.de", "Élodie Müller", 5, 5, 60, 70), c("tie1@x.com", "Tie One", 1, 1, 10, 10), c("tie2@x.com", "Tie Two", 1, 1, 10, 10),
  c("boss@company.com", "The Boss", 2, 2, 400, 400, true), c("نعمان@example.com", "نعمان شیروانی", 7, 3, 3, 3), c("ŁÓDŹ@city.pl", "Łukasz Źródło", 1, 0, 90, null), c("o.neil+tag@mail.io", "Ó Neil", 2, 6, 15, 8),
];
const inputs: [string, string, string[]][] = [
  ["name prefix", "zoy", []], ["accent typed", "zoyá", []], ["upper case", "ALI", []], ["word inside name", "khan", []], ["address local part", "o.neil", []], ["domain prefix", "gma", []],
  ["at sign", "ali@g", []], ["taken skipped", "ali", ["ali@gmail.com"]], ["tie order", "tie", []], ["pinned first", "bo", []], ["short needle", "a", []], ["urdu", "نع", []],
  ["decorated typing", ' "<Ali', []], ["no match", "qqqq", []], ["elodie", "elo", []], ["muller", "mull", []], ["max cap", "a", []],
];
const cases = inputs.map(([name, typed, taken]) => {
  const input = kernelInput(book, typed, new Set(taken), NOW, name === "max cap" ? 3 : 8);
  const t = name === "short needle" || name === "max cap" ? "ab" : typed; // "a" is below MIN_CHARS: keep one short case, make the cap case real
  const inp = name === "max cap" ? kernelInput(book, "al", new Set(), NOW, 3) : input;
  const hits = suggest(book, name === "max cap" ? "al" : t === "ab" ? typed : typed, new Set(taken), NOW, name === "max cap" ? 3 : 8);
  return { name, input: inp, hits: hits.map((h) => ({ i: book.indexOf(h.c), why: h.why, score: h.score })) };
});
await Bun.write(new URL("../../web-wasm/src/contacts_vectors.json", import.meta.url), JSON.stringify({ about: "generated from founder-web/src/book.ts by founder-web/sim/gen_contacts_vectors.ts; do not edit by hand", cases }, null, 1));
console.log("cases", cases.length, "hits", cases.map((x) => x.hits.length).join(","));
