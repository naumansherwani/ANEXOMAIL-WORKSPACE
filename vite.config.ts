// @lovable.dev/vite-tanstack-config already includes the following — do NOT add them manually
// or the app will break with duplicate plugins:
//   - TanStack devtools (dev-only, first), tanstackStart, viteReact, tailwindcss, tsConfigPaths,
//     nitro (build-only using cloudflare as a default target), VITE_* env injection, @ path alias,
//     React/TanStack dedupe, error logger plugins, and sandbox detection (port/host/strictPort).
// You can pass additional config via defineConfig({ vite: { ... }, etc... }) if needed.
import { defineConfig } from "@lovable.dev/vite-tanstack-config";
import { VitePWA } from "vite-plugin-pwa";

export default defineConfig({
  // Phase 28 — Cross-Platform: installable PWA + offline READ shell.
  // Registration lives in src/lib/pwa.ts (guarded); the plugin never injects it.
  plugins: [
    VitePWA({
      strategies: "generateSW",
      registerType: "autoUpdate",
      injectRegister: null,
      filename: "sw.js",
      devOptions: { enabled: false },
      manifest: false,
      workbox: {
        globPatterns: ["**/*.{js,css,woff2,png,svg,webmanifest}"],
        navigateFallback: "/",
        navigateFallbackDenylist: [/^\/~oauth/, /^\/api\//],
        cleanupOutdatedCaches: true,
        runtimeCaching: [
          {
            urlPattern: ({ request }) => request.mode === "navigate",
            handler: "NetworkFirst",
            options: { cacheName: "ax-pages", networkTimeoutSeconds: 4 },
          },
          {
            urlPattern: ({ request, sameOrigin }) =>
              sameOrigin && (request.destination === "script" || request.destination === "style"),
            handler: "CacheFirst",
            options: { cacheName: "ax-assets" },
          },
        ],
      },
    }),
  ],
  tanstackStart: {
    // Redirect TanStack Start's bundled server entry to src/server.ts (our SSR error wrapper).
    // nitro/vite builds from this
    server: { entry: "server" },
  },
});
