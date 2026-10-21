# GREEN-BOARD — docs + repo ka ek hisaab: kaun sa GREEN, kaun sa nahi

21 Oct 2026, asli ghadi ~06:50 PKT · repo HEAD b18c4b9+ · source: MASTER-BUILD-PLAN.md, MASTER-GAP-LEDGER.md, loophole-ledger.md, blueprint G-table, DONE-DO-NOT-REPEAT.md, PROMISES.md, TECH-MAP.md + repo grep (src/, server/).

**Zubaan (sach, jhoot nahi):**
- 🟢 **GREEN** = live saboot (founder ka server output ya Chrome mein dekha) — dobara mat chhuo.
- 🟡 **CODE** = repo mein bana (file maujood), live par chalne/dekhne ka saboot nahi.
- 🟠 **PARTIAL** = kuch hissa green/maujood, kuch baqi.
- 🔴 **TODO** = repo mein bana hi nahi (ya server par nahi chala).
- 🔵 **FOUNDER** = founder ka faisla/haan/login/DNS chahiye.
- ⚪ **PARKED** = founder ne rok rakha.
**Dhyaan:** P1–P9 ke "CODE" ka matlab sirf itna ki file maujood hai (grep se mila) — chalta hai ya nahi, wo live test se hi tay hoga. Isse zyada main daawa nahi karta.

## Ginti (kul)
| Hissa | Kul | 🟢 GREEN | 🟡 CODE | 🟠 PARTIAL | 🔴 TODO | 🔵 FOUNDER |
|---|---|---|---|---|---|---|
| MASTER-BUILD-PLAN P1–P9 (is plan ke 68 items) | 68 | 9 | 40 | 12 | 7 | 0 |
| G-series G1–G42 | 43 | 10 | 2 | 13 | 16 | 2 |
| Technology (live stack + B1–B8 + R) | 15 | 8 | 1 | 0 | 6 | 0 |
| Ops / bugs / ledger khule | 13 | 1 | – | – | 11 | 1 |

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
