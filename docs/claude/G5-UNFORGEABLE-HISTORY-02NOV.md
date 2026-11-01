# G5: Un-forgeable audit history (founder 2 Nov 2026 03:37, "technology rule khuda ke baad important, god level, her keemat")

Founder order: the three limits left by G4 must be SOLVED, not just listed: (1) the browser memory is only one browser, (2) a fully compromised server can feed a brand-new browser a consistent fake, (3) the kernel proves inclusion only, not consistency between two roots. Build them with the most advanced real technology, and review the code until it is genuinely super advanced. **This file is the design; nothing here is built yet and nothing is claimed on any page.**

## Technology read (2 Nov 2026, real sources, nothing from memory)
| Source | What it gives us |
|---|---|
| [RFC 9162 §2.1.4](https://datatracker.ietf.org/doc/rfc9162/) Merkle consistency proofs | Proof that tree size *n* extends tree size *m* without changing any of the first *m* leaves. Proof = at most ceil(log2 n)+1 hashes. Verifier keeps `fn/sn` (positions) and `fr/sr` (rebuilt old/new root); accept only if `fr`=old root, `sr`=new root, `sn`=0. Same leaf (0x00) and node (0x01) prefixes our E107 tree already uses; our iterative tree is proven equal to the RFC 6962 recursive tree for 1..150 leaves, so the RFC algorithm applies directly. |
| [C2SP tlog-checkpoint](https://github.com/C2SP/C2SP/blob/main/tlog-checkpoint.md) | Standard checkpoint note: `origin`, `tree size`, `root hash (base64)`, optional extension lines, then signature lines (signed-note). Rule: a log must never sign a checkpoint inconsistent with one it signed before. |
| [C2SP tlog-cosignature](https://www.github.com/C2SP/C2SP/blob/main/tlog-cosignature.md) | A WITNESS is a cosigner that keeps the latest tree head it saw per log and cosigns only after checking a consistency proof. Algorithms: **Ed25519** (cosignature/v1: `time`, origin, size, base64 root) and **ML-DSA-44** (post-quantum, the spec says recommended for NEW deployments). Clients are configured with (cosigner name, algorithm, public key) and verify a quorum. |
| Sigsum / siglog and the Tessera tile logs (search results; their specs are read in G5-0) | Existing independent witness ecosystems we can join instead of inventing trust. |
| RFC 3161 timestamps, OpenTimestamps/Bitcoin (search results; read in G5-0) | Time anchors. They prove "this root existed by time T" without trusting us; they do not prove consistency (witnesses do). |

NOT yet read (honest): the `tlog-witness` request/response protocol text (the fetch was refused by the tool), Sigsum witness policy files, OpenTimestamps format. They are G5-0 tasks, not guesses.

## The design (four layers, each closes one limit)
| Part | What | Technology | Closes |
|---|---|---|---|
| **G5a** | **Consistency proofs.** SQL `founder_audit_consistency_proof(old_size, new_size)` generates the RFC 9162 SUBPROOF over the existing E107 tree. One Rust source `server/rust/merkle_core.rs` gets `verify_consistency` (the ONE shared code, Rule 52). Kernel `merkle@2` exports `consistency_verify`. The browser pin becomes `(size, root)`; on every load it asks for ONE proof from the pinned size to the current size and verifies it in WASM. Replaces the G4 equality check with a cryptographic extension proof that works across any gap. | SQL + Rust + WASM kernel 0.7.0 + React-TS | limit 3, and makes limit 1 stronger |
| **G5b** | **Signed checkpoints in the C2SP format.** Each seal is published as a standard checkpoint note signed by a dedicated audit-log key (its own Ed25519 key, NOT the transport signing key; ML-DSA-44 option decided in G5-0 after a crate licence/audit read, since `ring` has none). Key id per the spec. | Rust + SQL | prepares limit 2 (a standard object others can cosign) |
| **G5c** | **External witnesses.** After each seal, Rust sends the checkpoint plus the consistency proof to independent witnesses (C2SP witness protocol); a witness checks it against what it saw before and returns a cosignature. Cosignatures are stored in SQL and shown. The browser verifies **k of n** witness cosignatures in WASM against witness keys pinned INSIDE the kernel release (so the server cannot swap them). A time anchor (OpenTimestamps or RFC 3161) is added as an extra, not a replacement. | Rust + SQL + WASM kernel + React-TS | limit 2: a compromised server cannot show one browser a history the witnesses never saw |
| **G5d** | **Pin portability.** A brand-new browser needs no remembered pin: it verifies the witnessed checkpoint (G5c) and one consistency proof (G5a). The old per-browser pin stays as an extra layer. | React-TS + kernel | limit 1 |

Order inside G5: **G5-0** research (finish reading the specs above) -> **G5a** -> **G5b** -> **G5c** -> **G5d**. One part at a time, green on the server + Chrome before the next (Rule 64).

## What this does NOT give (stated so it is never over-claimed)
- Witnesses only help if they are run by parties the server's operator does not control. A second server of ours on the same provider is not a witness. Which witnesses = founder decision **G5-D** below.
- Until G5c is green and shows a real k-of-n count, the gauge must say "not witnessed". No page says "tamper-proof".
- Nothing here protects mail content; it protects the audit history.

## Founder decision G5-D (needed before G5c, not before G5a/G5b)
Which independent witnesses? Candidates, in order of my recommendation: (1) join existing public witnesses of the C2SP/Sigsum ecosystem (no cost, real independence; availability and admission to be read in G5-0), (2) one witness we run on a different provider and different account, (3) a time anchor via OpenTimestamps (Bitcoin) or an RFC 3161 authority. Any paid account or outside signup is the founder's action (I cannot create accounts).

## Review gate (the founder's "review kero jab tak super advance na ho")
A part is NOT done until all of these are shown, in this order:
1. **Exhaustive vectors:** every pair (m, n) with 1 <= m <= n <= 150: SQL proof == Rust proof, and the verifier accepts. Reference generator written from RFC 9162 in a separate language (Python) so one bug cannot hide in two copies.
2. **Negative tests:** flipping any single bit of any proof hash, swapping hash order, truncating or extending the proof, wrong sizes (m=0, m>n), wrong old/new root: each MUST be rejected.
3. **Three-way parity:** SQL = Rust = WASM kernel on the same vectors (the same method E107 used for inclusion proofs).
4. **Property/fuzz test** on random trees and random byte garbage into the verifier (never panics, never accepts).
5. **Independent review:** a second reviewer that did not write the code reads the diff against this file and the RFC and reports. Findings are fixed and the review repeated until it reports none.
6. Then the server run and the founder's Chrome check. GREEN only with the pasted proof.
