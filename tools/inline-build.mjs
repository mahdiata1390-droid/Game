#!/usr/bin/env node
// Turn the Vite production build in dist/ into a single self-contained HTML file,
// so a downloaded artifact opens by double-click (file://) without a static server.
// The inlined code is byte-for-byte the same bundle Vite emitted; nothing is rebuilt.
import { readFileSync, writeFileSync, existsSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const distDir = resolve(root, "dist");
const indexPath = resolve(distDir, "index.html");
const outPath = resolve(distDir, "medieval-sandbox.html");

if (!existsSync(indexPath)) {
  console.error("dist/index.html not found — run `npm run build` first.");
  process.exit(1);
}

const readAsset = (href) => {
  const clean = href.split("?")[0].split("#")[0];
  const file = resolve(distDir, clean.replace(/^\//, ""));
  if (!existsSync(file)) {
    throw new Error(`referenced asset missing from dist: ${href} -> ${file}`);
  }
  return readFileSync(file, "utf8");
};

let html = readFileSync(indexPath, "utf8");
const inlined = [];

// Stylesheets: <link rel="stylesheet" href="/assets/x.css"> -> <style>…</style>
html = html.replace(/<link\b[^>]*rel=["']stylesheet["'][^>]*>/gi, (tag) => {
  const href = /href=["']([^"']+)["']/i.exec(tag)?.[1];
  if (!href) return tag;
  inlined.push(href);
  // Escape any closing tag inside CSS strings so the style block cannot be cut short.
  const css = readAsset(href).replace(/<\/style/gi, "<\\/style");
  return `<style>\n${css}\n</style>`;
});

// Scripts: <script type="module" src="/assets/x.js"></script> -> inline module
html = html.replace(/<script\b([^>]*)>(<\/script>)?\s*<\/script>/gi, (tag, attrs, _body) => {
  const src = /\bsrc=["']([^"']+)["']/i.exec(attrs)?.[1];
  if (!src) return tag;
  inlined.push(src);
  const js = readAsset(src).replace(/<\/script/gi, "<\\/script");
  const isModule = /\btype=["']module["']/i.test(attrs);
  return `<script${isModule ? ' type="module"' : ""}>\n${js}\n</script>`;
});

const leftover = [...html.matchAll(/\b(?:src|href)=["']([^"']+)["']/gi)]
  .map((m) => m[1])
  .filter((v) => !/^(?:data:|#|https?:)/i.test(v) && /\.(?:js|css|mjs)$/i.test(v));

if (leftover.length > 0) {
  console.error(`build is not self-contained, still references: ${leftover.join(", ")}`);
  process.exit(1);
}

writeFileSync(outPath, html, "utf8");

const kb = (n) => `${(n / 1024).toFixed(1)} kB`;
console.log(`inlined ${inlined.length} file(s): ${inlined.join(", ")}`);
console.log(`wrote ${outPath} (${kb(Buffer.byteLength(html))})`);
