<!--TECHLAW-->
# TECH-FIRST PROTOCOL: THE FOREVER SOLUTION (founder 11 Nov 2026 04:33: "1% mistake bardasht nahi")
READ THIS FIRST AFTER EVERY COMPACTION OR NEW CHAT, BEFORE ANY CODE, BEFORE ANY "GREEN". It is written for Claude. The founder's technology list is in CLAUDE.md line 18 (FOUNDER TECHNOLOGY LAW) and in the TECH LAW cell of every phase row of docs/claude/BLUEPRINT-ABC-01NOV.md.

## WHY THE MISTAKE KEPT HAPPENING (honest root cause)
A rule written in prose is read once and forgotten after compaction. K4 was written green with HTTP/1.1, K7 was written green with raw fetch: the behaviour was tested, the LISTED TECHNOLOGY was not. A promise is not a fix. THE FIX IS MECHANICAL: three gates in `docs/cursor-work/server/rules-gate.py` that refuse the commit, so the mistake cannot reach the repo even if Claude forgets everything.

## THE 5 STEPS FOR EVERY PHASE (no exception, big or small)
1. OPEN the phase row in the blueprint; copy its TECH LAW cell.
2. WRITE `docs/claude/tech-contracts/CURRENT.md` FIRST: one table row per listed technology = where in code it must live, IN CODE yes/no, proof. STATE: IN PROGRESS.
3. REGISTER every row that is not yet in code as an `open` check in `docs/claude/TECH-LAW-GATE.json` (deadline = the phase deadline). A phase can never silently skip a technology: it is a visible warning on every commit until it holds.
4. CODE. Every code commit must stage `tech-contracts/CURRENT.md` (gate 2). Raw network calls in the founder UI may only go down (gate 1).
5. GREEN only when: every row says YES, the gate checks are `ok`, live Chrome proof at 390/820/1200+, and the ledger line contains `TECH-LAW CHECKED` + `WIRED: YES / REAL: YES` (gate 3). Then STATE: GREEN.

## THE THREE GATES (what refuses the commit)
- GATE 1 RATCHET: `docs/claude/TECH-RATCHET.json` counts raw `fetch(` / XMLHttpRequest / `new WebSocket` in `founder-web/src` (not tests). The number may only fall. K8d drives it to the fallback-only count. New old-style network code = commit refused.
- GATE 2 CONTRACT: founder code (`founder-web/src`, `server/founder/src`, SQL) changed => `docs/claude/tech-contracts/CURRENT.md` must be in the commit, must say `TECH CONTRACT FOR PHASE`, and if `STATE: GREEN` no row may say `NO`.
- GATE 3 GREEN WORDS: any added line containing the word GREEN in `docs/cursor-work/DONE-DO-NOT-REPEAT.md` or `docs/claude/CLOSE-THE-GAPS-07NOV.md` must contain `TECH-LAW CHECKED`. You cannot write GREEN without having done step 5.
- Existing: `docs/claude/TECH-LAW-GATE.json` (per-technology presence checks, ok = fail, open = warn).

## WHAT I (CLAUDE) MUST NEVER DO AGAIN
- Never write "GREEN" from tests alone. Behaviour proof AND technology proof.
- Never add a new raw `fetch`, WebSocket, HTTP/1-only path, classical-only crypto where the list says post-quantum, or an older library where the list names a newer one.
- Never "explain" a gap after the fact: the gap is written down BEFORE coding (step 3).
- When unsure which technology a phase lists: read the blueprint row; if the row is silent, ask him in ONE line, do not guess.

## STATE AT WRITING (11 Nov 04:40)
Open gaps: K8d (kernel RPC, today), K7-devicekey-fetch (14 Nov), K7-devicekey-pq (Q), L-gsap, L-webgpu, M-moq, Q-pq-sign. Current contract: docs/claude/tech-contracts/CURRENT.md (K8d).
