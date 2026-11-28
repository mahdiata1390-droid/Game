// The playable medieval world: settlements, warbands, day/night and combat.
// Everything is authored in code, so the whole world is ~40 KB of source and
// no binary asset pack is required to boot.

import { clamp, angleDelta, lerp, type Vec3 } from "../engine/math";
import { World, type Entity } from "../engine/ecs";
import { ATLAS_TILE as TILE } from "../engine/textures";
import type { Input } from "../engine/input";
import type { Camera, Instance, Light } from "../engine/renderer";
import { buildSettlement as buildSettlementGeometry } from "./architecture";
import type { SfxId } from "../engine/audio";
import { emitFigure } from "./figures";
import { CHAMPIONS, houseOf, unitTitle, WEAPON_PROFILE } from "./houses";
import { COAST_X, MAP_HALF, SITES, type Site } from "./geography";
import { Kingdom } from "./kingdom";

export type Transform = {
  x: number; y: number; z: number;
  yaw: number; pitch: number;
  sx: number; sy: number; sz: number;
};

export type Appearance = {
  r: number; g: number; b: number;
  tile: number;
  repeat: number;
  /** optional independent vertical tiling for long surfaces */
  repeatY?: number;
  emissive: number;
  flash: number;
};

export type Body = { hx: number; hz: number; solid: boolean };

export type Character = {
  name: string;
  faction: "player" | "ally" | "enemy";
  /** owning house id; absent in scenes saved before houses existed */
  house?: string;
  hp: number;
  maxHp: number;
  speed: number;
  damage: number;
  cooldown: number;
  respawn: number;
  /** townsfolk: they wander, they never fight */
  civilian?: boolean;
};

export type Unit = {
  homeX: number;
  homeZ: number;
  wanderT: number;
  target: Entity;
};

export type Meta = { name: string; group: string };

const SETTLEMENTS = SITES;

type SettlementDef = Site;

// The company camps on the Kingsroad, in the open fields south of Kingsbridge
// where the city walls cannot crowd the camera at spawn.
const SPAWN: Vec3 = { x: 2, y: 0, z: 58 };

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
  /** the campaign that runs on top of the sandbox, one tick per in-game day */
  readonly kingdom = new Kingdom();
  /** set by the host so the sandbox can score its own combat */
  onSound?: (id: SfxId) => void;
  private spawnCooldown = 0;
  private random = rng(20261125);
  /**
   * Solid bodies never move, so collisions are answered from a coarse grid
   * instead of testing every wall in the basin for every walking figure.
   */
  private bodyGrid = new Map<string, Entity[]>();
  private bodyGridAge = 0;
  /** previous positions, so figures know whether they are walking */
  private lastPositions = new Map<Entity, { x: number; z: number }>();

  constructor(build = true) {
    if (build) this.build();
  }

  /** Recompute faction counts after loading a scene from disk. */
  refresh(): void {
    this.countLiving();
  }

  /**
   * Advance the clock by a whole day from outside the frame loop — the council
   * uses this so a campaign can be played without walking the valley.
   */
  advanceDay(): void {
    this.day += 1;
    this.hour = 8;
    this.kingdom.advanceDay();
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
      tile?: number; repeat?: number; repeatY?: number; emissive?: number;
      yaw?: number; pitch?: number; body?: Body; meta?: boolean;
    } = {},
  ): Entity {
    return this.world.create({
      Transform: { x, y, z, yaw: options.yaw ?? 0, pitch: options.pitch ?? 0, sx, sy, sz },
      Appearance: {
        r: color[0], g: color[1], b: color[2],
        tile: options.tile ?? -1,
        repeat: options.repeat ?? 1,
        repeatY: options.repeatY ?? options.repeat ?? 1,
        emissive: options.emissive ?? 0,
        flash: 0,
      },
      ...(options.body ? { Body: options.body } : {}),
      ...(options.meta === false ? {} : { Meta: { name, group } }),
    });
  }

  addCharacter(
    name: string,
    faction: Character["faction"],
    x: number,
    z: number,
    hp: number,
    houseId = "free_company",
    civilian = false,
  ): Entity {
    const house = houseOf(houseId);
    const profile = WEAPON_PROFILE[house.weapon];
    const base = faction === "player" ? 18 : faction === "enemy" ? 8 : 9;
    const walk = faction === "player" ? 5.6 : faction === "ally" ? 3.4 : 2.8;
    const id = this.world.create({
      Transform: { x, y: 0, z, yaw: 0, pitch: 0, sx: 1, sy: 1, sz: 1 },
      Appearance: {
        r: house.banner[0], g: house.banner[1], b: house.banner[2],
        tile: -1, repeat: 1, emissive: 0, flash: 0,
      },
      Character: {
        name, faction, house: house.id, hp, maxHp: hp,
        speed: civilian ? 1.6 : walk * profile.speed,
        damage: civilian ? 0 : Math.round(base * profile.damage),
        cooldown: 0, respawn: 0,
        ...(civilian ? { civilian: true } : {}),
      },
      Unit: { homeX: x, homeZ: z, wanderT: this.random() * 3, target: 0 },
      Body: { hx: 0.35, hz: 0.35, solid: false },
      Meta: {
        name,
        group: civilian
          ? "Populace"
          : faction === "player" ? "Player" : faction === "ally" ? "Warband" : "Enemies",
      },
      ...(faction === "player" ? { Player: {} } : {}),
    });
    return id;
  }

  private build(): void {
    // Ground, coast and roads
    this.add("Ground", "Terrain", 0, -1.1, 0, 380, 2, 380, [1, 1, 1], {
      tile: TILE.GRASS, repeat: 152, meta: false,
    });
    this.add("Shoreline", "Terrain", COAST_X - 3, -0.12, 0, 8, 0.2, 380, [1, 1, 1], {
      tile: TILE.SAND, repeat: 3, repeatY: 120, meta: false,
    });
    this.add("The Silver Sea", "Terrain", COAST_X + 22, 0.04, 0, 44, 0.1, 380, [1, 1, 1], {
      tile: TILE.WATER, repeat: 12, repeatY: 100, emissive: 0.08, meta: false,
    });
    this.add("Kingsroad", "Terrain", 0, -0.02, -40, 150, 0.06, 7, [1, 1, 1], {
      tile: TILE.DIRT, repeat: 75, repeatY: 3.5, meta: false,
    });
    this.add("South Road", "Terrain", 0, -0.02, 30, 9, 0.06, 92, [1, 1, 1], {
      tile: TILE.DIRT, repeat: 4.5, repeatY: 46, meta: false,
    });
    this.add("West Road", "Terrain", -84, -0.02, 66, 96, 0.06, 6, [1, 1, 1], {
      tile: TILE.DIRT, repeat: 48, repeatY: 3, yaw: 0.22, meta: false,
    });
    this.add("Coast Road", "Terrain", 96, -0.02, 84, 6, 0.06, 150, [1, 1, 1], {
      tile: TILE.DIRT, repeat: 3, repeatY: 75, meta: false,
    });

    for (const s of SETTLEMENTS) this.buildSettlement(s);
    this.buildForest();
    this.buildRocks();
    this.buildCamp();
    this.rebuildBodyGrid();

    // Player and warband
    this.player = this.addCharacter("You", "player", SPAWN.x, SPAWN.z, 100);
    for (let i = 0; i < 6; i++) {
      const angle = (i / 6) * Math.PI * 2;
      this.addCharacter(
        `Warband ${unitTitle("ally", i)}`, "ally",
        SPAWN.x + Math.cos(angle) * 3.4, SPAWN.z + Math.sin(angle) * 3.4, 60,
      );
    }

    // Hostile patrols, one or two from every rival power.
    const patrols: Array<[number, number, string, string]> = [
      [-8, -20, "Steppe Riders", "eastern_tribes"],
      [30, 10, "Redstone Guard", "eastern_tribes"],
      [-40, 24, "Clan Raiders", "western_clans"],
      [-96, 46, "Glen Prowlers", "western_clans"],
      [70, 40, "Sahr Lancers", "southern_sultanate"],
      [96, 118, "Sunmarch Riders", "southern_sultanate"],
      [-84, -34, "Frost Wolf Pack", "north_kingdom"],
      [18, -66, "Ford Halberdiers", "river_kingdom"],
    ];
    for (const [px, pz, squad, houseId] of patrols) {
      for (let i = 0; i < 4; i++) {
        const id = this.addCharacter(
          `${squad} ${unitTitle("enemy", i)}`, "enemy",
          px + (this.random() - 0.5) * 4, pz + (this.random() - 0.5) * 4, 45, houseId,
        );
        this.world.require<Unit>(id, "Unit").homeX = px;
        this.world.require<Unit>(id, "Unit").homeZ = pz;
      }
    }

    this.countLiving();
  }

  private buildSettlement(s: SettlementDef): void {
    const house = houseOf(s.owner);

    buildSettlementGeometry(
      {
        block: (request) => {
          this.add(
            request.name, request.group,
            request.x, request.y, request.z,
            request.sx, request.sy, request.sz,
            request.color,
            {
              tile: request.tile,
              repeat: request.repeat,
              repeatY: request.repeatY,
              emissive: request.emissive,
              yaw: request.yaw,
              pitch: request.pitch,
              body: request.solid
                ? { hx: Math.max(0.5, request.sx / 2), hz: Math.max(0.5, request.sz / 2), solid: true }
                : undefined,
            },
          );
        },
        random: () => this.random(),
      },
      s,
      house,
    );

    // Garrison: soldiers of the owning house carrying its signature weapon.
    const guards = s.kind === "castle" ? 5 : s.kind === "city" ? 4 : s.kind === "town" ? 2 : 1;
    for (let i = 0; i < guards; i++) {
      const a = (i / guards) * Math.PI * 2 + 0.35;
      const radius = s.kind === "castle" ? 11.5 : s.kind === "city" ? 10.5 : 6.5;
      this.addCharacter(
        `${s.name} ${unitTitle("ally", i)}`, "ally",
        s.x + Math.sin(a) * radius, s.z + Math.cos(a) * radius,
        s.kind === "castle" ? 85 : 65, s.owner,
      );
    }

    // Every castle and city is held by a named commander.
    if (s.kind === "castle" || s.kind === "city") {
      const champion = `${CHAMPIONS[s.owner] ?? "Warden"} of ${s.name}`;
      this.addCharacter(champion, "ally", s.x + 2.2, s.z + 2.6, 150, s.owner);
    }

    // Civilians: the reason a town looks inhabited rather than garrisoned.
    const residents = Math.min(6, Math.max(2, Math.round(s.population / 260)));
    for (let i = 0; i < residents; i++) {
      const a = this.random() * Math.PI * 2;
      const radius = s.kind === "village" ? 3.4 : 5.6;
      this.addCharacter(
        `${s.name} Resident ${i + 1}`, "ally",
        s.x + Math.sin(a) * radius, s.z + Math.cos(a) * radius,
        40, s.owner, true,
      );
    }
  }

  private buildForest(): void {
    const group = "Wilds";
    for (let i = 0; i < 560; i++) {
      const x = (this.random() - 0.5) * 336;
      const z = (this.random() - 0.5) * 336;
      if (x > COAST_X - 14) continue;
      if (Math.hypot(x - SPAWN.x, z - SPAWN.z) < 15) continue;
      if (SETTLEMENTS.some((s) => Math.hypot(x - s.x, z - s.z) < 17)) continue;
      const h = 3 + this.random() * 3.4;
      const yaw = this.random() * Math.PI;
      const spread = 3.4 + this.random() * 1.7;
      this.add("Pine Trunk", group, x, h * 0.5 + 0.6, z, 0.55, h, 0.55, [0.66, 0.54, 0.4], {
        tile: TILE.OAK, repeat: 1, yaw, meta: false,
      });
      // three stacked tiers give a fir silhouette instead of a flat slab
      const tiers = [
        { y: h + 1.1, s: spread, th: 2.5, c: [0.46, 0.64, 0.44] as [number, number, number] },
        { y: h + 2.4, s: spread * 0.78, th: 2.1, c: [0.55, 0.76, 0.5] as [number, number, number] },
        { y: h + 3.6, s: spread * 0.54, th: 1.8, c: [0.66, 0.88, 0.6] as [number, number, number] },
      ];
      tiers.forEach((tier, tierIndex) => {
        this.add(`Pine Canopy ${tierIndex + 1}`, group, x, tier.y, z, tier.s, tier.th, tier.s, tier.c, {
          tile: TILE.GRASS, repeat: 3, yaw, meta: false,
        });
      });
    }
  }

  private buildRocks(): void {
    for (let i = 0; i < 150; i++) {
      const x = (this.random() - 0.5) * 330;
      const z = (this.random() - 0.5) * 330;
      if (x > COAST_X - 4) continue;
      const s = 1 + this.random() * 2.4;
      const yaw = this.random() * Math.PI;
      this.add("Boulder", "Wilds", x, s * 0.4, z, s, s * 0.82, s * 1.1, [0.88, 0.9, 0.94], {
        tile: TILE.RUBBLE, repeat: 1, yaw, meta: false,
      });
      this.add("Boulder Cap", "Wilds", x + 0.2, s * 0.78, z - 0.18, s * 0.62, s * 0.42, s * 0.7,
        [0.98, 1.0, 1.02], { tile: TILE.RUBBLE, repeat: 1, yaw: yaw + 0.7, pitch: 0.2, meta: false });
    }
  }

  private buildCamp(): void {
    const house = houseOf("free_company");
    const cx = SPAWN.x + 5;
    const cz = SPAWN.z - 4;

    for (let i = 0; i < 9; i++) {
      const a = (i / 9) * Math.PI * 2;
      this.add("Campfire Stones", "Camp", cx + Math.sin(a) * 0.9, 0.16, cz + Math.cos(a) * 0.9,
        0.46, 0.36, 0.46, [0.88, 0.9, 0.94], { tile: TILE.RUBBLE, yaw: a });
    }
    this.add("Campfire Logs", "Camp", cx, 0.32, cz, 1.5, 0.28, 1.5, [0.5, 0.34, 0.2], {
      tile: TILE.OAK, yaw: 0.6, pitch: 0.12,
    });
    this.world.create({
      Transform: { x: cx, y: 0.82, z: cz, yaw: 0, pitch: 0, sx: 0.72, sy: 0.9, sz: 0.72 },
      Appearance: { r: 1, g: 0.6, b: 0.2, tile: -1, repeat: 1, emissive: 0.95, flash: 1 },
      Meta: { name: "Campfire Flame", group: "Camp" },
    });
    this.add("Campfire Embers", "Camp", cx, 0.26, cz, 1.5, 0.09, 1.5, [0.95, 0.34, 0.12], {
      emissive: 0.5,
    });

    const tent = (
      name: string, tx: number, tz: number, yaw: number,
      w: number, h: number, d: number,
    ) => {
      for (const side of [-1, 1]) {
        this.add(name, "Camp", tx, h * 0.5, tz + side * d * 0.26, w, h, d * 0.62,
          [0.92, 0.88, 0.78], {
            tile: TILE.CLOTH, repeat: 3, yaw, pitch: side * 0.52,
            body: side === -1 ? { hx: w / 2, hz: d / 2, solid: true } : undefined,
          });
      }
      for (const side of [-1, 1]) {
        this.add(`${name} Seam`, "Camp", tx, h * 0.55, tz + side * d * 0.52, w * 0.98, h * 0.7, 0.1,
          house.banner, { tile: house.heraldry, yaw, emissive: 0.04 });
      }
      this.add(`${name} Ridge`, "Camp", tx, h * 0.98, tz, 0.12, 0.12, d, [0.34, 0.24, 0.16], {
        tile: TILE.OAK, yaw,
      });
      this.add(`${name} Pennant`, "Camp",
        tx + Math.cos(yaw) * w * 0.5, h * 1.15, tz - Math.sin(yaw) * w * 0.5,
        0.05, 0.8, 0.9, house.banner, { tile: house.heraldry, emissive: 0.05, yaw });
    };

    tent("Pavilion", cx + 4.4, cz - 3.0, 0.3, 4.0, 2.8, 3.6);
    tent("Tent", cx - 4.0, cz - 2.2, -0.5, 2.8, 2.1, 2.8);
    tent("Tent", cx - 1.2, cz + 4.8, 0.9, 2.6, 1.9, 2.4);

    this.add("Warband Standard", "Camp", cx + 1.6, 3.6, cz - 5.6, 0.14, 7.2, 0.14,
      [0.3, 0.22, 0.15], { tile: TILE.OAK });
    this.add("Warband Banner", "Camp", cx + 1.72, 5.0, cz - 4.7, 0.06, 2.4, 2.2,
      house.banner, { tile: house.heraldry, emissive: 0.06 });

    this.add("Supply Cart Bed", "Camp", cx + 7.6, 0.95, cz + 2.4, 3.0, 0.24, 1.7,
      [0.46, 0.33, 0.21], { tile: TILE.WOOD, yaw: -0.4 });
    for (const dz of [-0.85, 0.85]) {
      this.add("Cart Wheel", "Camp", cx + 7.6, 0.6, cz + 2.4 + dz, 0.9, 0.9, 0.16,
        [0.32, 0.24, 0.16], { tile: TILE.OAK, yaw: -0.4 });
    }
    this.add("Cart Crate", "Camp", cx + 7.4, 1.32, cz + 2.5, 0.8, 0.8, 0.8, [0.52, 0.38, 0.24], {
      tile: TILE.WOOD,
    });
    this.add("Spare Spears", "Camp", cx + 6.2, 1.1, cz - 1.4, 0.8, 2.2, 0.8, [0.6, 0.45, 0.3], {
      tile: TILE.OAK, pitch: 0.22,
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
      // The campaign advances with the calendar you can watch in the sky.
      this.kingdom.advanceDay();
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
      t.x = clamp(t.x, -MAP_HALF, COAST_X - 2);
      t.z = clamp(t.z, -MAP_HALF, MAP_HALF);
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
      this.onSound?.("sword-draw");
      return;
    }
    const target = this.world.require<Character>(best, "Character");
    target.hp -= c.damage;
    this.world.require<Appearance>(best, "Appearance").flash = 1;
    if (target.hp <= 0) {
      this.kill(best);
      this.log = `${target.name} falls. +12 gold.`;
      this.gold += 12;
      this.onSound?.("armour");
    } else {
      this.log = `You strike ${target.name} for ${c.damage}.`;
      this.onSound?.("sword-clash");
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
      if (!c || !t || !unit || c.hp <= 0 || c.civilian) continue;
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
          if (victim === this.player) this.onSound?.("armour");
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
      if (oc.hp <= 0 || oc.civilian) continue;
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

  private rebuildBodyGrid(): void {
    this.bodyGrid.clear();
    for (const id of this.world.query("Body", "Transform")) {
      const body = this.world.get<Body>(id, "Body");
      const t = this.world.get<Transform>(id, "Transform");
      if (!body || !t || !body.solid) continue;
      const cx = Math.floor(t.x / 10);
      const cz = Math.floor(t.z / 10);
      for (let ox = -1; ox <= 1; ox++) {
        for (let oz = -1; oz <= 1; oz++) {
          const key = `${cx + ox},${cz + oz}`;
          const bucket = this.bodyGrid.get(key);
          if (bucket) bucket.push(id);
          else this.bodyGrid.set(key, [id]);
        }
      }
    }
    this.bodyGridAge = 0;
  }

  private resolveCollisions(t: Transform, radius: number): void {
    // Solid geometry is static; refreshing the grid about once a second keeps
    // it correct even after the editor has moved things around.
    this.bodyGridAge += 1;
    if (this.bodyGridAge > 60 || this.bodyGrid.size === 0) this.rebuildBodyGrid();

    const bucket = this.bodyGrid.get(`${Math.floor(t.x / 10)},${Math.floor(t.z / 10)}`);
    if (!bucket) return;
    for (const id of bucket) {
      const body = this.world.get<Body>(id, "Body");
      if (!body || !body.solid) continue;
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
      if (!c || c.hp <= 0 || c.civilian) continue;
      // The HUD counts the player's own war band, not every garrison in the basin.
      const ownCompany = c.house === undefined || c.house === "free_company";
      if (c.faction === "ally" && ownCompany) allies++;
      if (c.faction === "enemy") enemies++;
    }
    this.aliveAllies = allies;
    this.aliveEnemies = enemies;
  }

  // ---------------------------------------------------------------- rendering

  buildInstances(out: Instance[], selected: Entity | null, time: number, view?: Vec3): void {
    // The basin is bigger than the fog can show, so anything behind the far
    // plane is dropped before it reaches the instancing buffer.
    const cull = 158 * 158;
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
      if (view && id !== selected) {
        const dx = t.x - view.x;
        const dz = t.z - view.z;
        if (dx * dx + dz * dz > cull) continue;
      }
      const a = this.world.require<Appearance>(id, "Appearance");
      const c = this.world.get<Character>(id, "Character");

      if (c) {
        if (c.hp <= 0) continue;
        // Walking is inferred from frame-to-frame movement so the legs swing
        // only when the unit is actually going somewhere.
        const previous = this.lastPositions.get(id);
        const moved = previous ? Math.hypot(t.x - previous.x, t.z - previous.z) : 0;
        this.lastPositions.set(id, { x: t.x, z: t.z });
        const window = c.faction === "player" ? 0.42 : 1.15;
        emitFigure(out, {
          id,
          x: t.x, z: t.z, yaw: t.yaw,
          house: houseOf(c.house ?? "free_company"),
          faction: c.faction,
          hp: c.hp, maxHp: c.maxHp,
          swing: c.cooldown > 0.01 ? 1 - Math.min(1, c.cooldown / window) : 0,
          moving: moved > 0.012,
          time,
          selected: id === selected,
          flash: a.flash,
          civilian: c.civilian === true,
        });
        continue;
      }

      out.push({
        x: t.x, y: t.y, z: t.z,
        sx: t.sx, sy: t.sy, sz: t.sz,
        yaw: t.yaw, pitch: t.pitch,
        color: [a.r, a.g, a.b],
        tile: a.tile,
        repeat: a.repeat,
        repeatY: a.repeatY,
        emissive: Math.min(1, a.emissive + a.flash * 0.8),
        selected: id === selected,
      });
    }
  }

  /**
   * Shorten the third-person boom when it would pass through a solid body, so
   * the camera never ends up inside a wall. Marches out from the target and
   * tests the body footprints above the ground.
   */
  cameraDistance(target: Vec3, yaw: number, pitch: number, distance: number): number {
    const steps = 8;
    const bodies = this.world.query("Body", "Transform");
    for (let i = 1; i <= steps; i++) {
      const d = (distance * i) / steps;
      const x = target.x + Math.sin(yaw) * Math.cos(pitch) * d;
      const z = target.z + Math.cos(yaw) * Math.cos(pitch) * d;
      const y = target.y + 1.5 + Math.sin(pitch) * d;
      for (const id of bodies) {
        const body = this.world.get<Body>(id, "Body");
        if (!body || !body.solid) continue;
        const bt = this.world.get<Transform>(id, "Transform");
        if (!bt) continue;
        if (y > bt.y + bt.sy * 0.5 + 0.3) continue;
        if (Math.abs(x - bt.x) < body.hx + 0.35 && Math.abs(z - bt.z) < body.hz + 0.35) {
          return Math.max(1.6, (distance * (i - 1)) / steps);
        }
      }
    }
    return distance;
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

  update(
    input: Input,
    target: Vec3,
    clampDistance?: (distance: number) => number,
  ): Camera {
    this.yaw -= input.lookX * 0.0042;
    this.pitch = clamp(this.pitch + input.lookY * 0.0032, -0.35, 1.15);
    if (input.wheel) {
      this.distance = clamp(this.distance + input.wheel * 0.012, 3.5, 20);
    }
    if (input.wasPressed("KeyF")) {
      this.firstPerson = !this.firstPerson;
      this.distance = this.firstPerson ? 0.1 : 9;
    }

    const reach = clampDistance && !this.firstPerson
      ? clampDistance(this.distance)
      : this.distance;
    const eye: Vec3 = this.firstPerson
      ? { x: target.x, y: target.y + 2.05, z: target.z }
      : {
          x: target.x + Math.sin(this.yaw) * Math.cos(this.pitch) * reach,
          y: target.y + 1.5 + Math.sin(this.pitch) * reach,
          z: target.z + Math.cos(this.yaw) * Math.cos(this.pitch) * reach,
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
