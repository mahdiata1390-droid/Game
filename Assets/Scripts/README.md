# Prototype scripts

The Prototype scene runs `PrototypeBootstrap` at startup. It creates temporary greybox objects and mobile UI in code so the scene can remain small.

## Included prototype systems
- `Player/ThirdPersonMotor.cs`: camera-relative movement using the virtual joystick, with optional legacy keyboard fallback.
- `Input/VirtualJoystick.cs` + `MobileInputState.cs`: on-screen movement input.
- `Input/TouchLookArea.cs` + `MobileLookInput.cs`: right-side drag input for camera orbit.
- `Camera/CameraFollowRig.cs`: smoothed third-person camera with yaw/pitch limits.
- `Combat/Health.cs`: basic health and damage.
- `Combat/PlayerCombat.cs`: short-range melee attack.
- `Combat/SimpleEnemyAI.cs`: one prototype enemy that approaches and attacks the player.
- `UI/PlayerHealthDisplay.cs`: health bar and numeric HP label.
- `Save/PrototypeSaveSystem.cs`: local PlayerPrefs checkpoint for player position and health, saved on pause/quit.
- `World/ResourceNode.cs`: finite wood, stone, and herb nodes with saved depletion state.
- `Player/PlayerInventory.cs`: resource counts, local persistence, and consume/add operations.
- `Player/PlayerInteraction.cs`: collect nearby resources and consume herbs to heal.
- `UI/InventoryDisplay.cs`: compact resource-count HUD.
- `World/CampfireBuilder.cs`: craft and persist one campfire using 3 wood + 2 stone.

## Controls
- Left side: movement joystick.
- Right side: drag to rotate the camera.
- Bottom-right: ATTACK button.

## Current limitations
- Primitive capsules and a plane are placeholders, not final art.
- One enemy only; no animation controller, weapon model, hit reactions, sound, loot, quests, NPC schedules, economy, or world simulation yet.
- Combat is a simple overlap-based melee prototype, not a finished combat system.
- Camera collision, first-person mode integration, settings, remappable controls, and robust save slots are not implemented.
- No Unity Editor compilation, Play Mode test, Android build, or device test has been completed yet.

## Open in Unity
Use Unity 2022.3 LTS, open the repository as a Unity project, let packages import, then open `Assets/Scenes/Prototype.unity`. The scene is registered in Build Settings.
