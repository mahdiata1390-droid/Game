# Technical Audit — release-candidate

Engine: Godot 4.7.2. Branch: `release-candidate`. The Unity prototype described in older commits was never compiled or packaged and is historical.

## 1. Validation was disabled rather than satisfied

`godot/project.godot` contained:

```ini
[debug/gdscript]
warnings/enable=false
warnings/treat_warnings_as_errors=false
warnings/inference_on_variant=0
```

This made the project appear to import cleanly. GDScript's Variant-inference check is an error by default, and several real type errors in the codebase were only invisible because warnings were switched off.

Those settings were removed. With validation restored, **62 parse errors** appeared across 9 files, mostly `var x := <untyped expression>` declarations in `world_state.gd`, `campaign_systems.gd`, `final_game_systems.gd` and several `release_*` systems. They were fixed by giving each declaration its real type (`maxi`/`mini`/`clampi` for integer math, explicit `Dictionary`/`int`/`String`/`Variant` types where a call genuinely returns Variant). All 77 scripts now compile with warnings enabled and no suppression.

## 2. Engine abort from a runaway deferred call

`release_production_polish.gd` scheduled itself again every frame while waiting for a current scene:

```gdscript
if scene == null:
    call_deferred("_attach_to_game")
```

With no current scene the deferred queue grows without bound and the engine aborts (`Exit code 134`, C++ backtrace inside `_attach_to_game`). It now connects to `SceneTree.node_added` and attaches once a scene exists, with no self-rescheduling.

## 3. Save/load crashed with an invalid constructor

`release_playable_world.gd:201` called `String(world.player_region_id)`. `String` has no integer constructor in GDScript, so every `load_game()` raised `Invalid call. Nonexistent 'String' constructor.` while rebuilding the HUD. The same mistake existed in `release_stages_15_19.gd` and `release_thirty_systems.gd`; all were replaced with `str(...)`.

## 3b. Freed instances were cast and tested before validity checks

`release_combat_system.gd` (`_process`, `_nearest_enemy`), `release_combat_feedback.gd` and `main.gd::_update_troops` read a troop node, cast it (`as Node3D`, or into a typed variable) and only then called `is_instance_valid()`. Casting or assigning a freed instance raises a script error, which repeated thousands of times during a longer boot (2501 errors in a 15-second run). Validity is now checked on the raw `Variant` before any cast or typed assignment. `main.gd::_update_troops` also guards `troops[i] = data` because another troop can be removed during the same pass.

## 3c. Army simulation iterated a mutable array

`release_world_simulation.gd::_simulate_armies` looped `for i in range(world.armies.size())` while calling `assault_siege()`, which can destroy an army and reindex the array. A later index then pointed past the end (`Invalid access of index '11'`). The loop now iterates army **ids** and re-resolves the index each iteration, matching what `world_state._simulate_world_events` already did.

## 4. Gameplay defects found by running the simulation

A headless QA harness (`godot/qa/headless_qa.gd`) boots the real main scene, sets it as the current scene so autoloads attach exactly as in a real launch, and drives the real simulation. It found four behavioural defects that compile checks cannot see:

1. **The player could never own an army.** `recruit_from_settlement()` added paid recruits to the *settlement owner's* army and garrison. The player starts with no army, so army orders and sieges were unreachable. Recruits now join the player's Free Company band (created in that region when needed); the garrison only grows for settlements the player owns.
2. **Recruitment was impossible in defended settlements.** Capacity was `population/12 - garrison`, negative for most castles and cities. It is now `population/20 - garrison/4`.
3. **No autonomous caravan traffic.** Nothing created caravans without the player, so faction trade was static. Faction caravans now spawn on peace-time routes between neighbouring settlements, and profit is credited to the caravan's owner instead of always to the player.
4. **Save/load corrupted integer-keyed dictionaries.** JSON object keys are always strings, so after `load_game()` `sieges` came back as `{"9": {...}}`; `_simulate_sieges` then did `sieges[9]` and failed on every simulated day (120 errors in one QA pass). `battle_cooldowns` and `player_buildings` had the same latent defect. Loading now rebuilds those dictionaries with integer keys, and QA asserts the key type and a preserved cooldown value across the round trip.
5. **A naval defeat corrupted ship indices.** `WorldState.naval_battle()` deleted the losing ship without reindexing, invalidating every stored ship index (campaign orders, pending encounters, saves). Defeated ships are now crippled and disabled, matching `CampaignSystems.naval_battle`.

## 5. CI could not fail

The workflow used `--editor --quit` as its "Validate project" step. Godot prints parse errors but exits 0 there, so a non-compiling project produced a green build. The export preset was also generated by a heredoc at build time.

The workflow now runs:

- `qa/validate_scripts.gd` — loads all 77 scripts, exits non-zero on any compile failure.
- `qa/headless_qa.gd` — 56 gameplay assertions against the live world.
- a boot smoke test that fails if runtime output contains script errors.
- an APK export using the committed `godot/export_presets.cfg`, followed by archive integrity inspection (`unzip -t`, `AndroidManifest.xml`, `classes.dex`, `resources.arsc`, packaged `assets/`, native `lib/`).

## 6. Verification performed locally

| Check | Result |
| --- | --- |
| Editor import with warnings enabled | clean, 0 errors |
| `qa/validate_scripts.gd` | 77/77 scripts compile, exit 0 |
| `qa/headless_qa.gd` | 56 checks, 0 failures, exit 0 |
| Headless boot soak (60 s simulated, 3600 frames) | no script errors |
| Android debug APK export | succeeded, signed and aligned |
| APK contents | manifest, `classes.dex`, `resources.arsc`, `assets/*.gdc` + main scene, `lib/arm64-v8a` |
| APK signature | verified with `apksigner` |
| APK install/launch on hardware | **not performed** — no device or emulator available |

## 6b. Production art could never appear in an exported build

Two defects meant that installing art packs would still have shipped the procedural fallback:

1. `ReleaseProductionAssetIntegration._load_scene` read the raw `.glb` with `GLTFDocument`. Export packages the *imported* `.scn`, so the raw path does not exist inside an APK.
2. `ReleaseAssetRegistry.scan()` enumerated raw `.glb` paths with `DirAccess`. Those paths are absent from the packaged filesystem, so the registry reported zero models and the integrator logged `PRODUCTION_ART_FAILED` while the authored world stayed visible.

Both are fixed: the loader now resolves the path through `ResourceLoader` (which follows the import remap) and falls back to raw parsing only when that is unavailable, and the registry reads a build-time `assets/production/manifest.json` generated by `qa/generate_asset_manifest.gd` (run by CI before export). Verified by exporting a PCK with a test GLB and running it with `--main-pack`: `PRODUCTION_ART_READY spawned=1 nature=1` inside the packaged build, which previously reported `spawned=0`.

## 7. Remaining real problems

- **Size target:** the APK is ~29 MB because no art is committed. Textures, models and audio are what fill an APK; generating filler files would not add detail. The three core CC0 packs (~374 MB of archives) take it past ~400 MB and all eight listed packs exceed 500 MB. They require an interactive itch.io download and are then installed with `scripts/install_production_packs.sh`.
- **Production art is not in the repository.** `godot/assets/production/{medieval_village,nature,characters}` contain only `.gitkeep` and a README naming the CC0 Quaternius packs. `ReleaseAssetRegistry` detects the absence and the game uses authored procedural geometry. The target look cannot be reached until those packages are actually imported.
- `release_visual_world.gd` builds a complete standalone scene at fixed coordinates; it is not attached to the continent to avoid stacking a second world on the first. Settlement visuals come from `main.gd`, `release_content.gd` and `content_upgrade.gd`.
- Settlement interiors, animation, audio and navigation meshes are absent.
- Mobile touch UI exists but has not been exercised on a phone; frame rate on low-end hardware is unmeasured.
