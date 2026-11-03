using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.UI;

/// <summary>
/// Creates a small playable greybox when the Prototype scene starts.
/// This is deliberately placeholder geometry, not final art.
/// </summary>
public sealed class PrototypeBootstrap : MonoBehaviour
{
    private static PlayerCombat playerCombat;
    private static Health playerHealth;
    private static PlayerInteraction playerInteraction;
    private static PlayerInventory playerInventory;
    private static CampfireBuilder campfireBuilder;
    private void Start()
    {
        CreateLighting();
        CreateGround();
        CreatePlayer();
        CreateTouchControls();
        CreateEnemy();
        CreateResourceNodes();
        gameObject.AddComponent<WorldSimulation>();
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

        GameObject statusObject = new GameObject("Status Message", typeof(RectTransform), typeof(Text));
        statusObject.transform.SetParent(canvasObject.transform, false);
        RectTransform statusRect = statusObject.GetComponent<RectTransform>();
        statusRect.anchorMin = new Vector2(0.5f, 1f);
        statusRect.anchorMax = new Vector2(0.5f, 1f);
        statusRect.pivot = new Vector2(0.5f, 1f);
        statusRect.anchoredPosition = new Vector2(0f, -105f);
        statusRect.sizeDelta = new Vector2(760f, 58f);
        Text statusText = statusObject.GetComponent<Text>();
        statusText.font = Resources.GetBuiltinResource<Font>("Arial.ttf");
        statusText.fontSize = 25;
        statusText.alignment = TextAnchor.MiddleCenter;
        statusText.fontStyle = FontStyle.Bold;
        statusText.color = Color.white;
        statusText.raycastTarget = false;
        statusObject.AddComponent<PrototypeStatusDisplay>().Configure(statusText);

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
        attackButton.onClick.AddListener(playerCombat.Attack);

        GameObject collectObject = new GameObject("Collect Button", typeof(RectTransform), typeof(Image), typeof(Button));
        collectObject.transform.SetParent(canvasObject.transform, false);
        RectTransform collectRect = collectObject.GetComponent<RectTransform>();
        collectRect.anchorMin = new Vector2(1f, 0f);
        collectRect.anchorMax = new Vector2(1f, 0f);
        collectRect.pivot = new Vector2(0.5f, 0.5f);
        collectRect.anchoredPosition = new Vector2(-315f, 150f);
        collectRect.sizeDelta = new Vector2(150f, 110f);
        Image collectImage = collectObject.GetComponent<Image>();
        collectImage.color = new Color(0.12f, 0.38f, 0.24f, 0.88f);
        Button collectButton = collectObject.GetComponent<Button>();
        collectButton.targetGraphic = collectImage;
        collectButton.onClick.AddListener(playerInteraction.Interact);

        GameObject herbButtonObject = new GameObject("Use Herb Button", typeof(RectTransform), typeof(Image), typeof(Button));
        herbButtonObject.transform.SetParent(canvasObject.transform, false);
        RectTransform herbButtonRect = herbButtonObject.GetComponent<RectTransform>();
        herbButtonRect.anchorMin = new Vector2(1f, 0f);
        herbButtonRect.anchorMax = new Vector2(1f, 0f);
        herbButtonRect.pivot = new Vector2(0.5f, 0.5f);
        herbButtonRect.anchoredPosition = new Vector2(-315f, 280f);
        herbButtonRect.sizeDelta = new Vector2(150f, 90f);
        Image herbButtonImage = herbButtonObject.GetComponent<Image>();
        herbButtonImage.color = new Color(0.20f, 0.48f, 0.22f, 0.88f);
        Button herbButton = herbButtonObject.GetComponent<Button>();
        herbButton.targetGraphic = herbButtonImage;
        herbButton.onClick.AddListener(playerInteraction.UseHerb);

        GameObject buildButtonObject = new GameObject("Build Campfire Button", typeof(RectTransform), typeof(Image), typeof(Button));
        buildButtonObject.transform.SetParent(canvasObject.transform, false);
        RectTransform buildButtonRect = buildButtonObject.GetComponent<RectTransform>();
        buildButtonRect.anchorMin = new Vector2(1f, 0f);
        buildButtonRect.anchorMax = new Vector2(1f, 0f);
        buildButtonRect.pivot = new Vector2(0.5f, 0.5f);
        buildButtonRect.anchoredPosition = new Vector2(-315f, 390f);
        buildButtonRect.sizeDelta = new Vector2(150f, 90f);
        Image buildButtonImage = buildButtonObject.GetComponent<Image>();
        buildButtonImage.color = new Color(0.48f, 0.31f, 0.12f, 0.92f);
        Button buildButton = buildButtonObject.GetComponent<Button>();
        buildButton.targetGraphic = buildButtonImage;
        buildButton.onClick.AddListener(campfireBuilder.BuildCampfire);

        GameObject restButtonObject = new GameObject("Rest Button", typeof(RectTransform), typeof(Image), typeof(Button));
        restButtonObject.transform.SetParent(canvasObject.transform, false);
        RectTransform restButtonRect = restButtonObject.GetComponent<RectTransform>();
        restButtonRect.anchorMin = new Vector2(1f, 0f);
        restButtonRect.anchorMax = new Vector2(1f, 0f);
        restButtonRect.pivot = new Vector2(0.5f, 0.5f);
        restButtonRect.anchoredPosition = new Vector2(-145f, 390f);
        restButtonRect.sizeDelta = new Vector2(150f, 90f);
        Image restButtonImage = restButtonObject.GetComponent<Image>();
        restButtonImage.color = new Color(0.12f, 0.30f, 0.48f, 0.92f);
        Button restButton = restButtonObject.GetComponent<Button>();
        restButton.targetGraphic = restButtonImage;
        restButton.onClick.AddListener(campfireBuilder.RestAtCampfire);

        GameObject restLabelObject = new GameObject("Rest Label", typeof(RectTransform), typeof(Text));
        restLabelObject.transform.SetParent(restButtonObject.transform, false);
        RectTransform restLabelRect = restLabelObject.GetComponent<RectTransform>();
        restLabelRect.anchorMin = Vector2.zero;
        restLabelRect.anchorMax = Vector2.one;
        restLabelRect.offsetMin = Vector2.zero;
        restLabelRect.offsetMax = Vector2.zero;
        Text restLabel = restLabelObject.GetComponent<Text>();
        restLabel.text = "REST";
        restLabel.alignment = TextAnchor.MiddleCenter;
        restLabel.font = Resources.GetBuiltinResource<Font>("Arial.ttf");
        restLabel.fontSize = 20;
        restLabel.fontStyle = FontStyle.Bold;
        restLabel.color = Color.white;
        restLabel.raycastTarget = false;

        GameObject buildLabelObject = new GameObject("Build Campfire Label", typeof(RectTransform), typeof(Text));
        buildLabelObject.transform.SetParent(buildButtonObject.transform, false);
        RectTransform buildLabelRect = buildLabelObject.GetComponent<RectTransform>();
        buildLabelRect.anchorMin = Vector2.zero;
        buildLabelRect.anchorMax = Vector2.one;
        buildLabelRect.offsetMin = Vector2.zero;
        buildLabelRect.offsetMax = Vector2.zero;
        Text buildLabel = buildLabelObject.GetComponent<Text>();
        buildLabel.text = "BUILD FIRE";
        buildLabel.alignment = TextAnchor.MiddleCenter;
        buildLabel.font = Resources.GetBuiltinResource<Font>("Arial.ttf");
        buildLabel.fontSize = 18;
        buildLabel.fontStyle = FontStyle.Bold;
        buildLabel.color = Color.white;
        buildLabel.raycastTarget = false;

        GameObject herbLabelObject = new GameObject("Use Herb Label", typeof(RectTransform), typeof(Text));
        herbLabelObject.transform.SetParent(herbButtonObject.transform, false);
        RectTransform herbLabelRect = herbLabelObject.GetComponent<RectTransform>();
        herbLabelRect.anchorMin = Vector2.zero;
        herbLabelRect.anchorMax = Vector2.one;
        herbLabelRect.offsetMin = Vector2.zero;
        herbLabelRect.offsetMax = Vector2.zero;
        Text herbLabel = herbLabelObject.GetComponent<Text>();
        herbLabel.text = "USE HERB";
        herbLabel.alignment = TextAnchor.MiddleCenter;
        herbLabel.font = Resources.GetBuiltinResource<Font>("Arial.ttf");
        herbLabel.fontSize = 19;
        herbLabel.fontStyle = FontStyle.Bold;
        herbLabel.color = Color.white;
        herbLabel.raycastTarget = false;

        GameObject collectLabelObject = new GameObject("Collect Label", typeof(RectTransform), typeof(Text));
        collectLabelObject.transform.SetParent(collectObject.transform, false);
        RectTransform collectLabelRect = collectLabelObject.GetComponent<RectTransform>();
        collectLabelRect.anchorMin = Vector2.zero;
        collectLabelRect.anchorMax = Vector2.one;
        collectLabelRect.offsetMin = Vector2.zero;
        collectLabelRect.offsetMax = Vector2.zero;
        Text collectLabel = collectLabelObject.GetComponent<Text>();
        collectLabel.text = "COLLECT";
        collectLabel.alignment = TextAnchor.MiddleCenter;
        collectLabel.font = Resources.GetBuiltinResource<Font>("Arial.ttf");
        collectLabel.fontSize = 22;
        collectLabel.fontStyle = FontStyle.Bold;
        collectLabel.color = Color.white;
        collectLabel.raycastTarget = false;

        GameObject inventoryObject = new GameObject("Inventory HUD", typeof(RectTransform), typeof(Text));
        inventoryObject.transform.SetParent(canvasObject.transform, false);
        RectTransform inventoryRect = inventoryObject.GetComponent<RectTransform>();
        inventoryRect.anchorMin = new Vector2(0.5f, 1f);
        inventoryRect.anchorMax = new Vector2(0.5f, 1f);
        inventoryRect.pivot = new Vector2(0.5f, 1f);
        inventoryRect.anchoredPosition = new Vector2(0f, -38f);
        inventoryRect.sizeDelta = new Vector2(650f, 48f);
        Text inventoryLabel = inventoryObject.GetComponent<Text>();
        inventoryLabel.font = Resources.GetBuiltinResource<Font>("Arial.ttf");
        inventoryLabel.fontSize = 22;
        inventoryLabel.alignment = TextAnchor.MiddleCenter;
        inventoryLabel.color = Color.white;
        inventoryLabel.fontStyle = FontStyle.Bold;
        inventoryLabel.raycastTarget = false;
        InventoryDisplay inventoryDisplay = inventoryObject.AddComponent<InventoryDisplay>();
        inventoryDisplay.Configure(playerInventory, inventoryLabel);

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

        GameObject healthBackObject = new GameObject("Health Bar Background", typeof(RectTransform), typeof(Image));
        healthBackObject.transform.SetParent(canvasObject.transform, false);
        RectTransform healthBackRect = healthBackObject.GetComponent<RectTransform>();
        healthBackRect.anchorMin = new Vector2(0f, 1f);
        healthBackRect.anchorMax = new Vector2(0f, 1f);
        healthBackRect.pivot = new Vector2(0f, 1f);
        healthBackRect.anchoredPosition = new Vector2(40f, -38f);
        healthBackRect.sizeDelta = new Vector2(360f, 42f);
        healthBackObject.GetComponent<Image>().color = new Color(0.04f, 0.04f, 0.05f, 0.8f);

        GameObject fillObject = new GameObject("Health Bar Fill", typeof(RectTransform), typeof(Image));
        fillObject.transform.SetParent(healthBackObject.transform, false);
        RectTransform fillRect = fillObject.GetComponent<RectTransform>();
        fillRect.anchorMin = Vector2.zero;
        fillRect.anchorMax = Vector2.one;
        fillRect.offsetMin = new Vector2(4f, 4f);
        fillRect.offsetMax = new Vector2(-4f, -4f);
        Image fillImage = fillObject.GetComponent<Image>();
        fillImage.color = new Color(0.18f, 0.72f, 0.32f, 1f);
        fillImage.type = Image.Type.Filled;
        fillImage.fillMethod = Image.FillMethod.Horizontal;

        GameObject hpTextObject = new GameObject("Health Text", typeof(RectTransform), typeof(Text));
        hpTextObject.transform.SetParent(healthBackObject.transform, false);
        RectTransform hpTextRect = hpTextObject.GetComponent<RectTransform>();
        hpTextRect.anchorMin = Vector2.zero;
        hpTextRect.anchorMax = Vector2.one;
        hpTextRect.offsetMin = Vector2.zero;
        hpTextRect.offsetMax = Vector2.zero;
        Text hpText = hpTextObject.GetComponent<Text>();
        hpText.font = Resources.GetBuiltinResource<Font>("Arial.ttf");
        hpText.fontSize = 22;
        hpText.alignment = TextAnchor.MiddleCenter;
        hpText.color = Color.white;
        hpText.raycastTarget = false;

        PlayerHealthDisplay display = healthBackObject.AddComponent<PlayerHealthDisplay>();
        display.Configure(playerHealth, fillImage, hpText);
    }

    private static void CreateEnemy()
    {
        GameObject enemy = new GameObject("Prototype Enemy");
        enemy.transform.position = new Vector3(3f, 0.05f, 3f);
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

    private static void CreateResourceNodes()
    {
        CreateResourceNode("Wood Pile", ResourceType.Wood, new Vector3(2.2f, 0.45f, 0.2f),
            PrimitiveType.Cylinder, new Color(0.42f, 0.22f, 0.09f), 4);
        CreateResourceNode("Stone Deposit", ResourceType.Stone, new Vector3(-2.4f, 0.35f, 0.8f),
            PrimitiveType.Sphere, new Color(0.48f, 0.50f, 0.54f), 4);
        CreateResourceNode("Herb Patch", ResourceType.Herb, new Vector3(0.4f, 0.25f, 2.7f),
            PrimitiveType.Cube, new Color(0.18f, 0.62f, 0.24f), 3);
    }

    private static void CreateResourceNode(string objectName, ResourceType type, Vector3 position,
        PrimitiveType shape, Color color, int amount)
    {
        GameObject node = GameObject.CreatePrimitive(shape);
        node.name = objectName;
        node.transform.position = position;
        node.transform.localScale = type == ResourceType.Wood
            ? new Vector3(0.65f, 0.9f, 0.65f)
            : type == ResourceType.Stone
                ? new Vector3(0.85f, 0.65f, 0.75f)
                : new Vector3(0.55f, 0.45f, 0.55f);
        Renderer renderer = node.GetComponent<Renderer>();
        renderer.material = new Material(Shader.Find("Standard"));
        renderer.material.color = color;
        node.AddComponent<ResourceNode>().Configure(type, amount);
    }

    private static void CreatePlayer()
    {
        GameObject player = new GameObject("Prototype Player");
        player.transform.position = new Vector3(0f, 0.05f, 0f);

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
        playerHealth = player.AddComponent<Health>();
        player.AddComponent<PrototypeSaveSystem>();
        playerHealth.EnableAutoRespawn(controller, player.transform.position,
            player.transform.rotation, 2f);
        playerCombat = player.AddComponent<PlayerCombat>();
        playerInventory = player.AddComponent<PlayerInventory>();
        playerInteraction = player.AddComponent<PlayerInteraction>();
        campfireBuilder = player.AddComponent<CampfireBuilder>();
        campfireBuilder.Configure(playerInventory, player.transform);

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
