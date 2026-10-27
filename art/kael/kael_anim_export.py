"""Export des animations de Kael en images-clés pour Roblox (KeyframeSequence).

    blender -b art/kael/build/F001_Kael.blend --python art/kael/kael_anim_export.py -- \
        --out src/server/Dev/AnimationData/F001_Kael --step 2

Pourquoi ce format plutôt qu'un FBX d'animation : l'import FBX de l'éditeur
d'animation de Studio n'associait aucune piste aux os du rig importé (V0.2.2),
alors que l'Animator associe bien les poses aux os par leur nom (vérifié). On
exporte donc, pour chaque image échantillonnée et chaque os :

  - p : position de la tête de l'os posé, dans les axes Roblox, relative à
        l'origine de l'armature (les pieds, pivot du modèle) ;
  - q : rotation « monde » qui amène l'os de sa pose de repos à sa pose animée,
        dans les axes Roblox (quaternion w, x, y, z).

Ces deux grandeurs ne dépendent pas de l'orientation propre des os (roll, axes
locaux), qui diffère entre Blender et Roblox. Le module KeyframeBuilder recalcule
ensuite, à partir du vrai rig importé, le Transform local de chaque os.

Axes : Blender (Z haut, avant -Y) -> Roblox (Y haut, avant -Z) :
  X_roblox = -X_blender, Y_roblox = Z_blender, Z_roblox = Y_blender
(rotation propre, même conversion que l'export FBX -Z avant / Y haut).

Le fichier .blend de production n'est jamais modifié (lecture seule).
"""

import json
import math
import os
import sys

import bpy
from mathutils import Matrix

ANIMATIONS = ["Idle", "Attack", "Skill", "Ultimate", "Defend", "Hit", "Defeat"]
PRIORITIES = {"Idle": "Idle"}  # les autres : Action
FPS = 30

# Blender -> Roblox (orthonormale : inverse = transposée)
CONVERT = Matrix(((-1, 0, 0), (0, 0, 1), (0, 1, 0)))


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    out, step = "src/server/Dev/AnimationData/F001_Kael", 2
    for index, value in enumerate(argv):
        if value == "--out" and index + 1 < len(argv):
            out = argv[index + 1]
        elif value == "--step" and index + 1 < len(argv):
            step = int(argv[index + 1])
    return os.path.abspath(out), max(1, step)


def vec(v):
    r = CONVERT @ v
    return [round(r.x, 5), round(r.y, 5), round(r.z, 5)]


def world_delta(posed3, rest3):
    """Rotation qui amène l'orientation de repos à l'orientation animée (axes Roblox)."""
    delta = posed3 @ rest3.inverted()
    converted = CONVERT @ delta @ CONVERT.transposed()
    q = converted.to_quaternion().normalized()
    if q.w < 0:  # hémisphère unique : évite les sauts d'interpolation
        q.negate()
    return [round(q.w, 6), round(q.x, 6), round(q.y, 6), round(q.z, 6)]


def frame_list(start, end, step):
    frames = list(range(start, end + 1, step))
    if frames[-1] != end:
        frames.append(end)
    return frames


def main():
    out_dir, step = parse_args()
    os.makedirs(out_dir, exist_ok=True)
    scene = bpy.context.scene
    rig = bpy.data.objects["F001_Kael"]
    bones = [bone.name for bone in rig.data.bones]  # parents avant enfants (ordre de création)
    rest = {}
    for bone in rig.data.bones:
        rest[bone.name] = {
            "parent": bone.parent.name if bone.parent else None,
            "position": vec(bone.head_local),
            "rotation": bone.matrix_local.to_3x3().normalized(),
        }

    summary = {}
    for name in ANIMATIONS:
        action = bpy.data.actions["F001_Kael_" + name]
        rig.animation_data.action = action
        start, end = (int(round(f)) for f in action.frame_range)
        frames = []
        for frame in frame_list(start, end, step):
            scene.frame_set(frame)
            entry = {"time": round((frame - start) / FPS, 5), "bones": {}}
            for pose_bone in rig.pose.bones:
                posed = pose_bone.matrix  # espace de l'armature (à l'identité dans la scène)
                entry["bones"][pose_bone.name] = {
                    "p": vec(posed.translation),
                    "q": world_delta(posed.to_3x3().normalized(), rest[pose_bone.name]["rotation"]),
                }
            frames.append(entry)
        data = {
            "fighter": "F001",
            "model": "F001_Kael",
            "animation": name,
            "fps": FPS,
            "step": step,
            "length": round((end - start) / FPS, 5),
            "loop": name == "Idle",
            "priority": PRIORITIES.get(name, "Action"),
            "bones": bones,
            "parents": {b: rest[b]["parent"] for b in bones},
            "rest": {b: rest[b]["position"] for b in bones},
            "frames": frames,
        }
        path = os.path.join(out_dir, name + ".json")
        with open(path, "w", encoding="utf-8") as handle:
            json.dump(data, handle, separators=(",", ":"))
        summary[name] = {"frames": len(frames), "length": data["length"], "bytes": os.path.getsize(path)}
    rig.animation_data.action = None
    print("[KaelAnim]", json.dumps(summary))


if __name__ == "__main__":
    main()
