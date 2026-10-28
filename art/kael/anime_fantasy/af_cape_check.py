"""Intersections bras / cape sur le maillage réellement déformé, image par image.

    blender -b art/kael/anime_fantasy/build/F001_Kael_AF.blend --python art/kael/anime_fantasy/af_cape_check.py -- \
        --out art/kael/anime_fantasy/build/cape_check.json [--step 1]

Pour chaque animation et chaque image (pas de 1 par défaut, plus fin que les
images-clés exportées), compte les paires de triangles bras / cape qui se
coupent (BVHTree.overlap), séparément pour le bras gauche et le bras droit.
Un triangle « bras » appartient au corps ou à l'armure et a ses sommets
majoritairement pesés sur un os de bras (épaule exclue : UpperTorso). Donne aussi
la profondeur : distance maximale des sommets du bras qui passent derrière la
surface de la cape (côté intérieur, vers le dos). Le .blend n'est pas modifié.
"""

import json
import sys

import bpy
from mathutils.bvhtree import BVHTree

PARTS = {"body": 0, "armor": 1, "cape": 2, "sword": 3, "hair": 4, "head": 5}
ARMS = {
    "Left": ("LeftUpperArm", "LeftLowerArm", "LeftHand"),
    "Right": ("RightUpperArm", "RightLowerArm", "RightHand"),
}
ANIMATIONS = ["Idle", "Attack", "Skill", "Ultimate", "Defend", "Hit", "Defeat"]


def args():
    argv = sys.argv[sys.argv.index("--") + 1 :]
    out = argv[argv.index("--out") + 1]
    step = int(argv[argv.index("--step") + 1]) if "--step" in argv else 1
    return out, step


def main():
    out, step = args()
    scene = bpy.context.scene
    rig = bpy.data.objects["F001_Kael"]
    mesh = bpy.data.objects["F001_Kael_AF_Mesh"]
    names = {g.index: g.name for g in mesh.vertex_groups}
    attr = mesh.data.attributes["kael_part"]

    def arm_of(vertex):
        best, side_best = 0.0, None
        for side, bones in ARMS.items():
            w = sum(g.weight for g in vertex.groups if names[g.group] in bones)
            if w > best:
                best, side_best = w, side
        return side_best if best > 0.5 else None

    vertex_arm = {v.index: arm_of(v) for v in mesh.data.vertices}
    arm_faces = {"Left": [], "Right": []}
    cape_faces = []
    for poly, item in zip(mesh.data.polygons, attr.data):
        if item.value == PARTS["cape"]:
            cape_faces.append(poly.index)
        elif item.value in (PARTS["body"], PARTS["armor"]):
            sides = [vertex_arm[i] for i in poly.vertices]
            for side in ARMS:
                if sides.count(side) * 2 > len(sides):
                    arm_faces[side].append(poly.index)

    def bvh(coords, polygons, ids):
        polys = [list(polygons[i].vertices) for i in ids]
        used = sorted({i for p in polys for i in p})
        remap = {old: new for new, old in enumerate(used)}
        return BVHTree.FromPolygons([coords[i] for i in used], [[remap[i] for i in p] for p in polys]), used

    actions = {a.name[len("F001_Kael_") :]: a for a in bpy.data.actions if a.name.startswith("F001_Kael_")}
    # Contacts au repos (col, fermoirs, épaulières posées contre la cape) : invisibles,
    # exclus. Seules les paires absentes au repos comptent comme traversées.
    rig.animation_data.action = None
    for pb in rig.pose.bones:
        pb.location = (0, 0, 0)
        pb.rotation_quaternion = (1, 0, 0, 0)
        pb.rotation_euler = (0, 0, 0)
    scene.frame_set(scene.frame_current)
    data = mesh.evaluated_get(bpy.context.evaluated_depsgraph_get()).to_mesh()
    coords = [v.co.copy() for v in data.vertices]
    cape_rest, cape_used = bvh(coords, data.polygons, cape_faces)
    rest_pairs = {}
    for side, ids in arm_faces.items():
        tree, _ = bvh(coords, data.polygons, ids)
        rest_pairs[side] = set(tree.overlap(cape_rest))
    mesh.evaluated_get(bpy.context.evaluated_depsgraph_get()).to_mesh_clear()
    report = {"step": step, "restContactPairs": {k: len(v) for k, v in rest_pairs.items()}, "armFaces": {k: len(v) for k, v in arm_faces.items()}, "capeFaces": len(cape_faces), "animations": {}}
    for name in ANIMATIONS:
        action = actions[name]
        rig.animation_data.action = action
        first, last = (int(x) for x in action.frame_range)
        frames = list(range(first, last + 1, step))
        if frames[-1] != last:
            frames.append(last)
        entry = {"frames": [], "worst": None}
        for frame in frames:
            scene.frame_set(frame)
            depsgraph = bpy.context.evaluated_depsgraph_get()
            evaluated = mesh.evaluated_get(depsgraph)
            data = evaluated.to_mesh()
            coords = [v.co.copy() for v in data.vertices]
            cape, _ = bvh(coords, data.polygons, cape_faces)
            row = {"frame": frame}
            for side, ids in arm_faces.items():
                tree, used = bvh(coords, data.polygons, ids)
                pairs = [p for p in tree.overlap(cape) if p not in rest_pairs[side]]
                # Profondeur : sommets du bras situés du côté intérieur de la cape (normale
                # de la cape orientée vers l'extérieur) et à moins de 0,3 stud de sa surface.
                depth = 0.0
                if pairs:
                    for i in used:
                        hit = cape.find_nearest(coords[i], 0.3)
                        if hit[0] is not None and (coords[i] - hit[0]).dot(hit[1]) < 0:
                            depth = max(depth, hit[3])
                row[side] = {"pairs": len(pairs), "depth": round(depth, 3)}
            evaluated.to_mesh_clear()
            entry["frames"].append(row)
            score = row["Left"]["pairs"] + row["Right"]["pairs"]
            if score and (entry["worst"] is None or score > entry["worst"]["pairs"]):
                entry["worst"] = {"frame": frame, "pairs": score}
        entry["framesWithIntersection"] = [r["frame"] for r in entry["frames"] if r["Left"]["pairs"] + r["Right"]["pairs"] > 0]
        report["animations"][name] = entry
        print("[CapeCheck]", name, "images touchées", entry["framesWithIntersection"], "pire", entry["worst"])
    rig.animation_data.action = None
    with open(out, "w", encoding="utf-8") as handle:
        json.dump(report, handle, indent=1)
    print("[CapeCheck] ->", out)


main()
