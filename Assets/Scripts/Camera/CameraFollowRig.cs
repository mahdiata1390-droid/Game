using UnityEngine;

public class CameraFollowRig : MonoBehaviour
{
    [SerializeField] private Transform target;
    [SerializeField] private Vector3 offset = new Vector3(0f, 3f, -5f);
    [SerializeField, Min(0.01f)] private float positionSmoothTime = 0.12f;
    [SerializeField, Min(0f)] private float rotationSharpness = 12f;
    [SerializeField] private float lookSensitivity = 1f;
    [SerializeField] private float minPitch = -15f;
    [SerializeField] private float maxPitch = 65f;
    private Vector3 positionVelocity;
    private float yaw;
    private float pitch = 18f;

    private void Start() { if (target != null) yaw = target.eulerAngles.y; }

    private void LateUpdate()
    {
        if (target == null) return;
        Vector2 look = MobileLookInput.ConsumeDelta() * lookSensitivity;
        yaw += look.x;
        pitch = Mathf.Clamp(pitch - look.y, minPitch, maxPitch);
        Quaternion orbit = Quaternion.Euler(pitch, yaw, 0f);
        Vector3 desiredPosition = target.position + orbit * offset;
        transform.position = Vector3.SmoothDamp(transform.position, desiredPosition, ref positionVelocity, positionSmoothTime);
        Vector3 lookPoint = target.position + Vector3.up * 1.35f;
        Vector3 direction = lookPoint - transform.position;
        if (direction.sqrMagnitude > 0.001f)
        {
            Quaternion desiredRotation = Quaternion.LookRotation(direction, Vector3.up);
            transform.rotation = Quaternion.Slerp(transform.rotation, desiredRotation, rotationSharpness * Time.deltaTime);
        }
    }

    public void SetTarget(Transform newTarget) { target = newTarget; if (target != null) yaw = target.eulerAngles.y; }
}
