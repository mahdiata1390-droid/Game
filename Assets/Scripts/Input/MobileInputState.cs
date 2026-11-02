using UnityEngine;

/// <summary>
/// Shared input state for the on-screen joystick and gameplay scripts.
/// This keeps the prototype independent from a specific input package.
/// </summary>
public static class MobileInputState
{
    public static Vector2 Move { get; private set; }

    public static void SetMove(Vector2 value)
    {
        Move = Vector2.ClampMagnitude(value, 1f);
    }

    public static void ResetMove()
    {
        Move = Vector2.zero;
    }
}
