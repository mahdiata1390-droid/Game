using UnityEngine;

/// <summary>Small local checkpoint save for the prototype player position and health.</summary>
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

        if (float.IsNaN(savedPosition.x) || float.IsNaN(savedPosition.y) ||
            float.IsNaN(savedPosition.z) || savedPosition.y < -20f ||
            savedPosition.sqrMagnitude > 100000000f)
            savedPosition = new Vector3(0f, 1.05f, 0f);

        transform.position = savedPosition;
        if (health != null)
        {
            int savedHealth = PlayerPrefs.GetInt(Key("health"), health.Max);
            health.SetCurrent(savedHealth <= 0 ? health.Max : savedHealth);
        }
    }

    private void OnApplicationPause(bool paused) { if (paused) Save(); }
    private void OnApplicationQuit() { Save(); }

    public void Save()
    {
        PlayerPrefs.SetFloat(Key("x"), transform.position.x);
        PlayerPrefs.SetFloat(Key("y"), transform.position.y);
        PlayerPrefs.SetFloat(Key("z"), transform.position.z);
        if (health != null) PlayerPrefs.SetInt(Key("health"), health.Current);
        PlayerPrefs.SetInt(HasSaveKey, 1);
        PlayerPrefs.Save();
    }
}