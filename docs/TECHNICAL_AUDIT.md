# Prototype Technical Audit

This is a source review only. Unity Editor compilation, Play Mode, Android packaging, and device testing have not been performed.

## Completed in this pass
- Enemy CharacterController movement now applies gravity even when the player is outside detection range.
- Valid damage broadcasts an OnDamaged message.
- The prototype enemy briefly flashes its material when hit.
- Player and enemy CharacterController spawn heights were corrected to sit on the flat ground plane; legacy saved heights are recovered to the corrected spawn height.
- Checkpoints now persist player facing direction as well as position and health, and save immediately after automatic respawn.

## Outstanding verification
- ProjectSettings/ProjectSettings.asset is absent; confirm Unity project import and input handling in Unity 2022.3.
- Verify touch-look and attack-button raycast ordering in Play Mode.
- Test movement, combat, enemy grounding, death, respawn, and save/load across an app restart.
- Camera mode switching is not integrated; only third-person is active.
- No animation, sound, navigation mesh, or final environment assets exist yet.
- A Unity Android CI workflow needs a licensed Unity runner and Android Build Support. No credentials are available in this repository, so no misleading placeholder workflow was added.

## Required next checks
1. Open in Unity 2022.3 and fix import/compiler errors.
2. Run the complete prototype in Play Mode.
3. Configure licensed CI, build a development APK, install it on Android, and profile performance.

Checked roadmap items indicate authored source only, not verified runtime behavior.

## Resource gathering pass
- Added finite wood, stone, and herb nodes with depletion behavior.
- Added player inventory counters and a compact HUD.
- Added a collect action that selects the nearest resource node in front of the player within interaction range.
- Added herb consumption: one herb restores up to 25 health, capped at maximum health.
- Inventory counts now persist locally between sessions.
- Harvested node depletion persists locally between sessions.
- Added one-time campfire crafting for 3 wood + 2 stone; the built campfire and its location persist locally.
- Added a rest action that restores up to 50 health only when the player is within 3 metres of the campfire.
- These changes are source-authored only; they have not been compiled or exercised in Unity. Verify touch-button hit testing, interaction range/aiming, depleted-node behavior, and healing in Play Mode.
\n\n## Interaction feedback polish\n- Added a transient on-screen status message for successful collection, missing resources, herb use, campfire construction, and rest restrictions.\n- Added a subtle campfire flame pulse and light flicker.\n- Source-only changes; Unity compilation and Play Mode verification remain outstanding.\n