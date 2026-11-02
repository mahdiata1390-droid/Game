using UnityEngine;

public sealed class PlayerInteraction : MonoBehaviour
{
    [SerializeField, Min(1f)] private float searchDistance = 3.2f;
    private PlayerInventory inventory;
    private void Awake() { inventory = GetComponent<PlayerInventory>(); }

    public void Interact()
    {
        if (inventory == null) return;
        Vector3 origin = transform.position + Vector3.up * 0.9f;
        ResourceNode[] nodes = FindObjectsOfType<ResourceNode>();
        ResourceNode nearest = null;
        float nearestDistance = float.MaxValue;
        foreach (ResourceNode node in nodes)
        {
            if (node == null || node.Remaining <= 0) continue;
            Vector3 offset = node.transform.position - origin;
            float distance = offset.magnitude;
            if (distance > searchDistance || distance > node.InteractionRadius + 1f) continue;
            if (Vector3.Dot(transform.forward, offset.normalized) < 0.15f) continue;
            if (distance < nearestDistance) { nearest = node; nearestDistance = distance; }
        }
        if (nearest != null && nearest.TryHarvest(out ResourceType type)) inventory.Add(type);
    }
}
