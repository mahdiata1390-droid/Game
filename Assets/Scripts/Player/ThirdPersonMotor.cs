using UnityEngine;

/// <summary>
/// Device-friendly third-person prototype motor.
/// Add a CharacterController and assign the camera transform.
/// Touch input comes from MobileInputState; keyboard axes remain available
/// as an optional editor fallback.
/// </summary>
[RequireComponent(typeof(CharacterController))]
public sealed class ThirdPersonMotor : MonoBehaviour
{
    [SerializeField] private Transform cameraTransform;
    [SerializeField, Min(0f)] private float moveSpeed = 4.5f;
    [SerializeField, Min(0f)] private float rotationSpeed = 12f;
    [SerializeField, Min(0f)] private float gravity = 20f;
    [SerializeField] private bool allowKeyboardFallback = true;

    private CharacterController controller;
    private float verticalVelocity;

    private void Awake()
    {
        controller = GetComponent<CharacterController>();
        if (cameraTransform == null && Camera.main != null)
            cameraTransform = Camera.main.transform;
    }

    private void Update()
    {
        Vector2 input = MobileInputState.Move;

#if ENABLE_LEGACY_INPUT_MANAGER
        if (allowKeyboardFallback && input.sqrMagnitude < 0.0001f)
        {
            input = new Vector2(
                Input.GetAxisRaw("Horizontal"),
                Input.GetAxisRaw("Vertical"));
        }
#endif

        input = Vector2.ClampMagnitude(input, 1f);

        Vector3 move;
        if (cameraTransform != null)
        {
            Vector3 forward = Vector3.ProjectOnPlane(cameraTransform.forward, Vector3.up).normalized;
            Vector3 right = Vector3.ProjectOnPlane(cameraTransform.right, Vector3.up).normalized;
            move = forward * input.y + right * input.x;
        }
        else
        {
            move = new Vector3(input.x, 0f, input.y);
        }

        if (move.sqrMagnitude > 0.001f)
        {
            Quaternion targetRotation = Quaternion.LookRotation(move, Vector3.up);
            transform.rotation = Quaternion.Slerp(
                transform.rotation, targetRotation, rotationSpeed * Time.deltaTime);
        }

        if (controller.isGrounded && verticalVelocity < 0f)
            verticalVelocity = -2f;
        else
            verticalVelocity -= gravity * Time.deltaTime;

        Vector3 velocity = move.normalized * moveSpeed;
        velocity.y = verticalVelocity;
        controller.Move(velocity * Time.deltaTime);
    }
}
