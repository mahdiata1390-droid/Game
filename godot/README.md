# Medieval Sandbox — Release Candidate

Offline-first open-world medieval sandbox for Android, built with Godot 4.7.2.

## Release target

This branch is the active release-candidate branch. The word **complete** is reserved for the final release build only: all designed gameplay systems, final visual/audio content, mobile controls, save/load, performance checks, Android export, installation and runtime validation must pass before release is announced.

## Current development

The project now contains a dedicated release-content layer for authored-feeling castles, towns, farms, forests, materials, banners, torches, environmental particles, character detail and generated audio. Existing campaign, battle, economy and sandbox systems remain separate from this visual layer.

## Build and validation

- Engine: Godot 4.7.2
- Target: Android
- Renderer: Compatibility/OpenGL for broad mobile support
- CI workflow: .github/workflows/godot-android-build.yml
- Branch for release work: release-candidate

A CI build artifact is not considered a release until the APK has been checked for build success, installed successfully, launched, and exercised through the core gameplay loop.

## Planned release content

- Detailed castle/city/village variants
- Character, armor, weapon and mount visual variation
- Combat VFX and battlefield atmosphere
- Dedicated SFX and music set
- Siege visuals and equipment
- Naval gameplay and sea travel
- Expanded AI armies and formations
- Economy, trade, diplomacy, war and succession integration
- Family/generation gameplay
- World events, weather and day/night presentation
- Save/load reliability
- Mobile UI, touch controls and performance optimization

## Size estimate

Final APK size is intentionally not fixed yet. The final size will depend mainly on the number of imported 3D models, textures, animations, music and sound effects. The project will be optimized so visual quality does not translate directly into unnecessary file size.

Current target for the finished Android release is approximately **300–600 MB installed**, with the final downloadable APK/AAB size reported from the actual release build rather than guessed.


## Final candidate QA
The release-candidate branch is validated by the Android CI workflow before an APK is considered releasable.
