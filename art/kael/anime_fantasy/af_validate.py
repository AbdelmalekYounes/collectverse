"""Validation technique de Kael Anime Fantasy : rig, poids, déformations,
intersections et transitions des 7 animations.

    blender -b art/kael/anime_fantasy/build/F001_Kael_AF.blend --python art/kael/anime_fantasy/af_validate.py -- \
        --out art/kael/anime_fantasy/build/animation_report.json

Contrôles, sur le maillage réellement déformé par le rig :
  - poids : sommets influencés par un os éloigné (> 0,9 stud du segment de l'os) ;
  - étirement : rapport longueur d'arête posée / au repos, pour chaque image-clé
    (signale les écrasements et « papillotes » aux articulations) ;
  - intersections : sommets de la cape et de l'épée qui entrent dans le corps ou
    l'armure (test de parité par lancer de rayons sur des volumes fermés) ;
  - transitions : écart de rotation de chaque os entre le début / la fin d'une
    action et la pose d'attente (Idle), que Roblox fond en 0,1 s.
Le .blend n'est pas modifié.
"""

import json
import math
import sys

import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

PARTS = {"body": 0, "armor": 1, "cape": 2, "sword": 3, "hair": 4, "head": 5}
PART_NAMES = {v: k for k, v in PARTS.items()}


def out_path():
    argv = sys.argv[sys.argv.index("--") + 1 :]
    return argv[argv.index("--out") + 1]


def segment_distance(p, a, b):
    ab = b - a
    t = max(0.0, min(1.0, (p - a).dot(ab) / max(ab.length_squared, 1e-9)))
    return (p - a.lerp(b, t)).length


def weight_audit(mesh, rig, part_of_vertex):
    bones = {b.name: (b.head_local, b.tail_local) for b in rig.data.bones}
    names = {g.index: g.name for g in mesh.vertex_groups}
    far, per_bone = [], {}
    for v in mesh.data.vertices:
        for g in v.groups:
            if g.weight <= 0:
                continue
            name = names[g.group]
            per_bone[name] = per_bone.get(name, 0) + 1
            head, tail = bones[name]
            d = segment_distance(v.co, head, tail)
            # La lame part de la main : sa longueur dépasse naturellement 0,9 stud
            if g.weight > 0.3 and d > 0.9 and name not in ("RightHand",):
                far.append((name, round(d, 2), round(g.weight, 2), PART_NAMES[part_of_vertex.get(v.index, 1)]))
    far.sort(key=lambda x: -x[1])
    by_part = {}
    for entry in far:
        by_part[entry[3]] = by_part.get(entry[3], 0) + 1
    return {"verticesPerBone": per_bone, "farWeights": len(far), "farWeightsByPart": by_part, "farWeightSamples": far[:8]}


def part_sets(mesh):
    attr = mesh.data.attributes["kael_part"]
    faces = {k: [] for k in PARTS.values()}
    verts = {k: set() for k in PARTS.values()}
    for poly, item in zip(mesh.data.polygons, attr.data):
        faces[item.value].append(poly.index)
        verts[item.value].update(poly.vertices)
    return faces, verts


def bvh_for(coords, polygons, face_ids):
    polys = [list(polygons[i].vertices) for i in face_ids]
    used = sorted({i for p in polys for i in p})
    remap = {old: new for new, old in enumerate(used)}
    return BVHTree.FromPolygons([coords[i] for i in used], [[remap[i] for i in p] for p in polys])


def inside(bvh, p, direction=Vector((0.577, 0.577, 0.577))):
    """Parité des intersections le long d'un rayon (volume fermé)."""
    count, origin = 0, p.copy()
    for _ in range(40):
        hit = bvh.ray_cast(origin, direction, 30.0)
        if hit[0] is None:
            break
        count += 1
        origin = hit[0] + direction * 1e-4
    return count % 2 == 1


def main():
    scene = bpy.context.scene
    rig = bpy.data.objects["F001_Kael"]
    mesh = bpy.data.objects["F001_Kael_AF_Mesh"]
    faces, verts = part_sets(mesh)
    rest = [v.co.copy() for v in mesh.data.vertices]
    edges = [tuple(e.vertices) for e in mesh.data.edges]
    rest_len = [(rest[a] - rest[b]).length for a, b in edges]
    body_parts = faces[PARTS["body"]] + faces[PARTS["armor"]]
    names = {g.index: g.name for g in mesh.vertex_groups}
    held = {v.index for v in mesh.data.vertices if sum(g.weight for g in v.groups if names[g.group] in ("RightHand", "RightLowerArm")) > 0.5}
    cape_vertices = sorted(verts[PARTS["cape"]])
    sword_vertices = sorted(verts[PARTS["sword"]])
    # Le bras droit et le gantelet tiennent l'épée : exclus du volume testé pour l'épée
    part_of_vertex = {}
    for part, ids in verts.items():
        for i in ids:
            part_of_vertex[i] = part
    edge_part = [part_of_vertex.get(a, 1) for a, _ in edges]
    report = {"weights": weight_audit(mesh, rig, part_of_vertex), "animations": {}}
    idle_start = None
    actions = {a.name[len("F001_Kael_"):]: a for a in bpy.data.actions if a.name.startswith("F001_Kael_")}

    def bone_rotations():
        return {pb.name: pb.matrix.to_quaternion() for pb in rig.pose.bones}

    rig.animation_data.action = actions["Idle"]
    scene.frame_set(1)
    idle_start = bone_rotations()
    for name in ["Idle", "Attack", "Skill", "Ultimate", "Defend", "Hit", "Defeat"]:
        action = actions[name]
        rig.animation_data.action = action
        keys = sorted({int(k.co.x) for c in action.fcurves for k in c.keyframe_points})
        entry = {"frames": keys, "maxStretch": [], "minStretch": [], "capeInside": [], "swordInside": []}
        for frame in keys:
            scene.frame_set(frame)
            depsgraph = bpy.context.evaluated_depsgraph_get()
            evaluated = mesh.evaluated_get(depsgraph)
            data = evaluated.to_mesh()
            coords = [v.co.copy() for v in data.vertices]
            ratios = [((coords[a] - coords[b]).length / l, edge_part[k]) for k, ((a, b), l) in enumerate(zip(edges, rest_len)) if l > 1e-4]
            entry["maxStretch"].append(round(max(r for r, _ in ratios), 2))
            entry["minStretch"].append(round(min(r for r, _ in ratios), 2))
            worst = {}
            for r, part in ratios:
                name_ = PART_NAMES[part]
                lo, hi = worst.get(name_, (1.0, 1.0))
                worst[name_] = (min(lo, r), max(hi, r))
            entry.setdefault("stretchByPart", []).append({k: [round(a, 2), round(b, 2)] for k, (a, b) in worst.items()})
            solid = bvh_for(coords, data.polygons, body_parts)
            entry["capeInside"].append(sum(1 for i in cape_vertices[::2] if inside(solid, coords[i])))
            sword_body = bvh_for(coords, data.polygons, [f for f in body_parts if not set(data.polygons[f].vertices) & held])
            entry["swordInside"].append(sum(1 for i in sword_vertices if i not in held and inside(sword_body, coords[i])))
            evaluated.to_mesh_clear()
        # Transitions : écart avec la pose d'attente au début et à la fin de l'action
        scene.frame_set(keys[0])
        start = bone_rotations()
        scene.frame_set(keys[-1])
        end = bone_rotations()
        def diff(pose):
            angles = []
            for b in pose:
                a = math.degrees(pose[b].rotation_difference(idle_start[b]).angle) % 360
                angles.append(min(a, 360 - a))
            return round(max(angles), 1)
        entry["startVsIdleDeg"] = diff(start)
        entry["endVsIdleDeg"] = diff(end)
        entry["capeSampled"] = len(cape_vertices[::2])
        report["animations"][name] = entry
    rig.animation_data.action = None
    scene.frame_set(1)
    report["summary"] = {
        "farWeights": report["weights"]["farWeights"],
        "worstStretch": max(max(e["maxStretch"]) for e in report["animations"].values()),
        "worstCompression": min(min(e["minStretch"]) for e in report["animations"].values()),
        "capeInsideMax": {k: max(e["capeInside"]) for k, e in report["animations"].items()},
        "swordInsideMax": {k: max(e["swordInside"]) for k, e in report["animations"].items()},
    }
    with open(out_path(), "w", encoding="utf-8") as handle:
        json.dump(report, handle, indent=2, ensure_ascii=False)
    print("[Validate]", json.dumps(report["summary"], ensure_ascii=False))
    for k, e in report["animations"].items():
        print("[Validate]", k, "étirement", e["maxStretch"], "compression", e["minStretch"], "cape", e["capeInside"], "épée", e["swordInside"], "début/fin vs Idle", e["startVsIdleDeg"], e["endVsIdleDeg"])


if __name__ == "__main__":
    main()
