using UnityEngine;

/// <summary>
/// Creates a small playable greybox when the Prototype scene starts.
/// This is deliberately placeholder geometry, not final art.
/// </summary>
public sealed class PrototypeBootstrap : MonoBehaviour
{
    private void Start()
    {
        CreateLighting();
        CreateGround();
        CreatePlayer();
    }

    private static void CreateLighting()
    {
        RenderSettings.ambientMode = UnityEngine.Rendering.AmbientMode.Flat;
        RenderSettings.ambientLight = new Color(0.58f, 0.60f, 0.64f);

        GameObject lightObject = new GameObject("Prototype Directional Light");
        Light sun = lightObject.AddComponent<Light>();
        sun.type = LightType.Directional;
        sun.intensity = 1.15f;
        lightObject.transform.rotation = Quaternion.Euler(48f, -32f, 0f);
    }

    private static void CreateGround()
    {
        GameObject ground = GameObject.CreatePrimitive(PrimitiveType.Plane);
        ground.name = "Greybox Ground";
        ground.transform.position = Vector3.zero;
        ground.transform.localScale = new Vector3(8f, 1f, 8f);

        Renderer renderer = ground.GetComponent<Renderer>();
        renderer.material = new Material(Shader.Find("Standard"));
        renderer.material.color = new Color(0.30f, 0. thirtyf, 0.20f);
    }

    private static void CreatePlayer()
    {
        GameObject player = new GameObject("Prototype Player");
        player.transform.position = new Vector3(0f, 1.05f, 0f);

        CharacterController controller = player.AddComponent<CharacterController>();
        controller.height = 1.8f;
        controller.radius = 0.38f;
        controller.center = new Vector3(0f, 0.9f, 0f);
        controller.stepOffset = 0.3f;

        GameObject body = GameObject.CreatePrimitive(PrimitiveType.Capsule);
        body.name = "Placeholder Character Visual";
        body.transform.SetParent(player.transform, false);
        body.transform.localPosition = new Vector3(0f, 0.9f, 0f);
        body.transform.localScale = new Vector3(0.72f, 0.9f, 0.72f);
        Collider bodyCollider = body.GetComponent<Collider>();
        if (bodyCollider != null)
            Destroy(bodyCollider);

        Renderer bodyRenderer = body.GetComponent<Renderer>();
        bodyRenderer.material = new Material(Shader.Find("Standard"));
        bodyRenderer.material.color = new Color(0.22f, 0.32f, 0.52f);

        ThirdPersonMotor motor = player.AddComponent<ThirdPersonMotor>();

        GameObject cameraObject = new GameObject("Main Camera");
        cameraObject.tag = "MainCamera";
        Camera camera = cameraObject.AddComponent<Camera>();
        camera.fieldOfView = 60f;
        camera.nearClipPlane = 0.1f;
        camera.farClipPlane = 500f;
        cameraObject.AddComponent<AudioListener>();

        CameraFollowRig follow = cameraObject.AddComponent<CameraFollowRig>();
        follow.SetTarget(player.transform);
        cameraObject.transform.position = player.transform.TransformPoint(new Vector3(0f, 3f, -5f));
        motor.SendMessage("SetCameraTransform", cameraObject.transform, SendMessageOptions.DontRequireReceiver);
    }
}
