using UnityEngine;

public sealed class PlayerInventory : MonoBehaviour
{
    private const string SavePrefix = "prototype_inventory_";
    public int Wood { get; private set; }
    public int Stone { get; private set; }
    public int Herbs { get; private set; }

    private void Awake()
    {
        Wood = Mathf.Clamp(PlayerPrefs.GetInt(SavePrefix + "wood", 0), 0, 9999);
        Stone = Mathf.Clamp(PlayerPrefs.GetInt(SavePrefix + "stone", 0), 0, 9999);
        Herbs = Mathf.Clamp(PlayerPrefs.GetInt(SavePrefix + "herbs", 0), 0, 9999);
    }

    public void Add(ResourceType type, int amount = 1)
    {
        if (amount <= 0) return;
        switch (type)
        {
            case ResourceType.Wood: Wood = Mathf.Min(9999, Wood + amount); break;
            case ResourceType.Stone: Stone = Mathf.Min(9999, Stone + amount); break;
            case ResourceType.Herb: Herbs = Mathf.Min(9999, Herbs + amount); break;
        }
        Save();
        SendMessage("OnInventoryChanged", SendMessageOptions.DontRequireReceiver);
    }

    public bool TryConsume(ResourceType type, int amount = 1)
    {
        if (amount <= 0 || GetCount(type) < amount) return false;
        switch (type)
        {
            case ResourceType.Wood: Wood -= amount; break;
            case ResourceType.Stone: Stone -= amount; break;
            case ResourceType.Herb: Herbs -= amount; break;
        }
        Save();
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

    private void OnApplicationPause(bool paused) { if (paused) Save(); }
    private void OnApplicationQuit() { Save(); }

    private void Save()
    {
        PlayerPrefs.SetInt(SavePrefix + "wood", Wood);
        PlayerPrefs.SetInt(SavePrefix + "stone", Stone);
        PlayerPrefs.SetInt(SavePrefix + "herbs", Herbs);
        PlayerPrefs.Save();
    }
}
