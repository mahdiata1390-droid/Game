#!/usr/bin/env node
// Fetch the CC0 asset packs listed in packs/registry.json.
//
//   node tools/fetch-packs.mjs --list
//   node tools/fetch-packs.mjs --pack=polyhaven-sky-1k
//   node tools/fetch-packs.mjs --all --extract
//   node tools/fetch-packs.mjs --verify
//
// Packs without a direct URL are licensed but gated behind a download page, so
// they are reported with instructions instead of being fetched automatically.
// Nothing is written outside packs/<id>/.

import { createHash } from "node:crypto";
import { createWriteStream } from "node:fs";
import { mkdir, readFile, rename, rm, stat, writeFile } from "node:fs/promises";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { Readable } from "node:stream";
import { pipeline } from "node:stream/promises";
import { execFile } from "node:child_process";
import { promisify } from "node:util";

const here = dirname(fileURLToPath(import.meta.url));
const root = resolve(here, "..");
const registryPath = join(root, "packs", "registry.json");
const run = promisify(execFile);

const args = process.argv.slice(2);
const flags = new Set(
  args.filter((a) => a.startsWith("--") && !a.includes("=")).map((a) => a.slice(2)),
);
const values = new Map(
  args.filter((a) => a.includes("=")).map((a) => {
    const index = a.indexOf("=");
    return [a.slice(2, index), a.slice(index + 1)];
  }),
);

const registry = JSON.parse(await readFile(registryPath, "utf8"));
const packs = registry.packs;
const outDir = resolve(root, values.get("dir") ?? "packs");

const selected = values.get("pack")
  ? packs.filter((p) => p.id === values.get("pack"))
  : flags.has("all")
    ? packs
    : [];

function mb(bytes) {
  return (bytes / (1024 * 1024)).toFixed(2);
}

function list() {
  console.log(`Asset packs (${packs.length}) — nothing is downloaded until you ask.\n`);
  let total = 0;
  for (const pack of packs) {
    total += pack.approxSizeMB;
    const mode = pack.url ? "auto  " : "manual";
    console.log(`  ${mode}  ${pack.id.padEnd(26)} ~${String(pack.approxSizeMB).padStart(5)} MB  ${pack.license}`);
    console.log(`          ${pack.name} — ${pack.contents}`);
    console.log(`          ${pack.homepage}`);
  }
  console.log(`\nTotal if every pack is fetched: ~${total.toFixed(1)} MB`);
  console.log("Select packs: npm run packs:fetch -- --pack=<id>");
  console.log("Everything with a direct URL: npm run packs:fetch -- --all");
}

async function sha256(path) {
  const buffer = await readFile(path);
  return createHash("sha256").update(buffer).digest("hex");
}

async function download(pack) {
  const targetDir = join(outDir, pack.id);
  await mkdir(targetDir, { recursive: true });
  const fileName = new URL(pack.url).pathname.split("/").pop() || `${pack.id}.bin`;
  const target = join(targetDir, fileName);

  const head = await fetch(pack.url, { method: "HEAD", redirect: "follow" });
  if (!head.ok) throw new Error(`HEAD ${pack.url} → HTTP ${head.status}`);
  const expected = Number(head.headers.get("content-length") ?? 0);
  const limit = (pack.maxMB ?? 300) * 1024 * 1024;
  if (expected > limit) throw new Error(`${pack.id} is ${mb(expected)} MB, over the ${pack.maxMB} MB limit`);

  const response = await fetch(pack.url, { redirect: "follow" });
  if (!response.ok || !response.body) throw new Error(`GET ${pack.url} → HTTP ${response.status}`);

  const temp = `${target}.part`;
  await rm(temp, { force: true });
  await pipeline(Readable.fromWeb(response.body), createWriteStream(temp));
  const info = await stat(temp);
  if (expected > 0 && info.size !== expected) {
    await rm(temp, { force: true });
    throw new Error(`size mismatch: expected ${expected} bytes, got ${info.size}`);
  }
  await rm(target, { force: true });
  await rename(temp, target);

  const size = (await stat(target)).size;
  console.log(`  ✓ ${pack.id} — ${mb(size)} MB → ${target.replace(root + "/", "")}`);
  return { id: pack.id, file: target, bytes: size, sha256: await sha256(target), at: new Date().toISOString() };
}

async function extract(pack, file) {
  if (!file.endsWith(".zip")) return;
  try {
    await run("unzip", ["-qo", file, "-d", join(outDir, pack.id)]);
    console.log(`  ↳ extracted ${pack.id}`);
  } catch (error) {
    console.log(`  ↳ could not extract ${pack.id} (${error.message.split("\n")[0]}); the archive is kept`);
  }
}

async function verify() {
  const dir = join(outDir, "INSTALLED.json");
  try {
    const installed = JSON.parse(await readFile(dir, "utf8"));
    let ok = 0;
    for (const entry of installed.packs ?? []) {
      try {
        const info = await stat(entry.file);
        const hash = await sha256(entry.file);
        if (info.size === entry.bytes && hash === entry.sha256) {
          ok++;
          console.log(`  ✓ ${entry.id}`);
        } else {
          console.log(`  ✗ ${entry.id} — file changed or truncated`);
        }
      } catch {
        console.log(`  ✗ ${entry.id} — missing`);
      }
    }
    console.log(`\n${ok}/${(installed.packs ?? []).length} packs verified.`);
  } catch {
    console.log("No packs installed yet. Run: npm run packs:fetch -- --pack=<id>");
  }
}

if (flags.has("list") || args.length === 0) {
  list();
} else if (flags.has("verify")) {
  await verify();
} else if (selected.length === 0) {
  console.log("Unknown --pack. Run with --list to see ids.");
  process.exitCode = 1;
} else {
  await mkdir(outDir, { recursive: true });
  const installedPath = join(outDir, "INSTALLED.json");
  let installed = { packs: [] };
  try {
    installed = JSON.parse(await readFile(installedPath, "utf8"));
  } catch {
    // first run
  }

  let failures = 0;
  for (const pack of selected) {
    if (!pack.url) {
      console.log(`  ! ${pack.id} needs a manual download`);
      console.log(`    open ${pack.homepage}`);
      console.log(`    put its files in packs/${pack.id}/ (license: ${pack.license})`);
      continue;
    }
    try {
      console.log(`↓ ${pack.id}`);
      const record = await download(pack);
      if (flags.has("extract")) await extract(pack, record.file);
      installed.packs = [...(installed.packs ?? []).filter((p) => p.id !== pack.id), record];
      await writeFile(installedPath, JSON.stringify(installed, null, 2) + "\n");
    } catch (error) {
      failures++;
      console.error(`  ✗ ${pack.id}: ${error.message}`);
    }
  }
  console.log(failures ? `\n${failures} pack(s) failed.` : "\nDone.");
  if (failures) process.exitCode = 1;
}
