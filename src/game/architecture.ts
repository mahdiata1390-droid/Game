// Settlement architecture.
//
// Every building is assembled from the engine's box primitive, but proportions,
// layering and roofs do the work: battered tower bases, corbelled tops, real
// pitched roofs instead of flat slabs, jettied townhouses, arcades, and a
// different fortress silhouette for each of the five powers.
//
// Builders receive a `Placer` already bound to a local frame, so a building can
// be authored axis-aligned and dropped into the world at any rotation.

import { ATLAS_TILE as T } from "../engine/textures";
import type { House, Rgb } from "./houses";

export type Site = {
  name: string;
  kind: "village" | "town" | "castle" | "city";
  x: number;
  z: number;
  owner: string;
  population: number;
};

export type BlockRequest = {
  name: string;
  group: string;
  x: number;
  y: number;
  z: number;
  sx: number;
  sy: number;
  sz: number;
  color: Rgb;
  tile?: number;
  repeat?: number;
  repeatY?: number;
  emissive?: number;
  yaw?: number;
  pitch?: number;
  solid?: boolean;
};

export type Builder = {
  block(request: BlockRequest): void;
  random(): number;
};

export type PartOptions = {
  tile?: number;
  repeat?: number;
  repeatY?: number;
  emissive?: number;
  yaw?: number;
  pitch?: number;
  solid?: boolean;
};

type Placer = (
  name: string, lx: number, ly: number, lz: number,
  sx: number, sy: number, sz: number,
  color: Rgb, options?: PartOptions,
) => void;

const WARM_WINDOW: Rgb = [1, 0.83, 0.52];

/** A local frame: places parts relative to a building, rotated by yaw. */
function frameAt(b: Builder, group: string, cx: number, cz: number, yaw: number): Placer {
  const cos = Math.cos(yaw);
  const sin = Math.sin(yaw);
  return (name, lx, ly, lz, sx, sy, sz, color, options = {}) => {
    b.block({
      name,
      group,
      x: cx + lx * cos + lz * sin,
      y: ly,
      z: cz - lx * sin + lz * cos,
      sx, sy, sz,
      color,
      tile: options.tile,
      repeat: options.repeat,
      repeatY: options.repeatY,
      emissive: options.emissive,
      yaw: yaw + (options.yaw ?? 0),
      pitch: options.pitch,
      solid: options.solid,
    });
  };
}

const mul = (c: Rgb, k: number): Rgb => [c[0] * k, c[1] * k, c[2] * k];

// ------------------------------------------------------------------- roofs

/** Four tilted slabs: a true hipped roof with overlapping hips at the corners. */
function hipRoof(
  p: Placer, halfW: number, halfD: number, height: number, baseY: number,
  tile: number, tint: Rgb, overhang = 0.4,
): void {
  const width = 2 * Math.max(halfW, halfD) + overhang * 2;
  const faces: Array<{ yaw: number; half: number; dx: number; dz: number }> = [
    { yaw: 0, half: halfD, dx: 0, dz: 1 },
    { yaw: Math.PI, half: halfD, dx: 0, dz: -1 },
    { yaw: Math.PI / 2, half: halfW, dx: 1, dz: 0 },
    { yaw: -Math.PI / 2, half: halfW, dx: -1, dz: 0 },
  ];
  for (const face of faces) {
    const slope = Math.hypot(face.half + overhang, height);
    p("Roof", face.dx * (face.half + overhang) * 0.5, baseY + height * 0.5, face.dz * (face.half + overhang) * 0.5,
      width, 0.22, slope, tint, {
        tile,
        repeat: Math.max(1, Math.round(width / 2)),
        repeatY: Math.max(1, Math.round(slope / 2)),
        yaw: face.yaw,
        pitch: Math.atan2(height, face.half + overhang),
        emissive: 0.02,
      });
  }
  // Ridge cap and a warm finial so towers read against the sky.
  p("Roof Ridge", 0, baseY + height + 0.08, 0, Math.min(halfW, halfD) * 2 + 0.5, 0.16, 0.3, mul(tint, 0.86), {
    tile, yaw: 0, emissive: 0.02,
  });
}

/** Eight faceted slabs forming a cone: the roof of a round tower. */
function coneRoof(
  p: Placer, radius: number, height: number, baseY: number,
  tile: number, tint: Rgb,
): void {
  const slope = Math.hypot(radius, height);
  const width = 2 * radius * Math.tan(Math.PI / 8) * 1.18;
  const pitch = Math.atan2(height, radius);
  for (let i = 0; i < 8; i++) {
    const a = (i / 8) * Math.PI * 2;
    p("Cone Roof", Math.sin(a) * radius * 0.5, baseY + height * 0.5, Math.cos(a) * radius * 0.5,
      width, 0.2, slope, tint, {
        tile, repeat: Math.max(1, Math.round(width / 2)), repeatY: Math.max(1, Math.round(slope / 2)),
        yaw: a, pitch, emissive: 0.02,
      });
  }
  p("Finial", 0, baseY + height + 0.12, 0, 0.16, 0.5, 0.16, [0.82, 0.68, 0.34], {
    tile: T.BRONZE, emissive: 0.12,
  });
}

/** Tall square spire for bell towers and chapels. */
function spire(
  p: Placer, halfW: number, halfD: number, height: number, baseY: number,
  tile: number, tint: Rgb, finial: Rgb,
): void {
  hipRoof(p, halfW, halfD, height, baseY, tile, tint, 0.25);
  p("Spire Finial", 0, baseY + height + 0.35, 0, 0.18, 0.9, 0.18, finial, {
    tile: T.BRONZE, emissive: 0.14,
  });
  p("Spire Vane", 0, baseY + height + 1.05, 0, 0.55, 0.5, 0.05, finial, {
    tile: T.BRONZE, emissive: 0.16, yaw: 0.7,
  });
}

/** Onion dome from stacked, shrinking drums — the sultanate signature. */
function onionDome(
  p: Placer, radius: number, height: number, baseY: number, tint: Rgb,
): void {
  const rings = 14;
  const step = height / (rings - 1);
  for (let i = 0; i < rings; i++) {
    const t = i / (rings - 1);
    // cosine profile: broad shoulders, a point at the crown
    const r = radius * Math.cos(t * Math.PI * 0.47);
    const y = baseY + height * t;
    p("Dome", 0, y, 0, Math.max(0.16, r * 2), step * 1.5, Math.max(0.16, r * 2), tint, {
      tile: T.SANDSTONE, repeat: Math.max(1, Math.round(r / 2)), emissive: 0.02,
    });
  }
  p("Dome Drum", 0, baseY - 0.4, 0, radius * 2.15, 0.9, radius * 2.15, mul(tint, 0.94), {
    tile: T.SANDSTONE, repeat: 4,
  });
  p("Dome Finial", 0, baseY + height + 0.5, 0, 0.16, 1.0, 0.16, [0.94, 0.78, 0.34], {
    tile: T.BRONZE, emissive: 0.18,
  });
  p("Crescent", 0, baseY + height + 1.15, 0, 0.5, 0.5, 0.06, [0.98, 0.84, 0.38], {
    tile: T.BRONZE, emissive: 0.22, yaw: 0.4,
  });
}

// ------------------------------------------------------------------ towers

type TowerOptions = {
  radius: number;
  height: number;
  top: "crenel" | "cone" | "dome";
  stone: number;
  tint: Rgb;
  roof: number;
  roofTint: Rgb;
  banner?: House;
  name?: string;
};

/** A round tower: battered base, eight-sided drum, corbelled top. */
function drumTower(p: Placer, cx: number, cz: number, options: TowerOptions): void {
  const { radius, height, tint } = options;
  const width = 2 * radius * Math.tan(Math.PI / 8) * 1.06;
  const label = options.name ?? "Tower";

  // plinth
  for (let i = 0; i < 8; i++) {
    const a = (i / 8) * Math.PI * 2;
    p(`${label} Base`, cx + Math.sin(a) * radius * 1.06, 0.7, cz + Math.cos(a) * radius * 1.06,
      width * 1.18, 1.5, radius * 0.5, mul(tint, 0.94), {
        tile: options.stone, repeat: 2, yaw: a, solid: false,
      });
  }
  // drum
  for (let i = 0; i < 8; i++) {
    const a = (i / 8) * Math.PI * 2;
    p(`${label} Wall`, cx + Math.sin(a) * radius * 0.96, height * 0.5, cz + Math.cos(a) * radius * 0.96,
      width, height, radius * 0.46, tint, {
        tile: options.stone, repeat: Math.max(1, Math.round(width / 2)),
        repeatY: Math.max(2, Math.round(height / 2)), yaw: a,
      });
  }
  // corbel course under the battlements
  for (let i = 0; i < 8; i++) {
    const a = (i / 8) * Math.PI * 2;
    p(`${label} Corbel`, cx + Math.sin(a) * radius * 1.02, height - 0.55, cz + Math.cos(a) * radius * 1.02,
      width * 1.14, 0.45, radius * 0.5, mul(tint, 1.04), { tile: options.stone, yaw: a });
  }
  // arrow slits
  for (let i = 0; i < 4; i++) {
    const a = (i / 4) * Math.PI * 2 + Math.PI / 8;
    const s = radius * 1.02;
    p(`${label} Arrow Slit`, cx + Math.sin(a) * s, height * 0.55, cz + Math.cos(a) * s,
      0.12, 1.1, 0.5, [0.06, 0.06, 0.07], { yaw: a, emissive: 0 });
  }

  if (options.top === "crenel") {
    for (let i = 0; i < 12; i++) {
      const a = (i / 12) * Math.PI * 2;
      p(`${label} Merlon`, cx + Math.sin(a) * radius * 0.98, height + 0.55, cz + Math.cos(a) * radius * 0.98,
        0.5, 1.0, radius * 0.36, mul(tint, 1.06), { tile: options.stone, yaw: a });
    }
    p(`${label} Watch Rail`, cx, height + 0.1, cz, radius * 1.9, 0.14, radius * 1.9, mul(tint, 0.92), {
      tile: options.stone,
    });
  } else if (options.top === "cone") {
    p(`${label} Eaves`, cx, height + 0.2, cz, radius * 2.1, 0.22, radius * 2.1, mul(options.roofTint, 0.9), {
      tile: options.roof,
    });
    coneRoof(p, radius * 1.12, radius * 1.7, height + 0.4, options.roof, options.roofTint);
  } else {
    onionDome(p, radius * 1.15, radius * 1.5, height + 0.4, mul(options.roofTint, 1.02));
  }

  if (options.banner) {
    const banner = options.banner;
    p(`${label} Standard`, cx, height + 2.1, cz, 0.12, 4.2, 0.12, [0.32, 0.24, 0.16], {
      tile: T.WOOD, yaw: 0.3,
    });
    p(`${label} Pennant`, cx + 0.05, height + 3.4, cz + 1.05, 0.04, 1.5, 1.9, banner.banner, {
      tile: banner.heraldry, emissive: 0.05, yaw: 0.3,
    });
  }
}

// ------------------------------------------------------------------- walls

// ------------------------------------------------------------------- keeps

function keepNorthern(p: Placer, house: House): void {
  const w = 11, d = 9, h = 12;
  p("Keep Plinth", 0, 0.7, 0, w + 2, 1.6, d + 2, mul(house.stoneTint, 0.9), {
    tile: house.stone, repeat: 4, solid: true,
  });
  p("Keep", 0, h * 0.5 + 1.2, 0, w, h, d, house.stoneTint, {
    tile: house.stone, repeat: 5, solid: true,
  });
  // string courses
  for (const y of [4.6, 8.2]) {
    p("Keep Course", 0, y, 0, w + 0.5, 0.3, d + 0.5, mul(house.stoneTint, 1.08), {
      tile: house.stone, repeat: 6,
    });
  }
  // battlement
  for (let i = 0; i < 9; i++) {
    const x = -w / 2 + (i + 0.5) * (w / 9);
    p("Keep Merlon", x, h + 1.9, d / 2, 0.8, 1.0, 0.7, mul(house.stoneTint, 1.05), { tile: house.stone });
    p("Keep Merlon", x, h + 1.9, -d / 2, 0.8, 1.0, 0.7, mul(house.stoneTint, 1.05), { tile: house.stone });
  }
  for (let i = 0; i < 7; i++) {
    const z = -d / 2 + (i + 0.5) * (d / 7);
    p("Keep Merlon", w / 2, h + 1.9, z, 0.7, 1.0, 0.8, mul(house.stoneTint, 1.05), { tile: house.stone });
    p("Keep Merlon", -w / 2, h + 1.9, z, 0.7, 1.0, 0.8, mul(house.stoneTint, 1.05), { tile: house.stone });
  }
  // buttresses on the corners
  for (const sx of [-1, 1]) {
    for (const sz of [-1, 1]) {
      p("Keep Buttress", sx * (w / 2 - 0.2), h * 0.42 + 1.2, sz * (d / 2 - 0.2),
        1.5, h * 0.7, 1.5, mul(house.stoneTint, 0.96), { tile: house.stone, repeat: 3 });
    }
  }
  // roof and corner turrets
  hipRoof(p, w / 2 + 0.4, d / 2 + 0.4, 4.6, h + 2.4, house.roof, house.roofTint);
  for (const sx of [-1, 1]) {
    for (const sz of [-1, 1]) {
      drumTower(p, sx * (w / 2 + 0.4), sz * (d / 2 + 0.4), {
        radius: 1.5, height: h + 3.4, top: "cone",
        stone: house.stone, tint: house.stoneTint,
        roof: house.roof, roofTint: house.roofTint,
        name: "Corner Turret",
      });
    }
  }
  // windows: two lit rows on the long faces
  for (const zSide of [-1, 1]) {
    for (let i = 0; i < 3; i++) {
      for (const y of [4.2, 7.4]) {
        const x = -w / 3 + i * (w / 3);
        p("Keep Window", x, y, zSide * (d / 2 + 0.05), 1.1, 1.7, 0.18, [0.1, 0.1, 0.12], {
          emissive: 0,
        });
        p("Keep Window Glow", x, y, zSide * (d / 2 + 0.1), 0.9, 1.4, 0.1, WARM_WINDOW, {
          tile: T.CLOTH, emissive: 0.7,
        });
      }
    }
  }
  // door with a pointed arch and steps
  p("Keep Door", 0, 2.0, d / 2 + 0.06, 2.2, 3.6, 0.25, [0.3, 0.2, 0.13], { tile: T.OAK });
  p("Keep Door Arch", 0, 3.9, d / 2 + 0.04, 2.9, 0.7, 0.35, mul(house.stoneTint, 1.06), {
    tile: house.stone,
  });
  for (let i = 0; i < 3; i++) {
    p("Keep Step", 0, 0.12 + i * 0.06, d / 2 + 1.1 + i * 0.55, 3.0, 0.24, 0.6, mul(house.stoneTint, 0.95), {
      tile: house.stone,
    });
  }
  p("Keep Standard", 2.2, h + 4.4, d / 2 - 0.4, 0.12, 5.0, 0.12, [0.3, 0.22, 0.15], { tile: T.WOOD });
  p("Keep Banner", 2.2, h + 5.0, d / 2 + 0.7, 0.06, 2.0, 2.2, house.banner, {
    tile: house.heraldry, emissive: 0.06,
  });
}

function keepRiver(p: Placer, house: House): void {
  const w = 13, d = 9.5, h = 9;
  p("Hall Plinth", 0, 0.5, 0, w + 1.6, 1.2, d + 1.6, mul(house.stoneTint, 0.9), {
    tile: house.stone, repeat: 5, solid: true,
  });
  p("Great Hall", 0, h * 0.5 + 1.0, 0, w, h, d, house.stoneTint, {
    tile: house.stone, repeat: 6, solid: true,
  });
  // gilded banding
  for (const y of [3.4, 6.6]) {
    p("Gilded Band", 0, y, 0, w + 0.35, 0.24, d + 0.35, house.trim, {
      tile: T.GOLD, repeat: 6, emissive: 0.16,
    });
  }
  // arcade across the front: piers and a round-headed arcade band
  for (let i = -2; i <= 2; i++) {
    const x = i * (w / 5.2);
    p("Arcade Pier", x, 2.0, d / 2 + 0.55, 0.7, 3.4, 0.7, mul(house.stoneTint, 1.04), {
      tile: house.stone, repeat: 2,
    });
    if (i < 2) {
      p("Arcade Arch", x + w / 10.4, 3.75, d / 2 + 0.55, w / 5.2, 0.6, 0.75,
        mul(house.stoneTint, 1.02), { tile: house.stone });
    }
  }
  p("Loggia Floor", 0, 3.55, d / 2 + 0.5, w, 0.3, 1.2, mul(house.stoneTint, 1.06), {
    tile: house.stone, repeat: 5,
  });
  hipRoof(p, w / 2 + 0.5, d / 2 + 0.5, 4.2, h + 1.0, house.roof, house.roofTint);
  // dormers
  for (const x of [-3.6, 0, 3.6]) {
    p("Dormer", x, h + 3.4, d / 2 - 0.6, 1.5, 1.4, 1.2, mul(house.stoneTint, 1.02), {
      tile: house.stone,
    });
    p("Dormer Window", x, h + 3.4, d / 2 + 0.05, 0.9, 1.0, 0.1, WARM_WINDOW, {
      tile: T.CLOTH, emissive: 0.55,
    });
  }
  // tall lit windows
  for (const zSide of [-1, 1]) {
    for (let i = 0; i < 4; i++) {
      const x = -w / 2.6 + i * (w / 4);
      p("Hall Window", x, 5.4, zSide * (d / 2 + 0.06), 1.0, 2.3, 0.16, [0.1, 0.1, 0.12], { emissive: 0 });
      p("Hall Window Glow", x, 5.4, zSide * (d / 2 + 0.11), 0.82, 2.0, 0.1, WARM_WINDOW, {
        tile: T.CLOTH, emissive: 0.75,
      });
    }
  }
  // grand door
  p("Hall Door", 0, 1.9, d / 2 + 0.08, 2.4, 3.4, 0.2, [0.34, 0.22, 0.14], { tile: T.OAK });
  p("Hall Door Arch", 0, 3.8, d / 2 + 0.06, 3.2, 0.8, 0.3, house.trim, { tile: T.GOLD, emissive: 0.12 });
  p("Hall Banner Pole", -4.6, h + 4.0, d / 2 - 0.4, 0.12, 5.2, 0.12, [0.3, 0.22, 0.15], { tile: T.WOOD });
  p("Hall Banner", -4.6, h + 4.6, d / 2 + 0.8, 0.06, 2.2, 2.4, house.banner, {
    tile: house.heraldry, emissive: 0.06,
  });

  // bell tower attached to the east side
  const tx = w / 2 + 3.2;
  p("Bell Tower", tx, 9, 0, 3.8, 18, 3.8, mul(house.stoneTint, 1.02), {
    tile: house.stone, repeat: 6, solid: true,
  });
  for (const y of [7.0, 12.5]) {
    p("Bell Tower Band", tx, y, 0, 4.1, 0.22, 4.1, house.trim, { tile: T.GOLD, emissive: 0.14 });
  }
  for (const [dx, dz] of [[-1, 0], [1, 0], [0, -1], [0, 1]] as Array<[number, number]>) {
    p("Belfry Opening", tx + dx * 1.95, 15.6, dz * 1.95, dx ? 0.2 : 1.8, 2.4, dz ? 0.2 : 1.8,
      [0.08, 0.08, 0.1], { emissive: 0 });
  }
  p("Bell", tx, 15.2, 0, 0.9, 1.1, 0.9, [0.82, 0.66, 0.32], { tile: T.BRONZE, emissive: 0.12 });
  spire(p, 2.1, 2.1, 5.0, 18.2, house.roof, house.roofTint, house.trim);
}

function keepDesert(p: Placer, house: House): void {
  const w = 12, d = 11, h = 8.5;
  p("Citadel Base", 0, 0.6, 0, w + 1.4, 1.4, d + 1.4, mul(house.stoneTint, 0.92), {
    tile: house.stone, repeat: 5, solid: true,
  });
  p("Citadel", 0, h * 0.5 + 1.2, 0, w, h, d, house.stoneTint, {
    tile: house.stone, repeat: 5, solid: true,
  });
  // rounded crenellations
  for (let i = 0; i < 8; i++) {
    const x = -w / 2 + (i + 0.5) * (w / 8);
    for (const zSide of [-1, 1]) {
      p("Citadel Merlon", x, h + 1.6, zSide * (d / 2 - 0.3), 0.9, 1.0, 0.9, mul(house.stoneTint, 1.04), {
        tile: house.stone,
      });
    }
  }
  for (let i = 0; i < 7; i++) {
    const z = -d / 2 + (i + 0.5) * (d / 7);
    for (const xSide of [-1, 1]) {
      p("Citadel Merlon", xSide * (w / 2 - 0.3), h + 1.6, z, 0.9, 1.0, 0.9, mul(house.stoneTint, 1.04), {
        tile: house.stone,
      });
    }
  }
  // mosaic frieze
  p("Mosaic Frieze", 0, 6.9, d / 2 + 0.06, w - 0.8, 0.7, 0.14, house.trim, {
    tile: T.GOLD, repeat: 6, emissive: 0.2,
  });
  // horseshoe gate
  p("Citadel Gate Recess", 0, 2.2, d / 2 + 0.05, 3.6, 4.4, 0.2, [0.16, 0.12, 0.08], { emissive: 0 });
  p("Citadel Gate", 0, 1.9, d / 2 + 0.14, 2.6, 3.8, 0.16, [0.32, 0.22, 0.14], { tile: T.OAK });
  p("Gate Arch Ring", 0, 4.4, d / 2 + 0.12, 3.9, 0.5, 0.32, house.trim, { tile: T.GOLD, emissive: 0.14 });
  // windows with arched heads
  for (const zSide of [-1, 1]) {
    for (let i = 0; i < 3; i++) {
      const x = -w / 3 + i * (w / 3);
      p("Citadel Window", x, 4.6, zSide * (d / 2 + 0.07), 0.9, 1.8, 0.16, [0.12, 0.1, 0.09], { emissive: 0 });
      p("Citadel Window Glow", x, 4.6, zSide * (d / 2 + 0.12), 0.7, 1.5, 0.1, WARM_WINDOW, {
        tile: T.CLOTH, emissive: 0.6,
      });
    }
  }
  // dome court and minaret
  onionDome(p, 3.9, 4.6, h + 1.4, mul(house.roofTint, 1.02));
  const mx = w / 2 + 2.6;
  const mz = d / 2 - 1.4;
  p("Minaret", mx, 9.5, mz, 2.4, 19, 2.4, mul(house.stoneTint, 1.03), {
    tile: house.stone, repeat: 7, solid: true,
  });
  p("Minaret Balcony", mx, 14.2, mz, 3.4, 0.4, 3.4, mul(house.stoneTint, 1.08), {
    tile: house.stone, repeat: 3,
  });
  for (let i = 0; i < 8; i++) {
    const a = (i / 8) * Math.PI * 2;
    p("Balcony Rail", mx + Math.sin(a) * 1.6, 14.75, mz + Math.cos(a) * 1.6, 0.3, 0.8, 0.3,
      mul(house.stoneTint, 1.02), { tile: house.stone });
  }
  onionDome(p, 1.7, 2.2, 19.0, mul(house.roofTint, 1.04));
  // skinny minaret shaft position helper for the dome finial already added
  p("Citadel Banner Pole", -w / 2 - 1.4, h + 4.2, d / 2 - 1.0, 0.12, 6.0, 0.12, [0.3, 0.22, 0.15], {
    tile: T.WOOD,
  });
  p("Citadel Banner", -w / 2 - 1.35, h + 5.0, d / 2 + 0.6, 0.06, 2.4, 2.6, house.banner, {
    tile: house.heraldry, emissive: 0.06,
  });
}

function keepSteppe(p: Placer, house: House): void {
  const w = 13, d = 9, h = 5.4;
  p("Hall Platform", 0, 0.45, 0, w + 1.4, 1.0, d + 1.4, mul(house.stoneTint, 0.9), {
    tile: house.stone, repeat: 5, solid: true,
  });
  p("Great Hall", 0, h * 0.5 + 0.9, 0, w, h, d, house.stoneTint, {
    tile: house.stone, repeat: 5, solid: true,
  });
  // timber frame: posts + top plate, the steppe signature
  for (const x of [-w / 2 + 0.4, -w / 6, w / 6, w / 2 - 0.4]) {
    for (const zSide of [-1, 1]) {
      p("Timber Post", x, h * 0.5 + 0.9, zSide * (d / 2 + 0.08), 0.42, h, 0.3, [0.34, 0.24, 0.15], {
        tile: T.OAK,
      });
    }
  }
  for (const zSide of [-1, 1]) {
    p("Timber Plate", 0, h + 0.85, zSide * (d / 2 + 0.08), w + 0.6, 0.4, 0.34, [0.32, 0.23, 0.14], {
      tile: T.OAK,
    });
  }
  // broad conical shingle roof with a smoke hole
  coneRoof(p, 8.4, 3.6, h + 1.0, house.roof, house.roofTint);
  p("Smoke Hole", 0, h + 4.4, 0, 1.0, 0.5, 1.0, [0.2, 0.16, 0.12], { emissive: 0.1 });
  p("Roof Pole", 0, h + 5.0, 0, 0.14, 1.6, 0.14, [0.34, 0.24, 0.15], { tile: T.OAK });
  p("Hall Banner", 0.4, h + 5.4, 0.9, 0.05, 1.5, 1.8, house.banner, {
    tile: house.heraldry, emissive: 0.05,
  });
  // door and hearth glow
  p("Hall Door", 0, 1.9, d / 2 + 0.16, 2.2, 3.2, 0.24, [0.3, 0.2, 0.13], { tile: T.OAK });
  p("Hall Door Frame", 0, 3.6, d / 2 + 0.14, 2.9, 0.4, 0.3, [0.34, 0.24, 0.15], { tile: T.OAK });
  for (const x of [-3.4, 3.4]) {
    p("Hall Window", x, 3.2, d / 2 + 0.08, 1.5, 1.1, 0.14, WARM_WINDOW, {
      tile: T.CLOTH, emissive: 0.45,
    });
  }
}

function keepHighland(p: Placer, house: House): void {
  // Round peel tower and an attached longhouse: the clan signature.
  drumTower(p, -2.0, 0, {
    radius: 3.5, height: 17, top: "crenel",
    stone: house.stone, tint: house.stoneTint,
    roof: house.roof, roofTint: house.roofTint,
    banner: house, name: "Peel Tower",
  });
  // battered footing ring
  for (let i = 0; i < 8; i++) {
    const a = (i / 8) * Math.PI * 2;
    p("Peel Footing", -2.0 + Math.sin(a) * 3.9, 0.9, Math.cos(a) * 3.9, 3.4, 1.8, 1.4,
      mul(house.stoneTint, 0.9), { tile: house.stone, repeat: 3, yaw: a });
  }
  // door, lit window
  p("Peel Door", -2.0, 2.0, 3.5, 1.8, 3.0, 0.3, [0.28, 0.19, 0.12], { tile: T.OAK });
  p("Peel Window", -2.0, 8.0, 3.45, 0.8, 1.3, 0.2, WARM_WINDOW, { tile: T.CLOTH, emissive: 0.5 });

  // longhouse
  const hx = 7.5, hz = 0.5;
  p("Longhouse", hx, 1.9, hz, 9.0, 3.8, 5.4, mul(house.stoneTint, 0.94), {
    tile: house.stone, repeat: 4, solid: true,
  });
  p("Longhouse Plinth", hx, 0.4, hz, 9.4, 0.8, 5.8, mul(house.stoneTint, 0.86), {
    tile: house.stone, repeat: 4,
  });
  hipRoof(p, 5.0, 3.1, 2.8, 3.8, house.roof, house.roofTint, 0.6);
  p("Longhouse Door", hx - 1.2, 1.6, hz + 2.76, 1.6, 2.6, 0.2, [0.28, 0.19, 0.12], { tile: T.OAK });
  p("Longhouse Window", hx + 2.4, 2.1, hz + 2.76, 1.4, 1.0, 0.16, WARM_WINDOW, {
    tile: T.CLOTH, emissive: 0.5,
  });
  p("Longhouse Chimney", hx + 3.6, 5.6, hz - 1.0, 0.9, 2.4, 0.9, mul(house.stoneTint, 0.92), {
    tile: house.stone, repeat: 2,
  });
  p("Clan Banner Pole", 3.0, 4.0, 4.4, 0.12, 8.0, 0.12, [0.3, 0.22, 0.15], { tile: T.WOOD });
  p("Clan Banner", 3.05, 5.2, 5.3, 0.05, 2.2, 2.4, house.banner, {
    tile: house.heraldry, emissive: 0.06,
  });
}

// ---------------------------------------------------------------- small props

function brazier(p: Placer, x: number, z: number, y = 0): void {
  p("Brazier Stand", x, y + 0.5, z, 0.18, 1.0, 0.18, [0.26, 0.27, 0.3], { tile: T.IRON });
  p("Brazier Bowl", x, y + 1.05, z, 0.72, 0.34, 0.72, [0.3, 0.31, 0.34], { tile: T.IRON });
  p("Brazier Fire", x, y + 1.3, z, 0.5, 0.5, 0.5, [1, 0.62, 0.22], { emissive: 0.95 });
  p("Brazier Coal", x, y + 1.16, z, 0.66, 0.12, 0.66, [0.9, 0.3, 0.12], { emissive: 0.5 });
}

function well(p: Placer, x: number, z: number): void {
  for (let i = 0; i < 8; i++) {
    const a = (i / 8) * Math.PI * 2;
    p("Well Curb", x + Math.sin(a) * 0.95, 0.35, z + Math.cos(a) * 0.95, 0.95, 0.7, 0.35,
      [1.02, 1.02, 1.0], { tile: T.RUBBLE, repeat: 1, yaw: a });
  }
  p("Well Water", x, 0.58, z, 1.5, 0.1, 1.5, [0.6, 0.75, 0.85], { tile: T.WATER, emissive: 0.05 });
  for (const sx of [-1, 1]) {
    p("Well Post", x + sx * 0.9, 1.3, z, 0.16, 1.9, 0.16, [0.34, 0.24, 0.15], { tile: T.WOOD });
  }
  hipRoof(p, 1.1, 1.1, 0.8, 2.2, T.THATCH, [1, 0.96, 0.86], 0.2);
  p("Well Winch", x, 1.9, z, 1.8, 0.12, 0.12, [0.34, 0.24, 0.15], { tile: T.WOOD });
  p("Well Bucket", x + 0.3, 1.45, z, 0.3, 0.34, 0.3, [0.44, 0.32, 0.2], { tile: T.WOOD });
}

function bannerPole(p: Placer, house: House, x: number, z: number, height: number): void {
  p("Banner Pole", x, height / 2, z, 0.16, height, 0.16, [0.3, 0.22, 0.15], { tile: T.WOOD });
  p("Banner Crossbar", x, height - 0.6, z, 0.12, 0.12, 2.2, [0.3, 0.22, 0.15], { tile: T.WOOD });
  p("Banner", x, height - 1.8, z + 1.0, 0.05, 2.2, 1.8, house.banner, {
    tile: house.heraldry, emissive: 0.05,
  });
}

function marketStall(p: Placer, x: number, z: number, house: House): void {
  for (const [dx, dz] of [[-1, -1], [1, -1], [-1, 1], [1, 1]] as Array<[number, number]>) {
    p("Stall Post", x + dx * 1.3, 1.0, z + dz * 1.0, 0.12, 2.0, 0.12, [0.36, 0.26, 0.16], { tile: T.WOOD });
  }
  p("Stall Table", x, 0.9, z, 2.8, 0.14, 2.0, [0.44, 0.32, 0.2], { tile: T.WOOD });
  p("Stall Awning", x, 2.2, z, 3.2, 0.12, 2.5, house.cloth, { tile: T.CLOTH, pitch: 0.18, repeat: 2 });
  p("Stall Goods", x - 0.6, 1.12, z, 0.7, 0.34, 0.7, [0.78, 0.66, 0.36], { tile: T.CLOTH });
  p("Stall Crates", x + 0.8, 1.08, z + 0.2, 0.6, 0.42, 0.6, [0.5, 0.36, 0.22], { tile: T.WOOD });
}

function statue(p: Placer, house: House, x: number, z: number): void {
  p("Statue Plinth", x, 0.6, z, 2.0, 1.2, 2.0, [0.95, 0.95, 0.95], { tile: T.MARBLE, repeat: 2 });
  p("Statue Legs", x, 1.5, z, 0.6, 0.8, 0.5, [0.92, 0.92, 0.9], { tile: T.MARBLE });
  p("Statue Torso", x, 2.4, z, 0.9, 1.1, 0.6, [0.95, 0.95, 0.93], { tile: T.MARBLE });
  p("Statue Cloak", x, 2.3, z - 0.35, 1.1, 1.5, 0.2, [0.9, 0.9, 0.88], { tile: T.MARBLE });
  p("Statue Head", x, 3.15, z, 0.45, 0.45, 0.45, [0.96, 0.96, 0.94], { tile: T.MARBLE });
  p("Statue Sword", x + 0.7, 2.3, z + 0.1, 0.14, 2.2, 0.14, [0.9, 0.9, 0.88], {
    tile: T.MARBLE, pitch: 0.16,
  });
  p("Statue Banner", x - 1.5, 2.6, z + 0.4, 0.2, 3.2, 0.2, [0.9, 0.9, 0.88], { tile: T.MARBLE });
  p("Statue Banner Cloth", x - 1.5, 3.0, z + 1.1, 0.08, 1.8, 1.5, house.banner, {
    tile: house.heraldry, emissive: 0.04,
  });
}

function cottage(p: Placer, x: number, z: number, w: number, d: number, h: number, house: House, yaw: number): void {
  const c = Math.cos(yaw);
  const s = Math.sin(yaw);
  const at = (lx: number, lz: number): [number, number] => [x + lx * c + lz * s, z - lx * s + lz * c];
  const wall: Rgb = [1, 1, 1];
  p("Cottage", x, h / 2, z, w, h, d, wall, { tile: T.RUBBLE, repeat: 3, yaw, solid: true });
  p("Cottage Plinth", x, 0.3, z, w + 0.3, 0.6, d + 0.3, [0.95, 0.95, 0.95], {
    tile: T.RUBBLE, repeat: 3, yaw,
  });
  hipRoofAround(p, x, z, yaw, w / 2 + 0.3, d / 2 + 0.3, 1.9, h, house.roof, house.roofTint);
  // door, household arms and windows on the front face
  const [dx, dz] = at(0, d / 2 + 0.09);
  p("Cottage Door", dx, 1.05, dz, 1.2, 2.1, 0.18, [0.3, 0.2, 0.13], { tile: T.OAK, yaw });
  p("Cottage Arms", dx, 2.44, dz + 0.02, 0.46, 0.46, 0.1, house.banner, {
    tile: house.heraldry, yaw, emissive: 0.04,
  });
  const [wx, wz] = at(w / 2 - 0.9, d / 2 + 0.1);
  p("Cottage Window", wx, 1.5, wz, 0.9, 0.8, 0.16, WARM_WINDOW, { tile: T.CLOTH, emissive: 0.55, yaw });
  const [cx, cz] = at(-w / 2 + 0.7, -d / 4);
  p("Cottage Chimney", cx, h + 1.1, cz, 0.7, 2.4, 0.7, [0.96, 0.96, 0.94], { tile: T.RUBBLE, yaw });
  // woodpile and a haystack
  const [hx, hz] = at(w / 2 + 1.1, -d / 3);
  p("Haystack", hx, 0.8, hz, 1.7, 1.6, 1.7, [0.95, 0.88, 0.68], { tile: T.THATCH, yaw });
  const [px2, pz2] = at(-w / 2 - 0.9, d / 3);
  p("Woodpile", px2, 0.4, pz2, 1.4, 0.8, 1.0, [0.6, 0.45, 0.3], { tile: T.WOOD, yaw });
}

/** Hipped roof placed in world space at an arbitrary yaw. */
function hipRoofAround(
  p: Placer, cx: number, cz: number, yaw: number,
  halfW: number, halfD: number, height: number, baseY: number,
  tile: number, tint: Rgb,
): void {
  const width = 2 * Math.max(halfW, halfD) + 0.5;
  const c = Math.cos(yaw);
  const s = Math.sin(yaw);
  const faces: Array<{ faceYaw: number; half: number; dx: number; dz: number }> = [
    { faceYaw: 0, half: halfD, dx: 0, dz: 1 },
    { faceYaw: Math.PI, half: halfD, dx: 0, dz: -1 },
    { faceYaw: Math.PI / 2, half: halfW, dx: 1, dz: 0 },
    { faceYaw: -Math.PI / 2, half: halfW, dx: -1, dz: 0 },
  ];
  for (const face of faces) {
    const lx = face.dx * (face.half + 0.2) * 0.5;
    const lz = face.dz * (face.half + 0.2) * 0.5;
    const x = cx + lx * c + lz * s;
    const z = cz - lx * s + lz * c;
    p("Cottage Roof", x, baseY + height * 0.5, z, width, 0.2, Math.hypot(face.half, height),
      tint, {
        tile, repeat: 2, yaw: yaw + face.faceYaw, pitch: Math.atan2(height, face.half),
      });
  }
}

function townhouse(
  p: Placer, x: number, z: number, house: House, yaw: number,
  w: number, d: number, floors: number,
): void {
  const floorH = 3.0;
  const c = Math.cos(yaw);
  const s = Math.sin(yaw);
  const at = (lx: number, lz: number): [number, number] => [x + lx * c + lz * s, z - lx * s + lz * c];

  const stoneGround = house.style === "northern" || house.style === "river";
  p("Townhouse Ground", x, floorH * 0.5, z, w, floorH, d, [1, 1, 1], {
    tile: stoneGround ? house.stone : T.PLASTER, repeat: 3, yaw, solid: true,
  });
  // jettied upper floors, each slightly wider than the one below
  for (let f = 1; f < floors; f++) {
    const y = floorH * f + 1.5;
    p("Townhouse Floor", x, y, z, w + 0.45 * f, floorH, d + 0.45 * f, mul(house.stoneTint, 1.02), {
      tile: house.style === "steppe" ? T.MUD : T.PLASTER, repeat: 3, yaw, solid: f === 1,
    });
    p("Townhouse Beam", x, y - floorH / 2 + 0.1, z, w + 0.5 * f, 0.24, d + 0.5 * f, [0.36, 0.25, 0.16], {
      tile: T.OAK, yaw,
    });
  }
  const top = floorH * floors;
  hipRoofAround(p, x, z, yaw, w / 2 + 0.35, d / 2 + 0.35, 2.4, top, house.roof, house.roofTint);

  // door, awning and lit windows on the street face
  const [doorX, doorZ] = at(0, d / 2 + 0.1);
  p("Townhouse Door", doorX, 1.15, doorZ, 1.3, 2.3, 0.2, [0.32, 0.22, 0.14], { tile: T.OAK, yaw });
  const [awnX, awnZ] = at(0, d / 2 + 0.75);
  p("Townhouse Awning", awnX, 2.7, awnZ, w * 0.8, 0.12, 1.5, house.cloth, {
    tile: T.CLOTH, repeat: 2, pitch: 0.24, yaw,
  });
  for (let f = 0; f < floors; f++) {
    for (const side of [-1, 1]) {
      const [wx, wz] = at(side * (w / 4), d / 2 + 0.28 + 0.22 * f);
      p("Townhouse Window", wx, floorH * f + 1.8, wz, 0.9, 1.2, 0.16, WARM_WINDOW, {
        tile: T.CLOTH, emissive: f === 0 ? 0.5 : 0.62, yaw,
      });
      const [sx, sz] = at(side * (w / 4 + 0.72), d / 2 + 0.3);
      p("Townhouse Shutter", sx, floorH * f + 1.8, sz, 0.42, 1.2, 0.12, house.cloth, {
        tile: T.WOOD, yaw,
      });
    }
  }
  const [chX, chZ] = at(w / 3, -d / 3);
  p("Townhouse Chimney", chX, top + 1.4, chZ, 0.8, 2.8, 0.8, [1, 1, 1], {
    tile: house.stone, repeat: 2, yaw,
  });
}

function palisade(
  p: Placer, cx: number, cz: number, radius: number, segments: number,
  height: number, gapAngle: number,
): void {
  for (let i = 0; i < segments; i++) {
    const a = (i / segments) * Math.PI * 2;
    if (Math.abs(a - Math.PI * 2) < gapAngle || Math.abs(a) < gapAngle) continue;
    const x = cx + Math.sin(a) * radius;
    const z = cz + Math.cos(a) * radius;
    p("Palisade Post", x, height / 2, z, 1.5, height, 0.4, [0.42, 0.32, 0.2], {
      tile: T.OAK, yaw: a,
    });
    p("Palisade Point", x, height + 0.25, z, 1.2, 0.5, 0.36, [0.48, 0.36, 0.23], {
      tile: T.OAK, yaw: a,
    });
  }
  p("Palisade Rail", cx, height * 0.55, cz, 0.3, 0.25, radius * 2, [0.36, 0.27, 0.17], {
    tile: T.OAK, yaw: 0,
  });
  p("Palisade Rail", cx, height * 0.55, cz, radius * 2, 0.25, 0.3, [0.36, 0.27, 0.17], {
    tile: T.OAK, yaw: 0,
  });
}

// ------------------------------------------------------------- settlement API

export function buildSettlement(b: Builder, site: Site, house: House): void {
  const p = frameAt(b, `Settlement · ${site.name}`, site.x, site.z, 0);
  const random = () => b.random();

  // Courtyard paving shared by every settlement.
  const yard: Rgb = mul(house.stoneTint, 0.92);
  p("Courtyard", 0, 0.03, 0, site.kind === "castle" ? 28 : site.kind === "city" ? 34 : 15,
    0.08, site.kind === "castle" ? 28 : site.kind === "city" ? 34 : 13, yard, {
      tile: house.stone, repeat: site.kind === "castle" ? 9 : 6, emissive: 0.03,
    });

  if (site.kind === "castle") {
    buildCastle(p, house);
  } else if (site.kind === "city") {
    buildCity(p, house, random);
  } else if (site.kind === "town") {
    buildTown(p, house, random);
  } else {
    buildVillage(p, house, random);
  }
}

function buildCastle(p: Placer, house: House): void {
  const radius = 15;
  // curtain wall square
  const wallYaw = [0, Math.PI / 2];
  for (const yaw of wallYaw) {
    for (const side of [-1, 1]) {
      // place the wall in the settlement frame by rotating its own local x
      const length = radius * 2;
      const c = Math.cos(yaw);
      const s = Math.sin(yaw);
      const lx = 0, lz = side * radius;
      const x = lx * c + lz * s;
      const z = -lx * s + lz * c;
      curtainWallAt(p, x, z, yaw + Math.PI / 2, length, 7.2 * house.stature, 1.5,
        house.stone, house.stoneTint, "Curtain");
    }
  }
  // towers at the four corners
  const corner = radius * 0.72;
  for (const sx of [-1, 1]) {
    for (const sz of [-1, 1]) {
      drumTower(p, sx * corner, sz * corner, {
        radius: 2.6, height: 14 * house.stature, top: "crenel",
        stone: house.stone, tint: house.stoneTint,
        roof: house.roof, roofTint: house.roofTint,
        name: "Corner Tower",
      });
    }
  }

  gatehouseAround(p, 0, radius, 0, 11, 7.2 * house.stature, house);

  // inner bailey details
  well(p, -9, 7.5);
  marketStall(p, 9.5, 7.5, house);
  brazier(p, -4.5, 9.5);
  brazier(p, 4.5, 9.5);
  bannerPole(p, house, -9.5, -3.5, 8.5);
  p("Stable", 10.5, 1.5, -6.5, 5.5, 3.0, 3.6, mul(house.stoneTint, 0.96), {
    tile: house.style === "steppe" ? T.OAK : house.stone, repeat: 3, solid: true,
  });
  hipRoofAround(p, 10.5, -6.5, 0, 3.0, 2.0, 1.4, 3.0,
    house.style === "steppe" ? T.THATCH : house.roof, house.roofTint);
  p("Stable Door", 10.5, 1.2, -4.6, 2.2, 2.2, 0.2, [0.3, 0.21, 0.13], { tile: T.OAK });

  // the keep itself
  switch (house.style) {
    case "northern": keepNorthern(p, house); break;
    case "river": keepRiver(p, house); break;
    case "desert": keepDesert(p, house); break;
    case "steppe": keepSteppe(p, house); break;
    case "highland": keepHighland(p, house); break;
    default: keepNorthern(p, house); break;
  }
}

/** Curtain wall in the settlement frame, rotated to face outward along `yaw`. */
function curtainWallAt(
  p: Placer, cx: number, cz: number, yaw: number,
  length: number, height: number, thickness: number,
  stone: number, tint: Rgb, label: string,
): void {
  const c = Math.cos(yaw);
  const s = Math.sin(yaw);
  const at = (lx: number, lz: number): [number, number] => [cx + lx * c + lz * s, cz - lx * s + lz * c];

  p(`${label} Wall`, cx, height * 0.5, cz, length, height, thickness, tint, {
    tile: stone, repeat: Math.max(4, Math.round(length / 2.4)),
    repeatY: Math.max(2, Math.round(height / 2.4)), yaw, solid: true,
  });
  p(`${label} Walk`, cx, height + 0.12, cz, length + 0.5, 0.26, thickness + 0.5,
    mul(tint, 1.05), {
      tile: stone, repeat: Math.max(4, Math.round(length / 2.4)), yaw,
    });
  p(`${label} Footing`, cx, 0.4, cz, length + 1.0, 0.8, thickness + 0.8, mul(tint, 0.9), {
    tile: stone, repeat: Math.max(4, Math.round(length / 2.4)), yaw,
  });
  const count = Math.max(4, Math.round(length / 2.6));
  for (let i = 0; i < count; i++) {
    const lx = -length / 2 + (i + 0.5) * (length / count);
    const [x, z] = at(lx, 0);
    p(`${label} Merlon`, x, height + 0.8, z, 1.1, 1.0, thickness * 0.8, mul(tint, 1.02), {
      tile: stone, yaw,
    });
  }
  const slits = Math.max(2, Math.round(length / 7));
  for (let i = 0; i < slits; i++) {
    const lx = -length / 2 + ((i + 0.5) / slits) * length;
    const [x, z] = at(lx, thickness * 0.5);
    p(`${label} Loophole`, x, height * 0.55, z, 0.16, 1.1, 0.7, [0.06, 0.06, 0.07], {
      yaw, emissive: 0,
    });
  }
}

/** Gatehouse placed in the settlement frame and rotated. */
function gatehouseAround(
  p: Placer, cx: number, cz: number, yaw: number,
  width: number, height: number, house: House,
): void {
  const c = Math.cos(yaw);
  const s = Math.sin(yaw);
  const at = (lx: number, lz: number): [number, number] => [cx + lx * c + lz * s, cz - lx * s + lz * c];
  const stone = house.stone;
  const tint = house.stoneTint;

  for (const side of [-1, 1]) {
    p("Gatehouse Tower", cx + side * (width / 2) * c, height * 0.5 + 0.4,
      cz - side * (width / 2) * s, 4.4, height + 1.2, 4.0, mul(tint, 1.02), {
        tile: stone, repeat: 5, yaw, solid: true,
      });
    const [mx, mz] = at(side * (width / 2), 0);
    for (let i = 0; i < 3; i++) {
      p("Gatehouse Merlon", mx - 1.2 + i * 1.2, height + 1.6, mz, 0.8, 0.9, 3.6, mul(tint, 1.06), {
        tile: stone, yaw,
      });
    }
    const [bx, bz] = at(side * (width / 2), 2.2);
    p("Gate Brazier", bx, 1.3, bz, 0.5, 0.5, 0.5, [1, 0.64, 0.24], { emissive: 0.9, yaw });
  }
  p("Gate Lintel", cx, height + 0.9, cz, width + 1.2, 1.6, 4.2, mul(tint, 1.04), {
    tile: stone, repeat: 5, yaw,
  });
  // recessed passage
  p("Gate Passage", cx, 2.4, cz, 4.6, 4.8, 3.2, [0.1, 0.09, 0.09], { emissive: 0, yaw });
  for (let i = -2; i <= 2; i++) {
    const [x, z] = at(i * 0.9, 1.3);
    p("Portcullis Bar", x, 2.2, z, 0.12, 4.2, 0.12, [0.26, 0.27, 0.3], { tile: T.IRON, yaw });
  }
  for (let j = 0; j < 5; j++) {
    const [x, z] = at(0, 1.3);
    p("Portcullis Rail", x, 0.6 + j * 0.85, z, 4.3, 0.12, 0.12, [0.26, 0.27, 0.3], {
      tile: T.IRON, yaw,
    });
  }
  for (let i = 0; i < 4; i++) {
    const [x, z] = at(0, 2.6 + i * 0.9);
    p("Drawbridge Plank", x, 0.1 + i * 0.02, z, 4.4, 0.14, 0.85, [0.42, 0.3, 0.2], {
      tile: T.WOOD, repeat: 2, yaw,
    });
  }
  const [sx2, sz2] = at(-2.8, 2.0);
  p("Gate Standard", sx2, height + 3.4, sz2, 0.14, 5.0, 0.14, [0.3, 0.22, 0.15], { tile: T.WOOD, yaw });
  const [fx, fz] = at(-2.8, 2.9);
  p("Gate Banner", fx, height + 4.6, fz, 0.05, 2.2, 2.0, house.banner, {
    tile: house.heraldry, emissive: 0.06, yaw,
  });
}

function buildCity(p: Placer, house: House, random: () => number): void {
  // inner ring wall with four towers
  const radius = 18;
  for (const yaw of [0, Math.PI / 2]) {
    for (const side of [-1, 1]) {
      const c = Math.cos(yaw);
      const s = Math.sin(yaw);
      const lz = side * radius;
      curtainWallAt(p, lz * s, lz * c, yaw + Math.PI / 2, radius * 2, 6.4, 1.3,
        house.stone, house.stoneTint, "City Wall");
    }
  }
  for (const sx of [-1, 1]) {
    for (const sz of [-1, 1]) {
      drumTower(p, sx * radius * 0.72, sz * radius * 0.72, {
        radius: 2.2, height: 12, top: house.style === "desert" ? "dome" : "cone",
        stone: house.stone, tint: house.stoneTint,
        roof: house.roof, roofTint: house.roofTint, name: "City Tower",
      });
    }
  }
  gatehouseAround(p, 0, radius, 0, 10, 6.4, house);

  // the civic heart
  if (house.style === "river" || house.style === "northern") {
    p("Civic Hall", 0, 4.2, -5, 14, 8.4, 8, mul(house.stoneTint, 1.02), {
      tile: house.stone, repeat: 6, solid: true,
    });
    hipRoof(p, 7.4, 4.4, 4.0, 8.4, house.roof, house.roofTint);
    for (let i = 0; i < 4; i++) {
      p("Civic Window", -4.5 + i * 3, 6.0, -1.05, 1.2, 2.4, 0.16, WARM_WINDOW, {
        tile: T.CLOTH, emissive: 0.7,
      });
    }
    p("Civic Door", 0, 1.9, -1.0, 2.6, 3.4, 0.2, [0.3, 0.21, 0.14], { tile: T.OAK });
    for (let i = 0; i < 6; i++) {
      p("Civic Column", -6 + i * 2.4, 2.6, -0.6, 0.5, 5.0, 0.5, [0.98, 0.98, 0.96], {
        tile: T.MARBLE, repeat: 2,
      });
    }
    spire(p, 2.2, 2.2, 6.0, 8.4, house.roof, house.roofTint, house.trim);
    p("Bell Tower", 0, 4.4, -5, 4.6, 8.8, 4.4, mul(house.stoneTint, 1.04), {
      tile: house.stone, repeat: 5,
    });
  } else if (house.style === "desert") {
    p("Grand Mosque", 0, 4.6, -5, 13, 9.2, 9, mul(house.stoneTint, 1.02), {
      tile: house.stone, repeat: 6, solid: true,
    });
    onionDome(p, 4.2, 4.8, 9.2, mul(house.roofTint, 1.03));
    p("Mosque Arcade", 0, 2.4, -0.4, 12, 0.6, 1.4, house.trim, {
      tile: T.GOLD, repeat: 6, emissive: 0.16,
    });
    for (let i = -3; i <= 3; i++) {
      p("Mosque Pier", i * 1.9, 1.6, -0.4, 0.6, 3.2, 0.9, mul(house.stoneTint, 1.04), {
        tile: house.stone,
      });
    }
    p("Mosque Door", 0, 2.0, -0.3, 2.4, 3.6, 0.2, [0.3, 0.22, 0.14], { tile: T.OAK });
    for (const sx of [-1, 1]) {
      p("Mosque Minaret", sx * 7.6, 8.0, -8, 2.0, 16, 2.0, mul(house.stoneTint, 1.02), {
        tile: house.stone, repeat: 6,
      });
      onionDome(p, 1.4, 1.8, 16.2, mul(house.roofTint, 1.04));
    }
  } else if (house.style === "steppe") {
    p("Great Tent", 0, 3.4, -5, 13, 6.8, 11, [0.86, 0.8, 0.68], { tile: T.CLOTH, repeat: 4, solid: true });
    coneRoof(p, 7.6, 4.4, 6.8, T.THATCH, [1, 0.94, 0.8]);
    p("Tent Door", 0, 1.9, 0.6, 2.6, 3.6, 0.3, [0.34, 0.24, 0.15], { tile: T.OAK });
    p("Tent Banner", 0, 9.4, -5, 0.12, 1.4, 2.0, house.banner, {
      tile: house.heraldry, emissive: 0.05,
    });
    for (const sx of [-1, 1]) {
      p("Camp Standard", sx * 6.5, 4.5, 2.5, 0.14, 9.0, 0.14, [0.32, 0.23, 0.15], { tile: T.WOOD });
      p("Standard Pelt", sx * 6.5, 6.0, 3.4, 0.1, 2.4, 1.8, house.banner, {
        tile: house.heraldry, emissive: 0.05,
      });
    }
  } else {
    p("Clan Hall", 0, 3.2, -5, 13, 6.4, 9, mul(house.stoneTint, 0.96), {
      tile: house.stone, repeat: 5, solid: true,
    });
    hipRoof(p, 7.2, 5.2, 4.2, 6.4, house.roof, house.roofTint);
    p("Clan Door", 0, 1.9, -0.4, 2.4, 3.4, 0.2, [0.3, 0.21, 0.14], { tile: T.OAK });
    p("Clan Fire", 0, 1.0, 2.5, 2.2, 1.4, 2.2, [1, 0.6, 0.24], { emissive: 0.85 });
    drumTower(p, 8.5, -8.5, {
      radius: 2.8, height: 14, top: "crenel", stone: house.stone, tint: house.stoneTint,
      roof: house.roof, roofTint: house.roofTint, name: "Clan Tower",
    });
  }

  // townhouses lining a street
  const rows = 8;
  for (let i = 0; i < rows; i++) {
    const side = i % 2 === 0 ? -1 : 1;
    const index = Math.floor(i / 2);
    const z = -12 + index * 6.2;
    const x = side * 7.6;
    const w = 4.6 + random() * 1.2;
    townhouse(p, x, z, house, side > 0 ? Math.PI / 2 : -Math.PI / 2, w, 4.2, random() > 0.55 ? 3 : 2);
  }
  well(p, 0, 7.0);
  marketStall(p, -4.2, 8.6, house);
  marketStall(p, 4.2, 8.6, house);
  statue(p, house, 0, 3.5);
  brazier(p, -2.6, 5.2);
  brazier(p, 2.6, 5.2);
}

function buildTown(p: Placer, house: House, random: () => number): void {
  if (house.style === "steppe" || house.style === "highland") {
    palisade(p, 0, 0, 11.5, 22, 3.2, 0.28);
  }
  const rows = 5;
  for (let i = 0; i < rows; i++) {
    const side = i % 2 === 0 ? -1 : 1;
    const z = -6 + Math.floor(i / 2) * 6;
    townhouse(p, side * 6.2, z, house, side > 0 ? Math.PI / 2 : -Math.PI / 2, 4.4 + random(), 4.4, 2);
  }
  well(p, 0, 1.5);
  marketStall(p, -2.4, 4.6, house);
  marketStall(p, 2.4, 4.6, house);
  brazier(p, 0, -3.4);
  bannerPole(p, house, -4.4, -6.6, 7.5);
  // chapel / shrine
  p("Chapel", 0, 2.4, 9.0, 5.0, 4.8, 4.4, mul(house.stoneTint, 1.02), {
    tile: house.stone, repeat: 3, solid: true,
  });
  hipRoofAround(p, 0, 9.0, 0, 2.8, 2.4, 2.6, 4.8, house.roof, house.roofTint);
  p("Chapel Door", 0, 1.5, 11.15, 1.6, 2.6, 0.2, [0.3, 0.21, 0.14], { tile: T.OAK });
  p("Chapel Window", 0, 3.0, 11.18, 1.0, 1.6, 0.14, WARM_WINDOW, { tile: T.CLOTH, emissive: 0.6 });
  p("Chapel Bell", 1.2, 5.4, 8.0, 0.6, 0.7, 0.6, [0.84, 0.68, 0.34], { tile: T.BRONZE, emissive: 0.1 });
}

function buildVillage(p: Placer, house: House, random: () => number): void {
  const cottages = 4;
  for (let i = 0; i < cottages; i++) {
    const a = (i / cottages) * Math.PI * 2 + 0.55;
    const distance = 6.2 + random() * 1.6;
    cottage(
      p, Math.sin(a) * distance, Math.cos(a) * distance,
      4.2 + random() * 1.4, 3.4 + random() * 0.8, 2.5 + random() * 0.5,
      house, -a,
    );
  }
  well(p, 0, 0.5);
  // fence ring
  for (let i = 0; i < 26; i++) {
    const a = (i / 26) * Math.PI * 2;
    if (Math.abs(a - 0.55) < 0.14) continue;
    p("Fence Post", Math.sin(a) * 10.5, 0.55, Math.cos(a) * 10.5, 0.18, 1.1, 0.18,
      [0.42, 0.32, 0.2], { tile: T.WOOD });
  }
  for (const y of [0.55, 0.9]) {
    p("Fence Rail", 0, y, 0, 0.12, 0.12, 21, [0.42, 0.32, 0.2], { tile: T.WOOD });
    p("Fence Rail", 0, y, 0, 21, 0.12, 0.12, [0.42, 0.32, 0.2], { tile: T.WOOD });
  }
  bannerPole(p, house, -2.6, 3.2, 6.5);
  brazier(p, 2.6, 3.2);
}
