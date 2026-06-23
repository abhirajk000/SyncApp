#!/usr/bin/env python3
"""Generate Android launcher icons — zoomed out, centered in safe zone."""
from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image

ANDROID_RES = Path(__file__).resolve().parent.parent / "clients/android/app/src/main/res"
SIZES = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}
FOREGROUND_PX = 432
# Adaptive-icon safe zone ≈ 66/108 (61%). Zoom out so logo sits comfortably inside mask.
FOREGROUND_FILL = 0.55
LAUNCHER_FILL = 0.60
# In-app logo (login, header) — fuller than launcher foreground.
APP_LOGO_FILL = 0.78
BG_RGB = (244, 247, 251)  # #F4F7FB


def crop_content(im: Image.Image) -> Image.Image:
    bbox = im.getbbox()
    if not bbox:
        return im
    return im.crop(bbox)


def fit_contain(content: Image.Image, size: int, fill_ratio: float) -> Image.Image:
    """Scale down to fit inside the square with even padding (zoom out)."""
    cw, ch = content.size
    if cw == 0 or ch == 0:
        return Image.new("RGBA", (size, size), (0, 0, 0, 0))
    target = max(1, int(size * fill_ratio))
    scale = target / max(cw, ch)
    new_w = max(1, int(cw * scale))
    new_h = max(1, int(ch * scale))
    scaled = content.resize((new_w, new_h), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    canvas.paste(scaled, ((size - new_w) // 2, (size - new_h) // 2), scaled)
    return canvas


def composite_on_background(foreground: Image.Image, bg_rgb: tuple[int, int, int]) -> Image.Image:
    bg = Image.new("RGBA", foreground.size, (*bg_rgb, 255))
    bg.alpha_composite(foreground)
    return bg.convert("RGB")


def main() -> int:
    src = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parent.parent / "icon.png"
    if not src.is_file():
        print(f"Missing source icon: {src}", file=sys.stderr)
        return 1

    content = crop_content(Image.open(src).convert("RGBA"))

    drawable = ANDROID_RES / "drawable"
    drawable.mkdir(parents=True, exist_ok=True)
    foreground = fit_contain(content, FOREGROUND_PX, FOREGROUND_FILL)
    foreground.save(drawable / "ic_launcher_foreground.png")

    app_logo = fit_contain(content, 192, APP_LOGO_FILL)
    app_logo.save(drawable / "ic_app_logo.png")

    launcher = composite_on_background(fit_contain(content, 192, LAUNCHER_FILL), BG_RGB)

    for folder, px in SIZES.items():
        out_dir = ANDROID_RES / folder
        out_dir.mkdir(parents=True, exist_ok=True)
        icon = launcher.resize((px, px), Image.Resampling.LANCZOS)
        icon.save(out_dir / "ic_launcher.png")
        icon.save(out_dir / "ic_launcher_round.png")

    b = foreground.getbbox()
    if b:
        w, h = b[2] - b[0], b[3] - b[1]
        print(f"foreground content: {w}x{h} in {FOREGROUND_PX}px ({w/FOREGROUND_PX:.0%} x {h/FOREGROUND_PX:.0%})")
    print(f"Android icons written under {ANDROID_RES}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
