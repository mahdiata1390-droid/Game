# Medieval Sandbox 1.0.0

The first release of **Medieval Sandbox** — an offline-first medieval fantasy sandbox
for Android, running on Forge Engine, our own WebGL2 renderer and world simulator.

| | |
|---|---|
| **Version** | 1.0.0 (versionCode 10000) |
| **Package** | `com.mahdiata1390.medievalsandbox` |
| **APK** | `medieval-sandbox-1.0.0.apk` (~36 MB) |
| **Minimum Android** | 5.1 (API 22), target API 34 |
| **Signing** | Release keystore, V1 + V2 signature schemes |
| **Network** | None. The game is fully bundled and runs offline. |

## What is in the box

**The world.** A 3 km river basin holding thirty-three holdings across five powers and a
free company: masonry, roof tiles, coats of arms, armour and signature weapons painted into
a single texture atlas at boot and drawn in one instanced draw call. A full day/night cycle,
weather, fog, wildlife, gulls and crows, a working market town and five distinct castles.

**The sandbox.** Walk, sprint, look and fight with third-person controls rebuilt for touch
(drag-look, virtual stick, attack, gather, rest, craft). Gather wood, stone and herbs, raise
campfires, rest to recover, and hold your ground against warbands that pick fights on their
own. Save/load persists every scene and every campaign state locally.

**The council campaign.** Govern from the council screen: eight tabs covering the realm map,
army, economy, diplomacy, chronicle, faith and law. Levy troops, muster the free company,
build walls, sign truces, declare war, and watch the AI powers do the same to each other.
Sieges resolve against garrison, walls and relieving field armies, so a war is now a
campaign rather than a one-day wipe: the AI must mass a real advantage before it moves on
you, musters take time, and your last holding cannot be taken outright.

**Sound.** Five orchestral beds that crossfade with the scene — the heartland by day, the
elder magic of the council, the edge of silence at night, still water at the coast, the
bridge unseen in the deep wood — plus twenty effects for steel, gates, bells, hooves, horns,
coins, anvils and axes. Mute is one tap and is remembered.

**Art.** A painted title screen, council crest, champion portraits for the three companies,
a siege plate, and a gold rampant lion on crimson for the launcher icon, including a proper
adaptive icon with background and foreground layers at every density.

## Install

1. Copy `medieval-sandbox-1.0.0.apk` to the device (or download it directly on the device).
2. Open it and allow installs from this source when prompted.
3. Launch **Medieval Sandbox**. The first screen is the title card; tap to begin.

The app is landscape, fullscreen and immersive, keeps the screen awake while playing, and
the Android back button steps back through menus before it leaves the game.

## Requirements

- Android 5.1 or newer with a GPU that supports WebGL2 (any device from roughly 2015 on).
- About 40 MB of free storage.
- No internet connection, no account, no permissions beyond installing.

## Verify the download

Every build publishes a SHA-256 next to the APK
(`medieval-sandbox-1.0.0.apk.sha256`). Check it before installing:

```bash
sha256sum -c medieval-sandbox-1.0.0.apk.sha256
```

On Android you can compare against the value printed in the build summary instead.

## Known limitations

- This release is tested by automated build and asset verification, not on physical
  hardware; graphics, touch layout and audio mix should be checked on your own device.
- No cloud saves, no accounts, no multiplayer. Progress lives on the device.
- Texture detail is painted at boot rather than streamed from photo-scanned assets, so the
  world is stylised rather than photoreal.
- The council map is a painted plate, not a live projection of the terrain mesh.

## Credits and licences

- Music: Vindsvept, licensed CC BY 4.0 (Wikimedia Commons). Attribution is kept in
  `public/audio/CREDITS.md` and shipped inside the APK.
- Sound effects: CC0 previews sourced through the Openverse API.
- Engine, world generation, art generation and UI: original work in this repository.

## Build provenance

Built by GitHub Actions from the tagged commit with `npm run build`, then packaged into the
Capacitor WebView by `npx cap sync android` and signed with the release keystore. The APK
bundles `index.html`, the compiled JavaScript and CSS, all audio and all art locally — it
contains no remote URLs and makes no network requests.
