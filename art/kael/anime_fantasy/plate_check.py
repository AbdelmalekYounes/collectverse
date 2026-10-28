"""Chevauchement des plaques de combat selon la hauteur des combattants.

    python art/kael/anime_fantasy/plate_check.py

Reprend Arena.luau (emplacements, caméra) et BattleLayout.luau / UnitPlate.luau
(plaque = BillboardGui de 4,4 × 2 studs + marge de 36 × 10 px réduite sur petit
écran, placée à hauteur du modèle + 2,4 studs). Projette les 10 plaques (5 contre 5)
sur PC 1920 × 1080 et mobile 844 × 390, et mesure les recouvrements deux à deux.
Écrit plate_check.json à côté du rapport du modèle.
"""

import json
import math
import os

ROW_X = {"Front": [-10, 0, 10], "Back": [-5, 5]}
ROW_Z = {"Front": 4.5, "Back": 10}
CAMERA = (0.0, 32.0, 34.0)
TARGET = (0.0, 0.0, -1.0)
BASE_FOV = 42
DESIGN_ASPECT = 16 / 9
PLATE_STUDS = (4.4, 2.0)
PLATE_PIXELS = (36, 10)
SCREENS = {"pc": (1920, 1080), "mobile": (844, 390)}


def sub(a, b):
    return tuple(x - y for x, y in zip(a, b))


def dot(a, b):
    return sum(x * y for x, y in zip(a, b))


def cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def norm(a):
    length = math.sqrt(dot(a, a))
    return tuple(x / length for x in a)


def fov(aspect):
    if aspect >= DESIGN_ASPECT:
        return BASE_FOV
    half = math.atan(math.tan(math.radians(BASE_FOV / 2)) * DESIGN_ASPECT)
    return min(2 * math.degrees(math.atan(math.tan(half) / aspect)), 110)


def plates(height, screen):
    w, h = screen
    forward = norm(sub(TARGET, CAMERA))
    right = norm(cross(forward, (0, 1, 0)))
    up = cross(right, forward)
    focal = (h / 2) / math.tan(math.radians(fov(w / h)) / 2)
    factor = min(1.0, max(0.35, h / 800))
    rects = []
    for side, sign in (("Ally", 1), ("Enemy", -1)):
        for row in ("Front", "Back"):
            for x in ROW_X[row]:
                center = (x, height + 2.4, ROW_Z[row] * sign)
                d = sub(center, CAMERA)
                depth = dot(d, forward)
                sx = w / 2 + focal * dot(d, right) / depth
                sy = h / 2 - focal * dot(d, up) / depth
                pw = focal * PLATE_STUDS[0] / depth + PLATE_PIXELS[0] * factor
                ph = focal * PLATE_STUDS[1] / depth + PLATE_PIXELS[1] * factor
                rects.append((f"{side}{row}{x:+d}", sx - pw / 2, sy - ph / 2, sx + pw / 2, sy + ph / 2))
    return rects


def overlaps(rects):
    found = []
    for i in range(len(rects)):
        for j in range(i + 1, len(rects)):
            a, b = rects[i], rects[j]
            ox = min(a[3], b[3]) - max(a[1], b[1])
            oy = min(a[4], b[4]) - max(a[2], b[2])
            if ox > 0 and oy > 0:
                found.append({"plates": [a[0], b[0]], "overlapPx": [round(ox, 1), round(oy, 1)]})
    return found


def main():
    results = {}
    for label, height in (("production_6.6", 6.6), ("anime_fantasy_7.27", 7.27), ("studio_extents_7.38", 7.38)):
        results[label] = {}
        for screen, size in SCREENS.items():
            rects = plates(height, size)
            inside = all(r[1] >= 0 and r[3] <= size[0] and r[2] >= 0 and r[4] <= size[1] for r in rects)
            results[label][screen] = {"overlaps": overlaps(rects), "allOnScreen": inside, "topPlateY": round(min(r[2] for r in rects), 1)}
    out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "build", "plate_check.json")
    with open(out, "w", encoding="utf-8") as handle:
        json.dump(results, handle, indent=2)
    print(json.dumps(results, indent=1))


if __name__ == "__main__":
    main()
