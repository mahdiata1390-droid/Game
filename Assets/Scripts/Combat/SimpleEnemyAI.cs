using System.Collections;
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
    [SerializeField] private float gravity = -20f;
    [SerializeField] private Renderer hitRenderer;
    [SerializeField] private Color hitColor = new Color(1f, 0.72f, 0.62f);
    [SerializeField] private float hitFlashDuration = 0.12f;

    private Transform player;
    private CharacterController controller;
    private Health health;
    private float nextAttackTime;
    private float verticalVelocity;
    private Color baseColor = Color.white;
    private Coroutine hitFlash;

    private void Awake()
    {
        controller = GetComponent<CharacterController>();
        health = GetComponent<Health>();
        if (hitRenderer == null) hitRenderer = GetComponentInChildren<Renderer>();
        if (hitRenderer != null) baseColor = hitRenderer.material.color;
    }

    private void Start()
    {
        GameObject playerObject = GameObject.Find("Prototype Player");
        if (playerObject != null) player = playerObject.transform;
    }

    private void Update()
    {
        if (health.IsDead) return;

        Vector3 horizontalMove = Vector3.zero;
        if (player != null)
        {
            Vector3 delta = player.position - transform.position;
            delta.y = 0f;
            float distance = delta.magnitude;

            if (distance <= noticeDistance && distance > 0.01f)
            {
                transform.rotation = Quaternion.Slerp(transform.rotation,
                    Quaternion.LookRotation(delta), 8f * Time.deltaTime);

                if (distance > attackDistance)
                    horizontalMove = delta.normalized * moveSpeed;
                else if (Time.time >= nextAttackTime)
                {
                    nextAttackTime = Time.time + attackCooldown;
                    Health playerHealth = player.GetComponent<Health>();
                    if (playerHealth != null) playerHealth.TakeDamage(damage);
                }
            }
        }

        if (controller.isGrounded && verticalVelocity < 0f)
            verticalVelocity = -2f;
        else
            verticalVelocity += gravity * Time.deltaTime;

        Vector3 velocity = horizontalMove;
        velocity.y = verticalVelocity;
        controller.Move(velocity * Time.deltaTime);
    }

    private void OnDamaged()
    {
        if (hitRenderer == null) return;
        if (hitFlash != null) StopCoroutine(hitFlash);
        hitFlash = StartCoroutine(FlashOnHit());
    }

    private IEnumerator FlashOnHit()
    {
        hitRenderer.material.color = hitColor;
        yield return new WaitForSeconds(hitFlashDuration);
        if (hitRenderer != null) hitRenderer.material.color = baseColor;
        hitFlash = null;
    }

    private void OnDeath()
    {
        Destroy(gameObject, 0.25f);
    }

    private void OnDestroy()
    {
        if (hitRenderer != null) hitRenderer.material.color = baseColor;
    }
}