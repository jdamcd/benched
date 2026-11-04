#!/usr/bin/env python3
"""Draws Benched's gauge: the app icon's layers, and a menu bar image for every 10%.

Both come from the same shapes, so edit this and rerun it rather than editing the
SVGs, then commit what it writes:

    scripts/draw-gauge.py

The gauge is a faint ring with a sweep that brightens towards a dot at the level.
6 o'clock is both 0 and 100%, and usage runs clockwise from it, so the sweep
starts there and never crosses it. SVG has no sweep (conic) gradient, so the
sweep is a stack of segments that all end at the level, and their opacity adds
up to a smooth ramp.
"""

import json
import math
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ICON_ASSETS = ROOT / "Benched/AppIcon.icon/Assets"
MENU_BAR_ASSETS = ROOT / "Benched/Assets.xcassets/MenuBarGauge"

# Proportions, relative to the ring's outer diameter
STROKE = 0.12  # ring thickness
DOT = 1.75  # the level dot's diameter, relative to the ring thickness
TRACK = 0.3  # the ring's opacity where there's no sweep
STEPS = 48  # segments in the sweep
ZERO = 270  # 6 o'clock, in degrees, maths convention

ICON_LEVEL = 2 / 3


def num(x):
    return f"{x:.2f}"


def point(cx, cy, r, angle):
    t = math.radians(angle)
    return (cx + r * math.cos(t), cy - r * math.sin(t))


def sector(cx, cy, r, s, a0, a1):
    """A butt-ended ring segment from a0 clockwise to a1"""
    if a0 - a1 > 180:
        # An arc that starts and ends at the same point draws nothing, so a full
        # circle has to be two halves. Subpaths of one path fill with no seam.
        mid = (a0 + a1) / 2
        return sector(cx, cy, r, s, a0, mid) + " " + sector(cx, cy, r, s, mid, a1)
    ro, ri = r + s / 2, r - s / 2
    o0, o1 = point(cx, cy, ro, a0), point(cx, cy, ro, a1)
    i0, i1 = point(cx, cy, ri, a0), point(cx, cy, ri, a1)
    return (
        f"M {num(o0[0])} {num(o0[1])} A {num(ro)} {num(ro)} 0 0 1 {num(o1[0])} {num(o1[1])} "
        f"L {num(i1[0])} {num(i1[1])} A {num(ri)} {num(ri)} 0 0 0 {num(i0[0])} {num(i0[1])} Z"
    )


def ring(cx, cy, r, s):
    ro, ri = r + s / 2, r - s / 2
    circle = lambda rr: (
        f"M {num(cx - rr)} {num(cy)} A {num(rr)} {num(rr)} 0 1 0 {num(cx + rr)} {num(cy)} "
        f"A {num(rr)} {num(rr)} 0 1 0 {num(cx - rr)} {num(cy)} Z"
    )
    return f'<path opacity="{TRACK}" fill-rule="evenodd" d="{circle(ro)} {circle(ri)}"/>'


def sweep(cx, cy, r, s, level):
    end = ZERO - 360 * level
    paths = []
    if level > 0:
        # Segment k runs from step k to the level. Stacked, their opacity builds up
        # to a ramp from 0 at 6 o'clock to 1 at the level.
        for k in range(1, STEPS + 1):
            opacity = 1.0 if k == STEPS else 1 - (STEPS - k) / (STEPS - k + 1)
            start = ZERO - 360 * level * (k - 1) / STEPS
            paths.append(f'<path opacity="{opacity:.4f}" d="{sector(cx, cy, r, s, start, end)}"/>')
    return paths


def dot(cx, cy, r, s, level):
    x, y = point(cx, cy, r, ZERO - 360 * level)
    return f'<circle cx="{num(x)}" cy="{num(y)}" r="{num(s * DOT / 2)}"/>'


def geometry(diameter, cx, cy):
    s = STROKE * diameter
    return cx, cy, (diameter - s) / 2, s


def svg(width, height, shapes, colour):
    body = "\n    ".join(shapes)
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {width} {height}" width="{width}" height="{height}">\n'
        f'  <g fill="{colour}">\n    {body}\n  </g>\n</svg>\n'
    )


def write_json(path, value):
    path.write_text(json.dumps(value, indent=2) + "\n")


def draw_icon():
    # Two layers: the ring flat, because glass evens out the sweep's gradient,
    # and the dot in glass, so it reads as a knob
    g = geometry(600, 512, 512)
    (ICON_ASSETS / "Gauge.svg").write_text(svg(1024, 1024, [ring(*g), *sweep(*g, ICON_LEVEL)], "#FFFFFF"))
    (ICON_ASSETS / "Level.svg").write_text(svg(1024, 1024, [dot(*g, ICON_LEVEL)], "#FFFFFF"))


def draw_menu_bar():
    # 14pt across, with 1pt either side like an SF Symbol, so the button's gap
    # to the text matches. 16pt tall, so a dot at 6 o'clock isn't clipped.
    g = geometry(14, 8, 8)
    shutil.rmtree(MENU_BAR_ASSETS, ignore_errors=True)
    MENU_BAR_ASSETS.mkdir(parents=True)
    write_json(MENU_BAR_ASSETS / "Contents.json", {"info": {"author": "xcode", "version": 1}})
    for percent in range(0, 101, 10):
        name = f"MenuBarGauge-{percent}"
        folder = MENU_BAR_ASSETS / f"{name}.imageset"
        folder.mkdir()
        level = percent / 100
        (folder / f"{name}.svg").write_text(svg(16, 16, [ring(*g), *sweep(*g, level), dot(*g, level)], "#000000"))
        write_json(folder / "Contents.json", {
            "images": [{"filename": f"{name}.svg", "idiom": "universal"}],
            "info": {"author": "xcode", "version": 1},
            "properties": {"preserves-vector-representation": True, "template-rendering-intent": "template"},
        })


if __name__ == "__main__":
    draw_icon()
    draw_menu_bar()
