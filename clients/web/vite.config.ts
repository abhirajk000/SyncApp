import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import { readFileSync, writeFileSync } from "node:fs";
import { resolve } from "node:path";

const BUILD_ID = `${Date.now()}`;

export default defineConfig({
  define: {
    "import.meta.env.VITE_BUILD_ID": JSON.stringify(BUILD_ID),
  },
  plugins: [
    react(),
    {
      name: "syncbridge-build-meta",
      closeBundle() {
        const dist = resolve(__dirname, "dist");
        writeFileSync(
          resolve(dist, "version.json"),
          JSON.stringify({ build: BUILD_ID, at: new Date().toISOString() }),
        );
        const swTemplate = readFileSync(resolve(__dirname, "public/sw.js"), "utf8");
        writeFileSync(resolve(dist, "sw.js"), swTemplate.replaceAll("__BUILD_ID__", BUILD_ID));
      },
    },
  ],
  server: {
    port: 5173,
    proxy: {
      "/api": {
        target: "http://localhost:8080",
        changeOrigin: true,
      },
    },
  },
});
