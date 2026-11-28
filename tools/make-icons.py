#!/usr/bin/env python3
"""Build every Android launcher icon from one painted crest.

    python3 tools/make-icons.py

Source: public/art/app-icon.png (also used as the title-screen crest).
Writes legacy square/round mipmaps and the adaptive-icon background layers, so
the launcher icon on a phone is the same emblem the game opens with.
"""

from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "public" / "art" / "app-icon.png"
RES = ROOT / "android" / "app" / "src" / "main" / "res"
BACKGROUND = (18, 16, 13)

LEGACY = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
# 108 dp at each density, the canvas an adaptive icon is cut from
ADAPTIVE = {"mdpi": 108, "hdpi": 162, "xhdpi": 216, "xxhdpi": 324, "xxxhdpi": 432}


def square(image: Image.Image, size: int, inset: float, fill) -> Image.Image:
    canvas = Image.new("RGBA", (size, size), fill)
    inner = int(size * inset)
    art = image.resize((inner, inner), Image.LANCZOS)
    canvas.alpha_composite(art, ((size - inner) // 2, (size - inner) // 2))
    return canvas


def main() -> None:
    art = Image.open(SOURCE).convert("RGBA")
    # Ship the crest itself as a real PNG so every consumer decodes it the same way.
    if SOURCE.suffix == ".png" and art.size != (1024, 1024):
        art = art.resize((1024, 1024), Image.LANCZOS)
    art.save(SOURCE, "PNG", optimize=True)
    written = []

    for density, size in LEGACY.items():
        folder = RES / f"mipmap-{density}"
        folder.mkdir(parents=True, exist_ok=True)

        legacy = square(art, size, 0.94, BACKGROUND)
        legacy.save(folder / "ic_launcher.png", "PNG", optimize=True)

        mask = Image.new("L", (size * 4, size * 4), 0)
        ImageDraw.Draw(mask).ellipse((0, 0, size * 4 - 1, size * 4 - 1), fill=255)
        round_icon = legacy.copy()
        round_icon.putalpha(mask.resize((size, size), Image.LANCZOS))
        round_icon.save(folder / "ic_launcher_round.png", "PNG", optimize=True)

        adaptive = square(art, ADAPTIVE[density], 0.66, BACKGROUND)
        adaptive.save(folder / "ic_launcher_background.png", "PNG", optimize=True)

        transparent = Image.new("RGBA", (ADAPTIVE[density], ADAPTIVE[density]), (0, 0, 0, 0))
        transparent.save(folder / "ic_launcher_foreground.png", "PNG", optimize=True)

        written.append(density)

    for name in ("ic_launcher.xml", "ic_launcher_round.xml"):
        target = RES / "mipmap-anydpi-v26" / name
        if target.exists():
            text = target.read_text("utf-8").replace(
                '<background android:drawable="@color/ic_launcher_background"/>',
                '<background android:drawable="@mipmap/ic_launcher_background"/>',
            )
            target.write_text(text, "utf-8")

    print(f"icons written for {', '.join(written)} from {SOURCE.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
