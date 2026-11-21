import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import tailwindcss from "@tailwindcss/vite";
import { fileURLToPath } from "node:url";
// ADMIN DESK (R3a1): its OWN build, its OWN output folder, its OWN host (admindesk.anexomail.com). The founder bundle never contains Desk code and this bundle contains no founder screens.
export default defineConfig({
  base: "/",
  plugins: [react(), tailwindcss()],
  resolve: { alias: { "@": fileURLToPath(new URL("./src", import.meta.url)) } },
  build: { outDir: "dist-desk", emptyOutDir: true, chunkSizeWarningLimit: 1200, target: "es2022", rollupOptions: { input: fileURLToPath(new URL("./desk.html", import.meta.url)) } },
});
