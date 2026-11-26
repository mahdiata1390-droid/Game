// The atlas of the basin.
//
// Every settlement, port, mine and granary the world builder and the campaign
// layer know about lives here, so the place you walk through and the place you
// govern on the council map are the same place. Coordinates are world units on
// a 340 x 340 basin (MAP_HALF either side of the Kingsroad).

import type { HouseId } from "./houses";

export type SiteKind = "village" | "town" | "castle" | "city";

export type ResourceKind =
  | "grain" | "timber" | "stone" | "iron" | "fish" | "wine" | "cloth" | "salt";

export type Site = {
  id: string;
  name: string;
  kind: SiteKind;
  owner: HouseId;
  x: number;
  z: number;
  population: number;
  /** touches the Silver Sea, so it can build and feed galleys */
  port: boolean;
  resource: ResourceKind;
  /** men under arms when the campaign opens */
  garrison: number;
};

/** Half-width of the playable basin, in world units. */
export const MAP_HALF = 166;

/** Where the ground ends and the Silver Sea begins. */
export const COAST_X = 150;

export const SITES: Site[] = [
  // ---------------------------------------------------- The North Kingdom (NW)
  { id: "northwatch", name: "Northwatch", kind: "castle", owner: "north_kingdom", x: -58, z: -42, population: 720, port: false, resource: "stone", garrison: 260 },
  { id: "pinehaven", name: "Pinehaven", kind: "village", owner: "north_kingdom", x: -20, z: -48, population: 260, port: false, resource: "timber", garrison: 60 },
  { id: "frostport", name: "Frostport", kind: "town", owner: "north_kingdom", x: -64, z: 0, population: 610, port: true, resource: "fish", garrison: 150 },
  { id: "iceharbor", name: "Iceharbor", kind: "town", owner: "north_kingdom", x: -112, z: -96, population: 540, port: true, resource: "fish", garrison: 140 },
  { id: "highfell", name: "Highfell", kind: "castle", owner: "north_kingdom", x: -96, z: -18, population: 480, port: false, resource: "iron", garrison: 220 },
  { id: "greywater", name: "Greywater", kind: "village", owner: "north_kingdom", x: -40, z: -104, population: 210, port: false, resource: "timber", garrison: 50 },
  { id: "stonecross", name: "Stonecross", kind: "village", owner: "north_kingdom", x: -140, z: -46, population: 180, port: false, resource: "stone", garrison: 45 },

  // ------------------------------------------------- The River Kingdom (centre)
  { id: "valoria", name: "Valoria", kind: "city", owner: "river_kingdom", x: 22, z: -45, population: 1450, port: false, resource: "wine", garrison: 420 },
  { id: "kingsbridge", name: "Kingsbridge", kind: "city", owner: "river_kingdom", x: -16, z: -3, population: 1300, port: true, resource: "grain", garrison: 380 },
  { id: "goldford", name: "Goldford", kind: "town", owner: "river_kingdom", x: 26, z: -3, population: 820, port: false, resource: "wine", garrison: 190 },
  { id: "riversend", name: "Riversend", kind: "town", owner: "river_kingdom", x: 4, z: -88, population: 560, port: true, resource: "grain", garrison: 140 },
  { id: "millbrook", name: "Millbrook", kind: "village", owner: "river_kingdom", x: 44, z: -66, population: 240, port: false, resource: "grain", garrison: 55 },
  { id: "queensgate", name: "Queensgate", kind: "castle", owner: "river_kingdom", x: -30, z: 30, population: 610, port: false, resource: "stone", garrison: 240 },
  { id: "basinfield", name: "Basinfield", kind: "village", owner: "river_kingdom", x: -10, z: 40, population: 280, port: false, resource: "grain", garrison: 60 },
  { id: "harrowfield", name: "Harrowfield", kind: "village", owner: "river_kingdom", x: 44, z: -16, population: 300, port: false, resource: "cloth", garrison: 65 },
  { id: "larkmeadow", name: "Larkmeadow", kind: "village", owner: "river_kingdom", x: 56, z: 16, population: 260, port: false, resource: "cloth", garrison: 60 },

  // --------------------------------------------------- The Eastern Tribes (E)
  { id: "steppecamp", name: "Steppe Camp", kind: "village", owner: "eastern_tribes", x: 61, z: -29, population: 310, port: false, resource: "timber", garrison: 70 },
  { id: "redstone", name: "Redstone", kind: "castle", owner: "eastern_tribes", x: 61, z: 6, population: 540, port: false, resource: "iron", garrison: 230 },
  { id: "anvilkeep", name: "Anvil Keep", kind: "castle", owner: "eastern_tribes", x: 100, z: -58, population: 500, port: false, resource: "iron", garrison: 240 },
  { id: "horseford", name: "Horseford", kind: "town", owner: "eastern_tribes", x: 112, z: -16, population: 620, port: true, resource: "salt", garrison: 160 },
  { id: "ashencamp", name: "Ashen Camp", kind: "village", owner: "eastern_tribes", x: 124, z: -100, population: 220, port: false, resource: "timber", garrison: 50 },
  { id: "wolfstead", name: "Wolfstead", kind: "village", owner: "eastern_tribes", x: 140, z: -34, population: 200, port: false, resource: "timber", garrison: 45 },

  // -------------------------------------------------------- The West Clans (SW)
  { id: "clanhold", name: "Clanhold", kind: "castle", owner: "western_clans", x: -54, z: 38, population: 490, port: false, resource: "stone", garrison: 210 },
  { id: "glenmoor", name: "Glenmoor", kind: "town", owner: "western_clans", x: -100, z: 34, population: 580, port: false, resource: "cloth", garrison: 150 },
  { id: "duncreag", name: "Duncreag", kind: "castle", owner: "western_clans", x: -128, z: 84, population: 470, port: false, resource: "iron", garrison: 215 },
  { id: "cairnford", name: "Cairnford", kind: "village", owner: "western_clans", x: -72, z: 72, population: 230, port: false, resource: "timber", garrison: 50 },
  { id: "mistvale", name: "Mistvale", kind: "village", owner: "western_clans", x: -104, z: 128, population: 190, port: false, resource: "grain", garrison: 45 },

  // -------------------------------------------------- The Southern Sultanate (SE)
  { id: "sahr", name: "Sahr", kind: "city", owner: "southern_sultanate", x: 32, z: 38, population: 1600, port: false, resource: "cloth", garrison: 460 },
  { id: "pearlbay", name: "Pearl Bay", kind: "town", owner: "southern_sultanate", x: 64, z: 48, population: 730, port: true, resource: "fish", garrison: 180 },
  { id: "sunmere", name: "Sunmere", kind: "city", owner: "southern_sultanate", x: 92, z: 96, population: 1380, port: true, resource: "salt", garrison: 390 },
  { id: "alqasr", name: "Al-Qasr", kind: "castle", owner: "southern_sultanate", x: 128, z: 136, population: 520, port: false, resource: "stone", garrison: 250 },
  { id: "dunemarket", name: "Dune Market", kind: "town", owner: "southern_sultanate", x: 60, z: 116, population: 640, port: false, resource: "salt", garrison: 155 },
  { id: "palmcove", name: "Palm Cove", kind: "village", owner: "southern_sultanate", x: 140, z: 52, population: 260, port: true, resource: "fish", garrison: 60 },

  // ------------------------------------------------------- The Free Company
  { id: "wayfarers", name: "Wayfarers Rest", kind: "village", owner: "free_company", x: -2, z: -30, population: 220, port: false, resource: "grain", garrison: 60 },
  { id: "greyhollow", name: "Greyhollow Keep", kind: "castle", owner: "free_company", x: -38, z: 62, population: 380, port: false, resource: "stone", garrison: 150 },
];

export const SITE_BY_ID: Record<string, Site> = Object.fromEntries(
  SITES.map((site) => [site.id, site]),
);

/** Roads drawn on the council map, as pairs of settlement ids. */
export const ROADS: Array<[string, string]> = [
  ["northwatch", "kingsbridge"],
  ["northwatch", "highfell"],
  ["highfell", "frostport"],
  ["frostport", "clanhold"],
  ["valoria", "kingsbridge"],
  ["valoria", "redstone"],
  ["kingsbridge", "goldford"],
  ["kingsbridge", "queensgate"],
  ["goldford", "sahr"],
  ["redstone", "horseford"],
  ["clanhold", "glenmoor"],
  ["clanhold", "cairnford"],
  ["sahr", "pearlbay"],
  ["pearlbay", "sunmere"],
  ["sunmere", "alqasr"],
  ["greyhollow", "clanhold"],
  ["wayfarers", "kingsbridge"],
  ["riversend", "valoria"],
  ["millbrook", "valoria"],
];

/** Territory centres used to paint the council map. */
export const HEARTLANDS = [
  { house: "north_kingdom", x: -86, z: -58, radius: 88 },
  { house: "river_kingdom", x: 8, z: -8, radius: 78 },
  { house: "eastern_tribes", x: 104, z: -34, radius: 74 },
  { house: "western_clans", x: -90, z: 72, radius: 76 },
  { house: "southern_sultanate", x: 84, z: 88, radius: 80 },
  { house: "free_company", x: -20, z: 24, radius: 30 },
] as const;

export function sitesOf(owner: HouseId): Site[] {
  return SITES.filter((site) => site.owner === owner);
}

export function mapPercent(x: number, z: number): { left: number; top: number } {
  return {
    left: ((x + MAP_HALF) / (MAP_HALF * 2)) * 100,
    top: ((z + MAP_HALF) / (MAP_HALF * 2)) * 100,
  };
}
