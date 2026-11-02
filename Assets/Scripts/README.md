# Prototype scripts

These scripts are an initial code foundation, not a complete Unity project or playable build.

## Third-person motor
1. Create a Player GameObject.
2. Add a CharacterController.
3. Add `ThirdPersonMotor`.
4. Assign the active camera transform.

The current motor uses Unity's legacy input axes for quick editor prototyping. Before Android testing, replace this input source with a virtual joystick / Unity Input System action.

## Camera mode switcher
Create two child transforms on the player (or camera rig): one for the third-person camera position and one for first-person eye position. Assign both anchors and the active Camera.

The current switch is an immediate transform change. Smooth camera blending, collision handling, touch-look, and cinematic sequences are later tasks.
