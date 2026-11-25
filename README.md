# Game

Offline-first open-world medieval sandbox targeting Android. The active engine path is **Godot 4.7.2** in [`godot/`](godot/); the Unity files under `Assets/` and `ProjectSettings/` are historical and are not the game.

## What exists

77 GDScript files implement one simulated continent:

- **World simulation** — 12 regions, 48 settlements across four types, 6 factions, 12 armies, ships, caravans, weather and day/night. `advance_day()` runs settlement production, faction taxes and treasuries, faction AI recruitment and army movement, sieges, ship movement, faction caravans and world events without needing the player.
- **Player freedom** — no campaign and no forced missions. The player can trade, recruit a company, raid, besiege, take settlements, rise to lord or king, or ignore politics.
- **Economy** — regional resources, stockpiles, supply/demand prices, markets, contracts, caravans, taxes and prosperity.
- **Combat** — third-person melee, an optional first-person mode, manual and automatic resolution, both applied to the same world state.
- **Sieges** — walls, gates, breach phases, supplies, morale and capture that transfers real settlement ownership.
- **Naval** — ships with crews, cargo, routes and battles that change world state.
- **Diplomacy, family, succession, technology, rebellions, creatures** — persistent state owned by `world_state.gd`, `campaign_systems.gd` and `final_game_systems.gd`.
- **UI** — HUD, world map, army, settlement, diplomacy, economy, equipment, family, siege, naval and save/load panels bound to live data.
- **Save/load** — one JSON save covering world time, weather, factions, settlements, armies, sieges, ships, caravans, economy, family and progression.

## Verification

```bash
godot --headless --path godot --import
godot --headless --path godot --script res://qa/validate_scripts.gd   # every script must compile
godot --headless --path godot --script res://qa/headless_qa.gd       # boots the game and drives the simulation
```

CI runs both gates, a runtime boot smoke test, then exports and inspects the Android APK. All warnings are enabled; nothing is suppressed to make the build pass.

## Honest limitations

- **No production art is committed.** `godot/assets/production/` contains mount points and a README for the CC0 Quaternius packs, but no models or textures. The world is built from authored procedural meshes (castles, houses, roofs, walls, banners, forests, soldiers) and falls back gracefully when packs are absent. This is the largest gap to a finished game.
- Settlements are represented on the shared continent rather than as fully modelled walkable interiors.
- Animation, audio assets and navigation meshes are not present.
- Android is exported and the APK is structurally verified in CI, but it has not been installed on a physical device or emulator from this repository's automation.

## Docs

- [Game design](docs/GDD.md)
- [Roadmap](docs/ROADMAP.md)
- [Technical audit](docs/TECHNICAL_AUDIT.md)
- [Godot project notes](godot/README.md)
