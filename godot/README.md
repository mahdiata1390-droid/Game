# Medieval Sandbox — Release Candidate (Godot 4.7.2)

## Layout

| File | Role |
| --- | --- |
| `main.gd` / `main.tscn` | Boots world, player, camera, UI, input and the play loop |
| `world_state.gd` | Continent, factions, settlements, armies, ships, economy, diplomacy, battles, sieges, save/load |
| `campaign_systems.gd` | Autoload: naval campaign, trade contracts, family aging, succession |
| `final_game_systems.gd` | Autoload: politics, technology, NPCs, trade routes, wildlife, creatures, events |
| `final_systems_ui.gd` | Autoload: sandbox panels bound to live world state |
| `completion_systems.gd` | Autoload: late-game objectives from live state |
| `battle_controller.gd` | Autoload: battle/siege prompts, manual and automatic modes |
| `release_*.gd` (60+ files) | Release layers: content, visuals, combat, economy, logistics, weather, UI, mobile polish |
| `release_asset_registry.gd` | Detects `assets/production/` packs and falls back to authored geometry |
| `qa/validate_scripts.gd` | Compile gate; exits non-zero if any script fails |
| `qa/headless_qa.gd` | Headless gameplay QA driving the real simulation |

## Run and verify

```bash
godot --headless --path godot --import
godot --headless --path godot --script res://qa/validate_scripts.gd
godot --headless --path godot --script res://qa/headless_qa.gd
godot --path godot     # play
```

Headless QA boots `main.tscn` as the current scene, then checks continent generation, diplomacy, markets, recruitment, 45 simulated days, battles, sieges, naval combat, family data, autoloads, a save/load round trip and 120 further simulated days.

GDScript warnings are **enabled** in `project.godot`. Do not disable them to make a build pass; fix the code.

## Android

`export_presets.cfg` is committed (arm64-v8a, GL Compatibility). CI exports `build/MedievalSandbox.apk` and verifies the archive contents. `qa/` is excluded from the shipped package.

## Known gaps

- `assets/production/` is an empty mount point; no binary art is committed. Delete nothing there, but expect fallback geometry until the CC0 packs are imported.
- `release_visual_world.gd` is not attached to the continent (it would place a second world at the same coordinates).
- Interiors, animation, audio and navigation meshes are not implemented.
- Android has not been verified on physical hardware.
