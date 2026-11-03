using UnityEngine;

/// <summary>
/// Lightweight battlefield troop controller for the sandbox.
/// Friendly troops stay near the player and attack nearby enemy troops.
/// Enemy troops advance toward the player's warband.
/// </summary>
public sealed class BattleTroopAI : MonoBehaviour
{
    public enum Team { Player, Enemy }

    private Team team;
    private Transform commander;
    private CharacterController controller;
    private Health health;
    private float attackCooldown;
    private float moveSpeed = 2.2f;

    public void Configure(Team troopTeam, Transform troopCommander)
    {
        team = troopTeam;
        commander = troopCommander;
        controller = GetComponent<CharacterController>();
        health = GetComponent<Health>();
    }

    private void Update()
    {
        if (health != null && health.Current <= 0)
            return;

        attackCooldown -= Time.deltaTime;

        BattleTroopAI target = FindNearestEnemy();
        if (target != null && Vector3.Distance(transform.position, target.transform.position) <= 1.8f)
        {
            Face(target.transform.position);
            if (attackCooldown <= 0f)
            {
                target.ReceiveHit(10);
                attackCooldown = 0.8f;
            }
            return;
        }

        Vector3 destination = GetFormationDestination();
        Vector3 delta = destination - transform.position;
        delta.y = 0f;

        if (delta.sqrMagnitude > 0.35f)
        {
            Vector3 direction = delta.normalized;
            Move(direction * moveSpeed * Time.deltaTime);
            Face(transform.position + direction);
        }
    }

    private BattleTroopAI FindNearestEnemy()
    {
        BattleTroopAI[] troops = FindObjectsOfType<BattleTroopAI>();
        BattleTroopAI nearest = null;
        float best = float.MaxValue;

        for (int i = 0; i < troops.Length; i++)
        {
            if (troops[i] == this || troops[i].team == team)
                continue;

            float distance = (troops[i].transform.position - transform.position).sqrMagnitude;
            if (distance < best)
            {
                best = distance;
                nearest = troops[i];
            }
        }

        return nearest;
    }

    private Vector3 GetFormationDestination()
    {
        if (team == Team.Enemy)
            return commander != null ? commander.position : transform.position;

        if (commander == null)
            return transform.position;

        int index = Mathf.Abs(GetInstanceID()) % 6;
        int row = index / 3;
        int column = index % 3;
        Vector3 local = new Vector3((column - 1) * 1.25f, 0f, -2.2f - row * 1.2f);
        return commander.TransformPoint(local);
    }

    private void ReceiveHit(int damage)
    {
        if (health != null)
            health.TakeDamage(damage);
    }

    private void Move(Vector3 motion)
    {
        if (controller != null)
            controller.Move(motion);
        else
            transform.position += motion;
    }

    private void Face(Vector3 point)
    {
        Vector3 flat = point - transform.position;
        flat.y = 0f;
        if (flat.sqrMagnitude > 0.01f)
            transform.rotation = Quaternion.Slerp(transform.rotation, Quaternion.LookRotation(flat), Time.deltaTime * 8f);
    }
}
