import { Share, SquarePlus, X } from "lucide-react";
import { useEffect, useState } from "react";

import { useLocale } from "@/lib/i18n";

/**
 * iPhone/iPad par "Add to Home Screen" ka rasta (M7, Rule 19). Android Chrome mein install chip `CrossPlatformBar`
 * mein pehle se hai; iOS Safari mein `beforeinstallprompt` hota hi nahi, isliye wahan user ko kuch dikhta nahi aur
 * app hamesha browser tab mein rehti hai (toolbar, koi icon nahi, koi yaad nahi). Sirf wahan dikhta hai jahan faida
 * hai: iOS, abhi installed nahi, user ne band nahi kiya. Storage na chale to bhi page theek.
 */

const STORE = "ax-install-hint";

function isIos(): boolean {
  const ua = navigator.userAgent;
  if (/iPad|iPhone|iPod/.test(ua)) return true;
  // iPadOS 13+ "Macintosh" bankar aata hai; touch hona usay Mac se alag karta hai.
  return /Macintosh/.test(ua) && navigator.maxTouchPoints > 1;
}

function isStandalone(): boolean {
  const nav = navigator as Navigator & { standalone?: boolean };
  return nav.standalone === true || window.matchMedia("(display-mode: standalone)").matches;
}

function dismissed(): boolean {
  try {
    return window.localStorage.getItem(STORE) === "off";
  } catch {
    return false;
  }
}

export function InstallHint({ forceShow = false }: { forceShow?: boolean }) {
  const { t } = useLocale();
  const [show, setShow] = useState(false);

  useEffect(() => {
    if (forceShow) {
      setShow(true);
      return;
    }
    setShow(isIos() && !isStandalone() && !dismissed());
  }, [forceShow]);

  if (!show) return null;

  return (
    <section className="ax-plane ax-in relative mt-ax-4 rounded-2xl p-ax-4" aria-label={t("Add to Home Screen")}>
      <button
        type="button"
        onClick={() => {
          try {
            window.localStorage.setItem(STORE, "off");
          } catch {
            /* private window — is session mein hi chhupa rahega */
          }
          setShow(false);
        }}
        className="ax-press ax-tap absolute right-3 top-3 grid size-8 place-items-center rounded-full text-muted-foreground hover:bg-muted hover:text-foreground focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-[var(--cyan-accent)]"
        aria-label={t("Hide this tip")}
      >
        <X className="size-4" aria-hidden="true" />
      </button>
      <p className="ax-eyebrow">{t("Get the app")}</p>
      <h3 className="ax-heading mt-1 pr-8">{t("Add ANEXOMAIL to your Home Screen")}</h3>
      <p className="ax-caption mt-1">{t("Opens full-screen, one tap away — like a real app.")}</p>
      <ol className="ax-body mt-3 grid gap-2">
        <li className="flex items-center gap-2.5">
          <span className="grid size-8 shrink-0 place-items-center rounded-lg border border-border">
            <Share className="size-4" aria-hidden="true" />
          </span>
          <span>{t("Tap the Share button in Safari")}</span>
        </li>
        <li className="flex items-center gap-2.5">
          <span className="grid size-8 shrink-0 place-items-center rounded-lg border border-border">
            <SquarePlus className="size-4" aria-hidden="true" />
          </span>
          <span>{t("Choose “Add to Home Screen”")}</span>
        </li>
      </ol>
    </section>
  );
}
