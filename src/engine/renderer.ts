// Batched WebGL2 renderer: every visible box in the scene is drawn with one
// instanced draw call. Per-instance data carries transform, albedo, atlas tile,
// UV tiling, emissive amount and a selection flag.

import { compose, lookAt, multiply, mat4, perspective, type Vec3 } from "./math";
import { ATLAS_CELL, ATLAS_PAD_PX, ATLAS_TILES_PER_ROW } from "./textures";

const INSTANCE_FLOATS = 24;
const INSTANCE_BYTES = INSTANCE_FLOATS * 4;
const ATLAS_TILES = ATLAS_TILES_PER_ROW;
/** guard band, expressed in cell-local UV units */
const ATLAS_PAD_UV = (ATLAS_PAD_PX / ATLAS_CELL).toFixed(6);
const ATLAS_INSET_UV = (1 - (ATLAS_PAD_PX * 2) / ATLAS_CELL).toFixed(6);

const VERT = `#version 300 es
layout(location=0) in vec3 aPos;
layout(location=1) in vec3 aNormal;
layout(location=2) in vec2 aUV;
layout(location=3) in mat4 aModel;
layout(location=7) in vec4 aColorTile;
layout(location=8) in vec4 aParams;

uniform mat4 uViewProj;

out vec2 vUV;
out vec3 vNormal;
out vec3 vWorld;
out vec3 vColor;
out vec2 vRepeat;
out float vTile;
out float vEmissive;
out float vSelected;

void main() {
  vec4 world = aModel * vec4(aPos, 1.0);
  vWorld = world.xyz;
  vUV = aUV;
  vNormal = mat3(aModel) * aNormal;
  vColor = aColorTile.rgb;
  vTile = aColorTile.w;
  vRepeat = aParams.xy;
  vEmissive = aParams.z;
  vSelected = aParams.w;
  gl_Position = uViewProj * world;
}`;

const FRAG = `#version 300 es
precision highp float;

uniform sampler2D uAtlas;
uniform vec3 uLightDir;
uniform vec3 uLightColor;
uniform vec3 uAmbient;
uniform vec3 uFogColor;
uniform float uFogNear;
uniform float uFogFar;
uniform vec3 uCamPos;

in vec2 vUV;
in vec3 vNormal;
in vec3 vWorld;
in vec3 vColor;
in vec2 vRepeat;
in float vTile;
in float vEmissive;
in float vSelected;

out vec4 fragColor;

void main() {
  vec3 n = normalize(vNormal);
  vec3 albedo = vColor;
  if (vTile >= 0.0) {
    vec2 cell = vec2(mod(vTile, ${ATLAS_TILES}.0), floor(vTile / ${ATLAS_TILES}.0));
    // Sample inside the cell's guard band so mip filtering never crosses tiles.
    vec2 local = ${ATLAS_PAD_UV} + fract(vUV * vRepeat) * ${ATLAS_INSET_UV};
    vec2 uv = (cell + local) / ${ATLAS_TILES}.0;
    albedo *= texture(uAtlas, uv).rgb;
  }
  float ndl = max(dot(n, uLightDir), 0.0);
  float hemi = 0.55 + 0.45 * n.y;
  vec3 lit = albedo * (uAmbient * hemi + uLightColor * ndl);
  lit = mix(lit, albedo * 1.35, vEmissive);
  float dist = length(vWorld - uCamPos);
  float fog = smoothstep(uFogNear, uFogFar, dist);
  vec3 color = mix(lit, uFogColor, fog);
  if (vSelected > 0.5) color = mix(color, vec3(1.0, 0.83, 0.35), 0.5);
  fragColor = vec4(color, 1.0);
}`;

export type Camera = {
  eye: Vec3;
  target: Vec3;
  fov: number;
  near: number;
  far: number;
};

export type Light = {
  /** Direction the light comes from (normalised). */
  dir: Vec3;
  color: [number, number, number];
  ambient: [number, number, number];
  fogColor: [number, number, number];
  fogNear: number;
  fogFar: number;
};

export type Instance = {
  x: number; y: number; z: number;
  sx?: number; sy?: number; sz?: number;
  yaw?: number; pitch?: number;
  color: [number, number, number];
  tile?: number;
  repeat?: number;
  /** vertical tiling, for long thin surfaces such as roads and curtain walls */
  repeatY?: number;
  emissive?: number;
  selected?: boolean;
};

function compile(gl: WebGL2RenderingContext, type: number, source: string): WebGLShader {
  const shader = gl.createShader(type)!;
  gl.shaderSource(shader, source);
  gl.compileShader(shader);
  if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) {
    throw new Error(`shader compile failed: ${gl.getShaderInfoLog(shader)}`);
  }
  return shader;
}

function cubeGeometry(): { verts: Float32Array; indices: Uint16Array } {
  // 6 faces x 4 corners, positions/normals/uvs.
  const faces: Array<{ n: [number, number, number]; corners: Array<[number, number, number]> }> = [
    { n: [0, 0, 1], corners: [[-1, -1, 1], [1, -1, 1], [1, 1, 1], [-1, 1, 1]] },
    { n: [0, 0, -1], corners: [[1, -1, -1], [-1, -1, -1], [-1, 1, -1], [1, 1, -1]] },
    { n: [1, 0, 0], corners: [[1, -1, 1], [1, -1, -1], [1, 1, -1], [1, 1, 1]] },
    { n: [-1, 0, 0], corners: [[-1, -1, -1], [-1, -1, 1], [-1, 1, 1], [-1, 1, -1]] },
    { n: [0, 1, 0], corners: [[-1, 1, 1], [1, 1, 1], [1, 1, -1], [-1, 1, -1]] },
    { n: [0, -1, 0], corners: [[-1, -1, -1], [1, -1, -1], [1, -1, 1], [-1, -1, 1]] },
  ];
  const verts: number[] = [];
  const indices: number[] = [];
  const uvs: Array<[number, number]> = [[0, 0], [1, 0], [1, 1], [0, 1]];
  faces.forEach((face, f) => {
    face.corners.forEach((corner, i) => {
      verts.push(corner[0] * 0.5, corner[1] * 0.5, corner[2] * 0.5, ...face.n, ...uvs[i]);
    });
    const base = f * 4;
    indices.push(base, base + 1, base + 2, base, base + 2, base + 3);
  });
  return { verts: new Float32Array(verts), indices: new Uint16Array(indices) };
}

export class Renderer {
  readonly gl: WebGL2RenderingContext;
  private program: WebGLProgram;
  private vao: WebGLVertexArrayObject;
  private vbo: WebGLBuffer;
  private ebo: WebGLBuffer;
  private instanceBuffer: WebGLBuffer;
  private data = new Float32Array(INSTANCE_FLOATS * 4096);
  private count = 0;
  private uniforms: Record<string, WebGLUniformLocation | null> = {};
  private viewProj = mat4();
  private proj = mat4();
  private view = mat4();
  private canvas: HTMLCanvasElement;

  stats = { instances: 0, drawCalls: 0, gpuInstancesKiB: 0 };

  constructor(canvas: HTMLCanvasElement, atlas: WebGLTexture) {
    this.canvas = canvas;
    const gl = canvas.getContext("webgl2", { antialias: true, alpha: false });
    if (!gl) throw new Error("WebGL2 is not available in this browser");
    this.gl = gl;

    const prog = gl.createProgram()!;
    gl.attachShader(prog, compile(gl, gl.VERTEX_SHADER, VERT));
    gl.attachShader(prog, compile(gl, gl.FRAGMENT_SHADER, FRAG));
    gl.linkProgram(prog);
    if (!gl.getProgramParameter(prog, gl.LINK_STATUS)) {
      throw new Error(`program link failed: ${gl.getProgramInfoLog(prog)}`);
    }
    this.program = prog;

    for (const name of [
      "uViewProj", "uAtlas", "uLightDir", "uLightColor", "uAmbient",
      "uFogColor", "uFogNear", "uFogFar", "uCamPos",
    ]) {
      this.uniforms[name] = gl.getUniformLocation(prog, name);
    }

    const { verts, indices } = cubeGeometry();
    this.vao = gl.createVertexArray()!;
    gl.bindVertexArray(this.vao);

    this.vbo = gl.createBuffer()!;
    gl.bindBuffer(gl.ARRAY_BUFFER, this.vbo);
    gl.bufferData(gl.ARRAY_BUFFER, verts, gl.STATIC_DRAW);

    const stride = 32;
    gl.enableVertexAttribArray(0);
    gl.vertexAttribPointer(0, 3, gl.FLOAT, false, stride, 0);
    gl.enableVertexAttribArray(1);
    gl.vertexAttribPointer(1, 3, gl.FLOAT, false, stride, 12);
    gl.enableVertexAttribArray(2);
    gl.vertexAttribPointer(2, 2, gl.FLOAT, false, stride, 24);

    this.ebo = gl.createBuffer()!;
    gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, this.ebo);
    gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, indices, gl.STATIC_DRAW);

    this.instanceBuffer = gl.createBuffer()!;
    gl.bindBuffer(gl.ARRAY_BUFFER, this.instanceBuffer);
    gl.bufferData(gl.ARRAY_BUFFER, this.data.byteLength, gl.DYNAMIC_DRAW);
    for (let i = 0; i < 4; i++) {
      const loc = 3 + i;
      gl.enableVertexAttribArray(loc);
      gl.vertexAttribPointer(loc, 4, gl.FLOAT, false, INSTANCE_BYTES, i * 16);
      gl.vertexAttribDivisor(loc, 1);
    }
    // albedo + atlas tile
    gl.enableVertexAttribArray(7);
    gl.vertexAttribPointer(7, 4, gl.FLOAT, false, INSTANCE_BYTES, 64);
    gl.vertexAttribDivisor(7, 1);
    // uv repeat, emissive, selected
    gl.enableVertexAttribArray(8);
    gl.vertexAttribPointer(8, 4, gl.FLOAT, false, INSTANCE_BYTES, 80);
    gl.vertexAttribDivisor(8, 1);

    gl.bindVertexArray(null);

    gl.useProgram(prog);
    gl.activeTexture(gl.TEXTURE0);
    gl.bindTexture(gl.TEXTURE_2D, atlas);
    gl.uniform1i(this.uniforms.uAtlas!, 0);

    gl.enable(gl.DEPTH_TEST);
    gl.enable(gl.CULL_FACE);
    gl.cullFace(gl.BACK);

    this.resize();
  }

  resize(): void {
    const dpr = Math.min(window.devicePixelRatio || 1, 2);
    const width = Math.max(1, Math.floor(this.canvas.clientWidth * dpr));
    const height = Math.max(1, Math.floor(this.canvas.clientHeight * dpr));
    if (this.canvas.width !== width || this.canvas.height !== height) {
      this.canvas.width = width;
      this.canvas.height = height;
    }
    this.gl.viewport(0, 0, width, height);
  }

  begin(camera: Camera, light: Light): void {
    this.count = 0;
    const aspect = this.canvas.width / Math.max(1, this.canvas.height);
    perspective(this.proj, camera.fov, aspect, camera.near, camera.far);
    lookAt(this.view, camera.eye, camera.target, { x: 0, y: 1, z: 0 });
    multiply(this.viewProj, this.proj, this.view);

    const gl = this.gl;
    gl.clearColor(light.fogColor[0], light.fogColor[1], light.fogColor[2], 1);
    gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);
    gl.useProgram(this.program);
    gl.uniformMatrix4fv(this.uniforms.uViewProj!, false, this.viewProj);
    gl.uniform3f(this.uniforms.uLightDir!, light.dir.x, light.dir.y, light.dir.z);
    gl.uniform3f(this.uniforms.uLightColor!, ...light.color);
    gl.uniform3f(this.uniforms.uAmbient!, ...light.ambient);
    gl.uniform3f(this.uniforms.uFogColor!, ...light.fogColor);
    gl.uniform1f(this.uniforms.uFogNear!, light.fogNear);
    gl.uniform1f(this.uniforms.uFogFar!, light.fogFar);
    gl.uniform3f(this.uniforms.uCamPos!, camera.eye.x, camera.eye.y, camera.eye.z);
  }

  push(i: Instance): void {
    if ((this.count + 1) * INSTANCE_FLOATS > this.data.length) {
      const grown = new Float32Array(this.data.length * 2);
      grown.set(this.data);
      this.data = grown;
    }
    const base = this.count * INSTANCE_FLOATS;
    compose(
      this.data, base,
      i.x, i.y, i.z,
      i.yaw ?? 0, i.pitch ?? 0,
      i.sx ?? 1, i.sy ?? 1, i.sz ?? 1,
    );
    this.data[base + 16] = i.color[0];
    this.data[base + 17] = i.color[1];
    this.data[base + 18] = i.color[2];
    this.data[base + 19] = i.tile ?? 0;
    const repeat = i.repeat ?? 1;
    this.data[base + 20] = repeat;
    this.data[base + 21] = i.repeatY ?? repeat;
    this.data[base + 22] = i.emissive ?? 0;
    this.data[base + 23] = i.selected ? 1 : 0;
    this.count++;
  }

  flush(): void {
    this.stats.instances = this.count;
    this.stats.drawCalls = this.count > 0 ? 1 : 0;
    this.stats.gpuInstancesKiB = Math.round((this.count * INSTANCE_BYTES) / 1024);
    if (this.count === 0) return;
    const gl = this.gl;
    gl.bindVertexArray(this.vao);
    gl.bindBuffer(gl.ARRAY_BUFFER, this.instanceBuffer);
    gl.bufferData(gl.ARRAY_BUFFER, this.data.subarray(0, this.count * INSTANCE_FLOATS), gl.DYNAMIC_DRAW);
    gl.drawElementsInstanced(gl.TRIANGLES, 36, gl.UNSIGNED_SHORT, 0, this.count);
    gl.bindVertexArray(null);
  }
}
