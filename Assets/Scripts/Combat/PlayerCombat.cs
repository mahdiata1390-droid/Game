using UnityEngine;

public sealed class PlayerCombat : MonoBehaviour
{
    [SerializeField] private float attackRange = 2.1f;
    [SerializeField] private float attackRadius = 0.85f;
    [SerializeField] private int damage = 35;
    [SerializeField] private float attackCooldown = 0.65f;
    [SerializeField] private LayerMask targetLayers = ~0;
    private float nextAttackTime;

    public void Attack()
    {
        if (Time.time < nextAttackTime) return;
        nextAttackTime = Time.time + attackCooldown;

        Vector3 origin = transform.position + Vector3.up * 1.0f;
        Vector3 direction = transform.forward;
        Vector3 center = origin + direction * attackRange * 0.5f;
        Collider[] hits = Physics.OverlapSphere(center, attackRadius, targetLayers,
            QueryTriggerInteraction.Ignore);

        float nearest = float.MaxValue;
        Health target = null;
        foreach (Collider hit in hits)
        {
            if (hit.transform.root == transform.root) continue;
            Health candidate = hit.GetComponentInParent<Health>();
            if (candidate == null || candidate.IsDead) continue;
            float distance = Vector3.Distance(transform.position, candidate.transform.position);
            if (distance < nearest && distance <= attackRange + attackRadius)
            {
                nearest = distance;
                target = candidate;
            }
        }

        if (target != null) target.TakeDamage(damage);
    }
}
