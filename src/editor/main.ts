import "../styles.css";

import { createAtlasTexture } from "../engine/textures";
import { Input } from "../engine/input";
import { Renderer, type Instance } from "../engine/renderer";
import { loadScene, parseScene, serializeWorld, type SceneFile } from "../engine/scene";
import type { Entity } from "../engine/ecs";
import registryJson from "../../packs/registry.json";
import {
  CameraRig,
  MedievalWorld,
  type Appearance,
  type Character,
  type Meta,
  type Transform,
} from "../game/world";
import { Council } from "./council";

const SCENE_KEY = "forge.scene.v1";

function $<T extends HTMLElement>(id: string): T {
  const el = document.getElementById(id);
  if (!el) throw new Error(`missing #${id}`);
  return el as T;
}

const canvas = $<HTMLCanvasElement>("scene");
const boot = $("boot");
const statusEl = $("status");
const perfEl = $("perf");
const statsEl = $("stats");
const hierarchyEl = $<HTMLUListElement>("hierarchy");
const inspectorEl = $("inspector");
const entityCountEl = $("entity-count");
const modePill = $("mode-pill");
const hudHealth = $("hud-health");
const hudHealthBar = $("hud-healthbar");
const hudDay = $("hud-day");
const hudGold = $("hud-gold");
const hudWarband = $("hud-warband");
const hudFoes = $("hud-foes");
const hudLog = $("hud-log");
const searchEl = $<HTMLInputElement>("hierarchy-search");
const touchStickEl = $("touch-stick");
const touchKnobEl = $("touch-knob");

let game: MedievalWorld;
let renderer: Renderer;
let input: Input;
let council: Council | null = null;
const rig = new CameraRig();
let playing = false;
let selected: Entity | null = null;
let filter = "";

function setStatus(message: string): void {
  statusEl.textContent = message;
}

function start(): void {
  const gl = canvas.getContext("webgl2");
  if (!gl) {
    boot.textContent = "This browser has no WebGL2 support.";
    return;
  }
  const atlas = createAtlasTexture(gl);
  renderer = new Renderer(canvas, atlas);
  input = new Input(canvas);
  game = new MedievalWorld();
  refreshWorldUI();
  boot.classList.add("hidden");
  initTouchControls();
  initCouncil();
  setStatus("World ready — press Play to take command.");
  // Development-only handle so the world can be staged and inspected from the
  // console. Production builds strip it.
  const dev = (import.meta as unknown as { env?: { DEV?: boolean } }).env?.DEV === true;
  if (dev) {
    (window as unknown as { forge?: unknown }).forge = { game, rig, renderer };
  }
  requestAnimationFrame(frame);
}

// ------------------------------------------------------------------- editing

function refreshWorldUI(): void {
  selected = null;
  renderHierarchy();
  renderInspector();
  const counts = game.world.counts();
  entityCountEl.textContent = `${counts.entities} entities · ${game.world.query("Meta").length} authored`;
}

function renderHierarchy(): void {
  hierarchyEl.replaceChildren();
  const groups = new Map<string, Entity[]>();
  for (const id of game.world.query("Meta", "Transform")) {
    const meta = game.world.require<Meta>(id, "Meta");
    if (filter && !meta.name.toLowerCase().includes(filter)) continue;
    const list = groups.get(meta.group) ?? [];
    list.push(id);
    groups.set(meta.group, list);
  }
  for (const [group, ids] of groups) {
    const heading = document.createElement("li");
    heading.className = "group";
    heading.textContent = group;
    heading.style.cssText = "color:#8a7c5a;font-size:10px;letter-spacing:.08em;text-transform:uppercase;cursor:default;padding:8px 7px 3px";
    hierarchyEl.append(heading);

    for (const id of ids) {
      const meta = game.world.require<Meta>(id, "Meta");
      const appearance = game.world.get<Appearance>(id, "Appearance");
      const li = document.createElement("li");
      li.dataset.entity = String(id);
      if (selected === id) li.classList.add("selected");

      const swatch = document.createElement("span");
      swatch.className = "swatch";
      if (appearance) {
        const hex = `rgb(${Math.round(Math.min(1, appearance.r) * 255)},${Math.round(Math.min(1, appearance.g) * 255)},${Math.round(Math.min(1, appearance.b) * 255)})`;
        swatch.style.background = hex;
      }
      const label = document.createElement("span");
      label.textContent = meta.name;
      label.style.overflow = "hidden";
      label.style.textOverflow = "ellipsis";

      li.append(swatch, label);
      li.addEventListener("click", () => {
        selected = id;
        renderHierarchy();
        renderInspector();
        setStatus(`Selected ${meta.name}`);
      });
      hierarchyEl.append(li);
    }
  }
  if (hierarchyEl.children.length === 0) {
    hierarchyEl.innerHTML = '<li style="color:#7c7d84;cursor:default">Nothing matches.</li>';
  }
}

function renderInspector(): void {
  inspectorEl.replaceChildren();
  if (selected === null || !game.world.has(selected)) {
    const p = document.createElement("p");
    p.className = "muted";
    p.textContent = "Select an entity in the World list.";
    inspectorEl.append(p);
    return;
  }
  const id = selected;
  const meta = game.world.get<Meta>(id, "Meta");
  const t = game.world.get<Transform>(id, "Transform");
  const a = game.world.get<Appearance>(id, "Appearance");
  const c = game.world.get<Character>(id, "Character");

  const title = document.createElement("h3");
  title.textContent = meta?.name ?? `Entity ${id}`;
  inspectorEl.append(title);
  if (c) {
    const badge = document.createElement("p");
    badge.className = "muted";
    badge.textContent = `${c.faction} · ${Math.max(0, Math.round(c.hp))}/${c.maxHp} HP`;
    inspectorEl.append(badge);
  }

  if (t) {
    const row = (label: string, axes: Array<keyof Transform>, step = 0.1, apply: (axis: keyof Transform, value: number) => void) => {
      const wrap = document.createElement("div");
      wrap.className = "field";
      const lab = document.createElement("label");
      lab.textContent = label;
      const triple = document.createElement("div");
      triple.className = "triple";
      for (const axis of axes) {
        const field = document.createElement("input");
        field.type = "number";
        field.step = String(step);
        field.value = (t[axis] as number).toFixed(2);
        field.addEventListener("input", () => {
          const value = Number(field.value);
          if (Number.isFinite(value)) apply(axis, value);
        });
        triple.append(field);
      }
      wrap.append(lab, triple);
      inspectorEl.append(wrap);
    };
    row("Position", ["x", "y", "z"], 0.1, (axis, value) => { t[axis] = value; });
    row("Scale", ["sx", "sy", "sz"], 0.1, (axis, value) => { t[axis] = Math.max(0.02, value); });
    row("Rotation", ["yaw", "pitch"], 0.05, (axis, value) => { t[axis] = value; });
  }

  if (a) {
    const wrap = document.createElement("div");
    wrap.className = "field";
    const lab = document.createElement("label");
    lab.textContent = "Colour";
    const color = document.createElement("input");
    color.type = "color";
    const toHex = (v: number) => Math.round(Math.min(1, Math.max(0, v)) * 255).toString(16).padStart(2, "0");
    color.value = `#${toHex(a.r)}${toHex(a.g)}${toHex(a.b)}`;
    color.addEventListener("input", () => {
      const value = color.value;
      a.r = parseInt(value.slice(1, 3), 16) / 255;
      a.g = parseInt(value.slice(3, 5), 16) / 255;
      a.b = parseInt(value.slice(5, 7), 16) / 255;
      renderHierarchy();
    });
    wrap.append(lab, color);
    inspectorEl.append(wrap);

    const emissive = document.createElement("div");
    emissive.className = "field";
    emissive.innerHTML = "<label>Glow</label>";
    const range = document.createElement("input");
    range.type = "range";
    range.min = "0";
    range.max = "1";
    range.step = "0.05";
    range.value = String(a.emissive);
    range.addEventListener("input", () => { a.emissive = Number(range.value); });
    emissive.append(range);
    inspectorEl.append(emissive);
  }
}

// ------------------------------------------------------------- scene actions

function saveScene(): void {
  try {
    const scene = serializeWorld(game.world);
    localStorage.setItem(SCENE_KEY, JSON.stringify(scene));
    setStatus(`Saved ${scene.entities.length} entities to local storage.`);
  } catch (error) {
    setStatus(`Save failed: ${(error as Error).message}`);
  }
}

function loadSavedScene(): void {
  const raw = localStorage.getItem(SCENE_KEY);
  if (!raw) {
    setStatus("No saved scene yet — press Save scene first.");
    return;
  }
  try {
    const scene: SceneFile = parseScene(raw);
    const next = new MedievalWorld(false);
    loadScene(next.world, scene);
    const player = next.findPlayer();
    if (!player) throw new Error("scene has no player entity");
    next.player = player;
    next.refresh();
    game = next;
    playing = false;
    syncPlayButtons();
    refreshWorldUI();
    initCouncil();
    setStatus(`Loaded ${scene.entities.length} entities.`);
  } catch (error) {
    setStatus(`Load failed: ${(error as Error).message}`);
  }
}

function newWorld(): void {
  game = new MedievalWorld();
  playing = false;
  syncPlayButtons();
  refreshWorldUI();
  initCouncil();
  setStatus("New world generated.");
}

// ------------------------------------------------------------------- council

// The council is rebuilt whenever the world is, so its holdings always point at
// the settlements actually standing in the sandbox.
function initCouncil(): void {
  council?.destroy();
  council = new Council({
    kingdom: game.kingdom,
    onChange: (message, ok) => {
      if (message) setStatus(ok ? message : `The council refuses: ${message}`);
    },
    onEndDay: () => {
      game.advanceDay();
      setStatus(`Day ${game.day}: the council has ruled.`);
    },
  });
}

function openCouncil(): void {
  if (!council) return;
  setPlaying(false);
  council.show();
  setStatus("The council is seated.");
}

function toggleCouncil(): void {
  if (!council) return;
  if (council.open) {
    council.close();
    setStatus("The council rises.");
  } else {
    openCouncil();
  }
}

window.addEventListener("keydown", (event) => {
  if (event.code === "KeyM" && !(event.target instanceof HTMLInputElement)) {
    event.preventDefault();
    toggleCouncil();
  }
});

function setPlaying(next: boolean): void {
  playing = next;
  syncPlayButtons();
  setStatus(next ? "Simulation running." : "Simulation paused.");
}

let touchLayer = false;

function syncPlayButtons(): void {
  $("btn-play").classList.toggle("active", playing);
  modePill.textContent = playing ? "Playing" : "Edit";
  modePill.classList.toggle("playing", playing);
  $("touch-play").textContent = playing ? "Pause" : "Play";
}

// Touch build: the editor chrome is hidden, so the stick, the strike button and a
// play toggle are the whole interface. The simulation starts on its own because a
// phone has no visible Play button.
function initTouchControls(): void {
  const touch = input.isTouch || "ontouchstart" in window;
  if (!touch) return;
  touchLayer = true;
  document.body.classList.add("touch");
  $("touch-strike").addEventListener("pointerdown", (event) => {
    event.preventDefault();
    input.queueAttack();
  });
  $("touch-play").addEventListener("click", () => setPlaying(!playing));
  setPlaying(true);
}

function updateTouchVisual(): void {
  const visual = input.stickVisual;
  touchStickEl.classList.toggle("active", visual.active);
  if (!visual.active) return;
  touchStickEl.style.left = `${visual.originX}px`;
  touchStickEl.style.top = `${visual.originY}px`;
  touchKnobEl.style.transform = `translate(${visual.x * 30}px, ${visual.y * 30}px)`;
}

$("btn-council").addEventListener("click", openCouncil);
$("btn-play").addEventListener("click", () => setPlaying(true));
$("btn-stop").addEventListener("click", () => setPlaying(false));
$("btn-save").addEventListener("click", saveScene);
$("btn-load").addEventListener("click", loadSavedScene);
$("btn-reset").addEventListener("click", newWorld);
searchEl.addEventListener("input", () => {
  filter = searchEl.value.trim().toLowerCase();
  renderHierarchy();
});

// --------------------------------------------------------------- asset packs

type Pack = {
  id: string;
  name: string;
  category: string;
  license: string;
  approxSizeMB: number;
  url: string | null;
  homepage: string;
  contents: string;
  why: string;
};

function loadPacks(): void {
  const container = $("packs");
  try {
    const registry = registryJson as unknown as { packs: Pack[] };
    container.replaceChildren();
    let total = 0;
    for (const pack of registry.packs) {
      total += pack.approxSizeMB;
      const item = document.createElement("div");
      item.className = "pack";
      const top = document.createElement("div");
      top.className = "pack-top";
      const name = document.createElement("span");
      name.className = "pack-name";
      name.textContent = pack.name;
      const size = document.createElement("span");
      size.className = "pack-size";
      size.textContent = `~${pack.approxSizeMB} MB`;
      top.append(name, size);

      const meta = document.createElement("div");
      meta.className = "pack-meta";
      meta.append(document.createTextNode(`${pack.category} · ${pack.license} · ${pack.contents}`));
      if (pack.url) {
        meta.append(document.createTextNode(" · direct download"));
      } else {
        meta.append(document.createTextNode(" · manual download"));
      }

      const code = document.createElement("code");
      code.textContent = pack.url
        ? `npm run packs:fetch -- --pack=${pack.id}`
        : `open ${pack.homepage.replace(/^https?:\/\//, "")} → packs/${pack.id}/`;

      item.append(top, meta, code);
      container.append(item);
    }
    $("pack-total").textContent = `${registry.packs.length} packs · ~${total.toFixed(1)} MB if all fetched · 0 MB committed`;
  } catch (error) {
    container.innerHTML = `<p class="muted">Registry unavailable (${(error as Error).message}). Run npm run packs:list.</p>`;
  }
}

// ------------------------------------------------------------------ main loop

let last = performance.now();
let fpsAccum = 0;
let fpsFrames = 0;
let hudTick = 0;
const instances: Instance[] = [];

function frame(now: number): void {
  const dt = Math.min((now - last) / 1000, 0.05);
  last = now;

  renderer.resize();
  const playerTransform = game.world.get<Transform>(game.player, "Transform");
  const target = playerTransform
    ? { x: playerTransform.x, y: playerTransform.y, z: playerTransform.z }
    : { x: 0, y: 0, z: 0 };

  const camera = rig.update(input, target, (distance) =>
    game.cameraDistance(target, rig.yaw, rig.pitch, distance));
  game.update(dt, input, rig.facing, playing);

  instances.length = 0;
  game.buildInstances(instances, selected, now / 1000, camera.eye);
  renderer.begin(camera, game.light());
  for (const instance of instances) renderer.push(instance);
  renderer.flush();

  fpsAccum += dt;
  fpsFrames++;
  hudTick += dt;
  if (hudTick > 0.15) {
    hudTick = 0;
    const fps = fpsFrames / Math.max(fpsAccum, 0.0001);
    fpsAccum = 0;
    fpsFrames = 0;
    perfEl.textContent = `${fps.toFixed(0)} fps`;
    statsEl.textContent = `${instances.length} instances · ${renderer.stats.drawCalls} draw call · ${(renderer.stats.gpuInstancesKiB / 1024).toFixed(2)} MiB`;
    updateHud();
  }

  if (touchLayer) updateTouchVisual();
  input.endFrame();
  requestAnimationFrame(frame);
}

function updateHud(): void {
  const player = game.world.get<Character>(game.player, "Character");
  const hp = player ? Math.max(0, Math.round(player.hp)) : 0;
  const max = player?.maxHp ?? 100;
  hudHealth.textContent = `${hp} / ${max}`;
  hudHealthBar.style.width = `${(hp / max) * 100}%`;
  hudDay.textContent = String(game.day);
  hudGold.textContent = String(game.gold);
  hudWarband.textContent = String(game.aliveAllies);
  hudFoes.textContent = String(game.aliveEnemies);
  hudLog.textContent = game.log;
}

// The Android back button pauses the sandbox before the activity leaves.
window.addEventListener("forge:pause", () => setPlaying(false));

loadPacks();
requestAnimationFrame(() => start());
