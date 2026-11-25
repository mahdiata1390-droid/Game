import { defineConfig } from "vite";

// The cloud preview hostname changes between sessions, so it is supplied by the
// environment instead of being written into this file.
const env = (globalThis as {
  process?: { env: Record<string, string | undefined> };
}).process?.env;
const previewHosts = (env?.FORGE_PREVIEW_HOSTS ?? env?.__VITE_ADDITIONAL_SERVER_ALLOWED_HOSTS ?? "")
  .split(",")
  .map((host) => host.trim())
  .filter(Boolean);

export default defineConfig({
  server: {
    host: "0.0.0.0",
    port: 3000,
    strictPort: true,
    allowedHosts: previewHosts.length > 0 ? previewHosts : undefined,
  },
  build: {
    target: "es2022",
    outDir: "dist",
    sourcemap: false,
  },
});
