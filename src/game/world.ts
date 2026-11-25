// The playable medieval world: settlements, warbands, day/night and combat.
// Everything is authored in code, so the whole world is ~40 KB of source and
// no binary asset pack is required to boot.

import { clamp, angleDelta, lerp, type Vec3 } from "../engine/math";
import { World, type Entity } from "../engine/ecs";
import { ATLAS_TILE as TILE } from "../engine/textures";
import type { Input } from "../engine/input";
import type { Camera, Instance, Light } from "../engine/renderer";

export type Transform = {
  x: number; y: number; z: number;
  yaw: number; pitch: number;
  sx: number; sy: number; sz: number;
};

export type Appearance = {
  r: number; g: number; b: number;
  tile: number;
  repeat: number;
  emissive: number;
  flash: number;
};

export type Body = { hx: number; hz: number; solid: boolean };

export type Character = {
  name: string;
  faction: "player" | "ally" | "enemy";
  hp: number;
  maxHp: number;
  speed: number;
  damage: number;
  cooldown: number;
  respawn: number;
};

export type Unit = {
  homeX: number;
  homeZ: number;
  wanderT: number;
  target: Entity;
};

export type Meta = { name: string; group: string };

const FACTION_COLORS: Record<string, [number, number, number]> = {
  "Free Company": [0.42, 0.45, 0.5],
  north_kingdom: [0.24, 0.38, 0.66],
  river_kingdom: [0.74, 0.55, 0.2],
  eastern_tribes: [0.72, 0.24, 0.16],
  southern_sultanate: [0.82, 0.62, 0.14],
  western_clans: [0.42, 0.3, 0.58],
};

type SettlementDef = {
  name: string;
  kind: "village" | "town" | "castle" | "city";
  x: number;
  z: number;
  owner: string;
  population: number;
};

const SETTLEMENTS: SettlementDef[] = [
  { name: "Northwatch", kind: "castle", x: -58, z: -42, owner: "north_kingdom", population: 720 },
  { name: "Pinehaven", kind: "village", x: -20, z: -48, owner: "north_kingdom", population: 260 },
  { name: "Valoria", kind: "city", x: 22, z: -45, owner: "river_kingdom", population: 1450 },
  { name: "Steppe Camp", kind: "village", x: 61, z: -29, owner: "eastern_tribes", population: 310 },
  { name: "Frostport", kind: "town", x: -64, z: 0, owner: "north_kingdom", population: 610 },
  { name: "Kingsbridge", kind: "city", x: -16, z: -3, owner: "river_kingdom", population: 1300 },
  { name: "Goldford", kind: "town", x: 26, z: -3, owner: "river_kingdom", population: 820 },
  { name: "Redstone", kind: "castle", x: 61, z: 6, owner: "eastern_tribes", population: 540 },
  { name: "Clanhold", kind: "castle", x: -54, z: 38, owner: "western_clans", population: 490 },
  { name: "Basinfield", kind: "village", x: -10, z: 35, owner: "river_kingdom", population: 280 },
  { name: "Sahr", kind: "city", x: 32, z: 38, owner: "southern_sultanate", population: 1600 },
  { name: "Pearl Bay", kind: "town", x: 64, z: 48, owner: "southern_sultanate", population: 730 },
];

const SPAWN: Vec3 = { x: 0, y: 0, z: 14 };

function rng(seed: number): () => number {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

export class MedievalWorld {
  readonly world = new World();
  player: Entity = 0;
  gold = 250;
  day = 1;
  hour = 8;
  aliveAllies = 0;
  aliveEnemies = 0;
  log = "Click or press Space to strike.";
  private spawnCooldown = 0;
  private random = rng(20261125);

  constructor(build = true) {
    if (build) this.build();
  }

  /** Recompute faction counts after loading a scene from disk. */
  refresh(): void {
    this.countLiving();
  }

  /** The player entity, or 0 when a loaded scene does not contain one. */
  findPlayer(): Entity {
    const found = this.world.query("Player", "Transform");
    return found.length > 0 ? found[0] : 0;
  }

  // ---------------------------------------------------------------- authoring

  add(
    name: string,
    group: string,
    x: number, y: number, z: number,
    sx: number, sy: number, sz: number,
    color: [number, number, number],
    options: {
      tile?: number; repeat?: number; emissive?: number;
      yaw?: number; pitch?: number; body?: Body; meta?: boolean;
    } = {},
  ): Entity {
    return this.world.create({
      Transform: { x, y, z, yaw: options.yaw ?? 0, pitch: options.pitch ?? 0, sx, sy, sz },
      Appearance: {
        r: color[0], g: color[1], b: color[2],
        tile: options.tile ?? -1,
        repeat: options.repeat ?? 1,
        emissive: options.emissive ?? 0,
        flash: 0,
      },
      ...(options.body ? { Body: options.body } : {}),
      ...(options.meta === false ? {} : { Meta: { name, group } }),
    });
  }

  addCharacter(name: string, faction: Character["faction"], x: number, z: number, hp: number): Entity {
    const color: [number, number, number] = faction === "enemy"
      ? [0.62, 0.24, 0.2]
      : faction === "ally" ? [0.36, 0.5, 0.62] : [0.55, 0.62, 0.72];
    const id = this.world.create({
      Transform: { x, y: 0, z, yaw: 0, pitch: 0, sx: 1, sy: 1, sz: 1 },
      Appearance: { r: color[0], g: color[1], b: color[2], tile: -1, repeat: 1, emissive: 0, flash: 0 },
      Character: {
        name, faction, hp, maxHp: hp,
        speed: faction === "player" ? 5.6 : faction === "ally" ? 3.4 : 2.8,
        damage: faction === "player" ? 18 : 9,
        cooldown: 0, respawn: 0,
      },
      Unit: { homeX: x, homeZ: z, wanderT: this.random() * 3, target: 0 },
      Body: { hx: 0.35, hz: 0.35, solid: false },
      Meta: { name, group: faction === "player" ? "Player" : faction === "ally" ? "Warband" : "Enemies" },
      ...(faction === "player" ? { Player: {} } : {}),
    });
    return id;
  }

  private build(): void {
    // Ground and roads
    this.add("Ground", "Terrain", 0, -1.1, 0, 260, 2, 260, [1, 1, 1], {
      tile: TILE.GRASS, repeat: 44, meta: false,
    });
    this.add("Kingsroad", "Terrain", 0, -0.02, -40, 150, 0.06, 7, [1, 1, 1], {
      tile: TILE.DIRT, repeat: 18, meta: false,
    });
    this.add("South Road", "Terrain", 0, -0.02, 30, 9, 0.06, 92, [1, 1, 1], {
      tile: TILE.DIRT, repeat: 16, meta: false,
    });

    for (const s of SETTLEMENTS) this.buildSettlement(s);
    this.buildForest();
    this.buildRocks();
    this.buildCamp();

    // Player and warband
    this.player = this.addCharacter("You", "player", SPAWN.x, SPAWN.z, 100);
    for (let i = 0; i < 6; i++) {
      const angle = (i / 6) * Math.PI * 2;
      this.addCharacter(
        `Warband ${i + 1}`, "ally",
        SPAWN.x + Math.cos(angle) * 3.4, SPAWN.z + Math.sin(angle) * 3.4, 60,
      );
    }

    // Three hostile patrols
    const patrols: Array<[number, number, string]> = [
      [-8, -20, "Steppe Riders"],
      [30, 10, "Redstone Guard"],
      [-40, 24, "Clan Raiders"],
    ];
    for (const [px, pz, squad] of patrols) {
      for (let i = 0; i < 3; i++) {
        const id = this.addCharacter(
          `${squad} ${i + 1}`, "enemy",
          px + (this.random() - 0.5) * 4, pz + (this.random() - 0.5) * 4, 45,
        );
        this.world.require<Unit>(id, "Unit").homeX = px;
        this.world.require<Unit>(id, "Unit").homeZ = pz;
      }
    }

    this.countLiving();
  }

  private buildSettlement(s: SettlementDef): void {
    const color = FACTION_COLORS[s.owner] ?? [0.5, 0.5, 0.5];
    const [r, g, b] = color;
    const group = `Settlement · ${s.name}`;

    const keepHeight = s.kind === "castle" ? 9 : s.kind === "city" ? 7 : 4.5;
    const keepWidth = s.kind === "castle" ? 12 : 9;

    // Keep: stone body plus a clay roof
    this.world.create({
      Transform: { x: s.x, y: 0.5, z: s.z, yaw: 0, pitch: 0, sx: keepWidth, sy: keepHeight, sz: keepWidth * 0.8 },
      Appearance: { r: 1.2, g: 1.2, b: 1.16, tile: TILE.STONE, repeat: keepWidth / 4, emissive: 0, flash: 0 },
      Body: { hx: keepWidth / 2, hz: keepWidth * 0.4, solid: true },
      Meta: { name: `${s.name} Keep`, group },
    });
    this.world.create({
      Transform: { x: s.x, y: keepHeight + 1.6, z: s.z, yaw: 0.4, pitch: 0, sx: keepWidth * 1.06, sy: 3.2, sz: keepWidth * 0.9 },
      Appearance: { r: 0.9, g: 0.55, b: 0.42, tile: TILE.ROOF, repeat: keepWidth / 2.4, emissive: 0, flash: 0 },
      Meta: { name: `${s.name} Roof`, group },
    });

    // Corner towers
    for (const [dx, dz] of [[-1, -1], [1, -1], [-1, 1], [1, 1]]) {
      const tx = s.x + dx * (keepWidth / 2 + 1.5);
      const tz = s.z + dz * (keepWidth * 0.4 + 1.5);
      this.world.create({
        Transform: { x: tx, y: 1, z: tz, yaw: 0, pitch: 0, sx: 3.4, sy: 10, sz: 3.4 },
        Appearance: { r: 1.1, g: 1.1, b: 1.08, tile: TILE.STONE, repeat: 1.2, emissive: 0, flash: 0 },
        Body: { hx: 1.7, hz: 1.7, solid: true },
        Meta: { name: `${s.name} Tower`, group },
      });
      this.world.create({
        Transform: { x: tx, y: 6.6, z: tz, yaw: 0.78, pitch: 0, sx: 4.2, sy: 2.2, sz: 4.2 },
        Appearance: { r: 0.85, g: 0.5, b: 0.38, tile: TILE.ROOF, repeat: 2, emissive: 0, flash: 0 },
        Meta: { name: `${s.name} Tower Roof`, group },
      });
    }

    // Houses
    const houses = s.kind === "village" ? 3 : s.kind === "city" ? 6 : 4;
    for (let i = 0; i < houses; i++) {
      const a = (i / houses) * Math.PI * 2 + 0.6;
      const dist = keepWidth * 0.9 + 5;
      const hx = s.x + Math.cos(a) * dist;
      const hz = s.z + Math.sin(a) * dist * 0.9;
      const w = 5 + this.random() * 2;
      this.world.create({
        Transform: { x: hx, y: 0.5, z: hz, yaw: -a, pitch: 0, sx: w, sy: 3.6, sz: w * 0.78 },
        Appearance: { r: 1, g: 1, b: 1, tile: this.random() > 0.45 ? TILE.PLASTER : TILE.WOOD, repeat: 1.4, emissive: 0, flash: 0 },
        Body: { hx: w / 2, hz: w * 0.39, solid: true },
        Meta: { name: `${s.name} House ${i + 1}`, group },
      });
      this.world.create({
        Transform: { x: hx, y: 3.4, z: hz, yaw: -a, pitch: 0, sx: w * 1.14, sy: 1.9, sz: w * 0.92 },
        Appearance: { r: 0.95, g: 0.52, b: 0.4, tile: TILE.ROOF, repeat: 1.4, emissive: 0, flash: 0 },
        Meta: { name: `${s.name} Roof ${i + 1}`, group },
      });
    }

    // Faction banner
    this.world.create({
      Transform: { x: s.x + 2.6, y: 5, z: s.z + keepWidth * 0.5, yaw: 0, pitch: 0, sx: 0.18, sy: 10, sz: 0.18 },
      Appearance: { r: 0.22, g: 0.18, b: 0.14, tile: TILE.WOOD, repeat: 1, emissive: 0, flash: 0 },
      Meta: { name: `${s.name} Banner Pole`, group },
    });
    this.world.create({
      Transform: { x: s.x + 3.1, y: 7.6, z: s.z + keepWidth * 0.5, yaw: 0, pitch: 0, sx: 0.08, sy: 3.2, sz: 1.9 },
      Appearance: { r: r * 1.5, g: g * 1.5, b: b * 1.5, tile: TILE.CLOTH, repeat: 1, emissive: 0.06, flash: 0 },
      Meta: { name: `${s.name} Banner`, group },
    });

    // Windows as warm emissive details
    const windows = s.kind === "village" ? 4 : 8;
    for (let i = 0; i < windows; i++) {
      const a = (i / windows) * Math.PI * 2;
      this.world.create({
        Transform: {
          x: s.x + Math.cos(a) * (keepWidth / 2 + 0.06),
          y: 2.4 + (i % 2) * 1.8,
          z: s.z + Math.sin(a) * (keepWidth * 0.4 + 0.06),
          yaw: -a, pitch: 0, sx: 0.9, sy: 1.1, sz: 0.1,
        },
        Appearance: { r: 1, g: 0.82, b: 0.45, tile: TILE.CLOTH, repeat: 1, emissive: 0.85, flash: 0 },
        Meta: { name: `${s.name} Window`, group },
      });
    }

    // Settlers (visual population, non-combat)
    const settlers = Math.min(4, Math.max(1, Math.round(s.population / 400)));
    for (let i = 0; i < settlers; i++) {
      this.add(
        `${s.name} Settler ${i + 1}`, group,
        s.x + (this.random() - 0.5) * keepWidth * 1.6,
        0.7,
        s.z + (this.random() - 0.5) * keepWidth,
        0.55, 1.4, 0.55,
        [0.62, 0.56, 0.46],
        { tile: TILE.CLOTH, repeat: 1 },
      );
    }
  }

  private buildForest(): void {
    const group = "Wilds";
    for (let i = 0; i < 260; i++) {
      const x = (this.random() - 0.5) * 230;
      const z = (this.random() - 0.5) * 230;
      if (Math.hypot(x - SPAWN.x, z - SPAWN.z) < 14) continue;
      if (SETTLEMENTS.some((s) => Math.hypot(x - s.x, z - s.z) < 16)) continue;
      const h = 3 + this.random() * 3;
      this.add("Pine", group, x, h / 2 + 1.4, z, 0.7, h, 0.7, [0.9, 0.85, 0.8], {
        tile: TILE.WOOD, repeat: 1, meta: false,
      }, );
      this.add("Pine Canopy", group, x, h + 2.6, z, 4.2 + this.random() * 2, 4.6, 4.2, [0.62, 0.86, 0.6], {
        tile: TILE.GRASS, repeat: 2, yaw: this.random() * Math.PI, meta: false,
      });
    }
  }

  private buildRocks(): void {
    for (let i = 0; i < 45; i++) {
      const x = (this.random() - 0.5) * 210;
      const z = (this.random() - 0.5) * 210;
      const s = 1 + this.random() * 2.4;
      this.add("Boulder", "Wilds", x, s * 0.4, z, s, s * 0.8, s * 1.1, [0.72, 0.74, 0.76], {
        tile: TILE.STONE, repeat: 1, yaw: this.random() * Math.PI, meta: false,
      });
    }
  }

  private buildCamp(): void {
    const cx = SPAWN.x + 5;
    const cz = SPAWN.z - 4;
    this.add("Campfire", "Camp", cx, 0.6, cz, 1.6, 0.7, 1.6, [0.4, 0.4, 0.4], {
      tile: TILE.STONE, repeat: 1, body: { hx: 0.8, hz: 0.8, solid: false },
    });
    this.world.create({
      Transform: { x: cx, y: 1.35, z: cz, yaw: 0, pitch: 0, sx: 0.6, sy: 1.1, sz: 0.6 },
      Appearance: { r: 1, g: 0.62, b: 0.22, tile: -1, repeat: 1, emissive: 0.95, flash: 1 },
      Meta: { name: "Campfire Flame", group: "Camp" },
    });
    this.add("Tent", "Camp", cx + 3.4, 1.2, cz - 1.2, 3.4, 2.4, 3, [0.72, 0.66, 0.52], {
      tile: TILE.CLOTH, repeat: 1.5, pitch: 0.18, body: { hx: 1.7, hz: 1.5, solid: true },
    });
  }

  // ------------------------------------------------------------- simulation

  update(dt: number, input: Input, cameraYaw: number, active: boolean): void {
    const player = this.world.require<Character>(this.player, "Character");
    const transform = this.world.require<Transform>(this.player, "Transform");

    if (active) {
      this.updateDayNight(dt);
      this.updatePlayer(dt, input, cameraYaw, transform, player);
      this.updateUnits(dt);
      this.updateFlashes(dt);
      this.countLiving();
    }

    this.spawnCooldown = Math.max(0, this.spawnCooldown - dt);
  }

  private updateDayNight(dt: number): void {
    this.hour += dt * 0.14;
    if (this.hour >= 24) {
      this.hour -= 24;
      this.day += 1;
    }
  }

  private updatePlayer(dt: number, input: Input, cameraYaw: number, t: Transform, c: Character): void {
    if (c.hp <= 0) {
      c.respawn -= dt;
      if (c.respawn <= 0) {
        c.hp = c.maxHp;
        t.x = SPAWN.x;
        t.z = SPAWN.z;
        this.log = "You wake at camp. The warband holds.";
      }
      return;
    }

    let forward = input.axis("KeyS", "KeyW");
    let strafe = input.axis("KeyA", "KeyD");
    if (input.stick.x !== 0 || input.stick.y !== 0) {
      strafe += input.stick.x;
      forward += -input.stick.y;
    }
    const magnitude = Math.hypot(forward, strafe);
    if (magnitude > 1) {
      forward /= magnitude;
      strafe /= magnitude;
    }

    if (magnitude > 0.02) {
      // Camera-relative: W walks away from the camera.
      const sin = Math.sin(cameraYaw), cos = Math.cos(cameraYaw);
      const dx = -sin * forward + cos * strafe;
      const dz = -cos * forward - sin * strafe;
      const step = c.speed * dt;
      t.x += dx * step;
      t.z += dz * step;
      t.yaw = Math.atan2(dx, dz);
      this.resolveCollisions(t, 0.55);
      t.x = clamp(t.x, -118, 118);
      t.z = clamp(t.z, -118, 118);
    }

    c.cooldown = Math.max(0, c.cooldown - dt);
    if (input.attackQueued && c.cooldown <= 0) {
      c.cooldown = 0.42;
      this.playerStrike(t, c);
    }
  }

  private playerStrike(t: Transform, c: Character): void {
    const facingX = Math.sin(t.yaw);
    const facingZ = Math.cos(t.yaw);
    let best: Entity = 0;
    let bestDist = Infinity;
    for (const id of this.world.query("Character", "Transform")) {
      if (id === this.player) continue;
      const other = this.world.require<Character>(id, "Character");
      if (other.faction !== "enemy" || other.hp <= 0) continue;
      const ot = this.world.require<Transform>(id, "Transform");
      const dx = ot.x - t.x, dz = ot.z - t.z;
      const dist = Math.hypot(dx, dz);
      if (dist > 2.8) continue;
      const facing = (dx * facingX + dz * facingZ) / (dist || 1);
      if (facing < 0.25) continue;
      if (dist < bestDist) {
        bestDist = dist;
        best = id;
      }
    }
    if (!best) {
      this.log = "You swing at empty air.";
      return;
    }
    const target = this.world.require<Character>(best, "Character");
    target.hp -= c.damage;
    this.world.require<Appearance>(best, "Appearance").flash = 1;
    if (target.hp <= 0) {
      this.kill(best);
      this.log = `${target.name} falls. +12 gold.`;
      this.gold += 12;
    } else {
      this.log = `You strike ${target.name} for ${c.damage}.`;
    }
  }

  private updateUnits(dt: number): void {
    const playerTransform = this.world.require<Transform>(this.player, "Transform");

    for (const id of this.world.query("Character", "Transform", "Unit")) {
      if (id === this.player) continue;
      // A unit earlier in this tick may have killed a later one, so re-check.
      const c = this.world.get<Character>(id, "Character");
      const t = this.world.get<Transform>(id, "Transform");
      const unit = this.world.get<Unit>(id, "Unit");
      if (!c || !t || !unit || c.hp <= 0) continue;
      c.cooldown = Math.max(0, c.cooldown - dt);

      const nearby = this.findFoe(id, c, t);
      if (nearby) {
        const targetChar = this.world.require<Character>(nearby, "Character");
        const tt = this.world.require<Transform>(nearby, "Transform");
        const dx = tt.x - t.x, dz = tt.z - t.z;
        const dist = Math.hypot(dx, dz);
        t.yaw = this.turnToward(t.yaw, Math.atan2(dx, dz), dt * 6);
        if (dist > 1.6) {
          const step = c.speed * dt;
          t.x += (dx / (dist || 1)) * step;
          t.z += (dz / (dist || 1)) * step;
          this.resolveCollisions(t, 0.35);
        } else if (c.cooldown <= 0) {
          c.cooldown = 1.1 + this.random() * 0.4;
          const victim = targetChar.hp > 0 ? nearby : this.player;
          const vc = this.world.require<Character>(victim, "Character");
          vc.hp -= c.damage;
          this.world.require<Appearance>(victim, "Appearance").flash = 1;
          if (vc.hp <= 0 && victim === this.player) this.downPlayer(vc);
          else if (vc.hp <= 0) this.kill(victim);
        }
      } else {
        // Idle: drift around the camp or settlement.
        unit.wanderT -= dt;
        if (unit.wanderT <= 0) {
          unit.wanderT = 2 + this.random() * 4;
          unit.target = 0;
        }
        const dx = (unit.homeX + Math.sin(id * 1.7 + unit.wanderT) * 2.4) - t.x;
        const dz = (unit.homeZ + Math.cos(id * 2.3 + unit.wanderT) * 2.4) - t.z;
        const dist = Math.hypot(dx, dz);
        if (dist > 0.6) {
          t.x += (dx / dist) * c.speed * 0.22 * dt;
          t.z += (dz / dist) * c.speed * 0.22 * dt;
          t.yaw = this.turnToward(t.yaw, Math.atan2(dx, dz), dt * 2.4);
        }
      }

      if (c.faction === "ally" && Math.hypot(playerTransform.x - t.x, playerTransform.z - t.z) > 16) {
        const dx = playerTransform.x - t.x, dz = playerTransform.z - t.z;
        const dist = Math.hypot(dx, dz) || 1;
        t.x += (dx / dist) * c.speed * 1.2 * dt;
        t.z += (dz / dist) * c.speed * 1.2 * dt;
      }
    }
  }

  private findFoe(id: Entity, c: Character, t: Transform): Entity {
    const range = c.faction === "ally" ? 9 : 11;
    let best: Entity = 0;
    let bestDist = range;
    for (const other of this.world.query("Character", "Transform")) {
      if (other === id) continue;
      const oc = this.world.require<Character>(other, "Character");
      if (oc.hp <= 0) continue;
      const hostile =
        (c.faction === "enemy" && oc.faction !== "enemy") ||
        (c.faction === "ally" && oc.faction === "enemy");
      if (!hostile) continue;
      const ot = this.world.require<Transform>(other, "Transform");
      const dist = Math.hypot(ot.x - t.x, ot.z - t.z);
      if (dist < bestDist) {
        bestDist = dist;
        best = other;
      }
    }
    return best;
  }

  private turnToward(current: number, target: number, t: number): number {
    return current + angleDelta(current, target) * clamp(t, 0, 1);
  }

  private resolveCollisions(t: Transform, radius: number): void {
    for (const id of this.world.query("Body", "Transform")) {
      const body = this.world.require<Body>(id, "Body");
      if (!body.solid) continue;
      const bt = this.world.require<Transform>(id, "Transform");
      const dx = t.x - bt.x;
      const dz = t.z - bt.z;
      const cx = clamp(dx, -body.hx, body.hx);
      const cz = clamp(dz, -body.hz, body.hz);
      const ox = dx - cx;
      const oz = dz - cz;
      const dist = Math.hypot(ox, oz);
      if (dist < radius) {
        if (dist < 0.0001) {
          t.z = bt.z + body.hz + radius;
        } else {
          const push = (radius - dist) / dist;
          t.x += ox * push;
          t.z += oz * push;
        }
      }
    }
  }

  private updateFlashes(dt: number): void {
    for (const id of this.world.query("Appearance")) {
      const a = this.world.require<Appearance>(id, "Appearance");
      if (a.flash > 0) a.flash = Math.max(0, a.flash - dt * 4);
    }
  }

  private downPlayer(c: Character): void {
    c.hp = 0;
    c.respawn = 2.5;
    this.log = "You are struck down…";
  }

  private kill(id: Entity): void {
    const c = this.world.require<Character>(id, "Character");
    c.hp = 0;
    this.world.destroy(id);
  }

  private countLiving(): void {
    let allies = 0;
    let enemies = 0;
    for (const id of this.world.query("Character")) {
      const c = this.world.get<Character>(id, "Character");
      if (!c || c.hp <= 0) continue;
      if (c.faction === "ally") allies++;
      if (c.faction === "enemy") enemies++;
    }
    this.aliveAllies = allies;
    this.aliveEnemies = enemies;
  }

  // ---------------------------------------------------------------- rendering

  buildInstances(out: Instance[], selected: Entity | null, time: number): void {
    const flame = this.world.query("Appearance").find((id) => {
      const meta = this.world.get<Meta>(id, "Meta");
      return meta?.name === "Campfire Flame";
    });
    if (flame) {
      const a = this.world.require<Appearance>(flame, "Appearance");
      a.emissive = 0.6 + Math.sin(time * 9) * 0.15 + Math.sin(time * 3.3) * 0.1;
    }

    for (const id of this.world.query("Transform", "Appearance")) {
      const t = this.world.require<Transform>(id, "Transform");
      const a = this.world.require<Appearance>(id, "Appearance");
      const c = this.world.get<Character>(id, "Character");

      if (c) {
        // Characters: torso plus a head, and a dashed health bar above.
        if (c.hp <= 0) continue;
        const torso = Math.min(1, Math.max(0, c.hp / c.maxHp));
        out.push({
          x: t.x, y: 0.9, z: t.z, yaw: t.yaw,
          sx: 0.62, sy: 1.3, sz: 0.5,
          color: [a.r, a.g, a.b],
          tile: -1,
          emissive: a.flash > 0.6 ? 0.45 : a.flash,
          selected: id === selected,
        });
        out.push({
          x: t.x, y: 1.78, z: t.z, yaw: t.yaw,
          sx: 0.42, sy: 0.42, sz: 0.42,
          color: [0.85, 0.72, 0.58],
          tile: -1,
          selected: id === selected,
        });
        // Shoulder mark shows faction at a distance.
        out.push({
          x: t.x, y: 1.42, z: t.z, yaw: t.yaw,
          sx: 0.7, sy: 0.18, sz: 0.56,
          color: c.faction === "enemy" ? [0.72, 0.16, 0.12] : c.faction === "ally" ? [0.32, 0.55, 0.78] : [0.9, 0.78, 0.32],
          tile: -1,
          emissive: 0.12,
        });
        if (torso < 1) {
          out.push({
            x: t.x, y: 2.12, z: t.z, yaw: 0,
            sx: 0.9, sy: 0.1, sz: 0.06,
            color: [0.18, 0.16, 0.14],
            tile: -1,
          });
          out.push({
            x: t.x - 0.45 + 0.45 * torso, y: 2.12, z: t.z, yaw: 0,
            sx: 0.9 * torso, sy: 0.1, sz: 0.08,
            color: [0.65, 0.2, 0.16],
            tile: -1,
            emissive: 0.2,
          });
        }
        continue;
      }

      out.push({
        x: t.x, y: t.y, z: t.z,
        sx: t.sx, sy: t.sy, sz: t.sz,
        yaw: t.yaw, pitch: t.pitch,
        color: [a.r, a.g, a.b],
        tile: a.tile,
        repeat: a.repeat,
        emissive: Math.min(1, a.emissive + a.flash * 0.8),
        selected: id === selected,
      });
    }
  }

  light(): Light {
    const hour = this.hour;
    const sun = Math.sin(((hour - 6) / 12) * Math.PI); // rises at 6, sets at 18
    const dayness = clamp(sun, 0, 1);
    const dir: Vec3 = {
      x: Math.cos(((hour - 6) / 12) * Math.PI) * 0.55,
      y: clamp(sun, 0.12, 1),
      z: 0.42,
    };
    const dawn = clamp(1 - Math.abs(hour - 7) / 3, 0, 1) + clamp(1 - Math.abs(hour - 18.5) / 3, 0, 1);
    const fog: [number, number, number] = [
      lerp(0.045, 0.62, dayness) + dawn * 0.16,
      lerp(0.06, 0.71, dayness) + dawn * 0.07,
      lerp(0.1, 0.79, dayness) + dawn * 0.01,
    ];
    return {
      dir,
      color: [lerp(0.18, 1.0, dayness) + dawn * 0.12, lerp(0.2, 0.95, dayness), lerp(0.3, 0.84, dayness)],
      ambient: [lerp(0.1, 0.5, dayness), lerp(0.12, 0.53, dayness), lerp(0.2, 0.6, dayness)],
      fogColor: fog,
      fogNear: 42,
      fogFar: 132,
    };
  }
}

export class CameraRig {
  yaw = 0.5;
  pitch = 0.22;
  distance = 9;
  firstPerson = false;

  update(input: Input, target: Vec3): Camera {
    this.yaw -= input.lookX * 0.0042;
    this.pitch = clamp(this.pitch + input.lookY * 0.0032, -0.35, 1.15);
    if (input.wheel) {
      this.distance = clamp(this.distance + input.wheel * 0.012, 3.5, 20);
    }
    if (input.wasPressed("KeyF")) {
      this.firstPerson = !this.firstPerson;
      this.distance = this.firstPerson ? 0.1 : 9;
    }

    const eye: Vec3 = this.firstPerson
      ? { x: target.x, y: target.y + 2.05, z: target.z }
      : {
          x: target.x + Math.sin(this.yaw) * Math.cos(this.pitch) * this.distance,
          y: target.y + 1.5 + Math.sin(this.pitch) * this.distance,
          z: target.z + Math.cos(this.yaw) * Math.cos(this.pitch) * this.distance,
        };
    const look: Vec3 = this.firstPerson
      ? {
          x: target.x - Math.sin(this.yaw) * 8,
          y: target.y + 2.05 - Math.sin(this.pitch) * 8,
          z: target.z - Math.cos(this.yaw) * 8,
        }
      : { x: target.x, y: target.y + 1.5, z: target.z };

    return { eye, target: look, fov: (58 * Math.PI) / 180, near: 0.1, far: 320 };
  }

  /** Direction the player should face for camera-relative movement. */
  get facing(): number {
    return this.yaw;
  }
}
