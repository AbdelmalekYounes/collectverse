"""Plaques de combat contre modèles : quelle part de chaque combattant une plaque
masque-t-elle, selon la position des plaques ?

    python art/kael/anime_fantasy/plate_layout.py

Reprend la projection de plate_check.py (Arena.luau, BattleLayout.luau,
UnitPlate.luau) et y ajoute la silhouette projetée de chaque combattant (boîte de
3,4 × 2 studs, des pieds à sa hauteur) et les zones de l'interface de combat
(BattleHud : panneau du tour en haut à gauche, boutons en haut à droite, barre
d'ordres en bas). Compare plusieurs placements de plaques, sur PC 1920 × 1080 et
mobile 844 × 390. Écrit build/plate_layout.json.
"""

import json
import os

import plate_check as P

HEIGHTS = {"Kael": 7.38, "other": 6.0, "tall": 7.4}  # Kael AF (Studio) ; modèles provisoires ≈ 6
TALL_ALL = False  # True : 10 combattants de la taille de Kael AF (futurs modèles 3D)
MODEL_WIDTH, MODEL_DEPTH = 3.4, 2.0
HUD = {  # BattleHud (pixels, avant mise à l'échelle) : (gauche, haut, droite, bas), négatif = depuis la fin
    "turnPanel": (12, 10, 252, 92),
    "topButtons": (-332, 10, -12, 50),
    "commandBar": (None, -106, None, -10),  # 96 px de haut, 96 % de la largeur
}

# Placements comparés : décalage vertical (studs) du centre de la plaque, par camp et ligne.
LAYOUTS = {
    "actuel : au-dessus de tous": {("Ally", "Front"): "above", ("Ally", "Back"): "above", ("Enemy", "Front"): "above", ("Enemy", "Back"): "above"},
    "alliés avant sous les pieds": {("Ally", "Front"): "below", ("Ally", "Back"): "above", ("Enemy", "Front"): "above", ("Enemy", "Back"): "above"},
    "tous les alliés sous les pieds": {("Ally", "Front"): "below", ("Ally", "Back"): "below", ("Enemy", "Front"): "above", ("Enemy", "Back"): "above"},
    "alliés avant abaissés (tête + 0,9)": {("Ally", "Front"): "low", ("Ally", "Back"): "above", ("Enemy", "Front"): "above", ("Enemy", "Back"): "above"},
    "hauteur fixe (7,4 + 2,4) pour tous": {("Ally", "Front"): "fixed", ("Ally", "Back"): "fixed", ("Enemy", "Front"): "fixed", ("Enemy", "Back"): "fixed"},
    "proposé : alliés avant sous les pieds, autres à hauteur fixe": {("Ally", "Front"): "below", ("Ally", "Back"): "fixed", ("Enemy", "Front"): "fixed", ("Enemy", "Back"): "fixed"},
}
FIXED_HEIGHT = 7.4  # hauteur de référence des plaques au-dessus des têtes (plus grand modèle prévu)


def projector(screen):
    w, h = screen
    forward = P.norm(P.sub(P.TARGET, P.CAMERA))
    right = P.norm(P.cross(forward, (0, 1, 0)))
    up = P.cross(right, forward)
    focal = (h / 2) / P.math.tan(P.math.radians(P.fov(w / h)) / 2)

    def project(point):
        d = P.sub(point, P.CAMERA)
        depth = P.dot(d, forward)
        return w / 2 + focal * P.dot(d, right) / depth, h / 2 - focal * P.dot(d, up) / depth, depth

    return project, focal


def box(points):
    xs, ys = [p[0] for p in points], [p[1] for p in points]
    return (min(xs), min(ys), max(xs), max(ys))


def area(r):
    return max(0.0, r[2] - r[0]) * max(0.0, r[3] - r[1])


def inter(a, b):
    return (max(a[0], b[0]), max(a[1], b[1]), min(a[2], b[2]), min(a[3], b[3]))


def plate_center_y(mode, height):
    if mode == "above":
        return height + 2.4
    if mode == "low":
        return height + 0.9
    if mode == "fixed":
        return FIXED_HEIGHT + 2.4
    return -1.3  # sous les pieds : la plaque (2 studs) s'arrête juste sous le sol


def evaluate(layout, screen):
    project, focal = projector(screen)
    w, h = screen
    factor = min(1.0, max(0.35, h / 800))
    fighters = []
    for side, sign in (("Ally", 1), ("Enemy", -1)):
        for row in ("Front", "Back"):
            for x in P.ROW_X[row]:
                z = P.ROW_Z[row] * sign
                height = HEIGHTS["Kael"] if (row == "Front" and x == 0) else HEIGHTS["other"]
                height = HEIGHTS["tall"] if TALL_ALL else height
                corners = [project((x + dx, y, z + dz)) for dx in (-MODEL_WIDTH / 2, MODEL_WIDTH / 2) for dz in (-MODEL_DEPTH / 2, MODEL_DEPTH / 2) for y in (0, height)]
                cy = plate_center_y(layout[(side, row)], height)
                sx, sy, depth = project((x, cy, z))
                pw = focal * P.PLATE_STUDS[0] / depth + P.PLATE_PIXELS[0] * factor
                ph = focal * P.PLATE_STUDS[1] / depth + P.PLATE_PIXELS[1] * factor
                fighters.append({
                    "id": f"{side}{row}{x:+d}",
                    "model": box(corners),
                    "plate": (sx - pw / 2, sy - ph / 2, sx + pw / 2, sy + ph / 2),
                })
    hud = []
    for name, (l, t, r, b) in HUD.items():
        if name == "commandBar":
            hud.append((name, (w * 0.02, h + t, w * 0.98, h + b)))
        else:
            hud.append((name, (l if l >= 0 else w + l, t, r if r >= 0 else w + r, b)))
    result = {"modelsHidden": [], "plateOverlaps": [], "hudOverlaps": [], "offScreen": []}
    for f in fighters:
        p = f["plate"]
        if p[0] < 0 or p[1] < 0 or p[2] > w or p[3] > h:
            result["offScreen"].append(f["id"])
        for g in fighters:
            if g is f:
                continue
            covered = area(inter(p, g["model"])) / area(g["model"])
            if covered > 0.02:
                result["modelsHidden"].append({"plate": f["id"], "model": g["id"], "fraction": round(covered, 2)})
            if g["id"] > f["id"] and area(inter(p, g["plate"])) > 0:
                result["plateOverlaps"].append([f["id"], g["id"]])
        for name, r in hud:
            if area(inter(p, r)) > 0:
                result["hudOverlaps"].append([f["id"], name])
    result["worstHidden"] = max((m["fraction"] for m in result["modelsHidden"]), default=0)
    result["totalHidden"] = round(sum(m["fraction"] for m in result["modelsHidden"]), 2)
    return result


def main():
    global TALL_ALL
    report = {}
    for tall in (False, True):
      TALL_ALL = tall
      print("=== 10 combattants de 7,4 studs ===" if tall else "=== Kael AF au centre, modèles provisoires ailleurs ===")
      for name, layout in LAYOUTS.items():
        key = name + (" | tous à 7,4" if tall else "")
        report[key] = {screen: evaluate(layout, size) for screen, size in P.SCREENS.items()}
        for screen, r in report[key].items():
            print(f"{name:38s} {screen:6s} masqué max {r['worstHidden']:.2f} total {r['totalHidden']:.2f} "
                  f"plaques {len(r['plateOverlaps'])} HUD {r['hudOverlaps']} hors écran {r['offScreen']}")
            for m in sorted(r["modelsHidden"], key=lambda m: -m["fraction"])[:4]:
                print("      ", m)
    out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "build", "plate_layout.json")
    with open(out, "w", encoding="utf-8") as handle:
        json.dump(report, handle, indent=1)


if __name__ == "__main__":
    main()
