// Minimal, allocation-free-ish 3D math used by the renderer and gameplay.
// Matrices are column-major Float32Array(16), matching WebGL uniforms.

export type Vec3 = { x: number; y: number; z: number };
export type Mat4 = Float32Array;

export const vec3 = (x = 0, y = 0, z = 0): Vec3 => ({ x, y, z });
export const add = (a: Vec3, b: Vec3): Vec3 => vec3(a.x + b.x, a.y + b.y, a.z + b.z);
export const sub = (a: Vec3, b: Vec3): Vec3 => vec3(a.x - b.x, a.y - b.y, a.z - b.z);
export const scale = (a: Vec3, s: number): Vec3 => vec3(a.x * s, a.y * s, a.z * s);
export const dot = (a: Vec3, b: Vec3): number => a.x * b.x + a.y * b.y + a.z * b.z;
export const length = (a: Vec3): number => Math.sqrt(dot(a, a));

export function normalize(a: Vec3): Vec3 {
  const l = length(a) || 1;
  return vec3(a.x / l, a.y / l, a.z / l);
}

export function lerp(a: number, b: number, t: number): number {
  return a + (b - a) * t;
}

export function clamp(v: number, lo: number, hi: number): number {
  return v < lo ? lo : v > hi ? hi : v;
}

/** Shortest signed angular difference a -> b, in radians. */
export function angleDelta(a: number, b: number): number {
  let d = (b - a) % (Math.PI * 2);
  if (d > Math.PI) d -= Math.PI * 2;
  if (d < -Math.PI) d += Math.PI * 2;
  return d;
}

export function mat4(): Mat4 {
  return new Float32Array(16);
}

export function identity(out: Mat4): Mat4 {
  out.fill(0);
  out[0] = out[5] = out[10] = out[15] = 1;
  return out;
}

/** out = a * b (column-major). out must not alias a or b. */
export function multiply(out: Mat4, a: Mat4, b: Mat4): Mat4 {
  for (let c = 0; c < 4; c++) {
    const b0 = b[c * 4], b1 = b[c * 4 + 1], b2 = b[c * 4 + 2], b3 = b[c * 4 + 3];
    out[c * 4] = a[0] * b0 + a[4] * b1 + a[8] * b2 + a[12] * b3;
    out[c * 4 + 1] = a[1] * b0 + a[5] * b1 + a[9] * b2 + a[13] * b3;
    out[c * 4 + 2] = a[2] * b0 + a[6] * b1 + a[10] * b2 + a[14] * b3;
    out[c * 4 + 3] = a[3] * b0 + a[7] * b1 + a[11] * b2 + a[15] * b3;
  }
  return out;
}

export function perspective(out: Mat4, fovY: number, aspect: number, near: number, far: number): Mat4 {
  const f = 1 / Math.tan(fovY / 2);
  out.fill(0);
  out[0] = f / aspect;
  out[5] = f;
  out[10] = (far + near) / (near - far);
  out[11] = -1;
  out[14] = (2 * far * near) / (near - far);
  return out;
}

export function lookAt(out: Mat4, eye: Vec3, center: Vec3, up: Vec3): Mat4 {
  const z = normalize(sub(eye, center));
  const x = normalize(vec3(up.y * z.z - up.z * z.y, up.z * z.x - up.x * z.z, up.x * z.y - up.y * z.x));
  const y = vec3(z.y * x.z - z.z * x.y, z.z * x.x - z.x * z.x, z.x * x.y - z.y * x.x);
  out[0] = x.x; out[1] = y.x; out[2] = z.x; out[3] = 0;
  out[4] = x.y; out[5] = y.y; out[6] = z.y; out[7] = 0;
  out[8] = x.z; out[9] = y.z; out[10] = z.z; out[11] = 0;
  out[12] = -dot(x, eye);
  out[13] = -dot(y, eye);
  out[14] = -dot(z, eye);
  out[15] = 1;
  return out;
}

/**
 * Model matrix from translation, yaw (Y), pitch (X) and scale.
 * Written into `out` at an offset so it can fill an instance buffer directly.
 */
export function compose(
  out: Float32Array,
  offset: number,
  x: number, y: number, z: number,
  yaw: number, pitch: number,
  sx: number, sy: number, sz: number,
): void {
  const c = Math.cos(yaw), s = Math.sin(yaw);
  const cp = Math.cos(pitch), sp = Math.sin(pitch);
  // R = Ry(yaw) * Rx(pitch), then scaled on each local axis (column-major).
  out[offset + 0] = sx * c;
  out[offset + 1] = 0;
  out[offset + 2] = -sx * s;
  out[offset + 3] = 0;

  out[offset + 4] = sy * s * sp;
  out[offset + 5] = sy * cp;
  out[offset + 6] = sy * c * sp;
  out[offset + 7] = 0;

  out[offset + 8] = sz * s * cp;
  out[offset + 9] = -sz * sp;
  out[offset + 10] = sz * c * cp;
  out[offset + 11] = 0;

  out[offset + 12] = x;
  out[offset + 13] = y;
  out[offset + 14] = z;
  out[offset + 15] = 1;
}
