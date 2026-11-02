using UnityEngine;

public sealed class PlayerInventory : MonoBehaviour
{
    public int Wood { get; private set; }
    public int Stone { get; private set; }
    public int Herbs { get; private set; }

    public void Add(ResourceType type, int amount = 1)
    {
        if (amount <= 0) return;
        switch (type)
        {
            case ResourceType.Wood: Wood += amount; break;
            case ResourceType.Stone: Stone += amount; break;
            case ResourceType.Herb: Herbs += amount; break;
        }
        SendMessage("OnInventoryChanged", SendMessageOptions.DontRequireReceiver);
    }

    public bool TryConsume(ResourceType type, int amount = 1)
    {
        if (amount <= 0) return false;
        int current = GetCount(type);
        if (current < amount) return false;
        switch (type)
        {
            case ResourceType.Wood: Wood -= amount; break;
            case ResourceType.Stone: Stone -= amount; break;
            case ResourceType.Herb: Herbs -= amount; break;
        }
        SendMessage("OnInventoryChanged", SendMessageOptions.DontRequireReceiver);
        return true;
    }

    public int GetCount(ResourceType type)
    {
        switch (type)
        {
            case ResourceType.Wood: return Wood;
            case ResourceType.Stone: return Stone;
            case ResourceType.Herb: return Herbs;
            default: return 0;
        }
    }
}
