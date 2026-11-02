using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.UI;

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
        CreateTouchControls();
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
        renderer.material.color = new Color(0.30f, 0.30f, 0.20f);
    }

    private static void CreateTouchControls()
    {
        GameObject eventSystemObject = new GameObject("EventSystem");
        eventSystemObject.AddComponent<EventSystem>();
        eventSystemObject.AddComponent<StandaloneInputModule>();

        GameObject canvasObject = new GameObject("Mobile Controls");
        Canvas canvas = canvasObject.AddComponent<Canvas>();
        canvas.renderMode = RenderMode.ScreenSpaceOverlay;
        canvasObject.AddComponent<CanvasScaler>().uiScaleMode = CanvasScaler.ScaleMode.ScaleWithScreenSize;
        canvasObject.GetComponent<CanvasScaler>().referenceResolution = new Vector2(1920f, 1080f);
        canvasObject.GetComponent<CanvasScaler>().matchWidthOrHeight = 0.5f;
        canvasObject.AddComponent<GraphicRaycaster>();

        GameObject baseObject = new GameObject("Joystick Background", typeof(RectTransform), typeof(Image));
        baseObject.transform.SetParent(canvasObject.transform, false);
        RectTransform baseRect = baseObject.GetComponent<RectTransform>();
        baseRect.anchorMin = new Vector2(0f, 0f);
        baseRect.anchorMax = new Vector2(0f, 0f);
        baseRect.pivot = new Vector2(0.5f, 0.5f);
        baseRect.anchoredPosition = new Vector2(150f, 145f);
        baseRect.sizeDelta = new Vector2(190f, 190f);
        Image baseImage = baseObject.GetComponent<Image>();
        baseImage.color = new Color(0.06f, 0.08f, 0.12f, 0.48f);
        baseImage.raycastTarget = true;

        GameObject handleObject = new GameObject("Joystick Handle", typeof(RectTransform), typeof(Image));
        handleObject.transform.SetParent(baseObject.transform, false);
        RectTransform handleRect = handleObject.GetComponent<RectTransform>();
        handleRect.anchorMin = new Vector2(0.5f, 0.5f);
        handleRect.anchorMax = new Vector2(0.5f, 0.5f);
        handleRect.pivot = new Vector2(0.5f, 0.5f);
        handleRect.anchoredPosition = Vector2.zero;
        handleRect.sizeDelta = new Vector2(76f, 76f);
        Image handleImage = handleObject.GetComponent<Image>();
        handleImage.color = new Color(0.78f, 0.82f, 0.9f, 0.88f);
        handleImage.raycastTarget = false;

        VirtualJoystick joystick = baseObject.AddComponent<VirtualJoystick>();
        joystick.Configure(baseRect, handleRect, 58f);
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
        motor.SetCameraTransform(cameraObject.transform);
    }
}
