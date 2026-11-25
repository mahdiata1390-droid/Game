// Procedural texture atlas. The sample world needs zero binary art: a 512x512
// atlas is painted at boot (grass, stone, wood, roof, dirt, plaster, metal,
// water, cloth) so the repository and the download stay tiny.

const CELL = 128;
const TILES_PER_ROW = 4;
const SIZE = CELL * TILES_PER_ROW;

function mulberry32(seed: number): () => number {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

type Painter = (ctx: CanvasRenderingContext2D, rand: () => number) => void;

const painters: Painter[] = [
  // 0 grass
  (ctx, rand) => {
    ctx.fillStyle = "#41522f";
    ctx.fillRect(0, 0, CELL, CELL);
    for (let i = 0; i < 2600; i++) {
      const x = rand() * CELL, y = rand() * CELL;
      const g = 70 + rand() * 55;
      ctx.fillStyle = `rgb(${Math.round(g * 0.72)},${Math.round(g)},${Math.round(g * 0.5)})`;
      ctx.fillRect(x, y, 1 + rand() * 2, 1 + rand() * 3);
    }
  },
  // 1 stone blocks
  (ctx, rand) => {
    ctx.fillStyle = "#4a4a48";
    ctx.fillRect(0, 0, CELL, CELL);
    const bh = 22;
    for (let row = 0; row < CELL / bh; row++) {
      const offset = row % 2 === 0 ? 0 : 24;
      for (let x = -offset; x < CELL; x += 48) {
        const shade = 96 + rand() * 38;
        ctx.fillStyle = `rgb(${shade},${shade},${shade - 4})`;
        ctx.fillRect(x + 2, row * bh + 2, 44, bh - 4);
        ctx.fillStyle = "rgba(0,0,0,0.16)";
        ctx.fillRect(x + 2, row * bh + bh - 4, 44, 2);
      }
    }
        ctx.fillStyle = "rgba(0,0,0,0.12)";
    for (let i = 0; i < 300; i++) ctx.fillRect(rand() * CELL, rand() * CELL, 2, 2);
  },
  // 2 wood planks
  (ctx, rand) => {
    ctx.fillStyle = "#5a3a20";
    ctx.fillRect(0, 0, CELL, CELL);
    for (let x = 0; x < CELL; x += 26) {
      const shade = 86 + rand() * 26;
      ctx.fillStyle = `rgb(${shade},${shade * 0.62},${shade * 0.36})`;
      ctx.fillRect(x + 1, 0, 24, CELL);
      ctx.fillStyle = "rgba(20,10,4,0.45)";
      ctx.fillRect(x + 24, 0, 2, CELL);
      for (let i = 0; i < 12; i++) {
        ctx.fillStyle = `rgba(40,22,10,${0.16 + rand() * 0.2})`;
        ctx.fillRect(x + 3 + rand() * 18, rand() * CELL, 1, 8 + rand() * 26);
      }
    }
  },
  // 3 clay roof tiles
  (ctx, rand) => {
    ctx.fillStyle = "#7d3324";
    ctx.fillRect(0, 0, CELL, CELL);
    for (let y = 0; y < CELL; y += 18) {
      for (let x = 0; x < CELL; x += 22) {
        const shade = 128 + rand() * 34;
        ctx.fillStyle = `rgb(${shade},${shade * 0.44},${shade * 0.33})`;
        ctx.beginPath();
        ctx.arc(x + 11, y + 9, 10, Math.PI, 0);
        ctx.fill();
      }
    }
  },
  // 4 dirt path
  (ctx, rand) => {
    ctx.fillStyle = "#6a5334";
    ctx.fillRect(0, 0, CELL, CELL);
    for (let i = 0; i < 1800; i++) {
      const v = 70 + rand() * 60;
      ctx.fillStyle = `rgb(${v},${v * 0.8},${v * 0.55})`;
      ctx.fillRect(rand() * CELL, rand() * CELL, 1 + rand() * 3, 1 + rand() * 2);
    }
  },
  // 5 plaster wall
  (ctx, rand) => {
    ctx.fillStyle = "#c3b69a";
    ctx.fillRect(0, 0, CELL, CELL);
    for (let i = 0; i < 900; i++) {
      const v = 165 + rand() * 55;
      ctx.fillStyle = `rgba(${v},${v * 0.96},${v * 0.86},0.5)`;
      ctx.fillRect(rand() * CELL, rand() * CELL, 2, 2);
    }
    ctx.fillStyle = "rgba(70,58,40,0.25)";
    ctx.fillRect(0, CELL - 10, CELL, 10);
  },
  // 6 iron / metal
  (ctx, rand) => {
    ctx.fillStyle = "#5b6068";
    ctx.fillRect(0, 0, CELL, CELL);
    for (let i = 0; i < 240; i++) {
      const v = 90 + rand() * 60;
      ctx.fillStyle = `rgba(${v},${v + 4},${v + 9},0.5)`;
      ctx.fillRect(rand() * CELL, rand() * CELL, 2 + rand() * 6, 1 + rand() * 2);
    }
  },
  // 7 water
  (ctx, rand) => {
    ctx.fillStyle = "#25455c";
    ctx.fillRect(0, 0, CELL, CELL);
    for (let i = 0; i < 260; i++) {
      ctx.strokeStyle = `rgba(150,200,225,${0.06 + rand() * 0.14})`;
      ctx.lineWidth = 1 + rand() * 2;
      const y = rand() * CELL;
      ctx.beginPath();
      ctx.moveTo(rand() * CELL, y);
      ctx.lineTo(rand() * CELL, y);
      ctx.stroke();
    }
  },
  // 8 cloth / banner
  (ctx, rand) => {
    ctx.fillStyle = "#b9a06a";
    ctx.fillRect(0, 0, CELL, CELL);
    for (let i = 0; i < 1400; i++) {
      const v = 150 + rand() * 60;
      ctx.fillStyle = `rgba(${v},${v * 0.92},${v * 0.72},0.35)`;
      ctx.fillRect(rand() * CELL, rand() * CELL, 3, 1);
    }
  },
];

export function createAtlasCanvas(): HTMLCanvasElement {
  const canvas = document.createElement("canvas");
  canvas.width = SIZE;
  canvas.height = SIZE;
  const ctx = canvas.getContext("2d")!;
  ctx.fillStyle = "#30402c";
  ctx.fillRect(0, 0, SIZE, SIZE);
  painters.forEach((paint, index) => {
    ctx.save();
    ctx.translate((index % TILES_PER_ROW) * CELL, Math.floor(index / TILES_PER_ROW) * CELL);
    ctx.beginPath();
    ctx.rect(0, 0, CELL, CELL);
    ctx.clip();
    const rand = mulberry32(1000 + index * 7919);
    paint(ctx, rand);
    ctx.restore();
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

/** Atlas tile indices shared by the world builder. */
export const ATLAS_TILE = {
  GRASS: 0,
  STONE: 1,
  WOOD: 2,
  ROOF: 3,
  DIRT: 4,
  PLASTER: 5,
  METAL: 6,
  WATER: 7,
  CLOTH: 8,
} as const;
