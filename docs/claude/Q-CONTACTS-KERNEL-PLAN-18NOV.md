<!--TECHLAW-->
# Q-CONTACTS-KERNEL (his order 18 Nov 2026 05:00, started 07:10 PKT): the address-book filter + frecency rank move from TypeScript into the Rust WASM kernel
STATE: CODE WRITTEN 18 Nov 07:4x PKT, not GREEN (needs his founder-install, then my live Chrome look). Gate check `Q-contacts-kernel` (founder-web/src/book.ts must contain `kernel_contacts_filter`).

## 1. WEB RESEARCH (standing rule 0, 18 Nov 2026) and what it decided
| Finding | Decision |
|---|---|
| Recipient autocomplete in big mail clients filters a cached list on the client and ranks by use frequency and recency (Mozilla "frecency": visit count weighted by a decaying age; same idea as our E186 formula ln(1+3*sent+recv) * 2^(-days/45)). | Keep the formula bit for bit (SQL E186, book.ts and now Rust all give the same number). |
| Fast fuzzy matchers exist in Rust (nucleo, frizbee, fiveo: subsequence scoring) and compile to WASM. | NOT used: our rule is prefix on name words / address local part / domain (predictable, what a mail user expects), and a fuzzy crate would add size and change results. The module is ~150 lines of plain Rust. |
| Unicode folding: the browser uses NFKD; in Rust the ICU normalizer is large for a wasm. | Own small fold: lower-case + Latin-1 / Latin Extended-A accents + combining marks U+0300..036F + fullwidth ASCII. Same result as NFKD for every Latin name; Urdu / Arabic / CJK are only lower-cased by both. Documented limit, tested by shared vectors. |
| A second implementation always drifts. | ONE vector file `web-wasm/src/contacts_vectors.json` is GENERATED from book.ts (`bun founder-web/sim/gen_contacts_vectors.ts`) and tested on three levels: Rust unit test, the REAL shipped wasm in bun, and the TypeScript twin itself. |

## 2. DESIGN
- Kernel module `contacts@1` (web-wasm/src/contacts.rs), export `contacts_suggest(ptr,len)`: JSON in {q, taken, now, max, c:[{a,n,s,r,l,p}]} (`l` = the later of last_sent / last_recv in ms, so the kernel parses no date), JSON out {ok, hits:[{i, why, score}]}. Wrong shape = {ok:false}: the browser uses its TypeScript twin.
- Browser: kernel.ts `contactsSuggest` + kernel.worker.ts message `contacts` (the same way mailledger@1 / auditproof@1 are called); book.ts `kernelInput` / `hitsFromKernel`; RecipientField.tsx asks the kernel after the 150 ms pause and shows the kernel answer; until it arrives (or if the kernel cannot run) the TypeScript `suggest` answers at once, so the list never flickers empty. Same visible list either way (UI LAW: nothing visual changed).
- Tie order is now plain code-unit order in BOTH implementations (it was localeCompare in TS), so a tie can never be ordered differently.
- The server still sends the top 500 contacts through the signed door; the kernel filters them. Typing makes zero server calls (unchanged).

## 3. THE SHARED KERNEL (Rule 52) AND AWAM
- One crate (web-wasm), additive module, version 0.17.0 -> 0.18.0. NO fork: awam and founder are built from the same source. The FOUNDER pin (founder-web/src/kernel.pin.ts) is 0.18.0; the AWAM pin (src/lib/kernel/pin.gen.ts, public/kernel/) is NOT touched (his word 18 Nov 07:10). The guard test in kernel.test.ts changed from "same bytes as the user site" to "the same crate: founder version >= awam version, equal version = equal bytes".
- When awam takes the new kernel (its own turn, its own pull command, never mixed with the founder one) it only copies public/kernel + pin.gen.ts and the test returns to "equal bytes".

## 4. PROOF SO FAR
cargo (web-wasm) 143 passed incl. the vector test; bun 357 passed incl. REAL-wasm vectors and book twin tests; tsc clean; kernel wasm 0.18.0 sha 9a0c227d... built from the crate. STILL OPEN: his founder-install, my live Chrome look (typing "gm" shows the same sealed contacts), then GREEN (WIRED: YES / REAL: YES / TECH-LAW CHECKED).
