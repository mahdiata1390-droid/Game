using UnityEngine;
using UnityEngine.UI;

public sealed class InventoryDisplay : MonoBehaviour
{
    private PlayerInventory inventory;
    private Text label;
    public void Configure(PlayerInventory source, Text target) { inventory = source; label = target; Refresh(); }
    private void Update() { Refresh(); }
    private void Refresh()
    {
        if (inventory == null || label == null) return;
        label.text = "WOOD " + inventory.Wood + "   STONE " + inventory.Stone + "   HERB " + inventory.Herbs;
    }
}
