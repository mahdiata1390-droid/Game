// Forge Engine art atlas.
//
// One 1024x1024 canvas, painted deterministically at boot, holds every surface
// in the game: five stone traditions, three roof systems, four armour
// materials, four weapon metals and eight heraldry devices. Because it is
// generated in code the repository and the download stay binary-free, while
// each house still gets its own dressed masonry and its own coat of arms.
//
// Tiles are painted at high luminance on purpose: instances multiply the
// texture by their albedo, so a single stone tile can become cold granite in
// the north, cream ashlar on the river or sun-baked sandstone in the south.

export const ATLAS_CELL = 128;
export const ATLAS_TILES_PER_ROW = 8;
export const ATLAS_PX = ATLAS_CELL * ATLAS_TILES_PER_ROW;

const CELL = ATLAS_CELL;

type Rand = () => number;
type Painter = (ctx: CanvasRenderingContext2D, rand: Rand) => void;

function mulberry32(seed: number): Rand {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

// ------------------------------------------------------------------ utilities

function gradient(
  ctx: CanvasRenderingContext2D,
  x: number, y: number, w: number, h: number,
  top: string, bottom: string,
): void {
  const g = ctx.createLinearGradient(x, y, x, y + h);
  g.addColorStop(0, top);
  g.addColorStop(1, bottom);
  ctx.fillStyle = g;
  ctx.fillRect(x, y, w, h);
}

function rounded(
  ctx: CanvasRenderingContext2D,
  x: number, y: number, w: number, h: number, r: number,
): void {
  const radius = Math.min(r, w / 2, h / 2);
  ctx.beginPath();
  ctx.moveTo(x + radius, y);
  ctx.lineTo(x + w - radius, y);
  ctx.quadraticCurveTo(x + w, y, x + w, y + radius);
  ctx.lineTo(x + w, y + h - radius);
  ctx.quadraticCurveTo(x + w, y + h, x + w - radius, y + h);
  ctx.lineTo(x + radius, y + h);
  ctx.quadraticCurveTo(x, y + h, x, y + h - radius);
  ctx.lineTo(x, y + radius);
  ctx.quadraticCurveTo(x, y, x + radius, y);
  ctx.closePath();
}

/** Random specks, used for grit, mineral flecks and moss. */
function speck(
  ctx: CanvasRenderingContext2D,
  rand: Rand,
  count: number,
  color: (v: number) => string,
  maxW = 2,
  maxH = 2,
): void {
  for (let i = 0; i < count; i++) {
    ctx.fillStyle = color(rand());
    ctx.fillRect(rand() * CELL, rand() * CELL, 1 + rand() * maxW, 1 + rand() * maxH);
  }
}

/** A dressed stone block: body gradient, lit top edge, shadowed bottom edge. */
function block(
  ctx: CanvasRenderingContext2D,
  x: number, y: number, w: number, h: number,
  base: number, warm = 0,
): void {
  rounded(ctx, x, y, w, h, 1.5);
  const g = ctx.createLinearGradient(x, y, x, y + h);
  const top = Math.round(base + 16);
  const bottom = Math.round(base - 12);
  g.addColorStop(0, `rgb(${top + warm},${top},${top - 6 - warm})`);
  g.addColorStop(1, `rgb(${bottom + warm},${bottom},${bottom - 6 - warm})`);
  ctx.fillStyle = g;
  ctx.fill();
  ctx.fillStyle = "rgba(255,255,255,0.30)";
  ctx.fillRect(x + 1.5, y + 1.5, w - 3, 1.6);
  ctx.fillStyle = "rgba(0,0,0,0.28)";
  ctx.fillRect(x + 1.5, y + h - 3.2, w - 3, 1.8);
}

// -------------------------------------------------------------------- painters

const painters: Painter[] = [
  // 0 · meadow grass
  (ctx, rand) => {
    ctx.fillStyle = "#4c5c35";
    ctx.fillRect(0, 0, CELL, CELL);
    for (let i = 0; i < 1400; i++) {
      const g = 58 + rand() * 44;
      ctx.fillStyle = `rgba(${g * 0.72},${g},${g * 0.46},0.55)`;
      ctx.fillRect(rand() * CELL, rand() * CELL, 3 + rand() * 7, 2 + rand() * 4);
    }
    for (let i = 0; i < 1500; i++) {
      const x = rand() * CELL, y = rand() * CELL;
      const g = 76 + rand() * 46;
      ctx.strokeStyle = `rgba(${g * 0.7},${g},${g * 0.44},${0.1 + rand() * 0.2})`;
      ctx.lineWidth = 1;
      ctx.beginPath();
      ctx.moveTo(x, y);
      ctx.lineTo(x + (rand() - 0.5) * 3, y - 2 - rand() * 4);
      ctx.stroke();
    }
  },
  // 1 · dry grass / steppe
  (ctx, rand) => {
    ctx.fillStyle = "#6d6640";
    ctx.fillRect(0, 0, CELL, CELL);
    for (let i = 0; i < 1100; i++) {
      const g = 120 + rand() * 70;
      ctx.strokeStyle = `rgba(${g},${g * 0.9},${g * 0.52},${0.3 + rand() * 0.45})`;
      ctx.lineWidth = 1;
      const x = rand() * CELL, y = rand() * CELL;
      ctx.beginPath();
      ctx.moveTo(x, y);
      ctx.lineTo(x + (rand() - 0.5) * 6, y - 4 - rand() * 8);
      ctx.stroke();
    }
    speck(ctx, rand, 220, (v) => `rgba(${90 + v * 40},${80 + v * 35},${52 + v * 24},0.5)`, 3, 2);
  },
  // 2 · packed earth
  (ctx, rand) => {
    ctx.fillStyle = "#6d5637";
    ctx.fillRect(0, 0, CELL, CELL);
    for (let i = 0; i < 900; i++) {
      const v = 88 + rand() * 52;
      ctx.fillStyle = `rgba(${v},${v * 0.78},${v * 0.54},0.6)`;
      ctx.fillRect(rand() * CELL, rand() * CELL, 2 + rand() * 6, 1 + rand() * 3);
    }
    for (let i = 0; i < 60; i++) {
      const x = rand() * CELL, y = rand() * CELL, r = 1.5 + rand() * 3;
      ctx.fillStyle = `rgba(${120 + rand() * 40},${114 + rand() * 34},${100 + rand() * 30},0.9)`;
      ctx.beginPath();
      ctx.ellipse(x, y, r, r * 0.7, rand() * 3, 0, Math.PI * 2);
      ctx.fill();
      ctx.fillStyle = "rgba(0,0,0,0.25)";
      ctx.fillRect(x - r, y + r * 0.5, r * 2, 1);
    }
  },
  // 3 · desert sand
  (ctx, rand) => {
    ctx.fillStyle = "#c9a870";
    ctx.fillRect(0, 0, CELL, CELL);
    speck(ctx, rand, 2200, (v) => `rgba(${200 + v * 45},${180 + v * 40},${140 + v * 40},0.55)`, 1.5, 1.5);
    for (let i = 0; i < 26; i++) {
      const y = rand() * CELL;
      ctx.strokeStyle = `rgba(${150 + rand() * 40},${128 + rand() * 30},${92 + rand() * 24},0.35)`;
      ctx.lineWidth = 1 + rand() * 2;
      ctx.beginPath();
      for (let x = 0; x <= CELL; x += 8) {
        const yy = y + Math.sin((x / CELL) * Math.PI * 2 + i) * 4;
        x === 0 ? ctx.moveTo(x, yy) : ctx.lineTo(x, yy);
      }
      ctx.stroke();
    }
  },
  // 4 · dressed ashlar (river kingdom)
  (ctx, rand) => {
    ctx.fillStyle = "#59554c";
    ctx.fillRect(0, 0, CELL, CELL);
    const rows = 5;
    const bh = CELL / rows;
    for (let row = 0; row < rows; row++) {
      const bw = CELL / 3 + (row % 2 === 0 ? 8 : -8);
      const offset = row % 2 === 0 ? 0 : -bw / 2;
      for (let x = offset; x < CELL; x += bw) {
        const clipped = Math.max(0, x + 1.5);
        const right = Math.min(CELL, x + bw - 3);
        if (right - clipped <= 2) continue;
        block(ctx, clipped, row * bh + 1.5, right - clipped, bh - 3, 148 + rand() * 26, 4);
      }
    }
    speck(ctx, rand, 420, (v) => `rgba(${90 + v * 50},${88 + v * 48},${80 + v * 44},0.22)`, 2, 2);
    ctx.fillStyle = "rgba(40,38,32,0.10)";
    for (let i = 0; i < 6; i++) ctx.fillRect(rand() * CELL, rand() * CELL, 10 + rand() * 40, 1);
  },
  // 5 · rubble masonry (villages, ruins)
  (ctx, rand) => {
    ctx.fillStyle = "#4f4c46";
    ctx.fillRect(0, 0, CELL, CELL);
    for (let i = 0; i < 90; i++) {
      const x = rand() * CELL, y = rand() * CELL;
      const w = 10 + rand() * 20, h = 7 + rand() * 13;
      const base = 104 + rand() * 46;
      rounded(ctx, x, y, w, h, 3 + rand() * 3);
      const g = ctx.createLinearGradient(x, y, x, y + h);
      g.addColorStop(0, `rgb(${base + 20},${base + 16},${base + 8})`);
      g.addColorStop(1, `rgb(${base - 24},${base - 26},${base - 30})`);
      ctx.fillStyle = g;
      ctx.fill();
      ctx.strokeStyle = "rgba(30,28,24,0.35)";
      ctx.lineWidth = 1;
      ctx.stroke();
    }
  },
  // 6 · basalt (highland)
  (ctx, rand) => {
    ctx.fillStyle = "#3a3c40";
    ctx.fillRect(0, 0, CELL, CELL);
    for (let x = 0; x < CELL; x += 22) {
      const base = 86 + rand() * 30;
      gradient(ctx, x + 1, 0, 20, CELL, `rgb(${base + 18},${base + 20},${base + 26})`, `rgb(${base - 20},${base - 18},${base - 12})`);
      ctx.fillStyle = "rgba(12,12,14,0.55)";
      ctx.fillRect(x, 0, 1.5, CELL);
      for (let i = 0; i < 3; i++) {
        ctx.fillStyle = "rgba(16,16,18,0.4)";
        ctx.fillRect(x + 2, rand() * CELL, 17, 1 + rand() * 2);
      }
    }
    speck(ctx, rand, 500, (v) => `rgba(${150 + v * 60},${152 + v * 60},${160 + v * 55},0.22)`, 1.5, 1.5);
  },
  // 7 · sandstone (sultanate)
  (ctx, rand) => {
    ctx.fillStyle = "#a98757";
    ctx.fillRect(0, 0, CELL, CELL);
    const rows = 4;
    const bh = CELL / rows;
    for (let row = 0; row < rows; row++) {
      for (let x = row % 2 ? -18 : 0; x < CELL; x += 36) {
        const left = Math.max(0, x + 1.5);
        const right = Math.min(CELL, x + 33);
        if (right - left <= 2) continue;
        block(ctx, left, row * bh + 2, right - left, bh - 4, 188 + rand() * 24, 26);
      }
    }
    speck(ctx, rand, 700, (v) => `rgba(${200 + v * 40},${170 + v * 36},${120 + v * 30},0.35)`, 3, 2);
  },
  // 8 · mossy stone
  (ctx, rand) => {
    ctx.fillStyle = "#4b4f42";
    ctx.fillRect(0, 0, CELL, CELL);
    for (let row = 0; row < 4; row++) {
      for (let x = row % 2 ? -22 : 0; x < CELL; x += 44) {
        const left = Math.max(0, x + 2), right = Math.min(CELL, x + 42);
        if (right - left <= 2) continue;
        block(ctx, left, row * 32 + 2, right - left, 28, 128 + rand() * 32, -2);
      }
    }
    for (let i = 0; i < 60; i++) {
      const x = rand() * CELL, y = rand() * CELL, r = 3 + rand() * 11;
      const g = ctx.createRadialGradient(x, y, 0, x, y, r);
      const hue = 70 + rand() * 40;
      g.addColorStop(0, `rgba(${hue * 0.55},${hue},${hue * 0.42},0.55)`);
      g.addColorStop(1, "rgba(60,80,40,0)");
      ctx.fillStyle = g;
      ctx.beginPath();
      ctx.arc(x, y, r, 0, Math.PI * 2);
      ctx.fill();
    }
  },
  // 9 · marble (civic halls)
  (ctx, rand) => {
    const g = ctx.createLinearGradient(0, 0, CELL, CELL);
    g.addColorStop(0, "#e6dfd2");
    g.addColorStop(1, "#c9c0b0");
    ctx.fillStyle = g;
    ctx.fillRect(0, 0, CELL, CELL);
    for (let i = 0; i < 14; i++) {
      ctx.strokeStyle = `rgba(${120 + rand() * 40},${112 + rand() * 36},${100 + rand() * 30},${0.10 + rand() * 0.14})`;
      ctx.lineWidth = 0.8 + rand() * 2.2;
      ctx.beginPath();
      ctx.moveTo(rand() * CELL, -10);
      ctx.bezierCurveTo(
        rand() * CELL, CELL * 0.3,
        rand() * CELL, CELL * 0.7,
        rand() * CELL, CELL + 10,
      );
      ctx.stroke();
    }
    speck(ctx, rand, 500, (v) => `rgba(255,255,255,${0.05 + v * 0.12})`, 2, 2);
  },
  // 10 · chased gold
  (ctx, rand) => {
    const g = ctx.createLinearGradient(0, 0, CELL, CELL);
    g.addColorStop(0, "#e8c469");
    g.addColorStop(0.45, "#b78a34");
    g.addColorStop(0.7, "#f2da92");
    g.addColorStop(1, "#8d6522");
    ctx.fillStyle = g;
    ctx.fillRect(0, 0, CELL, CELL);
    for (let i = 0; i < 26; i++) {
      ctx.strokeStyle = `rgba(${80 + rand() * 30},${56 + rand() * 24},${18 + rand() * 16},${0.25 + rand() * 0.3})`;
      ctx.lineWidth = 1 + rand() * 2;
      ctx.beginPath();
      const cx = rand() * CELL, cy = rand() * CELL, r = 6 + rand() * 22;
      ctx.arc(cx, cy, r, rand() * 6, rand() * 6 + 2);
      ctx.stroke();
    }
    speck(ctx, rand, 300, (v) => `rgba(255,${230 + v * 20},${170 + v * 40},0.4)`, 1.5, 1.5);
  },
  // 11 · timber planks
  (ctx, rand) => {
    ctx.fillStyle = "#4b2f1b";
    ctx.fillRect(0, 0, CELL, CELL);
    for (let x = 0; x < CELL; x += 26) {
      const shade = 104 + rand() * 26;
      gradient(ctx, x + 1, 0, 24, CELL, `rgb(${shade},${shade * 0.64},${shade * 0.4})`, `rgb(${shade * 0.74},${shade * 0.46},${shade * 0.26})`);
      ctx.fillStyle = "rgba(24,12,5,0.5)";
      ctx.fillRect(x + 24, 0, 2, CELL);
      for (let i = 0; i < 10; i++) {
        ctx.strokeStyle = `rgba(60,34,16,${0.18 + rand() * 0.22})`;
        ctx.lineWidth = 1;
        const gx = x + 4 + rand() * 16;
        ctx.beginPath();
        ctx.moveTo(gx, 0);
        ctx.bezierCurveTo(gx + rand() * 4, CELL * 0.3, gx - rand() * 4, CELL * 0.7, gx + rand() * 3, CELL);
        ctx.stroke();
      }
      for (let i = 0; i < 3; i++) {
        ctx.fillStyle = `rgba(40,26,14,${0.5 + rand() * 0.3})`;
        ctx.beginPath();
        ctx.ellipse(x + 6 + rand() * 14, rand() * CELL, 1.6, 2.6, 0, 0, Math.PI * 2);
        ctx.fill();
      }
    }
  },
  // 12 · dark aged oak
  (ctx, rand) => {
    ctx.fillStyle = "#33241a";
    ctx.fillRect(0, 0, CELL, CELL);
    for (let y = 0; y < CELL; y += 32) {
      const shade = 72 + rand() * 22;
      gradient(ctx, 0, y + 1, CELL, 30, `rgb(${shade},${shade * 0.68},${shade * 0.48})`, `rgb(${shade * 0.7},${shade * 0.46},${shade * 0.3})`);
      ctx.fillStyle = "rgba(14,9,5,0.6)";
      ctx.fillRect(0, y + 30, CELL, 2);
      for (let i = 0; i < 8; i++) {
        ctx.fillStyle = `rgba(30,20,12,${0.2 + rand() * 0.3})`;
        ctx.fillRect(rand() * CELL, y + 2 + rand() * 26, 10 + rand() * 40, 1);
      }
      // iron studs
      for (const sx of [12, CELL - 14]) {
        ctx.fillStyle = "#2a2b2e";
        ctx.beginPath();
        ctx.arc(sx, y + 15, 3.2, 0, Math.PI * 2);
        ctx.fill();
        ctx.fillStyle = "rgba(190,195,205,0.5)";
        ctx.beginPath();
        ctx.arc(sx - 1, y + 14, 1.2, 0, Math.PI * 2);
        ctx.fill();
      }
    }
  },
  // 13 · oak shingle roof (steppe, rural)
  (ctx, rand) => {
    ctx.fillStyle = "#4a3a26";
    ctx.fillRect(0, 0, CELL, CELL);
    for (let row = 0; row < 8; row++) {
      const y = row * 16;
      for (let x = row % 2 ? -12 : 0; x < CELL; x += 24) {
        const v = 96 + rand() * 44;
        ctx.fillStyle = `rgb(${v},${v * 0.74},${v * 0.5})`;
        rounded(ctx, x + 1, y, 22, 18, 5);
        ctx.fill();
        ctx.fillStyle = "rgba(0,0,0,0.28)";
        ctx.fillRect(x + 1, y + 16, 22, 2.4);
        ctx.fillStyle = "rgba(255,235,200,0.14)";
        ctx.fillRect(x + 3, y + 2, 18, 1.6);
      }
    }
  },
  // 14 · thatch
  (ctx, rand) => {
    ctx.fillStyle = "#7a6335";
    ctx.fillRect(0, 0, CELL, CELL);
    for (let i = 0; i < 520; i++) {
      const v = 130 + rand() * 70;
      const x = rand() * CELL, y = rand() * CELL;
      ctx.strokeStyle = `rgba(${v},${v * 0.84},${v * 0.46},${0.3 + rand() * 0.5})`;
      ctx.lineWidth = 1 + rand() * 1.4;
      ctx.beginPath();
      ctx.moveTo(x, y);
      ctx.lineTo(x + (rand() - 0.5) * 12, y + 5 + rand() * 14);
      ctx.stroke();
    }
    for (let y = 8; y < CELL; y += 26) {
      ctx.fillStyle = "rgba(40,28,10,0.28)";
      ctx.fillRect(0, y, CELL, 3);
      ctx.fillStyle = "rgba(220,196,140,0.16)";
      ctx.fillRect(0, y + 3, CELL, 1.5);
    }
  },
  // 15 · slate roof (north)
  (ctx, rand) => {
    ctx.fillStyle = "#3d4650";
    ctx.fillRect(0, 0, CELL, CELL);
    for (let row = 0; row < 7; row++) {
      const y = row * 19;
      for (let x = row % 2 ? -14 : 0; x < CELL; x += 28) {
        const v = 88 + rand() * 34;
        gradient(ctx, x + 1, y, 26, 22, `rgb(${v},${v + 8},${v + 18})`, `rgb(${v - 22},${v - 14},${v - 2})`);
        ctx.fillStyle = "rgba(12,16,20,0.45)";
        ctx.fillRect(x + 1, y + 20, 26, 2.4);
        ctx.fillStyle = "rgba(200,225,255,0.12)";
        ctx.fillRect(x + 3, y + 2, 20, 1.4);
      }
    }
  },
  // 16 · clay pantiles (river, towns)
  (ctx, rand) => {
    ctx.fillStyle = "#7a3325";
    ctx.fillRect(0, 0, CELL, CELL);
    for (let y = 0; y < CELL; y += 17) {
      for (let x = 0; x < CELL; x += 21) {
        const v = 132 + rand() * 34;
        const g = ctx.createLinearGradient(x, y, x + 21, y + 17);
        g.addColorStop(0, `rgb(${v + 22},${v * 0.52},${v * 0.42})`);
        g.addColorStop(1, `rgb(${v - 34},${v * 0.34},${v * 0.28})`);
        ctx.fillStyle = g;
        ctx.beginPath();
        ctx.arc(x + 10.5, y + 10, 10, Math.PI, 0);
        ctx.lineTo(x + 20.5, y + 17);
        ctx.lineTo(x + 0.5, y + 17);
        ctx.closePath();
        ctx.fill();
        ctx.fillStyle = "rgba(240,190,150,0.18)";
        ctx.fillRect(x + 4, y + 6, 4, 8);
      }
    }
  },
  // 17 · lime plaster
  (ctx, rand) => {
    ctx.fillStyle = "#c8bda2";
    ctx.fillRect(0, 0, CELL, CELL);
    for (let i = 0; i < 1600; i++) {
      const v = 186 + rand() * 50;
      ctx.fillStyle = `rgba(${v},${v * 0.96},${v * 0.85},0.4)`;
      ctx.fillRect(rand() * CELL, rand() * CELL, 2 + rand() * 4, 2 + rand() * 4);
    }
    for (let i = 0; i < 8; i++) {
      ctx.strokeStyle = `rgba(${120 + rand() * 30},${108 + rand() * 24},${88 + rand() * 20},0.28)`;
      ctx.lineWidth = 0.8;
      ctx.beginPath();
      let x = rand() * CELL, y = rand() * CELL;
      ctx.moveTo(x, y);
      for (let s = 0; s < 5; s++) {
        x += (rand() - 0.5) * 30;
        y += rand() * 16;
        ctx.lineTo(x, y);
      }
      ctx.stroke();
    }
    gradient(ctx, 0, CELL - 26, CELL, 26, "rgba(90,74,52,0)", "rgba(90,74,52,0.22)");
  },
  // 18 · rammed earth (steppe walls)
  (ctx, rand) => {
    ctx.fillStyle = "#8a6b45";
    ctx.fillRect(0, 0, CELL, CELL);
    for (let y = 0; y < CELL; y += 18) {
      const v = 132 + rand() * 26;
      gradient(ctx, 0, y, CELL, 17, `rgb(${v},${v * 0.78},${v * 0.55})`, `rgb(${v - 26},${v * 0.66},${v * 0.46})`);
      ctx.fillStyle = "rgba(50,34,18,0.25)";
      ctx.fillRect(0, y + 16, CELL, 2);
    }
    for (let i = 0; i < 500; i++) {
      const v = 170 + rand() * 60;
      ctx.strokeStyle = `rgba(${v},${v * 0.86},${v * 0.6},0.28)`;
      ctx.lineWidth = 1;
      const x = rand() * CELL, y = rand() * CELL;
      ctx.beginPath();
      ctx.moveTo(x, y);
      ctx.lineTo(x + 3 + rand() * 6, y + (rand() - 0.5) * 3);
      ctx.stroke();
    }
  },
  // 19 · steel
  (ctx, rand) => {
    const g = ctx.createLinearGradient(0, 0, CELL, 0);
    g.addColorStop(0, "#7d8794");
    g.addColorStop(0.35, "#c6d0da");
    g.addColorStop(0.55, "#8d97a4");
    g.addColorStop(1, "#5d6672");
    ctx.fillStyle = g;
    ctx.fillRect(0, 0, CELL, CELL);
    for (let i = 0; i < 260; i++) {
      const v = 150 + rand() * 90;
      ctx.strokeStyle = `rgba(${v},${v + 6},${v + 14},${0.06 + rand() * 0.16})`;
      ctx.lineWidth = 1;
      const x = rand() * CELL;
      ctx.beginPath();
      ctx.moveTo(x, 0);
      ctx.lineTo(x + (rand() - 0.5) * 3, CELL);
      ctx.stroke();
    }
    for (let i = 0; i < 5; i++) {
      const x = rand() * CELL, y = rand() * CELL;
      const gl = ctx.createRadialGradient(x, y, 0, x, y, 16 + rand() * 20);
      gl.addColorStop(0, "rgba(255,255,255,0.35)");
      gl.addColorStop(1, "rgba(255,255,255,0)");
      ctx.fillStyle = gl;
      ctx.fillRect(x - 40, y - 40, 80, 80);
    }
  },
  // 20 · blackened iron
  (ctx, rand) => {
    ctx.fillStyle = "#3c4046";
    ctx.fillRect(0, 0, CELL, CELL);
    for (let i = 0; i < 40; i++) {
      const x = rand() * CELL, y = rand() * CELL, r = 4 + rand() * 14;
      const g = ctx.createRadialGradient(x, y, 0, x, y, r);
      g.addColorStop(0, `rgba(${100 + rand() * 40},${104 + rand() * 40},${112 + rand() * 40},0.28)`);
      g.addColorStop(1, "rgba(30,32,36,0)");
      ctx.fillStyle = g;
      ctx.fillRect(x - r, y - r, r * 2, r * 2);
    }
    speck(ctx, rand, 260, (v) => `rgba(${20 + v * 30},${20 + v * 30},${24 + v * 30},0.5)`, 3, 2);
  },
  // 21 · bronze
  (ctx, rand) => {
    const g = ctx.createLinearGradient(0, 0, CELL, CELL);
    g.addColorStop(0, "#c79b52");
    g.addColorStop(0.5, "#8a6630");
    g.addColorStop(1, "#d9b878");
    ctx.fillStyle = g;
    ctx.fillRect(0, 0, CELL, CELL);
    for (let i = 0; i < 40; i++) {
      const x = rand() * CELL, y = rand() * CELL, r = 3 + rand() * 12;
      const p = ctx.createRadialGradient(x, y, 0, x, y, r);
      p.addColorStop(0, `rgba(${70 + rand() * 40},${130 + rand() * 40},${110 + rand() * 40},0.32)`);
      p.addColorStop(1, "rgba(60,110,100,0)");
      ctx.fillStyle = p;
      ctx.fillRect(x - r, y - r, r * 2, r * 2);
    }
    speck(ctx, rand, 300, (v) => `rgba(255,${220 + v * 30},${160 + v * 40},0.35)`, 2, 1.5);
  },
  // 22 · chainmail
  (ctx, rand) => {
    ctx.fillStyle = "#3f444b";
    ctx.fillRect(0, 0, CELL, CELL);
    for (let row = 0; row < 12; row++) {
      for (let x = (row % 2) * 6; x < CELL; x += 12) {
        const y = row * 11;
        const v = 128 + rand() * 60;
        ctx.strokeStyle = `rgb(${v},${v + 4},${v + 10})`;
        ctx.lineWidth = 2;
        ctx.beginPath();
        ctx.ellipse(x + 5, y + 5, 4.4, 5.4, 0, Math.PI * 0.15, Math.PI * 1.85);
        ctx.stroke();
        ctx.strokeStyle = "rgba(20,22,26,0.7)";
        ctx.lineWidth = 1;
        ctx.beginPath();
        ctx.ellipse(x + 5, y + 5, 3.2, 4, 0, 0, Math.PI * 2);
        ctx.stroke();
      }
    }
  },
  // 23 · leather
  (ctx, rand) => {
    ctx.fillStyle = "#6b4a2c";
    ctx.fillRect(0, 0, CELL, CELL);
    for (let i = 0; i < 1400; i++) {
      const v = 110 + rand() * 60;
      ctx.fillStyle = `rgba(${v},${v * 0.68},${v * 0.44},0.35)`;
      ctx.beginPath();
      ctx.arc(rand() * CELL, rand() * CELL, 0.8 + rand() * 1.8, 0, Math.PI * 2);
      ctx.fill();
    }
    ctx.strokeStyle = "rgba(40,26,14,0.45)";
    ctx.setLineDash([5, 4]);
    ctx.lineWidth = 1.6;
    ctx.strokeRect(7, 7, CELL - 14, CELL - 14);
    ctx.setLineDash([]);
  },
  // 24 · fur
  (ctx, rand) => {
    ctx.fillStyle = "#5d4c3b";
    ctx.fillRect(0, 0, CELL, CELL);
    for (let i = 0; i < 1300; i++) {
      const v = 96 + rand() * 90;
      const x = rand() * CELL, y = rand() * CELL;
      ctx.strokeStyle = `rgba(${v},${v * 0.88},${v * 0.74},${0.25 + rand() * 0.45})`;
      ctx.lineWidth = 1 + rand() * 1.6;
      ctx.beginPath();
      ctx.moveTo(x, y);
      ctx.quadraticCurveTo(x + 4, y + 8, x + (rand() - 0.5) * 8, y + 14 + rand() * 8);
      ctx.stroke();
    }
  },
  // 25 · woven cloth (tabards, tents)
  (ctx, rand) => {
    ctx.fillStyle = "#d8cfb8";
    ctx.fillRect(0, 0, CELL, CELL);
    for (let y = 0; y < CELL; y += 3) {
      ctx.fillStyle = `rgba(255,255,255,${0.06 + rand() * 0.1})`;
      ctx.fillRect(0, y, CELL, 1.6);
      ctx.fillStyle = "rgba(90,80,60,0.08)";
      ctx.fillRect(0, y + 1.6, CELL, 1);
    }
    for (let x = 0; x < CELL; x += 3) {
      ctx.fillStyle = "rgba(110,96,72,0.05)";
      ctx.fillRect(x, 0, 1, CELL);
    }
    speck(ctx, rand, 420, (v) => `rgba(${150 + v * 40},${140 + v * 36},${118 + v * 32},0.25)`, 2, 2);
  },
  // 26 · water
  (ctx, rand) => {
    const g = ctx.createLinearGradient(0, 0, 0, CELL);
    g.addColorStop(0, "#2b5069");
    g.addColorStop(1, "#1b3a4e");
    ctx.fillStyle = g;
    ctx.fillRect(0, 0, CELL, CELL);
    for (let i = 0; i < 40; i++) {
      const y = rand() * CELL;
      ctx.strokeStyle = `rgba(${150 + rand() * 70},${196 + rand() * 50},${216 + rand() * 30},${0.05 + rand() * 0.16})`;
      ctx.lineWidth = 1 + rand() * 2.4;
      ctx.beginPath();
      for (let x = 0; x <= CELL; x += 10) {
        const yy = y + Math.sin(x * 0.09 + i * 1.7) * 2.4;
        x === 0 ? ctx.moveTo(x, yy) : ctx.lineTo(x, yy);
      }
      ctx.stroke();
    }
    speck(ctx, rand, 90, (v) => `rgba(240,250,255,${0.1 + v * 0.25})`, 3, 1.5);
  },
  // 27 · heraldry: chevron
  (ctx, rand) => {
    heraldryField(ctx, rand);
    ctx.fillStyle = DEVICE;
    ctx.beginPath();
    ctx.moveTo(64, 26);
    ctx.lineTo(112, 104);
    ctx.lineTo(86, 104);
    ctx.lineTo(64, 66);
    ctx.lineTo(42, 104);
    ctx.lineTo(16, 104);
    ctx.closePath();
    ctx.fill();
  },
  // 28 · heraldry: cross
  (ctx, rand) => {
    heraldryField(ctx, rand);
    ctx.fillStyle = DEVICE;
    ctx.fillRect(52, 20, 24, 88);
    ctx.fillRect(22, 47, 84, 24);
  },
  // 29 · heraldry: saltire
  (ctx, rand) => {
    heraldryField(ctx, rand);
    ctx.strokeStyle = DEVICE;
    ctx.lineWidth = 20;
    ctx.lineCap = "butt";
    ctx.beginPath();
    ctx.moveTo(22, 22);
    ctx.lineTo(106, 106);
    ctx.moveTo(106, 22);
    ctx.lineTo(22, 106);
    ctx.stroke();
  },
  // 30 · heraldry: wolf
  (ctx, rand) => {
    heraldryField(ctx, rand);
    ctx.fillStyle = DEVICE;
    ctx.beginPath();
    ctx.moveTo(64, 20);
    ctx.lineTo(88, 34);
    ctx.lineTo(108, 30);
    ctx.lineTo(92, 54);
    ctx.lineTo(96, 86);
    ctx.lineTo(64, 108);
    ctx.lineTo(32, 86);
    ctx.lineTo(36, 54);
    ctx.lineTo(20, 30);
    ctx.lineTo(40, 34);
    ctx.closePath();
    ctx.fill();
    // ears and muzzle cut-outs read as a wolf head at game distance.
    ctx.fillStyle = "#efe9dc";
    ctx.beginPath();
    ctx.moveTo(64, 44);
    ctx.lineTo(78, 70);
    ctx.lineTo(64, 92);
    ctx.lineTo(50, 70);
    ctx.closePath();
    ctx.fill();
  },
  // 31 · heraldry: crescent
  (ctx, rand) => {
    heraldryField(ctx, rand);
    ctx.fillStyle = DEVICE;
    ctx.beginPath();
    ctx.arc(64, 64, 40, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = "#efe9dc";
    ctx.beginPath();
    ctx.arc(80, 56, 34, 0, Math.PI * 2);
    ctx.fill();
  },
  // 32 · heraldry: tower
  (ctx, rand) => {
    heraldryField(ctx, rand);
    ctx.fillStyle = DEVICE;
    ctx.fillRect(30, 44, 68, 62);
    for (let i = 0; i < 4; i++) ctx.fillRect(28 + i * 18, 30, 12, 18);
    ctx.fillRect(34, 66, 14, 24);
    ctx.fillRect(80, 66, 14, 24);
    ctx.fillStyle = "#efe9dc";
    ctx.beginPath();
    ctx.moveTo(64, 76);
    ctx.lineTo(74, 102);
    ctx.lineTo(54, 102);
    ctx.closePath();
    ctx.fill();
  },
  // 33 · heraldry: sun
  (ctx, rand) => {
    heraldryField(ctx, rand);
    ctx.fillStyle = DEVICE;
    ctx.beginPath();
    ctx.arc(64, 64, 22, 0, Math.PI * 2);
    ctx.fill();
    ctx.strokeStyle = DEVICE;
    ctx.lineWidth = 7;
    for (let i = 0; i < 12; i++) {
      const a = (i / 12) * Math.PI * 2;
      ctx.beginPath();
      ctx.moveTo(64 + Math.cos(a) * 28, 64 + Math.sin(a) * 28);
      ctx.lineTo(64 + Math.cos(a) * (i % 2 ? 40 : 46), 64 + Math.sin(a) * (i % 2 ? 40 : 46));
      ctx.stroke();
    }
  },
  // 34 · heraldry: pales
  (ctx, rand) => {
    heraldryField(ctx, rand);
    ctx.fillStyle = DEVICE;
    for (let i = 0; i < 3; i++) ctx.fillRect(24 + i * 28, 18, 14, 92);
  },
];

const DEVICE = "#211d19";

/** Shared cloth field so any instance colour tints the shield cleanly. */
function heraldryField(ctx: CanvasRenderingContext2D, rand: Rand): void {
  ctx.fillStyle = "#efe9dc";
  ctx.fillRect(0, 0, CELL, CELL);
  for (let i = 0; i < 900; i++) {
    const v = 226 + rand() * 26;
    ctx.fillStyle = `rgba(${v},${v - 4},${v - 14},0.5)`;
    ctx.fillRect(rand() * CELL, rand() * CELL, 3, 1);
  }
  ctx.strokeStyle = "rgba(110,96,74,0.45)";
  ctx.lineWidth = 6;
  ctx.strokeRect(6, 6, CELL - 12, CELL - 12);
  ctx.strokeStyle = "rgba(56,46,34,0.35)";
  ctx.lineWidth = 2;
  ctx.strokeRect(14, 14, CELL - 28, CELL - 28);
  // gentle fabric shading so banners are not flat
  const shade = ctx.createLinearGradient(0, 0, 0, CELL);
  shade.addColorStop(0, "rgba(255,255,255,0.10)");
  shade.addColorStop(0.55, "rgba(0,0,0,0)");
  shade.addColorStop(1, "rgba(0,0,0,0.16)");
  ctx.fillStyle = shade;
  ctx.fillRect(0, 0, CELL, CELL);
}

// -------------------------------------------------------------------- export

/**
 * Guard band, in pixels, around every cell.
 *
 * Mipmapping an atlas bleeds neighbouring cells into each other, which shows up
 * as a bright grid on large ground planes. Each tile is therefore drawn inset
 * by PAD pixels and its own edge pixels are smeared into the guard band, so a
 * filtered sample can never reach a different tile.
 */
export const ATLAS_PAD_PX = 8;

export function createAtlasCanvas(): HTMLCanvasElement {
  const canvas = document.createElement("canvas");
  canvas.width = ATLAS_PX;
  canvas.height = ATLAS_PX;
  const ctx = canvas.getContext("2d")!;
  ctx.fillStyle = "#2b3327";
  ctx.fillRect(0, 0, ATLAS_PX, ATLAS_PX);

  const tile = document.createElement("canvas");
  tile.width = CELL;
  tile.height = CELL;
  const tileCtx = tile.getContext("2d")!;
  const inner = CELL - ATLAS_PAD_PX * 2;

  painters.forEach((paint, index) => {
    tileCtx.clearRect(0, 0, CELL, CELL);
    paint(tileCtx, mulberry32(1000 + index * 7919));

    const x = (index % ATLAS_TILES_PER_ROW) * CELL;
    const y = Math.floor(index / ATLAS_TILES_PER_ROW) * CELL;
    const ox = x + ATLAS_PAD_PX;
    const oy = y + ATLAS_PAD_PX;
    ctx.drawImage(tile, 0, 0, CELL, CELL, ox, oy, inner, inner);

    // smear the tile's own edges across the guard band
    ctx.drawImage(tile, 0, 0, CELL, 1, ox, y, inner, ATLAS_PAD_PX);
    ctx.drawImage(tile, 0, CELL - 1, CELL, 1, ox, oy + inner, inner, ATLAS_PAD_PX);
    ctx.drawImage(tile, 0, 0, 1, CELL, x, oy, ATLAS_PAD_PX, inner);
    ctx.drawImage(tile, CELL - 1, 0, 1, CELL, ox + inner, oy, ATLAS_PAD_PX, inner);
    // corners
    ctx.drawImage(tile, 0, 0, 1, 1, x, y, ATLAS_PAD_PX, ATLAS_PAD_PX);
    ctx.drawImage(tile, CELL - 1, 0, 1, 1, ox + inner, y, ATLAS_PAD_PX, ATLAS_PAD_PX);
    ctx.drawImage(tile, 0, CELL - 1, 1, 1, x, oy + inner, ATLAS_PAD_PX, ATLAS_PAD_PX);
    ctx.drawImage(tile, CELL - 1, CELL - 1, 1, 1, ox + inner, oy + inner, ATLAS_PAD_PX, ATLAS_PAD_PX);
  });
  return canvas;
}

export function createAtlasTexture(gl: WebGL2RenderingContext): WebGLTexture {
  const canvas = createAtlasCanvas();
  const texture = gl.createTexture()!;
  gl.bindTexture(gl.TEXTURE_2D, texture);
  gl.pixelStorei(gl.UNPACK_FLIP_Y_WEBGL, 0);
  gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, canvas);
  gl.generateMipmap(gl.TEXTURE_2D);
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR_MIPMAP_LINEAR);
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT);
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT);
  return texture;
}

/** Atlas tile indices shared by the world builders. */
export const ATLAS_TILE = {
  GRASS: 0,
  GRASS_DRY: 1,
  DIRT: 2,
  SAND: 3,
  ASHLAR: 4,
  RUBBLE: 5,
  BASALT: 6,
  SANDSTONE: 7,
  MOSSY: 8,
  MARBLE: 9,
  GOLD: 10,
  WOOD: 11,
  OAK: 12,
  SHINGLE: 13,
  THATCH: 14,
  SLATE: 15,
  CLAY: 16,
  PLASTER: 17,
  MUD: 18,
  STEEL: 19,
  IRON: 20,
  BRONZE: 21,
  CHAIN: 22,
  LEATHER: 23,
  FUR: 24,
  CLOTH: 25,
  WATER: 26,
  CHEVRON: 27,
  CROSS: 28,
  SALTIRE: 29,
  WOLF: 30,
  CRESCENT: 31,
  TOWER: 32,
  SUN: 33,
  PALES: 34,
} as const;
