using UnityEngine;

/// <summary>
/// Creates the first Mount-and-Blade-style warband encounter:
/// a player commander, friendly troops, and an opposing squad.
/// This is a combat foundation, not a final large-scale battle system.
/// </summary>
public sealed class WarbandBattleBootstrap : MonoBehaviour
{
    private Transform player;

    public void Configure(Transform playerTransform)
    {
        player = playerTransform;
        BuildBattle();
    }

    private void BuildBattle()
    {
        if (player == null)
            return;

        for (int i = 0; i < 6; i++)
        {
            Vector3 spawn = player.TransformPoint(new Vector3((i % 3 - 1) * 1.25f, 0.05f, -2.2f - (i / 3) * 1.2f));
            CreateTroop("Player Soldier " + (i + 1), spawn, BattleTroopAI.Team.Player, new Color(0.18f, 0.38f, 0.72f), player);
        }

        Vector3 enemyCommander = player.position + player.forward * 10f + player.right * 2f;
        for (int i = 0; i < 8; i++)
        {
            Vector3 spawn = enemyCommander + new Vector3((i % 4 - 1.5f) * 1.35f, 0.05f, (i / 4) * 1.5f);
            CreateTroop("Enemy Soldier " + (i + 1), spawn, BattleTroopAI.Team.Enemy, new Color(0.68f, 0.15f, 0.12f), player);
        }
    }

    private static void CreateTroop(string name, Vector3 position, BattleTroopAI.Team team, Color color, Transform commander)
    {
        GameObject troop = new GameObject(name);
        troop.transform.position = position;

        CharacterController controller = troop.AddComponent<CharacterController>();
        controller.height = 1.7f;
        controller.radius = 0.32f;
        controller.center = new Vector3(0f, 0.85f, 0f);
        controller.stepOffset = 0.25f;

        GameObject visual = GameObject.CreatePrimitive(PrimitiveType.Capsule);
        visual.name = "Troop Visual";
        visual.transform.SetParent(troop.transform, false);
        visual.transform.localPosition = new Vector3(0f, 0.85f, 0f);
        visual.transform.localScale = new Vector3(0.55f, 0.85f, 0.55f);

        Collider collider = visual.GetComponent<Collider>();
        if (collider != null)
            Destroy(collider);

        Renderer renderer = visual.GetComponent<Renderer>();
        if (renderer != null)
        {
            renderer.material = new Material(Shader.Find("Standard"));
            renderer.material.color = color;
        }

        Health health = troop.AddComponent<Health>();
        health.SetCurrent(60);

        BattleTroopAI ai = troop.AddComponent<BattleTroopAI>();
        ai.Configure(team, commander);
    }
}
