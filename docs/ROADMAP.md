# Development Roadmap

## Phase 0 — Project foundation
- [x] Set Unity project version marker (2022.3 LTS)
- [x] Add initial project folders, scripts, and prototype scene
- [ ] Confirm project opens cleanly in Unity Editor
- [ ] Add a verified CI/build pipeline
- [ ] Define device performance budgets

## Phase 1 — Playable prototype
- [x] Small greybox test scene with runtime-created ground, light, and player
- [x] Third-person camera follow and touch drag-look
- [x] Camera-relative player movement and virtual joystick
- [x] Basic melee attack and one simple enemy behavior
- [x] Player health display
- [x] Local checkpoint persistence for player position and health
- [ ] Add animation, hit feedback, sound, and interaction polish
- [ ] Compile and test in Unity Play Mode
- [ ] Produce and verify an Android build on a real device

## Phase 2 — Vertical slice
- [ ] One compact village and surrounding terrain
- [ ] Basic NPC routines and interaction
- [ ] Small resource/trade loop
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
Do not build all long-term systems at once. Each phase must produce a working, testable result before expanding scope. Checked items above mean source files have been added; they do not imply Unity compilation or device verification.
