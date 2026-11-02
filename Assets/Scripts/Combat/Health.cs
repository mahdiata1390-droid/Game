using UnityEngine;

public sealed class Health : MonoBehaviour
{
    [SerializeField, Min(1)] private int maxHealth = 100;
    public int Current { get; private set; }
    public int Max => maxHealth;
    public bool IsDead => Current <= 0;

    private bool autoRespawn;
    private float respawnDelay = 2f;
    private float respawnAt;
    private Vector3 spawnPosition;
    private Quaternion spawnRotation;
    private CharacterController characterController;

    private void Awake() { Current = maxHealth; }

    private void Update()
    {
        if (!autoRespawn || !IsDead || respawnAt <= 0f || Time.time < respawnAt) return;

        if (characterController != null) characterController.enabled = false;
        transform.SetPositionAndRotation(spawnPosition, spawnRotation);
        if (characterController != null) characterController.enabled = true;
        RestoreFull();
        respawnAt = 0f;
    }

    public void EnableAutoRespawn(CharacterController controller, Vector3 position,
        Quaternion rotation, float delaySeconds = 2f)
    {
        characterController = controller;
        spawnPosition = position;
        spawnRotation = rotation;
        respawnDelay = Mathf.Max(0f, delaySeconds);
        autoRespawn = true;
    }

    public void TakeDamage(int amount)
    {
        if (IsDead || amount <= 0) return;
        Current = Mathf.Max(0, Current - amount);
        SendMessage("OnDamaged", SendMessageOptions.DontRequireReceiver);
        if (IsDead)
        {
            if (autoRespawn) respawnAt = Time.time + respawnDelay;
            SendMessage("OnDeath", SendMessageOptions.DontRequireReceiver);
        }
    }

    public void RestoreFull()
    {
        Current = maxHealth;
    }

    public void SetCurrent(int value)
    {
        Current = Mathf.Clamp(value, 0, maxHealth);
    }
}