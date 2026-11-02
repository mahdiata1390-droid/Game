using UnityEngine;

public enum ResourceType { Wood, Stone, Herb }

public sealed class ResourceNode : MonoBehaviour
{
    [SerializeField] private ResourceType resourceType;
    [SerializeField, Min(1)] private int remaining = 3;
    [SerializeField, Min(0.5f)] private float interactionRadius = 2.5f;

    public ResourceType Type => resourceType;
    public int Remaining => remaining;
    public float InteractionRadius => interactionRadius;

    public void Configure(ResourceType type, int amount, float radius = 2.5f)
    {
        resourceType = type;
        remaining = Mathf.Max(1, amount);
        interactionRadius = Mathf.Max(0.5f, radius);
    }

    public bool TryHarvest(out ResourceType type)
    {
        type = resourceType;
        if (remaining <= 0) return false;
        remaining--;
        if (remaining == 0)
        {
            Collider nodeCollider = GetComponent<Collider>();
            if (nodeCollider != null) nodeCollider.enabled = false;
            Renderer nodeRenderer = GetComponent<Renderer>();
            if (nodeRenderer != null) nodeRenderer.enabled = false;
        }
        return true;
    }
}
