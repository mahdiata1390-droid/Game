// The five powers of the basin, plus the free company the player leads.
//
// Every house owns a complete visual identity: a stone tradition, a roof
// system, a metal, a coat of arms, a signature weapon and an armour style.
// World builders and figure rigs read only from this table, so adding a sixth
// power is a data change rather than an art change.

import { ATLAS_TILE as T } from "../engine/textures";

export type HouseId =
  | "free_company"
  | "north_kingdom"
  | "river_kingdom"
  | "eastern_tribes"
  | "southern_sultanate"
  | "western_clans";

export type Style = "company" | "northern" | "river" | "steppe" | "desert" | "highland";
export type WeaponId = "longsword" | "halberd" | "waraxe" | "scimitar" | "bow" | "warhammer";
export type ArmourId = "plate" | "mail" | "leather" | "lamellar" | "fur" | "coat";
export type CrestId = "gem" | "tower" | "sun" | "wolf" | "crescent" | "saltire";
export type ShieldId = "kite" | "heater" | "round" | "none";

export type Rgb = [number, number, number];

export type House = {
  id: HouseId;
  name: string;
  motto: string;
  style: Style;
  weapon: WeaponId;
  armour: ArmourId;
  crest: CrestId;
  shield: ShieldId;
  /** atlas tile used on shields and hanging banners (tinted by `banner`) */
  heraldry: number;
  /** multiplier applied to the heraldry cloth: the coat of arms' field */
  banner: Rgb;
  /** trim, plumes, pennants and metal accents */
  trim: Rgb;
  stone: number;
  stoneTint: Rgb;
  roof: number;
  roofTint: Rgb;
  metal: number;
  /** cloth of cloaks, tabards and tent canvas */
  cloth: Rgb;
  /** how tall this house builds: castles scale their keep and curtain wall */
  stature: number;
};

export const HOUSES: Record<HouseId, House> = {
  north_kingdom: {
    id: "north_kingdom",
    name: "The North Kingdom",
    motto: "Stone endures, and so do we.",
    style: "northern",
    weapon: "longsword",
    armour: "plate",
    crest: "tower",
    shield: "kite",
    heraldry: T.TOWER,
    banner: [0.3, 0.46, 0.78],
    trim: [0.92, 0.94, 1.0],
    stone: T.ASHLAR,
    stoneTint: [0.98, 1.02, 1.08],
    roof: T.SLATE,
    roofTint: [0.58, 0.68, 0.84],
    metal: T.STEEL,
    cloth: [0.24, 0.36, 0.58],
    stature: 1.15,
  },
  river_kingdom: {
    id: "river_kingdom",
    name: "The River Kingdom",
    motto: "Gold in the granary, gold in the hall.",
    style: "river",
    weapon: "halberd",
    armour: "mail",
    crest: "sun",
    shield: "heater",
    heraldry: T.SUN,
    banner: [0.92, 0.7, 0.24],
    trim: [1.0, 0.9, 0.62],
    stone: T.ASHLAR,
    stoneTint: [1.08, 1.03, 0.92],
    roof: T.CLAY,
    roofTint: [1.08, 0.98, 0.92],
    metal: T.BRONZE,
    cloth: [0.72, 0.56, 0.22],
    stature: 1.0,
  },
  eastern_tribes: {
    id: "eastern_tribes",
    name: "The Eastern Tribes",
    motto: "The wolf takes what the wind reveals.",
    style: "steppe",
    weapon: "waraxe",
    armour: "leather",
    crest: "wolf",
    shield: "round",
    heraldry: T.WOLF,
    banner: [0.72, 0.22, 0.18],
    trim: [0.88, 0.74, 0.36],
    stone: T.MUD,
    stoneTint: [1.0, 0.94, 0.86],
    roof: T.SHINGLE,
    roofTint: [1.06, 0.96, 0.84],
    metal: T.IRON,
    cloth: [0.5, 0.26, 0.2],
    stature: 0.82,
  },
  southern_sultanate: {
    id: "southern_sultanate",
    name: "The Southern Sultanate",
    motto: "Under one sun, one law.",
    style: "desert",
    weapon: "scimitar",
    armour: "lamellar",
    crest: "crescent",
    shield: "round",
    heraldry: T.CRESCENT,
    banner: [0.16, 0.46, 0.38],
    trim: [0.96, 0.78, 0.34],
    stone: T.SANDSTONE,
    stoneTint: [1.04, 0.96, 0.84],
    roof: T.SANDSTONE,
    roofTint: [1.06, 0.98, 0.86],
    metal: T.BRONZE,
    cloth: [0.2, 0.5, 0.42],
    stature: 0.95,
  },
  western_clans: {
    id: "western_clans",
    name: "The Western Clans",
    motto: "No king above the glen.",
    style: "highland",
    weapon: "warhammer",
    armour: "fur",
    crest: "saltire",
    shield: "round",
    heraldry: T.SALTIRE,
    banner: [0.52, 0.36, 0.68],
    trim: [0.84, 0.8, 0.72],
    stone: T.BASALT,
    stoneTint: [0.98, 0.98, 1.02],
    roof: T.THATCH,
    roofTint: [1.0, 0.94, 0.82],
    metal: T.IRON,
    cloth: [0.4, 0.3, 0.52],
    stature: 1.05,
  },
  free_company: {
    id: "free_company",
    name: "The Free Company",
    motto: "Paid in coin, kept by steel.",
    style: "company",
    weapon: "longsword",
    armour: "coat",
    crest: "gem",
    shield: "heater",
    heraldry: T.CHEVRON,
    banner: [0.44, 0.52, 0.64],
    trim: [0.94, 0.8, 0.44],
    stone: T.RUBBLE,
    stoneTint: [1.0, 1.0, 1.0],
    roof: T.THATCH,
    roofTint: [1.0, 0.96, 0.88],
    metal: T.STEEL,
    cloth: [0.32, 0.36, 0.44],
    stature: 0.9,
  },
};

export function houseOf(owner: string): House {
  return HOUSES[owner as HouseId] ?? HOUSES.free_company;
}

/**
 * Each signature weapon changes how its bearer fights, so the six silhouettes
 * are also six combat styles rather than a cosmetic choice.
 */
export const WEAPON_PROFILE: Record<WeaponId, {
  damage: number; speed: number; rate: number; reach: number;
}> = {
  longsword: { damage: 1.0, speed: 1.0, rate: 2.4, reach: 2.8 },
  halberd: { damage: 1.35, speed: 0.92, rate: 3.0, reach: 3.6 },
  waraxe: { damage: 1.2, speed: 1.02, rate: 2.6, reach: 2.6 },
  scimitar: { damage: 0.85, speed: 1.12, rate: 2.0, reach: 2.5 },
  bow: { damage: 0.75, speed: 1.05, rate: 2.2, reach: 9.0 },
  warhammer: { damage: 1.5, speed: 0.85, rate: 3.2, reach: 2.7 },
};

/** Named commanders who hold each power's seat. */
export const CHAMPIONS: Record<string, string> = {
  north_kingdom: "Sir Aldric",
  river_kingdom: "Captain Merrow",
  eastern_tribes: "Khatun Sarai",
  southern_sultanate: "Sayyid Faruq",
  western_clans: "Laird Bram",
  free_company: "the Captain",
};

/** Rank-and-file names so a garrison reads like a garrison, not a clone army. */
const ENEMY_TITLES = ["Outrider", "Reaver", "Spear", "Scout", "Raider", "Axeman"];
const ALLY_TITLES = ["Sergeant", "Archer", "Shieldbearer", "Scout", "Pikeman", "Veteran"];

export function unitTitle(faction: "player" | "ally" | "enemy", index: number): string {
  const pool = faction === "enemy" ? ENEMY_TITLES : ALLY_TITLES;
  return pool[index % pool.length];
}
