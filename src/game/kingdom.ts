// The campaign layer.
//
// The sandbox is one valley; this is the war for the whole basin. Every holding
// on the council map produces food, coin and material, every power keeps an
// army in the field, and the AI powers besiege each other while you decide where
// to march. It ticks once per in-game day and is entirely data-driven, so the
// map, the ledgers and the chronicle all stay in step.

import { SITES, type ResourceKind, type Site, type SiteKind } from "./geography";
import { HOUSES, type HouseId } from "./houses";

export type PowerId = HouseId;

export type TroopId = "levy" | "spear" | "archer" | "knight" | "siege" | "galley";

export type Troop = {
  id: TroopId;
  name: string;
  power: number;
  upkeep: number;
  cost: { gold: number; food: number; iron: number };
  blurb: string;
};

export const TROOPS: Record<TroopId, Troop> = {
  levy: {
    id: "levy", name: "Levy Spearmen", power: 1, upkeep: 1,
    cost: { gold: 40, food: 60, iron: 4 },
    blurb: "Farmhands with a spear and a shield. Cheap, brave, expendable.",
  },
  spear: {
    id: "spear", name: "Serjeants", power: 3, upkeep: 3,
    cost: { gold: 120, food: 90, iron: 14 },
    blurb: "Drilled spearmen in mail. The spine of any battle line.",
  },
  archer: {
    id: "archer", name: "Longbowmen", power: 3, upkeep: 3,
    cost: { gold: 140, food: 70, iron: 9 },
    blurb: "Wet bows, dry powder, long range. Murder on walls.",
  },
  knight: {
    id: "knight", name: "Knights", power: 8, upkeep: 8,
    cost: { gold: 420, food: 160, iron: 40 },
    blurb: "Armoured horse and a household blade. Break the line with them.",
  },
  siege: {
    id: "siege", name: "Siege Train", power: 12, upkeep: 9,
    cost: { gold: 520, food: 120, iron: 90 },
    blurb: "Trebuchets, mangonels and the oxen to drag them. Walls fall.",
  },
  galley: {
    id: "galley", name: "War Galleys", power: 7, upkeep: 6,
    cost: { gold: 360, food: 110, iron: 55 },
    blurb: "Oars, a ram and forty marines. Only ports can build them.",
  },
};

export const TROOP_ORDER: TroopId[] = ["levy", "spear", "archer", "knight", "siege", "galley"];

export type Holding = {
  id: string;
  name: string;
  kind: SiteKind;
  owner: PowerId;
  x: number;
  z: number;
  population: number;
  port: boolean;
  resource: ResourceKind;
  garrison: number;
  walls: number;
  market: number;
  farms: number;
  unrest: number;
  siege: { by: PowerId; progress: number } | null;
};

export type Power = {
  id: PowerId;
  name: string;
  gold: number;
  food: number;
  timber: number;
  stone: number;
  iron: number;
  renown: number;
  troops: Record<TroopId, number>;
  /** -100 .. 100, the power's view of every other power */
  opinion: Record<PowerId, number>;
  atWar: PowerId[];
  /** true for houses the campaign AI runs */
  ai: boolean;
};

export type BuildKind = "walls" | "market" | "farms";

export const BUILDINGS: Record<BuildKind, { name: string; cost: { gold: number; timber: number; stone: number }; blurb: string }> = {
  walls: {
    name: "Curtain Wall",
    cost: { gold: 260, timber: 60, stone: 140 },
    blurb: "Raises the wall tier. Every tier slows a besieger by a quarter.",
  },
  market: {
    name: "Market Hall",
    cost: { gold: 200, timber: 90, stone: 30 },
    blurb: "More coin from trade and a brake on unrest.",
  },
  farms: {
    name: "Common Fields",
    cost: { gold: 160, timber: 40, stone: 10 },
    blurb: "More grain, and the granary that keeps an army fed.",
  },
};

export type ChronicleEntry = {
  day: number;
  kind: "economy" | "war" | "diplomacy" | "build" | "recruit" | "court";
  text: string;
};

const WAR_NAMES = ["the War of the Long Ford", "the Salt War", "the Glen Rising", "the Winter March"];

function mulberry(seed: number): () => number {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

function blankTroops(): Record<TroopId, number> {
  return { levy: 0, spear: 0, archer: 0, knight: 0, siege: 0, galley: 0 };
}

export const SEASONS = ["Spring", "Summer", "Harvest", "Winter"] as const;

export function seasonOf(day: number): string {
  return SEASONS[Math.floor(((day - 1) % 96) / 24)];
}

export class Kingdom {
  readonly holdings: Holding[];
  readonly powers: Record<PowerId, Power>;
  readonly player: PowerId = "free_company";
  readonly chronicle: ChronicleEntry[] = [];
  day = 1;
  taxRate = 0.2;
  /** the last thing the council was told, for the UI's status line */
  notice = "The council is seated. The basin waits.";
  private random = mulberry(771131);
  private warCount = 0;

  constructor() {
    this.holdings = SITES.map((site) => this.makeHolding(site));
    this.powers = {} as Record<PowerId, Power>;
    for (const id of Object.keys(HOUSES) as PowerId[]) {
      this.powers[id] = this.makePower(id);
    }
    this.applyStartGarrisons();
    this.record("court", "The Free Company takes the field. Two holdings, six hundred spears and a reputation to build.");
  }

  private makeHolding(site: Site): Holding {
    return {
      id: site.id,
      name: site.name,
      kind: site.kind,
      owner: site.owner,
      x: site.x,
      z: site.z,
      population: site.population,
      port: site.port,
      resource: site.resource,
      garrison: site.garrison,
      walls: site.kind === "castle" ? 3 : site.kind === "city" ? 2 : site.kind === "town" ? 1 : 0,
      market: site.kind === "city" ? 2 : site.kind === "town" ? 1 : 0,
      farms: site.kind === "village" ? 2 : 1,
      unrest: 0,
      siege: null,
    };
  }

  private makePower(id: PowerId): Power {
    const owned = this.holdings.filter((holding) => holding.owner === id);
    const population = owned.reduce((sum, holding) => sum + holding.population, 0);
    const opinion = {} as Record<PowerId, number>;
    for (const other of Object.keys(HOUSES) as PowerId[]) opinion[other] = other === id ? 100 : 6;
    return {
      id,
      name: HOUSES[id].name,
      gold: Math.round(population * (id === this.player ? 0.34 : 0.26)) + 180,
      food: Math.round(population * 0.5) + 240,
      timber: 160 + owned.length * 40,
      stone: 120 + owned.length * 36,
      iron: 70 + owned.length * 22,
      renown: id === this.player ? 12 : 40 + owned.length * 9,
      troops: blankTroops(),
      opinion,
      atWar: [],
      ai: id !== this.player,
    };
  }

  private applyStartGarrisons(): void {
    // Garrisons stay at home on the walls; only this fraction is the mobile
    // field army that draws pay and eats from the granary.
    for (const holding of this.holdings) {
      const power = this.powers[holding.owner];
      const levy = Math.round(holding.garrison * 0.13);
      power.troops.levy += levy;
      power.troops.spear += Math.round(holding.garrison * 0.08);
      power.troops.archer += Math.round(holding.garrison * 0.04);
      power.troops.knight += Math.round(holding.garrison * 0.013);
      if (holding.port) power.troops.galley += 2;
      if (holding.kind === "castle" || holding.kind === "city") power.troops.siege += 1;
    }
  }

  // ------------------------------------------------------------------ reading

  get playerPower(): Power {
    return this.powers[this.player];
  }

  get playerHoldings(): Holding[] {
    return this.holdings.filter((holding) => holding.owner === this.player);
  }

  holding(id: string): Holding | undefined {
    return this.holdings.find((holding) => holding.id === id);
  }

  armyOf(id: PowerId): number {
    const troops = this.powers[id].troops;
    return TROOP_ORDER.reduce((sum, key) => sum + troops[key] * TROOPS[key].power, 0);
  }

  garrisonOf(holding: Holding): number {
    return holding.garrison;
  }

  upkeepOf(id: PowerId): number {
    const troops = this.powers[id].troops;
    return TROOP_ORDER.reduce((sum, key) => sum + troops[key] * TROOPS[key].upkeep, 0);
  }

  incomeOf(id: PowerId): { gold: number; food: number; timber: number; stone: number; iron: number } {
    const total = { gold: 0, food: 0, timber: 0, stone: 0, iron: 0 };
    const tax = id === this.player ? this.taxRate : 0.22;
    for (const holding of this.holdings) {
      if (holding.owner !== id) continue;
      const order = 1 - holding.unrest / 240;
      total.gold += holding.population * tax * 1.5 * (1 + holding.market * 0.32) * order;
      total.food += holding.population * 0.012 * (1 + holding.farms * 0.45) * order;
      total.timber += holding.resource === "timber" ? 9 + holding.population * 0.004 : 2;
      total.stone += holding.resource === "stone" ? 9 + holding.population * 0.004 : 2;
      total.iron += holding.resource === "iron" ? 7 + holding.population * 0.003 : 1;
      if (holding.resource === "fish" || holding.resource === "salt") total.food += 6;
      if (holding.resource === "wine") total.gold += 12;
      if (holding.resource === "cloth") total.gold += 9;
    }
    return {
      gold: Math.round(total.gold),
      food: Math.round(total.food),
      timber: Math.round(total.timber),
      stone: Math.round(total.stone),
      iron: Math.round(total.iron),
    };
  }

  netGold(id: PowerId): number {
    return this.incomeOf(id).gold - this.upkeepOf(id);
  }

  relation(a: PowerId, b: PowerId): number {
    if (a === b) return 100;
    return this.powers[a].opinion[b] ?? 0;
  }

  isAtWar(a: PowerId, b: PowerId): boolean {
    return this.powers[a].atWar.includes(b);
  }

  /** A single number for the standings table. */
  strengthOf(id: PowerId): number {
    const holdings = this.holdings.filter((holding) => holding.owner === id).length;
    return Math.round(this.armyOf(id) + holdings * 40 + this.powers[id].renown * 0.8);
  }

  get standings(): Array<{ id: PowerId; name: string; strength: number; holdings: number; army: number; renown: number }> {
    return (Object.keys(HOUSES) as PowerId[])
      .map((id) => ({
        id,
        name: HOUSES[id].name,
        strength: this.strengthOf(id),
        holdings: this.holdings.filter((holding) => holding.owner === id).length,
        army: this.armyOf(id),
        renown: this.powers[id].renown,
      }))
      .sort((a, b) => b.strength - a.strength);
  }

  // ------------------------------------------------------------------ actions

  private record(kind: ChronicleEntry["kind"], text: string): void {
    this.chronicle.unshift({ day: this.day, kind, text });
    if (this.chronicle.length > 60) this.chronicle.length = 60;
  }

  private ok(text: string): { ok: true; message: string } {
    this.notice = text;
    return { ok: true, message: text };
  }

  private fail(text: string): { ok: false; message: string } {
    this.notice = text;
    return { ok: false, message: text };
  }

  setTaxRate(rate: number): void {
    this.taxRate = Math.max(0.05, Math.min(0.6, rate));
    this.notice = `Taxes set to ${Math.round(this.taxRate * 100)}%.`;
  }

  recruit(troop: TroopId, count: number): { ok: boolean; message: string } {
    const power = this.playerPower;
    const unit = TROOPS[troop];
    const n = Math.max(1, Math.floor(count));
    if (troop === "galley" && !this.playerHoldings.some((holding) => holding.port)) {
      return this.fail("No harbour. Take a port before laying down galleys.");
    }
    const gold = unit.cost.gold * n;
    const food = unit.cost.food * n;
    const iron = unit.cost.iron * n;
    if (power.gold < gold) return this.fail(`The treasury is short: ${gold} gold needed.`);
    if (power.food < food) return this.fail(`The granaries are short: ${food} food needed.`);
    if (power.iron < iron) return this.fail(`The forges are short: ${iron} iron needed.`);
    power.gold -= gold;
    power.food -= food;
    power.iron -= iron;
    power.troops[troop] += n;
    const text = `${n} ${unit.name.toLowerCase()} join the company.`;
    this.record("recruit", text);
    return this.ok(text);
  }

  build(siteId: string, kind: BuildKind): { ok: boolean; message: string } {
    const holding = this.holding(siteId);
    const power = this.playerPower;
    const plan = BUILDINGS[kind];
    if (!holding) return this.fail("No such holding.");
    if (holding.owner !== this.player) return this.fail("That holding is not yours to build in.");
    if (power.gold < plan.cost.gold) return this.fail(`${plan.name} needs ${plan.cost.gold} gold.`);
    if (power.timber < plan.cost.timber) return this.fail(`${plan.name} needs ${plan.cost.timber} timber.`);
    if (power.stone < plan.cost.stone) return this.fail(`${plan.name} needs ${plan.cost.stone} stone.`);
    power.gold -= plan.cost.gold;
    power.timber -= plan.cost.timber;
    power.stone -= plan.cost.stone;
    if (kind === "walls") holding.walls += 1;
    if (kind === "market") holding.market += 1;
    if (kind === "farms") holding.farms += 1;
    holding.unrest = Math.max(0, holding.unrest - 6);
    const text = `${plan.name} raised at ${holding.name}.`;
    this.record("build", text);
    return this.ok(text);
  }

  /** March the field army on a holding. Adjacent holdings only. */
  march(siteId: string): { ok: boolean; message: string } {
    const target = this.holding(siteId);
    if (!target) return this.fail("No such holding.");
    if (target.owner === this.player) return this.fail("That is already your holding.");
    if (target.siege) return this.fail(`${target.name} is already under siege.`);
    if (this.armyOf(this.player) < 40) {
      return this.fail("The field army is too small to open a siege. Recruit first.");
    }
    const nearest = this.playerHoldings.reduce(
      (best, holding) => Math.min(best, Math.hypot(holding.x - target.x, holding.z - target.z)),
      Infinity,
    );
    if (nearest > 130) return this.fail(`${target.name} is beyond the company's reach.`);
    if (!this.isAtWar(this.player, target.owner)) this.declareWar(target.owner, false);
    target.siege = { by: this.player, progress: 0 };
    const text = `The company marches on ${target.name}.`;
    this.record("war", text);
    return this.ok(text);
  }

  /** Buy opinion; higher tiers cost more and can end a war. */
  diplomacy(other: PowerId, kind: "gift" | "peace" | "alliance" | "war"): { ok: boolean; message: string } {
    const power = this.playerPower;
    if (other === this.player) return this.fail("You cannot treat with yourself.");
    const target = this.powers[other];
    if (kind === "gift") {
      const cost = 120;
      if (power.gold < cost) return this.fail("A gift of 120 gold is beyond the treasury.");
      power.gold -= cost;
      target.opinion[this.player] = Math.min(100, target.opinion[this.player] + 14);
      power.opinion[other] = Math.min(100, power.opinion[other] + 8);
      const text = `A gift of 120 gold to ${target.name}. They are warmer toward us.`;
      this.record("diplomacy", text);
      return this.ok(text);
    }
    if (kind === "peace") {
      if (!this.isAtWar(this.player, other)) return this.fail(`We are not at war with ${target.name}.`);
      target.opinion[this.player] = Math.max(-20, target.opinion[this.player] + 20);
      if (target.opinion[this.player] < -30) return this.fail(`${target.name} refuses to treat while the war runs hot.`);
      this.endWar(other);
      const text = `Peace with ${target.name}. The heralds are still shouting.`;
      this.record("diplomacy", text);
      return this.ok(text);
    }
    if (kind === "alliance") {
      if (this.isAtWar(this.player, other)) return this.fail("End the war before proposing an alliance.");
      if (target.opinion[this.player] < 45) return this.fail(`${target.name} will not swear to us yet.`);
      target.opinion[this.player] = Math.min(100, target.opinion[this.player] + 10);
      const text = `Alliance sworn with ${target.name}.`;
      this.record("diplomacy", text);
      return this.ok(text);
    }
    if (this.isAtWar(this.player, other)) return this.fail(`Already at war with ${target.name}.`);
    this.declareWar(other, true);
    return this.ok(`War declared on ${target.name}.`);
  }

  private declareWar(other: PowerId, record: boolean): void {
    const power = this.playerPower;
    if (!power.atWar.includes(other)) power.atWar.push(other);
    if (!this.powers[other].atWar.includes(this.player)) this.powers[other].atWar.push(this.player);
    this.powers[other].opinion[this.player] = Math.min(this.powers[other].opinion[this.player], -40);
    power.opinion[other] = Math.min(power.opinion[other], -40);
    if (record) {
      const name = WAR_NAMES[this.warCount % WAR_NAMES.length];
      this.warCount += 1;
      this.record("war", `War declared on ${this.powers[other].name}. The chroniclers call it ${name}.`);
    }
  }

  private endWar(other: PowerId): void {
    const power = this.playerPower;
    power.atWar = power.atWar.filter((id) => id !== other);
    this.powers[other].atWar = this.powers[other].atWar.filter((id) => id !== this.player);
  }

  /** Lift a siege the company is running. */
  withdraw(siteId: string): { ok: boolean; message: string } {
    const holding = this.holding(siteId);
    if (!holding || !holding.siege || holding.siege.by !== this.player) {
      return this.fail("No company siege there to lift.");
    }
    holding.siege = null;
    const text = `The siege of ${holding.name} is lifted.`;
    this.record("war", text);
    return this.ok(text);
  }

  // --------------------------------------------------------------------- tick

  advanceDay(): void {
    this.day += 1;
    this.notice = `Day ${this.day} of ${seasonOf(this.day).toLowerCase()}. The ledgers close and the roads fill.`;
    for (const id of Object.keys(HOUSES) as PowerId[]) this.tickPower(id);
    this.tickSieges();
    this.tickAi();
    for (const holding of this.holdings) {
      if (holding.owner === this.player && holding.unrest > 0) {
        holding.unrest = Math.max(0, holding.unrest - 0.6);
      }
    }
  }

  private tickPower(id: PowerId): void {
    const power = this.powers[id];
    const income = this.incomeOf(id);
    power.gold += income.gold - this.upkeepOf(id);
    power.food += income.food - Math.round(this.armyOf(id) * 0.06);
    power.timber += income.timber;
    power.stone += income.stone;
    power.iron += income.iron;
    for (const holding of this.holdings) {
      if (holding.owner !== id) continue;
      const tax = id === this.player ? this.taxRate : 0.22;
      holding.unrest = Math.max(
        0,
        Math.min(100, holding.unrest + (tax > 0.3 ? 1.6 : -0.4) - holding.market * 0.25),
      );
      if (holding.siege) continue;
      holding.population = Math.max(
        40,
        Math.round(holding.population * (1 + 0.0007 * (holding.farms + 1) - holding.unrest * 0.00002)),
      );
    }
    if (power.gold < 0) {
      power.gold = 0;
      // An unpaid army deserts before it mutinies.
      for (const key of TROOP_ORDER) {
        if (power.troops[key] > 0) {
          power.troops[key] = Math.max(0, power.troops[key] - Math.ceil(power.troops[key] * 0.06));
        }
      }
    }
    if (power.renown < 0) power.renown = 0;
  }

  private tickSieges(): void {
    for (const holding of this.holdings) {
      const siege = holding.siege;
      if (!siege) continue;
      const attacker = this.powers[siege.by];
      const defender = this.powers[holding.owner];
      const field = this.armyOf(siege.by);
      const wall = holding.garrison + holding.walls * 45;
      const siegeBonus = 1 + attacker.troops.siege * 0.18;
      // No storm is resolved in a single night: a siege grinds for at least
      // three days and never stalls completely.
      const rate = ((field * siegeBonus) / Math.max(1, wall)) * 6;
      siege.progress += Math.min(34, Math.max(0.5, rate));
      if (siege.progress >= 100) {
        const previous = holding.owner;
        holding.owner = siege.by;
        holding.siege = null;
        holding.garrison = Math.max(40, Math.round(holding.garrison * 0.35));
        holding.unrest = 30;
        defender.renown = Math.max(0, defender.renown - 8);
        attacker.renown += 10;
        this.record("war", `${holding.name} falls to ${attacker.name}. ${defender.name} loses the holding.`);
        if (previous === this.player) this.record("court", `We have lost ${holding.name}. The company must answer.`);
      } else {
        holding.garrison = Math.max(20, holding.garrison - Math.round((field / 60) + 1));
      }
    }
  }

  private tickAi(): void {
    const ids = (Object.keys(HOUSES) as PowerId[]).filter((id) => id !== this.player);
    if (this.random() < 0.22) {
      const a = ids[Math.floor(this.random() * ids.length)];
      const b = ids[Math.floor(this.random() * ids.length)];
      if (a !== b) {
        if (this.powers[a].atWar.includes(b)) {
          if (this.random() < 0.5) {
            this.powers[a].atWar = this.powers[a].atWar.filter((id) => id !== b);
            this.powers[b].atWar = this.powers[b].atWar.filter((id) => id !== a);
            this.powers[a].opinion[b] += 18;
            this.powers[b].opinion[a] += 18;
            this.record("diplomacy", `${this.powers[a].name} and ${this.powers[b].name} make peace.`);
          }
        } else if (this.powers[a].opinion[b] < -15 && this.random() < 0.5) {
          this.powers[a].atWar.push(b);
          this.powers[b].atWar.push(a);
          this.powers[a].opinion[b] -= 25;
          this.powers[b].opinion[a] -= 25;
          this.record("war", `${this.powers[a].name} declares war on ${this.powers[b].name}.`);
        }
      }
    }

    // A power at war picks the closest enemy holding and invests it.
    for (const id of ids) {
      const power = this.powers[id];
      if (power.atWar.length === 0 || this.random() > 0.22) continue;
      const enemies = this.holdings.filter((holding) => power.atWar.includes(holding.owner) && !holding.siege);
      if (enemies.length === 0) continue;
      const home = this.holdings.filter((holding) => holding.owner === id);
      if (home.length === 0) continue;
      const target = enemies.reduce((best, holding) => {
        const distance = Math.min(...home.map((h) => Math.hypot(h.x - holding.x, h.z - holding.z)));
        return distance < best.distance ? { holding, distance } : best;
      }, { holding: enemies[0], distance: Infinity });
      if (target.distance > 190) continue;
      if (this.armyOf(id) < 40) continue;
      target.holding.siege = { by: id, progress: 0 };
      this.record("war", `${power.name} invests ${target.holding.name}.`);
    }
  }

  /** Campaign effects the sandbox can act on: spawn and count warband. */
  fieldArmySize(): number {
    return Math.min(14, Math.floor(this.armyOf(this.player) / 26));
  }
}
