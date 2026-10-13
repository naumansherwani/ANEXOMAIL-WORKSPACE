import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import {
  Outlet,
  Link,
  createRootRouteWithContext,
  useRouter,
  HeadContent,
  Scripts,
} from "@tanstack/react-router";
import { useEffect, type ReactNode } from "react";

import appCss from "../styles.css?url";
import { Toaster } from "@/components/ui/sonner";
import { AuthProvider } from "@/lib/auth";
import { CrossPlatformBar } from "@/components/app/CrossPlatformBar";
import { SiteLock } from "@/components/site/SiteLock";
import { FounderBar } from "@/components/site/FounderBar";
import { VisitorBadge } from "@/components/site/VisitorBadge";
import { useLocale } from "@/lib/i18n";
import { registerServiceWorker } from "@/lib/pwa";
import { startTelemetry } from "@/lib/telemetry";

function NotFoundComponent() {
  const { t } = useLocale();
  return (
    <div className="flex min-h-screen items-center justify-center bg-background px-4">
      <div className="ax-in max-w-md text-center">
        <h1 className="ax-display ax-platinum-text">404</h1>
        <h2 className="ax-heading mt-ax-4 text-foreground">{t("Page not found")}</h2>
        <p className="ax-body mt-ax-2">
          {t("The page you're looking for doesn't exist or has been moved.")}
        </p>
        <div className="mt-ax-5">
          <Link
            to="/"
            className="ax-press ax-focus ax-tap inline-flex items-center justify-center rounded-md bg-primary px-ax-4 py-ax-2 ax-label text-primary-foreground hover:bg-primary/90"
          >
            {t("Go home")}
          </Link>
        </div>
      </div>
    </div>
  );
}

function ErrorComponent({ error, reset }: { error: Error; reset: () => void }) {
  console.error(error);
  const router = useRouter();
  const { t } = useLocale();

  return (
    <div className="flex min-h-screen items-center justify-center bg-background px-4">
      <div className="ax-in max-w-md text-center" role="alert">
        <h1 className="ax-heading text-foreground">{t("This page didn't load")}</h1>
        <p className="ax-body mt-ax-2">
          {t("Something went wrong on our end. You can try refreshing or head back home.")}
        </p>
        <div className="mt-ax-5 flex flex-wrap justify-center gap-ax-2">
          <button
            onClick={() => {
              router.invalidate();
              reset();
            }}
            className="ax-press ax-focus ax-tap inline-flex items-center justify-center rounded-md bg-primary px-ax-4 py-ax-2 ax-label text-primary-foreground hover:bg-primary/90"
          >
            {t("Try again")}
          </button>
          <a
            href="/"
            className="ax-press ax-focus ax-tap inline-flex items-center justify-center rounded-md border border-input bg-background px-ax-4 py-ax-2 ax-label text-foreground hover:bg-accent"
          >
            {t("Go home")}
          </a>
        </div>
      </div>
    </div>
  );
}

export const Route = createRootRouteWithContext<{ queryClient: QueryClient }>()({
  head: () => ({
    meta: [
      { charSet: "utf-8" },
      { name: "viewport", content: "width=device-width, initial-scale=1" },
      { title: "ANEXOMAIL — Business Email Workspace" },
      {
        name: "description",
        content:
          "ANEXOMAIL is a premium business email workspace for custom domains — secure mail, contacts, calendar and teams.",
      },
      { property: "og:title", content: "ANEXOMAIL — Business Email Workspace" },
      {
        property: "og:description",
        content:
          "Premium business email on your own domain, with contacts, calendar, tasks and team collaboration.",
      },
      { property: "og:type", content: "website" },
      { name: "twitter:card", content: "summary_large_image" },
      { name: "theme-color", content: "#0b0b0c" },
      { name: "apple-mobile-web-app-capable", content: "yes" },
      { name: "apple-mobile-web-app-title", content: "ANEXOMAIL" },
      { name: "apple-mobile-web-app-status-bar-style", content: "black-translucent" },
    ],
    links: [
      {
        rel: "stylesheet",
        href: appCss,
      },
      { rel: "preconnect", href: "https://fonts.googleapis.com" },
      {
        rel: "preconnect",
        href: "https://fonts.gstatic.com",
        crossOrigin: "anonymous",
      },
      {
        rel: "stylesheet",
        href: "https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap",
      },
      { rel: "icon", href: "/favicon.svg", type: "image/svg+xml" },
      { rel: "manifest", href: "/manifest.webmanifest" },
      { rel: "apple-touch-icon", href: "/apple-touch-icon.png", sizes: "180x180" },
    ],
  }),
  shellComponent: RootShell,
  component: RootComponent,
  notFoundComponent: NotFoundComponent,
  errorComponent: ErrorComponent,
});

function RootShell({ children }: { children: ReactNode }) {
  return (
    <html lang="en-GB" className="dark">
      <head>
        <HeadContent />
        <script
          dangerouslySetInnerHTML={{
            __html: `(function(){try{var h=location.hostname;if(h!=="anexomail.com"&&h!=="www.anexomail.com"&&h!=="ai.anexomail.com"){document.documentElement.lang="en-GB";document.documentElement.dir="ltr";return;}var t=localStorage.getItem("ax.locale")||"en-GB";var rtl=/^(ur-PK|ar-SA|fa-IR)$/.test(t);document.documentElement.lang=t;document.documentElement.dir=rtl?"rtl":"ltr";}catch(e){}})();`,
          }}
        />
      </head>
      <body>
        {children}
        <Scripts />
      </body>
    </html>
  );
}

function LocaleRoot({ children }: { children: ReactNode }) {
  useLocale();
  return children;
}

function RootComponent() {
  const { queryClient } = Route.useRouteContext();

  // Phase 28 — Cross-Platform: guarded SW registration (prod, non-preview only).
  useEffect(() => {
    registerServiceWorker();
  }, []);

  // Phase 47 — PostHog session replay + glitch reporting (CRM alerts backend se).
  useEffect(() => {
    void startTelemetry();
  }, []);

  return (
    <QueryClientProvider client={queryClient}>
      <AuthProvider>
        {/* Host gate: anexomail.com = awam product; AI host coming-soon; unlock key baqi. */}
        <LocaleRoot>
        <SiteLock>
          {/* Founder-only preview strip — awam ko bilkul invisible. */}
          <FounderBar />
          {/* Required: nested routes render here. Removing <Outlet /> breaks all child routes. */}
          <Outlet />
          <CrossPlatformBar />
          <VisitorBadge />
          <Toaster />
        </SiteLock>
        </LocaleRoot>
      </AuthProvider>
    </QueryClientProvider>
  );
}
