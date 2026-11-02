using UnityEngine;

[RequireComponent(typeof(CharacterController))]
[RequireComponent(typeof(Health))]
public sealed class SimpleEnemyAI : MonoBehaviour
{
    [SerializeField] private float moveSpeed = 2.1f;
    [SerializeField] private float noticeDistance = 12f;
    [SerializeField] private float attackDistance = 1.5f;
    [SerializeField] private int damage = 8;
    [SerializeField] private float attackCooldown = 1.4f;
    private Transform player;
    private CharacterController controller;
    private Health health;
    private float nextAttackTime;

    private void Awake()
    {
        controller = GetComponent<CharacterController>();
        health = GetComponent<Health>();
    }

    private void Start()
    {
        GameObject playerObject = GameObject.Find("Prototype Player");
        if (playerObject != null) player = playerObject.transform;
    }

    private void Update()
    {
        if (health.IsDead || player == null) return;
        Vector3 delta = player.position - transform.position;
        delta.y = 0f;
        float distance = delta.magnitude;
        if (distance > noticeDistance || distance < 0.01f) return;

        transform.rotation = Quaternion.Slerp(transform.rotation,
            Quaternion.LookRotation(delta), 8f * Time.deltaTime);

        if (distance > attackDistance)
            controller.Move(delta.normalized * moveSpeed * Time.deltaTime);
        else if (Time.time >= nextAttackTime)
        {
            nextAttackTime = Time.time + attackCooldown;
            Health playerHealth = player.GetComponent<Health>();
            if (playerHealth != null) playerHealth.TakeDamage(damage);
        }
    }

    private void OnDeath()
    {
        Destroy(gameObject, 0.25f);
    }
}
