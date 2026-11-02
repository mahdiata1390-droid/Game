# Development Roadmap

## Phase 0 — Project foundation
- [x] Set Unity project version marker (2022.3 LTS)
- [x] Add initial project folders, scripts, and prototype scene
- [ ] Confirm project opens cleanly in Unity Editor
- [ ] Add a verified CI/build pipeline
- [ ] Define device performance budgets

## Phase 1 — Playable prototype
- [x] Greybox scene setup for runtime-created ground, light, player, and enemy
- [x] Third-person camera follow and touch drag-look source
- [x] Camera-relative player movement and virtual joystick source
- [x] Basic melee interaction source and one simple enemy behavior
- [x] Player health display source
- [x] Local checkpoint persistence source with invalid/zero-health recovery
- [x] Optional automatic respawn support, configured for the prototype player
- [x] Basic resource interaction button and inventory HUD source
- [x] Basic interaction feedback messages and campfire flame/light flicker\n- [ ] Animation, hit feedback, sound, and further interaction polish
- [ ] Compile and test in Unity Play Mode
- [ ] Produce and verify an Android build on a real device

## Phase 2 — Vertical slice
- [ ] One compact village and surrounding terrain
- [ ] Basic NPC routines and interaction
- [x] Starter resource gathering and inventory loop (wood, stone, herbs; herb consumption heals the player)
- [x] Basic campfire crafting from 3 wood + 2 stone, with local persistence
- [x] Rest at a nearby campfire to restore up to 50 health
- [ ] Trading, broader crafting, and expanded resource economy
- [ ] Robust save/load slots and offline persistence tests
- [ ] Performance profiling on representative Android devices

## Phase 3 — Sandbox foundation
- [ ] Player origin selection
- [ ] Optional activities and emergent events
- [ ] Settlement growth and simple world simulation
- [ ] Early kingdom/leadership loop

## Phase 4 — Expansion
- [ ] More settlements and cultures
- [ ] Deeper economy, diplomacy, family, and army simulation
- [ ] Additional regions and fantasy systems

## Phase 5 — Release preparation
- [ ] Stability, accessibility, localization, and device compatibility
- [ ] Save migration and recovery tests
- [ ] Closed testing, feedback, and optimization

## Scope rule
Do not build all long-term systems at once. Each phase must produce a working, testable result before expanding scope. Checked source items mean files/features have been authored; they do not imply Unity compilation or device verification.
