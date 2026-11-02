using UnityEngine;
using UnityEngine.EventSystems;

/// <summary>
/// Add to a UI joystick background with a child handle.
/// Configure the background and handle RectTransforms in the Inspector.
/// </summary>
public class VirtualJoystick : MonoBehaviour, IPointerDownHandler, IDragHandler, IPointerUpHandler
{
    [SerializeField] private RectTransform background;
    [SerializeField] private RectTransform handle;
    [SerializeField, Min(1f)] private float handleRange = 60f;

    private void Awake()
    {
        if (background == null)
            background = transform as RectTransform;

        if (handle == null || background == null)
            Debug.LogError("VirtualJoystick requires Background and Handle references.", this);
    }

    public void OnPointerDown(PointerEventData eventData)
    {
        OnDrag(eventData);
    }

    public void OnDrag(PointerEventData eventData)
    {
        if (background == null || handle == null)
            return;

        if (!RectTransformUtility.ScreenPointToLocalPointInRectangle(
                background, eventData.position, eventData.pressEventCamera, out Vector2 localPoint))
            return;

        Vector2 radius = background.rect.size * 0.5f;
        Vector2 normalized = new Vector2(
            radius.x > 0f ? localPoint.x / radius.x : 0f,
            radius.y > 0f ? localPoint.y / radius.y : 0f);

        normalized = Vector2.ClampMagnitude(normalized, 1f);
        handle.anchoredPosition = normalized * handleRange;
        MobileInputState.SetMove(normalized);
    }

    public void OnPointerUp(PointerEventData eventData)
    {
        if (handle != null)
            handle.anchoredPosition = Vector2.zero;

        MobileInputState.ResetMove();
    }

    private void OnDisable()
    {
        MobileInputState.ResetMove();
    }
}
