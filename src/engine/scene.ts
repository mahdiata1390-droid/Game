// Scene persistence: the engine's save format is plain JSON, one entry per
// entity, so worlds can be diffed, hand-edited and loaded by other tools.

import { type Entity, World } from "./ecs";

export const COMPONENTS = [
  "Transform",
  "Appearance",
  "Body",
  "Character",
  "Unit",
  "Meta",
  "Player",
] as const;

export type SceneFile = {
  format: "forge-scene";
  version: 1;
  savedAt: string;
  entities: Array<{ id: number; components: Record<string, object> }>;
};

export function serializeWorld(world: World): SceneFile {
  const entities: SceneFile["entities"] = [];
  for (const id of world.query()) {
    const components: Record<string, object> = {};
    for (const name of COMPONENTS) {
      const value = world.get(id, name);
      if (value) components[name] = JSON.parse(JSON.stringify(value));
    }
    entities.push({ id, components });
  }
  return {
    format: "forge-scene",
    version: 1,
    savedAt: new Date().toISOString(),
    entities,
  };
}

export function loadScene(world: World, scene: SceneFile): Entity[] {
  const created: Entity[] = [];
  for (const entry of scene.entities) {
    created.push(world.create(entry.components as Record<string, object>));
  }
  return created;
}

export function parseScene(text: string): SceneFile {
  const parsed = JSON.parse(text) as Partial<SceneFile>;
  if (parsed.format !== "forge-scene" || !Array.isArray(parsed.entities)) {
    throw new Error("not a Forge scene file");
  }
  return parsed as SceneFile;
}
