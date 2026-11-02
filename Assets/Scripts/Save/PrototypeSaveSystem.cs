using UnityEngine;

/// <summary>Small local checkpoint save for the prototype player position, facing, and health.</summary>
public sealed class PrototypeSaveSystem : MonoBehaviour
{
    private const string HasSaveKey = "prototype_save_exists";
    private Health health;

    private string Key(string suffix) { return "prototype_player_" + suffix; }

    private void Awake()
    {
        health = GetComponent<Health>();
        if (PlayerPrefs.GetInt(HasSaveKey, 0) != 1) return;

        Vector3 savedPosition = new Vector3(
            PlayerPrefs.GetFloat(Key("x"), transform.position.x),
            PlayerPrefs.GetFloat(Key("y"), transform.position.y),
            PlayerPrefs.GetFloat(Key("z"), transform.position.z));

        if (!IsFinite(savedPosition.x) || !IsFinite(savedPosition.y) ||
            !IsFinite(savedPosition.z) || savedPosition.y < -20f ||
            savedPosition.sqrMagnitude > 100000000f)
            savedPosition = new Vector3(0f, 1.05f, 0f);

        transform.position = savedPosition;
        float savedYaw = PlayerPrefs.GetFloat(Key("yaw"), transform.eulerAngles.y);
        if (IsFinite(savedYaw))
            transform.rotation = Quaternion.Euler(0f, savedYaw, 0f);

        if (health != null)
        {
            int savedHealth = PlayerPrefs.GetInt(Key("health"), health.Max);
            health.SetCurrent(savedHealth <= 0 ? health.Max : savedHealth);
        }
    }

    private static bool IsFinite(float value)
    {
        return !float.IsNaN(value) && !float.IsInfinity(value);
    }

    private void OnApplicationPause(bool paused) { if (paused) Save(); }
    private void OnApplicationQuit() { Save(); }

    private void OnRespawn() { Save(); }

    public void Save()
    {
        PlayerPrefs.SetFloat(Key("x"), transform.position.x);
        PlayerPrefs.SetFloat(Key("y"), transform.position.y);
        PlayerPrefs.SetFloat(Key("z"), transform.position.z);
        PlayerPrefs.SetFloat(Key("yaw"), transform.eulerAngles.y);
        if (health != null) PlayerPrefs.SetInt(Key("health"), health.Current);
        PlayerPrefs.SetInt(HasSaveKey, 1);
        PlayerPrefs.Save();
    }
}