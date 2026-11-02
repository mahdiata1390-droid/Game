using UnityEngine;

/// <summary>
/// Smooth third-person camera follow prototype.
/// Assign the player Transform as Target and position this rig behind the player.
/// This is a basic follow rig; collision and touch-look are future tasks.
/// </summary>
public class CameraFollowRig : MonoBehaviour
{
    [SerializeField] private Transform target;
    [SerializeField] private Vector3 offset = new Vector3(0f, 3f, -5f);
    [SerializeField, Min(0.01f)] private float positionSmoothTime = 0.12f;
    [SerializeField, Min(0f)] private float rotationSharpness = 12f;
    [SerializeField] private bool lookAtTarget = true;

    private Vector3 positionVelocity;

    private void LateUpdate()
    {
        if (target == null)
            return;

        Vector3 desiredPosition = target.TransformPoint(offset);
        transform.position = Vector3.SmoothDamp(
            transform.position, desiredPosition, ref positionVelocity, positionSmoothTime);

        if (lookAtTarget)
        {
            Vector3 lookDirection = target.position + Vector3.up * 1.4f - transform.position;
            if (lookDirection.sqrMagnitude > 0.001f)
            {
                Quaternion desiredRotation = Quaternion.LookRotation(lookDirection, Vector3.up);
                transform.rotation = Quaternion.Slerp(
                    transform.rotation, desiredRotation, rotationSharpness * Time.deltaTime);
            }
        }
    }

    public void SetTarget(Transform newTarget)
    {
        target = newTarget;
    }
}
