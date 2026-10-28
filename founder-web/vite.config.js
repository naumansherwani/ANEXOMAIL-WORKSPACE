import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
// Founder SPA: static build (sandbox/CI mein), server par sirf Rust binary dist/ serve karti hai. Bun/Node server par nahi.
export default defineConfig({ base: "./", plugins: [react()], build: { outDir: "dist", chunkSizeWarningLimit: 1200, target: "es2022" } });
