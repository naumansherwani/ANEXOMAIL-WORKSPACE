# WIRE 17 — PORT MAP (locked)

Har arm ka apna port. Naya arm bina port kabhi nahi.

| Arm | Port | Runtime | Status |
| --- | --- | --- | --- |
| Caddy edge (HTTPS + HTTP/3) | 80/443 tcp, 443 udp | Caddy | DONE |
| `anexomail-web` frontend SSR | 3000 | Bun (`bun run build:bun`) | DONE |
| `anexomail-leo` API (Phase 1–10) | 3100 | Bun | DONE |
| `anexomail-rust` engine PRIMARY (`/rpc/*` `/file/*` `/wt/*`) | 3200 tcp | Rust axum/tokio | DONE |
| Rust WebTransport / QUIC | 3443 udp | Rust | DONE |
| `anexochat` API fallback (`/api/chat/*`) | 3300 | Bun | DONE |
| `polar-rust-payment` webhook + checkout | 3400 | Rust | DONE |
| ANEXOVideoCall SFU media forwarding (reserved) | 3500 tcp / 3501 udp | Rust | TODO |
| Rust `/metrics` + `/ready` scrape | 3600 (loopback only) | Rust | READY |
| `n8n` automation | 5678 | Node (isolated) | DONE |
| coturn TURN/STUN | 3478, 5349 (+ 49152–49500 udp) | coturn | DONE |
| Postfix SMTP / submission | 25, 587, 465 | Postfix | READY |
| Dovecot IMAPS | 993 (143 loopback) | Dovecot 2.4 | DONE |
| Supabase transaction pooler | 6543 (outbound) | Supabase | DONE |

Rule: 3200 primary hai, 3300 sirf fallback. Port sirf loopback par sunta hai;
public sirf Caddy se.

## Frontend stack (locked)

React 19.2 · TanStack Start v1 (router 1.170) · Vite 8.2 · Tailwind v4.2 ·
Radix/shadcn · framer-motion + GSAP · three.js (R3F).
SSR runtime **Bun** (PM2 `interpreter: bun`, port 3000), host **Hetzner only**.
Node 22 sirf emergency fallback.

## 3D graphics (kaun deta hai)

- Provider: **three.js** via `@react-three/fiber` + `drei` + `postprocessing`
  (+ `rapier` sirf snow physics), client-side only — server par kabhi nahi.
- ANEXOChat scene: `src/components/app/chat/cinema/Scene.tsx`, budget
  `src/lib/chat-cinema.ts` (mobile par particles 50%, dpr cap).
- **Call par auto OFF:** `useCinema(calm, effect, callActive)` — jab
  `call.phase !== "idle"` ho to quality `off` → Three.js poora unmount/dispose,
  koi rAF loop nahi, GPU/CPU sab video call ko. Chip: "3D paused for this call".
- **User toggle:** header ka `3D graphics on/off` button, yaad rehta hai
  (`localStorage ax.chat.cinema.enabled`). Off par quality select bhi disabled.
- Calm Mode aur OS reduced-motion hamesha upar — dono 3D ko off rakhte hain.
