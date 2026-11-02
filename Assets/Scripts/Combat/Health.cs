using UnityEngine;

public sealed class Health : MonoBehaviour
{
    [SerializeField, Min(1)] private int maxHealth = 100;
    public int Current { get; private set; }
    public int Max => maxHealth;
    public bool IsDead => Current <= 0;

    private void Awake() { Current = maxHealth; }

    public void TakeDamage(int amount)
    {
        if (IsDead || amount <= 0) return;
        Current = Mathf.Max(0, Current - amount);
        if (IsDead) SendMessage("OnDeath", SendMessageOptions.DontRequireReceiver);
    }

    public void RestoreFull() { Current = maxHealth; }
}
