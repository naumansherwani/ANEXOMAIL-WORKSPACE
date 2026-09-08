# BRAND LOGO CODES — ANEXOMAIL · ANEXOChat · ANEXOVideoCall

Founder: **Muhammad Nauman Sherwani**

Har logo **code se** bana hai — koi PNG/JPG file nahi, koi external asset nahi.
Is liye har jagah (site, app, email, docs, PDF, favicon) bina quality kharaab
hone ke use ho sakta hai.

## Repo mein kahan hain

| Logo | React component | Import |
| --- | --- | --- |
| ANEXOMAIL Workspace | `src/components/site/BrandMark.tsx` | `import { BrandMark } from "@/components/site/BrandMark";` |
| ANEXOChat (cinematic) | `src/components/brand/AnexoChatMark.tsx` | `import { AnexoChatMark } from "@/components/brand/AnexoChatMark";` |
| ANEXOVideoCall | `src/components/brand/AnexoVideoCallMark.tsx` | `import { AnexoVideoCallMark } from "@/components/brand/AnexoVideoCallMark";` |

## Use kaise karein

```tsx
<BrandMark />                       {/* mark + wordmark */}
<BrandMark compact />               {/* sirf mark */}
<AnexoChatMark />                   {/* cinematic sheen ON */}
<AnexoChatMark compact />           {/* nav / rail ke liye */}
<AnexoChatMark cinematic={false} /> {/* Calm Mode — glow OFF */}
<AnexoVideoCallMark compact />
<BrandMark className="scale-125" /> {/* size Tailwind se */}
```

Props har mark par same hain: `compact`, `className`, aur chat/video par
`cinematic`.

## Brand colors (design tokens, hardcode nahi)

| Role | Value |
| --- | --- |
| Navy deep | `oklch(0.235 0.050 258)` |
| Navy mid | `oklch(0.375 0.080 258)` |
| Navy light | `oklch(0.50 0.098 258)` |
| Platinum edge | `oklch(0.975 0.004 250)` → `oklch(0.60 0.016 253)` |
| Wordmark sheen | CSS class `.ax-platinum-text` (`src/styles.css`) |

## Rules

- Gradient `id` har instance mein `useId()` se unique banta hai — do marks ek
  page par ho to fill kabhi gum nahi hota. Naya mark banate waqt yahi pattern
  copy karein.
- Wordmark ka font weight/tracking na badlein; size sirf `className` se.
- Logo ke andar koi doosra brand, platform ka naam ya credit nahi.
- Static SVG file chahiye (email signature, print, favicon)? Component ka
  `<svg>` block waise hi copy karke `viewBox="0 0 64 64"` ke saath `.svg` file
  mein daal dein — `oklch()` values modern browsers/renderers mein chalti hain.

## Cinematic ANEXOChat mark — kya cheez cinematic hai

1. **Do overlapping planes** — do log, ek guftagu (depth + parallax feel).
2. **Radial key light** — mark ke peechay halka platinum glow (`cinematic` prop).
3. **Platinum edge gradient** — ek hi light source, upar se neechay girti hui.
4. **Teen fading nodes** — realtime typing/awaaz ka ishaara.

Calm Mode ya reduced-motion surfaces par `cinematic={false}` bhejein.

## Active page highlight (nav rule)

Website ke nav mein jo page khula hai woh hamesha highlight hota hai:
platinum text + neechay underline bar + `aria-current="page"`.
Workspace rail mein wahi kaam filled pill se hota hai. Ye rule har naye nav
link par lagana lazmi hai.
