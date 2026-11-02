using UnityEngine;

/// <summary>
/// Switches between configured first-person and third-person camera anchors.
/// Cinematic shots can later be driven by Timeline or a dedicated camera rig.
/// </summary>
public sealed class CameraModeSwitcher : MonoBehaviour
{
    [SerializeField] private Camera targetCamera;
    [SerializeField] private Transform thirdPersonAnchor;
    [SerializeField] private Transform firstPersonAnchor;
    [SerializeField] private bool startFirstPerson;

    private bool firstPerson;

    private void Awake()
    {
        if (targetCamera == null)
            targetCamera = Camera.main;

        SetMode(startFirstPerson);
    }

    public void ToggleMode() => SetMode(!firstPerson);

    public void SetMode(bool useFirstPerson)
    {
        firstPerson = useFirstPerson;
        if (targetCamera == null) return;

        Transform anchor = firstPerson ? firstPersonAnchor : thirdPersonAnchor;
        if (anchor == null) return;

        targetCamera.transform.SetPositionAndRotation(anchor.position, anchor.rotation);
    }
}
