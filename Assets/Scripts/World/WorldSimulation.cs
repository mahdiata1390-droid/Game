using UnityEngine;

/// <summary>
/// Runtime world layer for the prototype: day/night cycle, simple weather mood,
/// village props, ambient NPCs and wildlife. Uses only built-in Unity primitives.
/// </summary>
public sealed class WorldSimulation : MonoBehaviour
{
    [Header("Time")]
    [SerializeField] private float secondsPerDay = 360f;
    [SerializeField] private float startTime = 8f;

    private Light sun;
    private float timeOfDay;

    private void Awake()
    {
        timeOfDay = Mathf.Repeat(startTime, 24f);
        BuildWorld();
    }

    private void Update()
    {
        timeOfDay = Mathf.Repeat(timeOfDay + (24f / Mathf.Max(30f, secondsPerDay)) * Time.deltaTime, 24f);

        float sunAngle = (timeOfDay / 24f) * 360f - 90f;
        if (sun != null)
        {
            sun.transform.rotation = Quaternion.Euler(sunAngle, -35f, 0f);
            float daylight = Mathf.Clamp01(Mathf.Sin((timeOfDay - 6f) / 12f * Mathf.PI));
            sun.intensity = Mathf.Lerp(0.08f, 1.15f, daylight);
        }

        float night = 1f - Mathf.Clamp01(Mathf.Sin((timeOfDay - 6f) / 12f * Mathf.PI));
        RenderSettings.ambientLight = Color.Lerp(
            new Color(0.055f, 0.07f, 0.12f),
            new Color(0.58f, 0.60f, 0.64f),
            1f - night);
        RenderSettings.fog = true;
        RenderSettings.fogDensity = Mathf.Lerp(0.012f, 0.004f, 1f - night);
    }

    private void BuildWorld()
    {
        GameObject lightObject = GameObject.Find("Prototype Directional Light");
        if (lightObject != null)
            sun = lightObject.GetComponent<Light>();

        CreateVillage();
        CreateForest();
        CreateWildlife();
        CreateWorldMarker(new Vector3(7f, 0.05f, 7f), new Color(0.75f, 0.55f, 0.12f), "Village Center");
    }

    private static void CreateVillage()
    {
        CreateHouse(new Vector3(6f, 0f, 5f), 1.0f);
        CreateHouse(new Vector3(9f, 0f, 7f), 0.85f);
        CreateHouse(new Vector3(7f, 0f, 10f), 0.9f);

        GameObject market = GameObject.CreatePrimitive(PrimitiveType.Cube);
        market.name = "Village Market Stall";
        market.transform.position = new Vector3(5f, 0.8f, 8f);
        market.transform.localScale = new Vector3(2.4f, 1.6f, 1.5f);
        SetColor(market, new Color(0.38f, 0.22f, 0.10f));

        for (int i = 0; i < 5; i++)
        {
            Vector3 spawn = new Vector3(5.5f + (i % 3) * 1.7f, 0.05f, 6.5f + (i / 3) * 2f);
            GameObject npc = CreateHumanoid("Villager " + (i + 1), spawn, new Color(0.34f + i * 0.04f, 0.25f, 0.18f));
            WorldNpcAgent agent = npc.AddComponent<WorldNpcAgent>();
            agent.SetCenter(new Vector3(7f, 0f, 8f), 5f, i * 1.37f);
        }
    }

    private static void CreateHouse(Vector3 position, float scale)
    {
        GameObject house = new GameObject("Village House");

        GameObject body = GameObject.CreatePrimitive(PrimitiveType.Cube);
        body.transform.SetParent(house.transform, false);
        body.transform.localPosition = position + new Vector3(0f, 1.1f * scale, 0f);
        body.transform.localScale = new Vector3(2.6f, 2.2f, 2.4f) * scale;
        SetColor(body, new Color(0.30f, 0.20f, 0.13f));

        GameObject roof = GameObject.CreatePrimitive(PrimitiveType.Cube);
        roof.transform.SetParent(house.transform, false);
        roof.transform.localPosition = position + new Vector3(0f, 2.55f * scale, 0f);
        roof.transform.localScale = new Vector3(3.0f, 0.35f, 2.8f) * scale;
        roof.transform.localRotation = Quaternion.Euler(0f, 0f, 0f);
        SetColor(roof, new Color(0.16f, 0.09f, 0.07f));

        GameObject door = GameObject.CreatePrimitive(PrimitiveType.Cube);
        door.transform.SetParent(house.transform, false);
        door.transform.localPosition = position + new Vector3(0f, 0.7f * scale, -1.23f * scale);
        door.transform.localScale = new Vector3(0.65f, 1.3f, 0.12f) * scale;
        SetColor(door, new Color(0.16f, 0.09f, 0.05f));
    }

    private static void CreateForest()
    {
        Vector3[] positions =
        {
            new Vector3(-9f, 0f, -6f), new Vector3(-6f, 0f, -10f),
            new Vector3(-2f, 0f, -8f), new Vector3(10f, 0f, -7f),
            new Vector3(13f, 0f, -2f), new Vector3(12f, 0f, 11f),
            new Vector3(-11f, 0f, 8f), new Vector3(-7f, 0f, 12f),
            new Vector3(14f, 0f, 4f), new Vector3(2f, 0f, 13f)
        };

        for (int i = 0; i < positions.Length; i++)
            CreateTree(positions[i], 0.85f + (i % 4) * 0.12f);
    }

    private static void CreateTree(Vector3 position, float scale)
    {
        GameObject trunk = GameObject.CreatePrimitive(PrimitiveType.Cylinder);
        trunk.name = "Pine Tree Trunk";
        trunk.transform.position = position + Vector3.up * (1.5f * scale);
        trunk.transform.localScale = new Vector3(0.28f, 1.5f, 0.28f) * scale;
        SetColor(trunk, new Color(0.22f, 0.12f, 0.06f));

        GameObject crown = GameObject.CreatePrimitive(PrimitiveType.Capsule);
        crown.name = "Pine Tree Crown";
        crown.transform.position = position + Vector3.up * (3.2f * scale);
        crown.transform.localScale = new Vector3(1.35f, 2.2f, 1.35f) * scale;
        SetColor(crown, new Color(0.08f, 0.28f, 0.12f));
    }

    private static void CreateWildlife()
    {
        for (int i = 0; i < 3; i++)
        {
            Vector3 spawn = new Vector3(-4f + i * 3.2f, 0.05f, 5f + i);
            GameObject animal = CreateHumanoid("Deer " + (i + 1), spawn, new Color(0.45f, 0.30f, 0.18f));
            animal.transform.localScale = new Vector3(0.7f, 0.65f, 1.15f);
            WorldNpcAgent agent = animal.AddComponent<WorldNpcAgent>();
            agent.SetCenter(new Vector3(0f, 0f, 6f), 7f, 4f + i);
        }
    }

    private static GameObject CreateHumanoid(string name, Vector3 position, Color color)
    {
        GameObject root = new GameObject(name);
        root.transform.position = position;

        GameObject body = GameObject.CreatePrimitive(PrimitiveType.Capsule);
        body.transform.SetParent(root.transform, false);
        body.transform.localPosition = Vector3.up * 0.9f;
        body.transform.localScale = new Vector3(0.55f, 0.9f, 0.55f);
        SetColor(body, color);

        GameObject head = GameObject.CreatePrimitive(PrimitiveType.Sphere);
        head.transform.SetParent(root.transform, false);
        head.transform.localPosition = Vector3.up * 1.85f;
        head.transform.localScale = Vector3.one * 0.42f;
        SetColor(head, new Color(0.68f, 0.48f, 0.34f));

        return root;
    }

    private static void CreateWorldMarker(Vector3 position, Color color, string label)
    {
        GameObject marker = GameObject.CreatePrimitive(PrimitiveType.Cylinder);
        marker.name = label;
        marker.transform.position = position + Vector3.up * 0.35f;
        marker.transform.localScale = new Vector3(0.25f, 0.35f, 0.25f);
        SetColor(marker, color);
    }

    private static void SetColor(GameObject target, Color color)
    {
        Renderer renderer = target.GetComponent<Renderer>();
        if (renderer == null)
            return;

        Material material = new Material(Shader.Find("Standard"));
        material.color = color;
        renderer.material = material;

        Collider collider = target.GetComponent<Collider>();
        if (collider != null && target.name.Contains("Pine Tree Crown"))
            collider.enabled = false;
    }

    private sealed class WorldNpcAgent : MonoBehaviour
    {
        private Vector3 center;
        private float radius;
        private float seed;
        private Vector3 destination;
        private float wait;

        public void SetCenter(Vector3 value, float movementRadius, float randomSeed)
        {
            center = value;
            radius = movementRadius;
            seed = randomSeed;
            PickDestination();
        }

        private void Update()
        {
            if (wait > 0f)
            {
                wait -= Time.deltaTime;
                return;
            }

            Vector3 flat = destination - transform.position;
            flat.y = 0f;

            if (flat.sqrMagnitude < 0.25f)
            {
                wait = 0.7f + Mathf.Abs(Mathf.Sin(seed + Time.time)) * 1.8f;
                PickDestination();
                return;
            }

            Vector3 direction = flat.normalized;
            transform.position += direction * (Time.deltaTime * 0.7f);
            if (direction.sqrMagnitude > 0.01f)
                transform.rotation = Quaternion.Slerp(transform.rotation, Quaternion.LookRotation(direction), Time.deltaTime * 5f);
        }

        private void PickDestination()
        {
            float angle = (Time.time * 17f + seed * 53f) % 360f;
            Vector3 offset = new Vector3(Mathf.Cos(angle * Mathf.Deg2Rad), 0f, Mathf.Sin(angle * Mathf.Deg2Rad)) * radius;
            destination = center + offset;
            destination.y = 0.05f;
        }
    }
}
