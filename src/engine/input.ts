// Keyboard, mouse and touch input normalised into one small surface.
// Touch: left half of the screen is a virtual stick, right half looks around.

export class Input {
  private keys = new Set<string>();
  private pressed = new Set<string>();
  private pointerDown = false;
  lookX = 0;
  lookY = 0;
  wheel = 0;
  attackQueued = false;
  pointerLocked = false;
  readonly isTouch = typeof window !== "undefined" && window.matchMedia("(pointer: coarse)").matches;

  private stickId: number | null = null;
  private lookId: number | null = null;
  private stickOrigin = { x: 0, y: 0 };
  private lookLast = { x: 0, y: 0 };
  stick = { x: 0, y: 0 };
  /** Screen-space stick state, in CSS pixels, for the on-screen joystick. */
  readonly stickVisual = { active: false, originX: 0, originY: 0, x: 0, y: 0 };

  private target: HTMLElement;

  constructor(target: HTMLElement) {
    this.target = target;
    window.addEventListener("keydown", this.onKeyDown);
    window.addEventListener("keyup", this.onKeyUp);
    window.addEventListener("blur", this.onBlur);

    target.addEventListener("mousedown", this.onMouseDown);
    window.addEventListener("mouseup", this.onMouseUp);
    window.addEventListener("mousemove", this.onMouseMove);
    target.addEventListener("wheel", this.onWheel, { passive: false });
    target.addEventListener("contextmenu", (e) => e.preventDefault());

    target.addEventListener("touchstart", this.onTouchStart, { passive: false });
    target.addEventListener("touchmove", this.onTouchMove, { passive: false });
    target.addEventListener("touchend", this.onTouchEnd, { passive: false });
    target.addEventListener("touchcancel", this.onTouchEnd, { passive: false });
  }

  key(code: string): boolean {
    return this.keys.has(code);
  }

  axis(neg: string, pos: string): number {
    return (this.key(pos) ? 1 : 0) - (this.key(neg) ? 1 : 0);
  }

  wasPressed(code: string): boolean {
    return this.pressed.has(code);
  }

  /** Queue a strike from an on-screen button. */
  queueAttack(): void {
    this.attackQueued = true;
  }

  get moving(): boolean {
    return this.stick.x !== 0 || this.stick.y !== 0 ||
      this.keys.has("KeyW") || this.keys.has("KeyA") ||
      this.keys.has("KeyS") || this.keys.has("KeyD");
  }

  endFrame(): void {
    this.lookX = 0;
    this.lookY = 0;
    this.wheel = 0;
    this.pressed.clear();
    this.attackQueued = false;
  }

  private onKeyDown = (event: KeyboardEvent) => {
    if (event.repeat) return;
    // Never steal keys from editor text fields.
    const el = document.activeElement;
    if (el instanceof HTMLInputElement || el instanceof HTMLTextAreaElement) return;
    this.keys.add(event.code);
    this.pressed.add(event.code);
    if (event.code === "Space") {
      this.attackQueued = true;
      event.preventDefault();
    }
  };

  private onKeyUp = (event: KeyboardEvent) => {
    this.keys.delete(event.code);
  };

  private onBlur = () => {
    this.keys.clear();
    this.stick.x = 0;
    this.stick.y = 0;
    this.stickVisual.active = false;
    this.stickVisual.x = 0;
    this.stickVisual.y = 0;
  };

  private onMouseDown = (event: MouseEvent) => {
    if (event.button !== 0) return;
    this.pointerDown = true;
    this.attackQueued = true;
  };

  private onMouseUp = () => {
    this.pointerDown = false;
  };

  private onMouseMove = (event: MouseEvent) => {
    if (!this.pointerDown && !this.pointerLocked) return;
    this.lookX += event.movementX || 0;
    this.lookY += event.movementY || 0;
  };

  private onWheel = (event: WheelEvent) => {
    this.wheel += event.deltaY;
    event.preventDefault();
  };

  private onTouchStart = (event: TouchEvent) => {
    for (const touch of Array.from(event.changedTouches)) {
      if (touch.clientX < this.target.clientWidth * 0.45 && this.stickId === null) {
        this.stickId = touch.identifier;
        this.stickOrigin = { x: touch.clientX, y: touch.clientY };
        this.stick = { x: 0, y: 0 };
        this.stickVisual.active = true;
        this.stickVisual.originX = touch.clientX;
        this.stickVisual.originY = touch.clientY;
        this.stickVisual.x = 0;
        this.stickVisual.y = 0;
      } else if (this.lookId === null) {
        this.lookId = touch.identifier;
        this.lookLast = { x: touch.clientX, y: touch.clientY };
        this.attackQueued = true;
      }
    }
    event.preventDefault();
  };

  private onTouchMove = (event: TouchEvent) => {
    for (const touch of Array.from(event.changedTouches)) {
      if (touch.identifier === this.stickId) {
        const dx = touch.clientX - this.stickOrigin.x;
        const dy = touch.clientY - this.stickOrigin.y;
        const max = 56;
        this.stick = {
          x: Math.max(-1, Math.min(1, dx / max)),
          y: Math.max(-1, Math.min(1, dy / max)),
        };
        this.stickVisual.x = this.stick.x;
        this.stickVisual.y = this.stick.y;
      } else if (touch.identifier === this.lookId) {
        // Touch events carry no movementX/Y, so track the last position ourselves;
        // without this the camera could not be turned on a phone at all.
        this.lookX += touch.clientX - this.lookLast.x;
        this.lookY += touch.clientY - this.lookLast.y;
        this.lookLast = { x: touch.clientX, y: touch.clientY };
      }
    }
    event.preventDefault();
  };

  private onTouchEnd = (event: TouchEvent) => {
    for (const touch of Array.from(event.changedTouches)) {
      if (touch.identifier === this.stickId) {
        this.stickId = null;
        this.stick = { x: 0, y: 0 };
        this.stickVisual.active = false;
        this.stickVisual.x = 0;
        this.stickVisual.y = 0;
      }
      if (touch.identifier === this.lookId) this.lookId = null;
    }
  };
}
