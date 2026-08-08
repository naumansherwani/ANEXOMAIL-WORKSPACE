---
name: Founder access (preview mode)
description: Founder can open every /app page without a session via /pages toggle; localStorage key ax.founder.preview
type: feature
---
FOUNDER ACCESS RULE (locked): founder ko har page bina login dekhna hai.
- `/pages` par "Enable founder access" switch hai. ON karne se `localStorage.ax.founder.preview = "on"`.
- `src/routes/app.tsx` guard: preview ON hone par signed-out/unavailable redirect skip hota hai aur AppShell render hota hai; niche ek "Founder preview — no session" strip + Exit button.
- Helper: `src/lib/founder-preview.ts` (`founderPreviewEnabled`, `setFounderPreview`).
- Ye sirf VIEW key hai — koi session mint nahi, koi mock data nahi. Unwired endpoint = honest "Not wired yet" state (NO MOCK rule intact).
