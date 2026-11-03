# Medieval Sandbox — Godot Prototype

This is the new Godot 4.7.2 prototype for the offline-first medieval sandbox.

## Why Godot

Unity was removed from the active development path because the current workflow has no local Unity Editor/Android build machine. Godot is open source and supports Android export; the project is also structured so a headless CI runner can build it.

## Current slice

- 3D third-person player
- Keyboard fallback plus touch-look foundation
- Runtime village props and forest
- Friendly and enemy troop squads
- Basic squad movement and abstract melee combat
- Player attack button
- Android-oriented Compatibility renderer
- No external assets required for the first CI test

This is intentionally a greybox. The goal is to prove the engine + GitHub build pipeline first, then expand the game.

## Build

The repository contains a GitHub Actions workflow that attempts a headless Godot Android export. A successful workflow run is the first real proof that the new engine path works.

Godot version: 4.7.2 stable.
