# GREEN-BOARD — docs + repo ka ek hisaab: kaun sa GREEN, kaun sa nahi

21 Oct 2026, asli ghadi ~06:50 PKT · repo HEAD b18c4b9+ · source: MASTER-BUILD-PLAN.md, MASTER-GAP-LEDGER.md, loophole-ledger.md, blueprint G-table, DONE-DO-NOT-REPEAT.md, PROMISES.md, TECH-MAP.md + repo grep (src/, server/).

**FOUNDER RULE (21 Oct 06:56): file server par aa gayi aur wire hai = GREEN.** Do darje: 🟢 live dekha/proof (pakka) · 🟢 server par aaya + wire (live click-test baqi). Baqi sab NOT-GREEN.
**Zubaan:**
- 🟢 **GREEN** = live saboot (founder ka server output ya Chrome mein dekha) — dobara mat chhuo.
- 🟢 **GREEN (server par)** = file repo mein hai AUR pull/installer se server par aa chuki (Web server==repo 490/491; Rust/Brain installer chala) — ab sirf Chrome mein dekhna.
- 🟠 **PARTIAL** = kuch hissa green/maujood, kuch baqi.
- 🔴 **TODO** = repo mein bana hi nahi (ya server par nahi chala).
- 🔵 **FOUNDER** = founder ka faisla/haan/login/DNS chahiye.
- ⚪ **PARKED** = founder ne rok rakha.
**Dhyaan:** "server par aaya" repo grep + server==repo pull output se hai; chalta hai ya nahi wo Chrome click-test se tay hoga (list: NOT-GREEN/01).

## Ginti (kul)
| Hissa | Kul | 🟢 live dekha | 🟢 server par (click-test baqi) | 🟠 PARTIAL | 🔴 TODO | 🔵 FOUNDER |
|---|---|---|---|---|---|---|
| MASTER-BUILD-PLAN P1–P9 (is plan ke 68 items) | 68 | 9 | 41 | 12 | 6 | 0 |
| G-series G1–G42 | 43 | 10 | 3 | 13 | 15 | 2 |
| Technology (live stack + B1–B8 + R) | 15 | 9 | 1 | 0 | 5 | 0 |
| Ops / bugs / ledger khule | 14 | 3 | – | – | 10 | 1 |

## Files
- `01-GREEN.md` — jo live saboot ke saath green hai (dobara mat chhuo).
- `02-PLAN-P1-P9-vs-REPO.md` — MASTER-BUILD-PLAN ka har item, repo evidence ke saath.
- `03-G-SERIES.md` — G1–G42 ek-ek karke.
- `04-TECHNOLOGY.md` — stack + B-series + R-items.
- `05-DOCS-INVENTORY.md` — docs ki har file: kya hai, kitni purani/saaf, kya STALE hai.
- `06-REPO-INVENTORY.md` — repo mein kya kya hai (routes, components, Rust modules, SQL, scripts) ginti ke saath.
- **`NOT-GREEN/`** — jo green NAHI hai woh alag folder mein (side par), 5 file: code-live-baqi, todo, partial, founder-chahiye, stale-doc + parked.

## Sabse bada sach (3 line)
1. Plan doc ka **STATUS BOARD purana hai**: P2–P9 "TODO/NEXT" likha hai jabki Dashboard/Mail/Compose/Calendar/Contacts ka bada hissa live hai (Basic ke liye). Isliye is board se plan ka status mat parho — `NOT-GREEN/04-stale-docs.md` mein exact lines hain.
2. **Basic = GREEN.** Pro/Business/Business Pro ka live test (G41) abhi TODO — woh technology migration (B4–B8) ke BAAD (founder tarteeb 05:53).
3. B4 repo mein tayyar + sandbox asli QUIC proof PASS; server par `rust-events-install.sh` dobara chalana baqi.
