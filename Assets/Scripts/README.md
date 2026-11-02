# Prototype scripts

These scripts are early Unity prototype components, not a complete game.

## Player movement

- `Player/ThirdPersonMotor.cs` currently reads the legacy Horizontal/Vertical axes.
- `Input/MobileInputState.cs` stores the normalized movement vector written by the touch joystick.
- `Input/VirtualJoystick.cs` implements Unity UI pointer handling for a virtual joystick.
- Important: the joystick is not yet connected to `ThirdPersonMotor`; that integration remains a separate task.

## Camera

- `Camera/CameraModeSwitcher.cs` switches between assigned first-person and third-person anchors.
- `Camera/CameraFollowRig.cs` provides a basic smooth follow camera. Assign the player Transform to Target.
- Smooth blending, camera collision, touch-look, and cinematic sequences are not implemented yet.

## Virtual joystick setup

1. Create a Canvas and set its render mode to Screen Space - Overlay.
2. Add an EventSystem to the scene (Unity usually creates one with UI objects).
3. Create a UI Image as the joystick background and a smaller child Image as its handle.
4. Add `VirtualJoystick` to the background and assign both RectTransforms.
5. Set Handle Range to roughly half the background width in UI units.

The joystick currently only publishes `MobileInputState.Move`. No Unity editor compilation, Android build, or device test has been performed.
