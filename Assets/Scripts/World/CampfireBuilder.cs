using UnityEngine;

public sealed class CampfireBuilder : MonoBehaviour
{
    private const string BuiltKey = "prototype_campfire_built";
    private const string XKey = "prototype_campfire_x";
    private const string YKey = "prototype_campfire_y";
    private const string ZKey = "prototype_campfire_z";

    private PlayerInventory inventory;
    private Transform player;
    private Health playerHealth;
    private GameObject campfire;
    private Light fireLight;
    private Transform flameTransform;

    public void Configure(PlayerInventory sourceInventory, Transform playerTransform)
    {
        inventory = sourceInventory;
        player = playerTransform;
        playerHealth = playerTransform.GetComponent<Health>();
        LoadCampfire();
    }

    public void BuildCampfire()
    {
        if (campfire != null)
        {
            PrototypeStatusDisplay.Show("You already built a campfire");
            return;
        }

        if (inventory == null || player == null)
        {
            PrototypeStatusDisplay.Show("Campfire is unavailable");
            return;
        }

        if (inventory.Wood < 3 || inventory.Stone < 2)
        {
            PrototypeStatusDisplay.Show("Need 3 wood and 2 stone");
            return;
        }

        if (!inventory.TryConsume(ResourceType.Wood, 3)) return;
        if (!inventory.TryConsume(ResourceType.Stone, 2))
        {
            inventory.Add(ResourceType.Wood, 3);
            PrototypeStatusDisplay.Show("Not enough stone");
            return;
        }

        Vector3 position = player.position + player.forward * 2.2f;
        position.y = 0.08f;
        CreateCampfire(position);

        PlayerPrefs.SetInt(BuiltKey, 1);
        PlayerPrefs.SetFloat(XKey, position.x);
        PlayerPrefs.SetFloat(YKey, position.y);
        PlayerPrefs.SetFloat(ZKey, position.z);
        PlayerPrefs.Save();

        PrototypeStatusDisplay.Show("Campfire built");
    }

    public void RestAtCampfire()
    {
        if (campfire == null || player == null || playerHealth == null || playerHealth.IsDead)
        {
            PrototypeStatusDisplay.Show("Build a campfire first");
            return;
        }

        Vector3 flatPlayer = new Vector3(player.position.x, 0f, player.position.z);
        Vector3 flatFire = new Vector3(campfire.transform.position.x, 0f, campfire.transform.position.z);
        if (Vector3.Distance(flatPlayer, flatFire) > 3f)
        {
            PrototypeStatusDisplay.Show("Move closer to the campfire");
            return;
        }

        if (playerHealth.Current >= playerHealth.Max)
        {
            PrototypeStatusDisplay.Show("Health is already full");
            return;
        }

        playerHealth.Restore(50);
        PrototypeStatusDisplay.Show("Rested: restored up to 50 health");
    }

    private void Update()
    {
        if (fireLight == null) return;

        float wave = Mathf.PerlinNoise(Time.time * 3.7f, 0.41f);
        fireLight.intensity = 1.15f + wave * 0.65f;

        if (flameTransform != null)
        {
            float pulse = 1f + Mathf.Sin(Time.time * 5.2f) * 0.08f;
            float heightPulse = 1f + Mathf.Sin(Time.time * 4.1f + 0.8f) * 0.10f;
            flameTransform.localScale = new Vector3(0.32f * pulse, 0.58f * heightPulse, 0.32f * pulse);
        }
    }

    private void LoadCampfire()
    {
        if (PlayerPrefs.GetInt(BuiltKey, 0) != 1) return;

        Vector3 position = new Vector3(
            PlayerPrefs.GetFloat(XKey, 0f),
            PlayerPrefs.GetFloat(YKey, 0.08f),
            PlayerPrefs.GetFloat(ZKey, 0f));

        if (float.IsNaN(position.x) || float.IsInfinity(position.x) ||
            float.IsNaN(position.z) || float.IsInfinity(position.z) ||
            Mathf.Abs(position.x) > 10000f || Mathf.Abs(position.z) > 10000f)
        {
            PlayerPrefs.DeleteKey(BuiltKey);
            PlayerPrefs.DeleteKey(XKey);
            PlayerPrefs.DeleteKey(YKey);
            PlayerPrefs.DeleteKey(ZKey);
            PlayerPrefs.Save();
            return;
        }

        CreateCampfire(position);
    }

    private void CreateCampfire(Vector3 position)
    {
        campfire = new GameObject("Player Campfire");
        campfire.transform.position = position;

        CreatePart("Log A", PrimitiveType.Cylinder, position + new Vector3(0f, 0.12f, 0f),
            new Vector3(0.12f, 0.65f, 0.12f), new Color(0.28f, 0.13f, 0.06f),
            Quaternion.Euler(0f, 0f, 90f));
        CreatePart("Log B", PrimitiveType.Cylinder, position + new Vector3(0f, 0.15f, 0f),
            new Vector3(0.12f, 0.65f, 0.12f), new Color(0.34f, 0.17f, 0.08f),
            Quaternion.Euler(0f, 90f, 90f));

        for (int i = 0; i < 5; i++)
        {
            float angle = i * Mathf.PI * 2f / 5f;
            Vector3 offset = new Vector3(Mathf.Cos(angle) * 0.48f, 0.08f,
                Mathf.Sin(angle) * 0.48f);
            CreatePart("Fire Stone " + i, PrimitiveType.Sphere, position + offset,
                new Vector3(0.22f, 0.16f, 0.22f), new Color(0.35f, 0.36f, 0.38f),
                Quaternion.identity);
        }

        GameObject flame = CreatePart("Campfire Flame", PrimitiveType.Sphere,
            position + new Vector3(0f, 0.52f, 0f), new Vector3(0.32f, 0.58f, 0.32f),
            new Color(1f, 0.34f, 0.04f), Quaternion.identity);
        flameTransform = flame.transform;
        fireLight = flame.AddComponent<Light>();
        fireLight.type = LightType.Point;
        fireLight.range = 7f;
        fireLight.intensity = 1.4f;
        fireLight.color = new Color(1f, 0.42f, 0.12f);
    }

    private GameObject CreatePart(string partName, PrimitiveType primitive, Vector3 position,
        Vector3 scale, Color color, Quaternion rotation)
    {
        GameObject part = GameObject.CreatePrimitive(primitive);
        part.name = partName;
        part.transform.SetParent(campfire.transform, true);
        part.transform.position = position;
        part.transform.rotation = rotation;
        part.transform.localScale = scale;

        Collider partCollider = part.GetComponent<Collider>();
        if (partCollider != null) Destroy(partCollider);

        Renderer renderer = part.GetComponent<Renderer>();
        renderer.material = new Material(Shader.Find("Standard"));
        renderer.material.color = color;
        return part;
    }
}