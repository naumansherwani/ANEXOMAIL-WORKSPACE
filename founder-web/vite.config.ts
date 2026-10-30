import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import tailwindcss from "@tailwindcss/vite";
import { fileURLToPath } from "node:url";
// Founder SPA: static build (sandbox/CI mein), server par sirf Rust binary dist/ serve karti hai. Bun/Node server par nahi.
export default defineConfig({
  base: "/_cc/",
  plugins: [react(), tailwindcss()],
  resolve: { alias: { "@": fileURLToPath(new URL("./src", import.meta.url)) } },
  build: { outDir: "dist", chunkSizeWarningLimit: 1200, target: "es2022" },
});
