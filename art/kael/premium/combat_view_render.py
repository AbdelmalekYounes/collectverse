"""Kael vu par la vraie caméra de combat, à la taille réelle à l'écran (V0.2.4).

    blender -b <fichier.blend> --python art/kael/premium/combat_view_render.py -- \
        --out art/kael/premium/build/lookdev --tag after

Reprend les réglages du jeu (src/client/Battle/Arena.luau, BattleLayout.luau) :
caméra en (0, 32, 34) vers (0, 0, -1), champ vertical 42° (16:9 et plus large),
combattant au centre de la ligne avant :
  - allié en (0, 0, 4.5), tourné vers -Z : vu de dos et en plongée ;
  - ennemi en (0, 0, -4.5), tourné vers +Z : vu de face (l'Écho de Kael).
Deux écrans : PC 1920 × 1080 et téléphone en paysage 844 × 390. Seule la zone
autour du personnage est rendue, à sa taille réelle en pixels.

L'éclairage est celui du look-dev (lookdev_render.py), pas celui de l'arène Roblox :
c'est une estimation de lisibilité, à confirmer dans Studio après import.
"""

import importlib.util
import math
import os
import sys

import bpy
from bpy_extras.object_utils import world_to_camera_view
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location("lookdev_render", os.path.join(HERE, "lookdev_render.py"))
lookdev = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(lookdev)

FIELD_OF_VIEW = 42  # BattleLayout.BaseFieldOfView
CAMERA = Vector((0, 32, 34))  # Arena.cameraCFrame (repère Roblox, relatif à ORIGIN)
TARGET = Vector((0, 0, -1))
SLOTS = {"ally": (Vector((0, 0, 4.5)), False), "enemy": (Vector((0, 0, -4.5)), True)}
SCREENS = {"pc": (1920, 1080), "mobile": (844, 390)}


def to_blender(v):
    """Roblox -> Blender : X = -X, Y = Z, Z = Y (personnage à l'origine, avant vers -Y)."""
    return Vector((-v.x, v.z, v.y))


def relative(point, slot, turned):
    local = point - slot
    if turned:  # le modèle est tourné de 180° autour de la verticale
        local = Vector((-local.x, local.y, -local.z))
    return to_blender(local)


def character_bounds():
    points = []
    for obj in bpy.context.scene.objects:
        if obj.type == "MESH" and obj.name.startswith("F001_Kael"):
            points += [obj.matrix_world @ Vector(corner) for corner in obj.bound_box]
    return points


def main():
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    out_dir = os.path.abspath(argv[argv.index("--out") + 1])
    tag = argv[argv.index("--tag") + 1]
    os.makedirs(out_dir, exist_ok=True)
    camera = lookdev.setup_scene()
    camera.data.sensor_fit = "VERTICAL"
    scene = bpy.context.scene
    bounds = character_bounds()
    for slot_name, (slot, turned) in SLOTS.items():
        lookdev.aim(camera, relative(CAMERA, slot, turned), relative(TARGET, slot, turned))
        for screen, (width, height) in SCREENS.items():
            scene.render.resolution_x, scene.render.resolution_y = width, height
            # Champ vertical constant : 42° tant que l'écran est au moins 16:9.
            camera.data.angle_y = math.radians(FIELD_OF_VIEW)
            bpy.context.view_layer.update()
            projected = [world_to_camera_view(scene, camera, p) for p in bounds]
            margin = 0.01
            scene.render.use_border = True
            scene.render.use_crop_to_border = True
            scene.render.border_min_x = max(0.0, min(p.x for p in projected) - margin)
            scene.render.border_max_x = min(1.0, max(p.x for p in projected) + margin)
            scene.render.border_min_y = max(0.0, min(p.y for p in projected) - margin)
            scene.render.border_max_y = min(1.0, max(p.y for p in projected) + margin)
            pixels = (max(p.y for p in projected) - min(p.y for p in projected)) * height
            print(f"[Combat] {tag} {slot_name} {screen} : hauteur à l'écran ≈ {pixels:.0f} px")
            lookdev.render(os.path.join(out_dir, f"{tag}_combat_{slot_name}_{screen}.png"), width, height)


if __name__ == "__main__":
    main()
