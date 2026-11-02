# Game

Offline-first medieval fantasy sandbox for Android, planned in Unity.

## Current prototype foundation

The repository contains a Unity 2022.3 project marker and a greybox Prototype scene. At scene start, runtime setup creates a ground plane, placeholder player and enemy, third-person follow camera, touch drag-look area, virtual movement joystick, attack button, and player health HUD.

Gameplay source includes camera-relative movement, basic melee combat, a simple enemy behavior, local checkpoint persistence, automatic respawn, and a starter resource loop. The greybox now spawns finite wood, stone, and herb nodes; gathered counts appear in the HUD and persist locally. One herb restores up to 25 health. Three wood plus two stone craft one persistent campfire placed in front of the player. The prototype player is configured to return to the saved spawn position with full health two seconds after defeat. Checkpoint loading rejects obviously invalid coordinates and restores full health if a saved checkpoint contains zero health.

All visuals remain temporary primitive placeholders. Resource nodes are colored primitives and disappear visually when depleted. This is a small systems prototype foundation, not the planned full open-world sandbox.

## Design and planning
- [Game Design Document](docs/GDD.md)
- [Development Roadmap](docs/ROADMAP.md)
- [Prototype scripts guide](Assets/Scripts/README.md)

## Honest build status

The Unity project files and scripts have been committed, but Unity Editor compilation, Play Mode testing, Android packaging, and real-device testing have **not** been performed. There is no verified APK yet.

An Android build requires Unity 2022.3 with Android Build Support (SDK/NDK + OpenJDK). Unity Editor does not run natively on iPhone; a compatible computer or configured cloud build runner is required. A cloud build also needs valid Unity licensing/CI credentials.
