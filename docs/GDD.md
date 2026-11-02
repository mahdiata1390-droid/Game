# Game Design Document (GDD) — v1.0

## Vision
An offline-first, third-person/first-person 3D medieval fantasy sandbox for Android. The player writes their own story in a living world: no compulsory main questline and no required main missions.

## Player starts
Choose one:
- Ordinary person
- Ruler of an existing kingdom
- Leader of a nomadic tribe starting from humble beginnings

## World
The long-term vision is five hand-crafted continents with distinct climates, geography, resources, cultures, and civilizations. Version 1 will focus on one compact, complete region; the other continents are future expansions.

## Core pillars
1. **Freedom:** players choose their own goals and lifestyle.
2. **Living world:** settlements, people, trade, politics, and borders can change without the player.
3. **Readable strategy:** kingdom, economy, diplomacy, and army systems should be understandable on a phone.
4. **Scalable presentation:** graphics and simulation detail adapt to device capability.
5. **Offline first:** the first release must be playable without an internet connection.

## Planned systems (long-term vision)
- Character creation, progression, family, aging, and succession
- Settlements, population, jobs, construction, agriculture, and trade
- Kingdom management, laws, diplomacy, intelligence, and historical events
- Army organization and large-scale battles, scaled to device performance
- Exploration, ships, wildlife, weather, and natural events
- Fantasy species, magic, dragons, mythical creatures, and ancient places
- Optional side activities and emergent events; no mandatory main story
- Save slots, autosave, world history, and recovery
- Persian and English interface; touch-first controls

## Camera and controls
- Switchable third-person and first-person views
- Optional cinematic camera moments
- Customizable touch controls and HUD
- Optional Bluetooth controller support, subject to testing

## Graphics and performance
Target scalable quality tiers rather than promising cinematic quality on every phone. Adjust resolution, shadows, environment detail, crowd density, and simulation distance according to tested device capability.

## Version 1 scope
A small but complete offline vertical slice:
- One compact playable region
- One player character and a small set of NPCs
- Basic movement, camera, interaction, and a simple non-graphic fantasy combat prototype
- One settlement with a small economy loop
- A limited, testable save system
- Android performance profiling and device testing

## Future expansion
- More settlements, civilizations, and the remaining continents
- Deeper kingdom, economy, family, and world simulation
- Naval exploration and advanced fantasy systems
- Optional online features only after the offline foundation is stable

## Technical reality
This document records design intent, not implemented features. Unity Editor does not run natively on iPhone. A cloud build environment or a computer with Unity and Android build support is required for actual Android APK builds. No APK is produced by this document.
