#!/usr/bin/env python3
"""Frame device captures inside Apple Design Resources bezel PNGs.

The bezel's screen area is transparent; the capture is scaled to cover that
hole (center-cropped) and composited underneath the bezel. Output is trimmed
to the device outline, ready for appstore-shots' compose.py.
"""

from pathlib import Path

import numpy as np
from PIL import Image

HERE = Path(__file__).parent

# capture -> bezel
JOBS = {
    "1.PNG": "bezels/watch-46mm-black.png",
    "2.PNG": "bezels/watch-46mm-black.png",
    "3.PNG": "bezels/watch-46mm-black.png",
    "4.PNG": "bezels/watch-46mm-black.png",
    "7.PNG": "bezels/watch-46mm-black.png",
    "5.PNG": "bezels/iphone-air-black.png",
    "6.PNG": "bezels/iphone-air-black.png",
}


def screen_hole(bezel: Image.Image) -> tuple[tuple[int, int, int, int], Image.Image]:
    """Locate the transparent screen cutout.

    Returns its bounding box plus a full-size paste mask: 255 - alpha inside the
    cutout (including its anti-aliased rim), 0 everywhere border-connected, so the
    capture never pokes past the device's rounded corners.
    """
    alpha = np.array(bezel.getchannel("A"), dtype=np.uint8)
    passable = alpha < 250
    outside = np.zeros_like(passable)
    # flood the border-connected (semi-)transparent region until stable
    outside[0, :] = passable[0, :]
    outside[-1, :] = passable[-1, :]
    outside[:, 0] |= passable[:, 0]
    outside[:, -1] |= passable[:, -1]
    while True:
        grown = outside.copy()
        grown[1:, :] |= outside[:-1, :]
        grown[:-1, :] |= outside[1:, :]
        grown[:, 1:] |= outside[:, :-1]
        grown[:, :-1] |= outside[:, 1:]
        grown &= passable
        if (grown == outside).all():
            break
        outside = grown
    interior = passable & ~outside
    mask = np.where(interior, 255 - alpha, 0).astype(np.uint8)
    hole = interior & (alpha < 8)
    ys, xs = np.nonzero(hole)
    bbox = (int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1)
    return bbox, Image.fromarray(mask, "L")


def cover(capture: Image.Image, w: int, h: int) -> Image.Image:
    """Scale to fill w x h, center-cropping any overshoot."""
    scale = max(w / capture.width, h / capture.height)
    scaled = capture.resize((round(capture.width * scale), round(capture.height * scale)), Image.LANCZOS)
    x = (scaled.width - w) // 2
    y = (scaled.height - h) // 2
    return scaled.crop((x, y, x + w, y + h))


def main() -> None:
    out_dir = HERE / "framed"
    out_dir.mkdir(exist_ok=True)
    holes: dict[str, tuple] = {}
    for capture_name, bezel_name in JOBS.items():
        bezel = Image.open(HERE / bezel_name).convert("RGBA")
        if bezel_name not in holes:
            holes[bezel_name] = screen_hole(bezel)
        (x0, y0, x1, y1), mask = holes[bezel_name]
        capture = Image.open(HERE / capture_name).convert("RGBA")
        layer = Image.new("RGBA", bezel.size, (0, 0, 0, 0))
        layer.paste(cover(capture, x1 - x0, y1 - y0), (x0, y0))
        out = Image.new("RGBA", bezel.size, (0, 0, 0, 0))
        out.paste(layer, (0, 0), mask)
        out.alpha_composite(bezel)
        out = out.crop(out.getbbox())
        path = out_dir / f"{Path(capture_name).stem}-framed.png"
        out.save(path)
        print(f"{path.name}: hole {x1 - x0}x{y1 - y0} in {bezel_name}, out {out.size[0]}x{out.size[1]}")


if __name__ == "__main__":
    main()
