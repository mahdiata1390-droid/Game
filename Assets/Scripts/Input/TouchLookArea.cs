using UnityEngine;
using UnityEngine.EventSystems;

/// <summary>Attach to a transparent UI image covering the right side of the screen.</summary>
public sealed class TouchLookArea : MonoBehaviour, IPointerDownHandler, IDragHandler, IPointerUpHandler
{
    [SerializeField] private float sensitivity = 0.12f;
    private Vector2 previousPosition;
    private int activePointerId = int.MinValue;

    public void OnPointerDown(PointerEventData eventData)
    {
        activePointerId = eventData.pointerId;
        previousPosition = eventData.position;
    }

    public void OnDrag(PointerEventData eventData)
    {
        if (eventData.pointerId != activePointerId) return;
        Vector2 delta = eventData.position - previousPosition;
        previousPosition = eventData.position;
        MobileLookInput.AddDelta(delta * sensitivity);
    }

    public void OnPointerUp(PointerEventData eventData)
    {
        if (eventData.pointerId == activePointerId)
            activePointerId = int.MinValue;
    }

    private void OnDisable() { MobileLookInput.Reset(); }
}
