"""Reconstruit seulement les 7 actions de Kael Anime Fantasy dans le .blend existant
(maillage, poids, textures et exports du modèle inchangés), puis recale au sol.

    blender -b art/kael/anime_fantasy/build/F001_Kael_AF.blend --python art/kael/anime_fantasy/af_rebuild_actions.py -- \
        [--save <fichier.blend>] [--skill '<json>']

--save : enregistre ailleurs (essai) ; sinon le .blend ouvert est réenregistré.
--skill : remplace kael_af_build.SKILL_ARMS pour un essai, ex.
          '{"8": {"RightUpperArm": [-30, 68, 0]}}'.
"""

import json
import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kael_af_build as B  # noqa: E402


def option(name):
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    return argv[argv.index(name) + 1] if name in argv else None


def main():
    trial = option("--skill")
    if trial:
        override = {}
        for frame, arms in json.loads(trial).items():
            override[int(frame)] = {bone: tuple(angles) for bone, angles in arms.items()}
        B.SKILL_ARMS = override
    rig = bpy.data.objects["F001_Kael"]
    mesh = bpy.data.objects["F001_Kael_AF_Mesh"]
    for action in list(bpy.data.actions):
        if action.name.startswith("F001_Kael_"):
            bpy.data.actions.remove(action)
    actions = B.build_animations(rig)
    changes = B.fix_ground(mesh, rig, actions)
    rig.animation_data.action = None
    for pb in rig.pose.bones:
        pb.location = (0, 0, 0)
        pb.rotation_euler = (0, 0, 0)
    target = option("--save") or bpy.data.filepath
    bpy.ops.wm.save_as_mainfile(filepath=target, copy=bool(option("--save")))
    print("[Rebuild] actions", sorted(a.name for a in bpy.data.actions), "recalage", changes, "->", target)


main()
