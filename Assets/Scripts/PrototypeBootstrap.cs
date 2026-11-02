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
        CreateEnemy();
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

        GameObject lookObject = new GameObject("Touch Look Area", typeof(RectTransform), typeof(Image));
        lookObject.transform.SetParent(canvasObject.transform, false);
        RectTransform lookRect = lookObject.GetComponent<RectTransform>();
        lookRect.anchorMin = new Vector2(0.48f, 0.12f);
        lookRect.anchorMax = new Vector2(1f, 0.94f);
        lookRect.offsetMin = Vector2.zero;
        lookRect.offsetMax = Vector2.zero;
        Image lookImage = lookObject.GetComponent<Image>();
        lookImage.color = new Color(1f, 1f, 1f, 0.015f);
        lookImage.raycastTarget = true;
        lookObject.AddComponent<TouchLookArea>();

        GameObject attackObject = new GameObject("Attack Button", typeof(RectTransform), typeof(Image), typeof(Button));
        attackObject.transform.SetParent(canvasObject.transform, false);
        RectTransform attackRect = attackObject.GetComponent<RectTransform>();
        attackRect.anchorMin = new Vector2(1f, 0f);
        attackRect.anchorMax = new Vector2(1f, 0f);
        attackRect.pivot = new Vector2(0.5f, 0.5f);
        attackRect.anchoredPosition = new Vector2(-145f, 150f);
        attackRect.sizeDelta = new Vector2(150f, 150f);
        Image attackImage = attackObject.GetComponent<Image>();
        attackImage.color = new Color(0.55f, 0.12f, 0.10f, 0.82f);
        Button attackButton = attackObject.GetComponent<Button>();
        attackButton.targetGraphic = attackImage;
        attackButton.onClick.AddListener(combat.Attack);

        GameObject labelObject = new GameObject("Attack Label", typeof(RectTransform), typeof(Text));
        labelObject.transform.SetParent(attackObject.transform, false);
        RectTransform labelRect = labelObject.GetComponent<RectTransform>();
        labelRect.anchorMin = Vector2.zero;
        labelRect.anchorMax = Vector2.one;
        labelRect.offsetMin = Vector2.zero;
        labelRect.offsetMax = Vector2.zero;
        Text label = labelObject.GetComponent<Text>();
        label.text = "ATTACK";
        label.alignment = TextAnchor.MiddleCenter;
        label.font = Resources.GetBuiltinResource<Font>("Arial.ttf");
        label.fontSize = 28;
        label.fontStyle = FontStyle.Bold;
        label.color = Color.white;
        label.raycastTarget = false;
    }

    private static void CreateEnemy()
    {
        GameObject enemy = new GameObject("Prototype Enemy");
        enemy.transform.position = new Vector3(3f, 1.05f, 3f);
        CharacterController controller = enemy.AddComponent<CharacterController>();
        controller.height = 1.8f;
        controller.radius = 0.4f;
        controller.center = new Vector3(0f, 0.9f, 0f);
        controller.stepOffset = 0.25f;

        GameObject visual = GameObject.CreatePrimitive(PrimitiveType.Capsule);
        visual.name = "Enemy Placeholder Visual";
        visual.transform.SetParent(enemy.transform, false);
        visual.transform.localPosition = new Vector3(0f, 0.9f, 0f);
        visual.transform.localScale = new Vector3(0.78f, 0.9f, 0.78f);
        Collider visualCollider = visual.GetComponent<Collider>();
        if (visualCollider != null) Destroy(visualCollider);
        Renderer renderer = visual.GetComponent<Renderer>();
        renderer.material = new Material(Shader.Find("Standard"));
        renderer.material.color = new Color(0.55f, 0.16f, 0.12f);

        enemy.AddComponent<Health>();
        enemy.AddComponent<SimpleEnemyAI>();
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
        player.AddComponent<Health>();
        PlayerCombat combat = player.AddComponent<PlayerCombat>();

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
