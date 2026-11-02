using UnityEngine;

/// <summary>Shared drag-look input in screen-independent normalized units.</summary>
public static class MobileLookInput
{
    public static Vector2 Delta { get; private set; }
    public static void AddDelta(Vector2 value) { Delta += value; }
    public static Vector2 ConsumeDelta()
    {
        Vector2 value = Delta;
        Delta = Vector2.zero;
        return value;
    }
    public static void Reset() { Delta = Vector2.zero; }
}
