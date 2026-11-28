// Audio for the sandbox: five scored music beds, an ambience layer and one-shot
// effects, all shipped inside the build so the game is silent-free offline.
//
// Browsers and Android WebViews refuse to start audio before a user gesture, so
// nothing is created until `unlock()` is called from the first tap or key press.
// Everything after that is plain HTMLAudioElement: no decoder, no fetch of a
// 20 MB decode buffer, and the media stack streams from the packaged files.

export type SfxId =
  | "sword-clash"
  | "sword-draw"
  | "arrow"
  | "horse-gallop"
  | "war-drums"
  | "bell"
  | "coins"
  | "anvil"
  | "chop"
  | "gate"
  | "cheer"
  | "horn"
  | "blast"
  | "fire"
  | "wind"
  | "page"
  | "waves"
  | "seagull"
  | "crows"
  | "armour";

/** Files live under public/audio and are copied verbatim into the APK. */
const SFX: Record<SfxId, string> = {
  "sword-clash": "audio/sfx/sword-clash.mp3",
  "sword-draw": "audio/sfx/sword-draw.mp3",
  arrow: "audio/sfx/arrow.mp3",
  "horse-gallop": "audio/sfx/horse-gallop.mp3",
  "war-drums": "audio/sfx/war-drums.mp3",
  bell: "audio/sfx/bell.mp3",
  coins: "audio/sfx/coins.mp3",
  anvil: "audio/sfx/anvil.mp3",
  chop: "audio/sfx/chop.mp3",
  gate: "audio/sfx/gate.mp3",
  cheer: "audio/sfx/cheer.mp3",
  horn: "audio/sfx/horn.mp3",
  blast: "audio/sfx/blast.mp3",
  fire: "audio/sfx/fire.mp3",
  wind: "audio/sfx/wind.mp3",
  page: "audio/sfx/page.mp3",
  waves: "audio/sfx/waves.mp3",
  seagull: "audio/sfx/seagull.mp3",
  crows: "audio/sfx/crows.mp3",
  armour: "audio/sfx/armour.mp3",
};

export type MusicId = "overworld" | "council" | "battle" | "night" | "campaign";

export const MUSIC: Record<MusicId, string> = {
  overworld: "audio/music/heartland.ogg",
  council: "audio/music/elder-magic.ogg",
  battle: "audio/music/edge-of-silence.ogg",
  night: "audio/music/silent-waters.ogg",
  campaign: "audio/music/bridge-unseen.opus",
};

const MUSIC_VOLUME = 0.32;
const AMBIENCE_VOLUME = 0.16;
const MUTE_KEY = "forge.audio.muted";

type OneShot = { volume?: number; /** seconds before a long recording is faded out */ maxSeconds?: number };

export class AudioDirector {
  readonly supported: boolean;
  muted = false;
  unlocked = false;
  private pendingMusic: MusicId | null = "campaign";
  private music: HTMLAudioElement | null = null;
  private musicId: MusicId | null = null;
  private ambience: HTMLAudioElement | null = null;
  private ambienceId: SfxId | null = null;
  private pool = new Map<SfxId, HTMLAudioElement[]>();

  constructor() {
    const probe = typeof document !== "undefined" ? document.createElement("audio") : null;
    this.supported = Boolean(probe && typeof probe.play === "function");
    try {
      this.muted = localStorage.getItem(MUTE_KEY) === "1";
    } catch {
      // private mode: audio simply starts unmuted
    }
  }

  /** Call from a real user gesture; safe to call more than once. */
  unlock(): void {
    if (!this.supported) return;
    this.unlocked = true;
    if (this.pendingMusic) {
      const next = this.pendingMusic;
      this.pendingMusic = null;
      this.setMusic(next);
    }
  }

  setMusic(id: MusicId): void {
    if (!this.unlocked) {
      this.pendingMusic = id;
      return;
    }
    if (this.musicId === id) return;
    this.musicId = id;

    const previous = this.music;
    if (previous) {
      this.fade(previous, 0, 900, () => {
        previous.pause();
        previous.removeAttribute("src");
      });
    }

    const track = new Audio(MUSIC[id]);
    track.loop = true;
    track.preload = "auto";
    track.volume = 0;
    this.music = track;
    if (this.muted) return;
    void track.play().catch(() => {});
    this.fade(track, MUSIC_VOLUME, 1400);
  }

  /** A looping bed for the place the player stands in (wind, surf, hearth). */
  setAmbience(id: SfxId | null): void {
    if (!this.unlocked || this.ambienceId === id) return;
    const previous = this.ambience;
    if (previous) {
      this.fade(previous, 0, 700, () => {
        previous.pause();
        previous.removeAttribute("src");
      });
    }
    this.ambienceId = id;
    this.ambience = null;
    if (!id) return;
    const bed = new Audio(SFX[id]);
    bed.loop = true;
    bed.preload = "none";
    bed.volume = 0;
    this.ambience = bed;
    if (this.muted) return;
    void bed.play().catch(() => {});
    this.fade(bed, AMBIENCE_VOLUME, 1200);
  }

  play(id: SfxId, options: OneShot = {}): void {
    if (!this.supported || !this.unlocked || this.muted) return;
    const volume = options.volume ?? 0.75;
    let voices = this.pool.get(id);
    if (!voices) {
      voices = [];
      this.pool.set(id, voices);
    }
    let voice = voices.find((candidate) => candidate.paused || candidate.ended);
    if (!voice) {
      if (voices.length >= 3) voice = voices[0];
      else {
        voice = new Audio(SFX[id]);
        voice.preload = "auto";
        voices.push(voice);
      }
    }
    if (!voice) return;
    try {
      voice.currentTime = 0;
    } catch {
      // not seekable yet; replaying from the start is not worth an error
    }
    voice.volume = volume;
    void voice.play().catch(() => {});
    if (options.maxSeconds) {
      const fading = voice;
      window.setTimeout(() => this.fade(fading, 0, 600, () => fading.pause()), options.maxSeconds * 1000);
    }
  }

  /** Returns the new mute state. */
  toggleMute(): boolean {
    this.muted = !this.muted;
    try {
      localStorage.setItem(MUTE_KEY, this.muted ? "1" : "0");
    } catch {
      // ignore storage failures
    }
    if (this.music) {
      if (this.muted) this.music.pause();
      else {
        this.music.volume = MUSIC_VOLUME;
        void this.music.play().catch(() => {});
      }
    }
    if (this.ambience) {
      if (this.muted) this.ambience.pause();
      else {
        this.ambience.volume = AMBIENCE_VOLUME;
        void this.ambience.play().catch(() => {});
      }
    }
    return this.muted;
  }

  private fade(audio: HTMLAudioElement, to: number, ms: number, done?: () => void): void {
    const from = audio.volume;
    const start = performance.now();
    const step = () => {
      const t = Math.min(1, (performance.now() - start) / ms);
      audio.volume = Math.max(0, Math.min(1, from + (to - from) * t));
      if (t < 1) requestAnimationFrame(step);
      else done?.();
    };
    requestAnimationFrame(step);
  }
}
