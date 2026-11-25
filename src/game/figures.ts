// Character and weapon rigs.
//
// A soldier is not one box: it is boots, legs, a cuirass built for its house's
// armour tradition, pauldrons, a heraldic tabard, a head with a helmet, a cape,
// a shield and a signature weapon held in the right hand. Roughly twenty
// instances per figure, all still inside the engine's single draw call.
//
// Everything is authored in the figure's local space (forward = +z) and rotated
// into the world by yaw, so the rig composes with movement and combat.

import type { Instance } from "../engine/renderer";
import { ATLAS_TILE as T } from "../engine/textures";
import type { House, Rgb } from "./houses";

export type FigureSpec = {
  id: number;
  x: number;
  z: number;
  yaw: number;
  house: House;
  faction: "player" | "ally" | "enemy";
  hp: number;
  maxHp: number;
  /** 0 = weapon at rest, 1 = end of the strike */
  swing: number;
  moving: boolean;
  time: number;
  selected: boolean;
  /** damage flash, 0..1 */
  flash: number;
  /** townsfolk carry no weapon and no shield */
  civilian: boolean;
};

const SKIN: Rgb = [0.82, 0.68, 0.54];
const SKIN_DARK: Rgb = [0.62, 0.47, 0.36];
const BOOT: Rgb = [0.26, 0.19, 0.14];
const EYE: Rgb = [0.12, 0.1, 0.09];

type PartOptions = {
  tile?: number;
  repeat?: number;
  pitch?: number;
  yaw?: number;
  emissive?: number;
  highlight?: boolean;
};

export function emitFigure(out: Instance[], f: FigureSpec): void {
  const { x, z, yaw, house } = f;
  const cos = Math.cos(yaw);
  const sin = Math.sin(yaw);

  /** Local (left/right, forward) offset to world. */
  const world = (lx: number, lz: number) => ({
    x: x + lx * cos + lz * sin,
    z: z - lx * sin + lz * cos,
  });

  const part = (
    lx: number, ly: number, lz: number,
    sx: number, sy: number, sz: number,
    color: Rgb, options: PartOptions = {},
  ) => {
    const p = world(lx, lz);
    out.push({
      x: p.x, y: ly, z: p.z,
      yaw: yaw + (options.yaw ?? 0),
      pitch: options.pitch ?? 0,
      sx, sy, sz,
      color,
      tile: options.tile ?? -1,
      repeat: options.repeat ?? 1,
      emissive: (options.emissive ?? 0.02) + f.flash * 0.75,
      selected: options.highlight ? f.selected : false,
    });
  };

  // ------------------------------------------------------------ animation
  const phase = f.time * 9 + f.id * 0.7;
  const stride = f.moving ? Math.sin(phase) : 0;
  const bob = f.moving ? Math.abs(Math.cos(phase)) * 0.045 : Math.sin(f.time * 1.7 + f.id) * 0.012;
  const swing = Math.min(1, Math.max(0, f.swing));
  // Fast wind-up, faster follow-through.
  const swingEase = swing < 0.35 ? (swing / 0.35) * 0.35 : 0.35 + ((swing - 0.35) / 0.65) * 0.65;
  const lean = swing > 0.2 ? (swing - 0.2) * 0.22 : 0;

  const base = 0.06;

  if (f.civilian) {
    // Townsfolk: a hooded tunic, an apron and a basket. No steel, no banner.
    for (const side of [-1, 1]) {
      const legLift = stride * side * 0.3;
      part(side * 0.12, 0.32 + bob, legLift * 0.3, 0.14, 0.46, 0.15, [0.36, 0.3, 0.24], {
        tile: T.CLOTH, pitch: legLift * 0.45,
      });
      part(side * 0.12, 0.07, 0.03, 0.15, 0.14, 0.26, BOOT, { tile: T.LEATHER });
    }
    part(0, 1.0 + bob, 0, 0.46, 0.78, 0.3, house.cloth, { tile: T.CLOTH, repeat: 2, highlight: true });
    part(0, 0.94 + bob, 0.16, 0.28, 0.5, 0.04, [0.86, 0.82, 0.72], { tile: T.CLOTH });
    part(0, 1.42 + bob, 0.02, 0.3, 0.1, 0.3, house.banner, { tile: T.CLOTH });
    part(0, 1.58 + bob, 0.01, 0.27, 0.28, 0.26, SKIN, {});
    part(0, 1.7 + bob, -0.01, 0.3, 0.2, 0.3, [0.34, 0.3, 0.28], { tile: T.CLOTH });
    part(0, 1.7 + bob, 0.14, 0.24, 0.08, 0.12, [0.3, 0.26, 0.24], { tile: T.CLOTH, pitch: 0.2 });
    for (const side of [-1, 1]) {
      part(side * 0.26, 1.12 + bob, 0.02 + (side === 1 ? stride * 0.1 : 0), 0.12, 0.42, 0.14,
        SKIN, { pitch: stride * side * 0.2 });
    }
    part(0.34, 0.86 + bob, 0.14, 0.3, 0.24, 0.24, [0.62, 0.48, 0.3], { tile: T.WOOD });
    if (f.hp < f.maxHp) {
      const ratio = Math.max(0, Math.min(1, f.hp / f.maxHp));
      part(0, 1.98 + bob, 0, 0.9, 0.1, 0.06, [0.12, 0.1, 0.09], {});
      part(-0.45 + 0.45 * ratio, 1.98 + bob, 0.01, 0.9 * ratio, 0.1, 0.08, [0.72, 0.2, 0.16], {
        emissive: 0.25,
      });
    }
    return;
  }

  // ------------------------------------------------------------- footing
  part(0, base, 0, 0.92, 0.025, 0.92, f.selected ? [0.95, 0.78, 0.28] : house.cloth, {
    emissive: f.selected ? 0.45 : 0.06,
  });

  for (const side of [-1, 1]) {
    const legLift = stride * side * 0.34;
    part(side * 0.13, 0.34 + bob + Math.abs(legLift) * 0.06, legLift * 0.35, 0.155, 0.5, 0.17,
      f.faction === "enemy" ? [0.3, 0.24, 0.18] : [0.32, 0.33, 0.36], {
        tile: house.armour === "plate" ? T.STEEL : T.LEATHER,
        pitch: legLift * 0.5,
      });
    part(side * 0.13, 0.09, 0.04 + legLift * 0.35, 0.17, 0.16, 0.29, BOOT, {
      tile: T.LEATHER, pitch: legLift * 0.5,
    });
  }

  // ---------------------------------------------------------------- torso
  const torsoY = 1.06 + bob;
  const shoulder = 1.36 + bob;

  if (house.armour === "plate") {
    part(0, torsoY, 0, 0.5, 0.66, 0.34, [0.78, 0.82, 0.9], { tile: T.STEEL, repeat: 1, highlight: true });
    part(0, 0.8 + bob, 0, 0.46, 0.16, 0.36, [0.68, 0.72, 0.8], { tile: T.STEEL });
    for (const side of [-1, 1]) {
      part(side * 0.3, shoulder, 0, 0.2, 0.2, 0.3, [0.86, 0.9, 0.96], { tile: T.STEEL });
      part(side * 0.3, shoulder - 0.16, 0, 0.16, 0.16, 0.26, [0.62, 0.66, 0.74], { tile: T.STEEL });
    }
    // heraldic tabard over the breastplate
    part(0, 1.08 + bob, 0.2, 0.28, 0.46, 0.05, house.banner, { tile: house.heraldry });
  } else if (house.armour === "mail") {
    part(0, torsoY, 0, 0.46, 0.68, 0.32, [0.72, 0.76, 0.82], { tile: T.CHAIN, repeat: 2 });
    part(0, shoulder, 0, 0.54, 0.16, 0.38, [0.66, 0.7, 0.78], { tile: T.CHAIN, repeat: 2 });
    part(0, 1.1 + bob, 0.19, 0.34, 0.56, 0.05, house.banner, { tile: house.heraldry });
    part(0, 0.86 + bob, 0, 0.48, 0.1, 0.36, [0.32, 0.22, 0.14], { tile: T.LEATHER });
  } else if (house.armour === "leather") {
    part(0, torsoY, 0, 0.5, 0.62, 0.32, [0.62, 0.44, 0.28], { tile: T.LEATHER, highlight: true });
    for (let band = 0; band < 3; band++) {
      part(0, 0.92 + band * 0.16 + bob, 0, 0.54, 0.07, 0.34, [0.66, 0.68, 0.72], { tile: T.IRON });
    }
    part(0, 1.05 + bob, 0.18, 0.26, 0.26, 0.05, house.banner, { tile: house.heraldry });
    // wolf pelt over one shoulder
    part(-0.26, shoulder + 0.04, -0.02, 0.3, 0.22, 0.4, [0.42, 0.36, 0.3], { tile: T.FUR });
  } else if (house.armour === "lamellar") {
    part(0, torsoY, 0, 0.5, 0.66, 0.34, [0.96, 0.78, 0.4], { tile: T.BRONZE, highlight: true });
    for (let band = 0; band < 4; band++) {
      part(0, 0.86 + band * 0.17 + bob, 0, 0.52, 0.12, 0.36, [0.82, 0.68, 0.38], { tile: T.LEATHER });
    }
    part(0, 1.24 + bob, 0, 0.2, 0.2, 0.36, [0.86, 0.7, 0.34], { tile: T.BRONZE });
    part(0, 0.84 + bob, 0.06, 0.58, 0.12, 0.38, house.cloth, { tile: T.CLOTH });
  } else if (house.armour === "fur") {
    part(0, torsoY, 0, 0.58, 0.7, 0.4, [0.44, 0.4, 0.38], { tile: T.FUR, highlight: true });
    part(0, shoulder - 0.02, 0, 0.62, 0.2, 0.42, [0.5, 0.45, 0.42], { tile: T.FUR });
    part(0, 1.02 + bob, 0, 0.34, 0.12, 0.42, [0.3, 0.24, 0.2], { tile: T.LEATHER });
  } else {
    part(0, 1.0 + bob, 0, 0.48, 0.74, 0.32, house.cloth, { tile: T.CLOTH, repeat: 2, highlight: true });
    part(0, 0.92 + bob, 0, 0.5, 0.1, 0.34, [0.28, 0.22, 0.17], { tile: T.LEATHER });
    part(0, 1.04 + bob, 0.17, 0.24, 0.24, 0.04, house.banner, { tile: house.heraldry });
    part(0, 1.2 + bob, 0.19, 0.07, 0.07, 0.04, [0.95, 0.8, 0.4], { emissive: 0.35 });
  }

  // pelvis closes the gap between legs and cuirass
  part(0, 0.66 + bob, 0, 0.36, 0.24, 0.3, [0.3, 0.26, 0.22], { tile: T.LEATHER });

  // ----------------------------------------------------------- arms + head
  for (const side of [-1, 1]) {
    const armSwing = side === 1 ? swingEase * 0.9 : -swingEase * 0.35;
    part(side * 0.3, 1.16 + bob, 0.02 + armSwing * 0.1, 0.14, 0.44, 0.16,
      house.armour === "plate" ? [0.8, 0.84, 0.9] : SKIN, {
        tile: house.armour === "plate" ? T.STEEL : house.armour === "fur" ? T.FUR : -1,
        pitch: armSwing * 0.6,
      });
  }

  const headY = 1.64 + bob;
  part(0, headY - 0.16, 0, 0.15, 0.14, 0.15, f.faction === "enemy" ? SKIN_DARK : SKIN, {});
  part(0, headY, 0.01, 0.24, 0.26, 0.24, f.faction === "enemy" ? SKIN_DARK : SKIN, {});
  for (const side of [-1, 1]) {
    part(side * 0.055, headY + 0.03, 0.125, 0.04, 0.04, 0.02, EYE, { emissive: 0 });
  }

  // ------------------------------------------------------------- helmet
  if (house.armour === "plate") {
    part(0, headY + 0.1, 0, 0.28, 0.22, 0.27, [0.84, 0.88, 0.96], { tile: T.STEEL });
    part(0, headY + 0.03, 0.135, 0.25, 0.04, 0.03, [0.1, 0.12, 0.15], { emissive: 0 });
    part(0, headY + 0.23, 0, 0.07, 0.14, 0.1, house.trim, { emissive: 0.08 });
    part(0, headY + 0.32, -0.05, 0.05, 0.12, 0.24, house.banner, { emissive: 0.06 });
  } else if (house.armour === "mail") {
    part(0, headY + 0.08, 0, 0.27, 0.2, 0.26, [0.7, 0.74, 0.8], { tile: T.CHAIN, repeat: 2 });
    part(0, headY + 0.19, 0, 0.36, 0.05, 0.36, [0.8, 0.84, 0.9], { tile: T.STEEL });
    part(0, headY + 0.24, 0, 0.16, 0.07, 0.16, house.trim, { emissive: 0.05 });
  } else if (house.armour === "leather") {
    part(0, headY + 0.1, 0, 0.29, 0.2, 0.29, [0.44, 0.36, 0.28], { tile: T.FUR });
    part(0, headY + 0.21, 0, 0.08, 0.11, 0.08, house.trim, { emissive: 0.05 });
    part(0, headY - 0.05, 0.02, 0.28, 0.13, 0.28, [0.24, 0.18, 0.14], { tile: T.FUR });
  } else if (house.armour === "lamellar") {
    part(0, headY + 0.1, 0, 0.31, 0.23, 0.31, [0.92, 0.9, 0.82], { tile: T.CLOTH, yaw: 0.3 });
    part(0, headY + 0.25, 0, 0.35, 0.08, 0.35, [0.96, 0.92, 0.8], { tile: T.CLOTH });
    part(0, headY + 0.1, 0.17, 0.1, 0.1, 0.04, [1.0, 0.82, 0.36], { tile: T.BRONZE, emissive: 0.14 });
  } else if (house.armour === "fur") {
    part(0, headY + 0.11, 0, 0.31, 0.21, 0.3, [0.46, 0.42, 0.4], { tile: T.FUR });
    part(0, headY + 0.02, 0.125, 0.08, 0.09, 0.22, [0.55, 0.56, 0.6], { tile: T.IRON });
    part(0, headY + 0.26, 0, 0.08, 0.14, 0.08, house.trim, { emissive: 0.05 });
  } else {
    // hooded free-company captain: the face stays visible under a dropped hood
    part(0, headY + 0.22, -0.09, 0.3, 0.14, 0.22, [0.2, 0.21, 0.24], { tile: T.CLOTH, pitch: -0.5 });
    part(0, headY + 0.11, -0.12, 0.28, 0.27, 0.12, [0.2, 0.21, 0.24], { tile: T.CLOTH });
    part(0, headY - 0.06, 0.12, 0.12, 0.05, 0.04, [0.3, 0.24, 0.18], { emissive: 0 });
  }

  // ---------------------------------------------------------------- cloak
  if (house.armour !== "leather") {
    part(0, 1.02 + bob, -0.2 - Math.abs(stride) * 0.03, 0.5, 0.92, 0.06,
      house.armour === "fur" ? [0.44, 0.4, 0.38] : house.cloth, {
        tile: house.armour === "fur" ? T.FUR : T.CLOTH,
        pitch: -0.14 - Math.abs(stride) * 0.08 + lean * 0.4,
        emissive: 0.03,
      });
  }

  // --------------------------------------------------------------- shield
  if (house.shield !== "none" && house.weapon !== "bow") {
    const sx = -0.36;
    const sy = 1.05 + bob;
    const sz = 0.14;
    if (house.shield === "kite") {
      part(sx, sy, sz, 0.4, 0.62, 0.07, house.banner, { tile: house.heraldry, yaw: -0.18 });
      part(sx, sy - 0.36, sz, 0.16, 0.2, 0.06, house.banner, { tile: house.heraldry, yaw: -0.18 });
      part(sx, sy + 0.32, sz - 0.01, 0.42, 0.06, 0.08, [0.7, 0.74, 0.8], { tile: T.STEEL, yaw: -0.18 });
    } else if (house.shield === "heater") {
      part(sx, sy, sz, 0.4, 0.46, 0.07, house.banner, { tile: house.heraldry, yaw: -0.18 });
      part(sx, sy + 0.25, sz, 0.42, 0.06, 0.08, [0.78, 0.72, 0.5], { tile: T.BRONZE, yaw: -0.18 });
    } else {
      part(sx, sy, sz, 0.44, 0.44, 0.08, house.banner, { tile: house.heraldry, yaw: -0.18 });
      part(sx, sy, sz + 0.06, 0.12, 0.12, 0.06, [0.9, 0.76, 0.4], { tile: T.BRONZE, yaw: -0.18 });
      part(sx, sy, sz - 0.03, 0.46, 0.46, 0.03, [0.32, 0.3, 0.28], { tile: T.IRON, yaw: -0.18 });
    }
  }

  // --------------------------------------------------------------- weapon
  emitWeapon(out, f, house, bob, swingEase);

  // ------------------------------------------------------------ health bar
  if (f.hp < f.maxHp) {
    const ratio = Math.max(0, Math.min(1, f.hp / f.maxHp));
    part(0, 2.06 + bob, 0, 0.9, 0.1, 0.06, [0.12, 0.1, 0.09], { emissive: 0.02 });
    part(-0.45 + 0.45 * ratio, 2.06 + bob, 0.01, 0.9 * ratio, 0.1, 0.08, [0.72, 0.2, 0.16], { emissive: 0.25 });
  }
}

/**
 * Weapon rig. The grip sits at the right hand; every piece is placed along the
 * weapon's own axis so a single tilt and sweep angle animates the whole thing.
 */
function emitWeapon(
  out: Instance[],
  f: FigureSpec,
  house: House,
  bob: number,
  swingEase: number,
): void {
  const sweep = (swingEase - 0.35) * 1.5;
  const tilt = 1.75 - swingEase * 2.05;
  const handY = 1.02 + bob;
  const hand = { x: f.x + 0.4 * Math.cos(f.yaw) + 0.1 * Math.sin(f.yaw), z: f.z - 0.4 * Math.sin(f.yaw) + 0.1 * Math.cos(f.yaw) };
  const dirYaw = f.yaw + sweep;
  const ax = Math.sin(dirYaw);
  const az = Math.cos(dirYaw);
  const px = Math.cos(dirYaw);
  const pz = -Math.sin(dirYaw);
  const cosT = Math.cos(tilt);
  const sinT = Math.sin(tilt);

  /** Place a part centred `t` along the weapon axis, `lateral` to the side. */
  const piece = (
    t: number, length: number, width: number, thick: number,
    color: Rgb, tile: number,
    lateral = 0, tiltOffset = 0, emissive = 0.02,
  ) => {
    out.push({
      x: hand.x + ax * sinT * t + px * lateral,
      y: handY + cosT * t,
      z: hand.z + az * sinT * t + pz * lateral,
      yaw: dirYaw,
      pitch: tilt + tiltOffset,
      sx: width, sy: length, sz: thick,
      color, tile, repeat: 1, emissive,
    });
  };

  const steel: Rgb = [0.86, 0.9, 0.98];
  const gold: Rgb = house.trim;
  const glint = swingEase > 0.18 ? 0.28 : 0.04;

  switch (house.weapon) {
    case "longsword": {
      piece(-0.1, 0.12, 0.11, 0.11, gold, T.BRONZE, 0, 0, 0.1);
      piece(0.04, 0.24, 0.08, 0.08, [0.32, 0.22, 0.15], T.LEATHER);
      piece(0.2, 0.09, 0.36, 0.1, gold, T.BRONZE, 0, 0, 0.12);
      if (house.crest === "gem") piece(0.2, 0.1, 0.1, 0.12, [0.3, 0.6, 0.95], T.STEEL, 0, 0, 0.55);
      piece(0.58, 0.66, 0.09, 0.04, steel, T.STEEL, 0, 0, glint);
      piece(0.98, 0.2, 0.06, 0.035, steel, T.STEEL, 0, 0, glint);
      break;
    }
    case "halberd": {
      piece(0.6, 2.1, 0.075, 0.075, [0.56, 0.42, 0.26], T.WOOD);
      piece(1.5, 0.08, 0.1, 0.1, gold, T.BRONZE, 0, 0, 0.1);
      piece(1.58, 0.34, 0.3, 0.05, steel, T.STEEL, 0.16, 0, glint);
      piece(1.74, 0.42, 0.07, 0.06, steel, T.STEEL, 0, 0, glint);
      piece(1.5, 0.16, 0.16, 0.05, steel, T.STEEL, -0.16, 0, glint);
      break;
    }
    case "waraxe": {
      piece(0.45, 0.98, 0.075, 0.075, [0.46, 0.33, 0.2], T.OAK);
      piece(0.86, 0.1, 0.12, 0.12, [0.4, 0.42, 0.46], T.IRON);
      piece(0.95, 0.3, 0.36, 0.07, steel, T.STEEL, 0.13, 0, glint);
      piece(0.79, 0.18, 0.16, 0.07, steel, T.STEEL, 0.1, 0, glint);
      piece(1.1, 0.14, 0.06, 0.06, steel, T.STEEL, 0, 0, 0.1);
      break;
    }
    case "scimitar": {
      piece(-0.06, 0.1, 0.1, 0.1, gold, T.BRONZE, 0, 0, 0.1);
      piece(0.06, 0.22, 0.075, 0.075, [0.4, 0.26, 0.16], T.LEATHER);
      piece(0.2, 0.06, 0.3, 0.1, gold, T.BRONZE, 0, 0, 0.14);
      piece(0.5, 0.42, 0.08, 0.04, steel, T.STEEL, 0, 0.03, glint);
      piece(0.82, 0.36, 0.075, 0.04, steel, T.STEEL, 0, 0.2, glint);
      piece(1.03, 0.24, 0.055, 0.035, steel, T.STEEL, 0, 0.44, glint);
      break;
    }
    case "warhammer": {
      piece(0.5, 1.1, 0.085, 0.085, [0.4, 0.3, 0.2], T.OAK);
      for (const t of [0.18, 0.34, 0.68]) piece(t, 0.07, 0.105, 0.105, [0.44, 0.46, 0.5], T.IRON);
      piece(1.02, 0.3, 0.3, 0.32, steel, T.STEEL, 0, 0, glint);
      piece(1.02, 0.34, 0.1, 0.1, steel, T.STEEL, -0.16, 0, glint);
      piece(0.86, 0.08, 0.34, 0.36, gold, T.BRONZE, 0, 0, 0.1);
      break;
    }
    case "bow": {
      // Held upright, limbs above and below the grip.
      piece(0.08, 0.5, 0.06, 0.06, [0.36, 0.26, 0.18], T.OAK, 0, -tilt);
      piece(0.34, 0.5, 0.05, 0.05, [0.32, 0.24, 0.16], T.OAK, -0.04, -tilt);
      piece(-0.24, 0.5, 0.05, 0.05, [0.32, 0.24, 0.16], T.OAK, 0.04, -tilt);
      piece(0.1, 0.06, 0.14, 0.14, gold, T.BRONZE, 0, -tilt, 0.12);
      piece(0.08, 0.86, 0.015, 0.015, [0.86, 0.82, 0.7], T.CLOTH, -0.1, -tilt);
      // quiver across the back
      out.push({
        x: f.x - 0.16 * Math.cos(f.yaw) - 0.2 * Math.sin(f.yaw),
        y: 1.3 + bob,
        z: f.z + 0.16 * Math.sin(f.yaw) - 0.2 * Math.cos(f.yaw),
        yaw: f.yaw + 0.5, pitch: 0.5,
        sx: 0.16, sy: 0.5, sz: 0.16,
        color: [0.36, 0.26, 0.18], tile: T.LEATHER,
      });
      break;
    }
  }
}
