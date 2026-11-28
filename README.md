# Game

Offline-first medieval fantasy sandbox for Android.

## Release 1.0.0

Version **1.0.0** (versionCode 10000, package `com.mahdiata1390.medievalsandbox`) is the
first public Android release. GitHub Actions builds the signed APK and uploads it with its
SHA-256 and release notes as the `medieval-sandbox-android-1.0.0` artifact; pushing a `v*`
tag also opens a draft GitHub Release.

- [Release notes](RELEASE_NOTES.md) — what is in the build, install steps, requirements, credits.
- Build workflow: [.github/workflows/android-build.yml](.github/workflows/android-build.yml).
- Version lives in [android/app/build.gradle](android/app/build.gradle) (`versionName` / `versionCode`).

```bash
npm ci
npm run build && npx cap sync android
cd android && ./gradlew assembleRelease   # needs an Android SDK + release keystore
```

## Forge Engine (own engine, new)

The active path is now **Forge Engine**, our own WebGL2 + TypeScript engine and editor, running the medieval world without Unity or Godot. It boots with zero binary assets, draws the whole scene in one instanced draw call, and includes a scene format, hierarchy/inspector editor, and an asset-pack registry with sizes and licences.

```bash
npm install
npm run dev     # editor + playable world at http://localhost:3000
npm run build   # typecheck + dist/
```

Read [docs/ENGINE.md](docs/ENGINE.md) for the architecture, the size budget, and an honest comparison against Godot (including what Forge does *not* do yet). Asset packs are opt-in: `npm run packs:list`.

### Art system

[**docs/DESIGN.md**](docs/DESIGN.md) is the art and design bible: five powers and a free company, each with its own masonry, roof, coat of arms, armour, helmet, shield and signature weapon; five distinct castle silhouettes with gatehouses and portcullises; twenty-instance character rigs; and thirty-five materials painted into a single 1024² atlas at boot. It includes the concept plates and in-engine captures.

Everything is authored in code and drawn in **one instanced draw call** — around 6,500 instances, 0.59 MiB of instance data, no binary art committed.

## Current prototype foundation

The repository contains a Unity 2022.3 project marker and a greybox Prototype scene. At scene start, runtime setup creates a ground plane, placeholder player and enemy, third-person follow camera, touch drag-look area, virtual movement joystick, attack button, and player health HUD.

Gameplay source includes camera-relative movement, basic melee combat, a simple enemy behavior, local checkpoint persistence, automatic respawn, and a starter resource loop. The greybox now spawns finite wood, stone, and herb nodes; gathered counts appear in the HUD and persist locally. One herb restores up to 25 health. Three wood plus two stone craft one persistent campfire placed in front of the player; resting within three metres restores up to 50 health. Actions show brief on-screen feedback for gathering, healing, missing resources, and campfire restrictions; the campfire flame and light have a subtle flicker. Actions now show short on-screen feedback for missing resources, out-of-range resting, and successful gathering/healing; the campfire flame and light have a subtle flicker. The prototype player is configured to return to the saved spawn position with full health two seconds after defeat. Checkpoint loading rejects obviously invalid coordinates and restores full health if a saved checkpoint contains zero health.

All visuals remain temporary primitive placeholders. Resource nodes are colored primitives and disappear visually when depleted. This is a small systems prototype foundation, not the planned full open-world sandbox.

## Design and planning
- [Game Design Document](docs/GDD.md)
- [Development Roadmap](docs/ROADMAP.md)
- [Prototype scripts guide](Assets/Scripts/README.md)

## Honest build status

The Forge Engine path does produce a verified, signed APK (see the release section above and
[RELEASE_NOTES.md](RELEASE_NOTES.md)). The legacy Unity project files below are still in the
repository, but Unity Editor compilation, Play Mode testing and Unity-based Android packaging
have **not** been performed.

An Android build requires Unity 2022.3 with Android Build Support (SDK/NDK + OpenJDK). Unity Editor does not run natively on iPhone; a compatible computer or configured cloud build runner is required. A cloud build also needs valid Unity licensing/CI credentials.
