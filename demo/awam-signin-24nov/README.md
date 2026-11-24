# DEMO: awam sign-in, "Enter The Global Grid" (24 Nov 2026)
Folder name = demo. NOTHING here is in `src/`; real awam code is untouched until he approves (his 12:19 word: "demo ke bina approval nahi hoga").
- `demo.js` = all demo code (texts, left panel in the logo palette, Rule 52 technology list, right side navy with grid + dust + glass card, idea 2 verify-line state, idea 3 passkey-touch glow). Injected into the REAL `/auth` page.
- `run.cjs` = renders the three states at 1280 and 390 into `screens/`.
- Promises: the HTTP/3, AES-256 and X25519MLKEM768 lines stay OFF the live awam page until K5b is proven (docs/claude/WEBSITE-PROMISES.md P2).
Run: `npx vite dev --port 5391 --host 127.0.0.1` then `NODE_PATH=$(npm root -g) node demo/awam-signin-24nov/run.cjs`.
