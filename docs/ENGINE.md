# Forge Engine

**Forge is our own game engine, built in this repository.** It is not yet "better than Godot" — nobody builds a general-purpose engine that beats a 10-year, 90-person open-source project in one sitting. What exists here is a real, working v0.1: a WebGL2 renderer, an entity/component runtime, a scene format, an in-browser editor, and the medieval sandbox world running on all of it, with zero binary assets required.

The honest claim: **Forge is already better than Godot for this project's workflow** (no install, no editor download, one-command run, ~1 draw call, instant reload, a ~40 KB world), and it is far behind Godot on production features (animation, physics, audio, shadows, mobile export, docs, community). The gap is listed below instead of hidden.

---

## Run it

```bash
npm install
npm run dev        # http://localhost:3000
npm run build      # typecheck + production bundle in dist/
npm run packs:list # asset pack catalogue with sizes and licences
```

Controls: `WASD` move · drag look · wheel zoom · `Space` or click attack · `F` first/third person · touch: left half is a stick, right half looks.

## What is implemented

| Module | File | What it does |
| --- | --- | --- |
| Math | `src/engine/math.ts` | vec3 helpers, column-major mat4, perspective, lookAt, TRS compose |
| ECS | `src/engine/ecs.ts` | entities, typed component stores, queries, stats |
| Renderer | `src/engine/renderer.ts` | WebGL2 instanced forward pass, atlas sampling, sun + hemisphere ambient, fog, selection highlight, one draw call |
| Textures | `src/engine/textures.ts` | deterministic 1024×1024 procedural atlas: 35 painted tiles (five masonries, four roofs, five metals, armour, cloth, water, eight heraldry devices) with guard bands so mipmaps cannot bleed between tiles |
| Input | `src/engine/input.ts` | keyboard, mouse, wheel, drag-look, mobile virtual stick |
| Scene | `src/engine/scene.ts` | JSON save/load of every component, versioned format |
| World | `src/game/world.ts` | 12 settlements, 6 factions, forests, warbands, combat, day/night, collision, body-aware camera |
| Houses | `src/game/houses.ts` | the five powers plus the free company: stone, roof, metal, heraldry, armour, weapon and combat profile |
| Architecture | `src/game/architecture.ts` | castles, gatehouses, curtain walls, drum towers, keeps, townhouses, cottages, markets, wells, braziers |
| Figures | `src/game/figures.ts` | twenty-instance character rigs: armour, helmets, shields, cloaks, six weapons, walk and swing animation |
| Editor | `src/editor/main.ts` | play/pause, hierarchy, inspector, save/load, perf counters, asset pack panel |
| Packs | `tools/fetch-packs.mjs` | list/verify/download CC0 asset packs, size-capped, hash-recorded |

### Frame loop

```
resize → camera from input → fixed-cap simulation step → build instance list
      → upload one instance buffer → one drawElementsInstanced → DOM HUD
```

The renderer keeps every box, tree, tower and soldier in a single instanced draw. Each instance stores a model matrix (16 floats), albedo + atlas tile (4), and UV repeat/emissive/selection (4): 96 bytes. 1,000 objects cost ~94 KiB of instance data and **one** draw call.

Measured production build: **85.7 kB JavaScript (29.4 kB gzipped)** plus 7.6 kB CSS — no engine runtime download, no WebAssembly, no asset request on boot. The art system (five powers, castles, character rigs, 35-tile atlas) is part of that, at ~6,500 instances in one draw call.

### Scene format

```json
{ "format": "forge-scene", "version": 1,
  "entities": [{ "id": 12, "components": { "Transform": { "x": 0 } } }] }
```

Saving writes this to `localStorage` from the editor; loading rebuilds a fresh world and re-finds the player entity. Because it is plain JSON, a build pipeline, a test, or a future CLI can edit scenes without opening the editor.

---

## Asset packs, graphics and size

The engine deliberately boots with **0 MB of binary art**: the atlas is painted at runtime, so the game renders identically on first clone and on an offline phone. Optional CC0 packs upgrade the look. Sizes below are approximate download sizes; `packs/registry.json` is the source of truth and `packs/` is git-ignored, so the repository does not grow.

| Pack | Use | ~Size | Licence |
| --- | --- | --- | --- |
| Poly Haven sky HDRI (1k) | sky + image ambient | 1.1 MB | CC0 |
| Kenney Castle Kit | walls, gates, battlements | 4.5 MB | CC0 |
| Kenney Nature Kit | trees, rocks, cliffs | 8.2 MB | CC0 |
| Kenney Medieval RTS | map markers, banners | 1.2 MB | CC0 |
| Kenney UI Pack | touch HUD | 1.6 MB | CC0 |
| Kenney RPG Audio | sword/hit/UI audio | 9.4 MB | CC0 |
| Quaternius Ultimate Fantasy | animated characters | 12.5 MB | CC0 |

Total if everything is fetched: **~38.5 MB**, none of it committed. The HDRI was fetched and hash-verified during this build (1.12 MB on disk). Fetch only what a scene needs:

```bash
npm run packs:list
npm run packs:fetch -- --pack=polyhaven-sky-1k
npm run packs:fetch -- --all --extract
npm run packs:verify
```

Budget targets in the registry: repository < 15 MB, APK < 90 MB, texture RAM < 64 MB. The current build needs **0 MB** of the first two.

---

## Where Forge beats Godot for *this* game

- **Zero install.** A browser tab is the editor and the game; CI needs Node, not a 1 GB editor download or a licence.
- **One command to ship a preview.** `npm run dev`, or a static `dist/` anywhere.
- **Measurable frame cost.** One draw call, explicit instance bytes, live counters in the toolbar.
- **Tiny, readable codebase.** ~2,000 lines of engine, world and editor you can change today versus a multi-million-line C++ engine.
- **Deterministic, code-first worlds.** No `.tscn` merge conflicts; the world is reviewable source.
- **Trivial modding.** Scenes are JSON and components are plain objects.

## Where Godot is still years ahead

- Skeletal animation, IK, retargeting, animation trees.
- Real physics: 3D bodies, joints, character controllers, soft bodies.
- Shadow maps, GI, post-processing, PBR materials, glTF import.
- Audio buses and spatial audio.
- Navigation meshes and pathfinding.
- Android/iOS/desktop/console export, controller support, platform QA.
- A mature visual editor: gizmos, undo, prefabs, tilemaps, terrain, plugin ecosystem.
- Documentation, tutorials, community, and a decade of bug reports.

## Roadmap that could actually get us there

1. **v0.2 — content pipeline:** glTF/GLB importer, texture packs, material params, shadow map, frustum culling.
2. **v0.3 — believable world:** skeletal animation (glTF skins), spatial audio, Rapier physics, navigation grid.
3. **v0.4 — editor:** transform gizmos, undo/redo, prefabs, terrain sculpt, scene graph view, gizmo snapping.
4. **v0.5 — ship:** PWA offline cache, Capacitor Android wrapper, device profiling, save slots, localisation (Persian/English).
5. **v1.0 — parity:** the features in the "years ahead" list, each with tests, on at least one phone that is not the developer's.

Steps 1–2 are weeks of focused work. Full Godot parity is a multi-year, multi-person effort, and claiming otherwise would be dishonest.
