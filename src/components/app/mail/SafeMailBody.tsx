import { ImageOff } from "lucide-react";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";

import { useBlockRemoteImages } from "@/lib/settings";

/**
 * Bahar se aayi HTML mail ko MEHFOOZ dikhana (20 Oct 2026 — pehle `dangerouslySetInnerHTML` se seedha page mein lagti thi,
 * aur na Bun pipe na Rust pipe HTML saaf karta hai: kisi mail ka `<script>` / `onerror=` humari app ke andar chal kar login token
 * utha sakta tha). Ab Gmail jaisa: har HTML mail apne alag, band dabbe (sandboxed iframe) mein:
 *   - `sandbox` mein `allow-scripts` NAHI => mail ka koi JavaScript kabhi nahi chalta; forms/top-navigation band.
 *   - `allow-same-origin` sirf is liye ke hum (parent) dabbe ki unchai naap sakein — script band hain, is liye mail khud kuch nahi kar sakti.
 *   - CSP: bahar ki tasveerein (tracking pixel — "mail khuli ya nahi" ka jasoos) default BAND; "Show images" dabane par hi.
 *     Fonts/CSS/frames/connect sab band. Links naye tab mein (`noopener`).
 * Sada (text) mail pehle jaisi app ke andar hi dikhti hai.
 */
const REMOTE_IMG = /<img\b[^>]*\bsrc\s*=\s*["']?\s*https?:/i;
const REMOTE_CSS_BG = /url\(\s*["']?\s*https?:/i;

function doc(html: string, images: boolean): string {
  const img = images ? "img-src https: http: data: cid:;" : "img-src data: cid:;";
  const csp = `default-src 'none'; ${img} style-src 'unsafe-inline'; font-src data:; media-src 'none'; frame-src 'none'; form-action 'none'; base-uri 'none'`;
  return `<!doctype html><html><head><meta charset="utf-8"><meta http-equiv="Content-Security-Policy" content="${csp}"><base target="_blank"><meta name="referrer" content="no-referrer"><style>
html,body{margin:0;padding:0;background:#fff;color:#111;font:14px/1.5 -apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,Helvetica,Arial,sans-serif;word-wrap:break-word;overflow-wrap:anywhere}
body{padding:16px}img{max-width:100%;height:auto}table{max-width:100%}pre{white-space:pre-wrap}a{color:#1a56db}
${images ? "" : 'img[src^="http:"],img[src^="https:"],img[src^="//"]{visibility:hidden}'}
</style></head><body>${html}</body></html>`;
}

export function SafeMailBody({ html }: { html: string }) {
  const frame = useRef<HTMLIFrameElement | null>(null);
  const [height, setHeight] = useState(120);
  // Settings → Privacy → "Block tracking pixels" band kiya ho to tasveerein seedha (user ka apna faisla)
  const block = useBlockRemoteImages();
  const [shown, setImages] = useState(false);
  const images = shown || !block;
  const hasRemote = useMemo(() => REMOTE_IMG.test(html) || REMOTE_CSS_BG.test(html), [html]);
  const srcDoc = useMemo(() => doc(html, images), [html, images]);

  const measure = useCallback(() => {
    const d = frame.current?.contentDocument;
    if (!d?.body) return;
    const h = Math.max(d.documentElement.scrollHeight, d.body.scrollHeight);
    setHeight(Math.min(Math.max(h, 60), 20000));
  }, []);

  useEffect(() => {
    const f = frame.current;
    if (!f) return;
    let ro: ResizeObserver | null = null;
    const onLoad = () => {
      measure();
      const d = f.contentDocument;
      if (!d) return;
      // links: hamesha naya tab, bina opener ke
      d.querySelectorAll("a[href]").forEach((a) => {
        a.setAttribute("target", "_blank");
        a.setAttribute("rel", "noopener noreferrer");
      });
      if (typeof ResizeObserver !== "undefined" && d.body) {
        ro = new ResizeObserver(() => measure());
        ro.observe(d.body);
      }
      d.querySelectorAll("img").forEach((im) =>
        im.addEventListener("load", measure, { once: true }),
      );
    };
    f.addEventListener("load", onLoad);
    return () => {
      f.removeEventListener("load", onLoad);
      ro?.disconnect();
    };
  }, [srcDoc, measure]);

  return (
    <div className="mt-ax-3 flex flex-col gap-2">
      {hasRemote && !images && (
        <div className="flex flex-wrap items-center gap-2 rounded-lg border border-border bg-muted/40 px-3 py-2 text-[12px] text-muted-foreground">
          <ImageOff className="size-3.5 shrink-0" aria-hidden="true" />
          <span>Images from the sender are hidden, so they can't tell when you opened this.</span>
          <button
            type="button"
            onClick={() => setImages(true)}
            className="ax-focus ml-auto rounded-md px-2 py-1 font-semibold text-primary underline-offset-2 hover:underline"
          >
            Show images
          </button>
        </div>
      )}
      <iframe
        ref={frame}
        title="Message"
        srcDoc={srcDoc}
        sandbox="allow-same-origin allow-popups allow-popups-to-escape-sandbox"
        referrerPolicy="no-referrer"
        className="w-full rounded-xl border border-border bg-white"
        style={{ height }}
      />
    </div>
  );
}
