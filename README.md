# Game

Offline-first medieval fantasy sandbox for Android, planned in Unity.

## Current prototype foundation
The repository now includes a Unity 2022.3 project marker, a greybox Prototype scene, runtime-created ground/player/enemy, third-person follow camera with touch drag-look, virtual movement joystick, attack button, basic melee damage, simple enemy chase/attack behavior, player health HUD, and local player checkpoint saving.

All visuals are temporary primitive placeholders. This is an early vertical-slice foundation, not the full sandbox game.

## Design and planning
- [Game Design Document](docs/GDD.md)
- [Development Roadmap](docs/ROADMAP.md)
- [Prototype scripts guide](Assets/Scripts/README.md)

## Honest build status
The Unity project files and scripts have been committed, but Unity Editor compilation, Play Mode testing, Android packaging, and real-device testing have **not** been performed. There is no verified APK yet.

An Android build requires Unity 2022.3 with Android Build Support (SDK/NDK + OpenJDK). Unity Editor does not run natively on iPhone; a compatible computer or configured cloud build runner is required.
