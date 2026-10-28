"""Kael (F001) — Anime Fantasy (V0.2.5) : nouveau modèle 3D complet.

    blender -b --factory-startup --python art/kael/anime_fantasy/kael_af_build.py -- \
        --out art/kael/anime_fantasy/build [--stage A|B|C|full]

Nouveau personnage, construit dans Blender par script (reproductible) :
  - proportions héroïques anime (≈ 7,3 têtes, 7 studs), corps continu déformable ;
  - visage mature (décalques peints par shader puis cuits), cheveux en mèches courbes ;
  - armure en coques biseautées, épée des braises, cape à plis ;
  - textures cuites dans un atlas (couleur, émission, rugosité, métal, normales) ;
  - même squelette que la production (17 os, mêmes noms et hiérarchie), repositionné
    pour les nouvelles proportions : les animations sont reconstruites à partir des
    mêmes intentions (kael_build.ANIMATIONS) et réexportées par kael_anim_export.py.

Le modèle de production (assets/Fighters/F001_Kael.rbxm) n'est pas touché.
"""

import importlib.util
import json
import math
import os
import sys

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import af_lib as L  # noqa: E402
import kael_af_head as H  # noqa: E402
import kael_af_materials as M  # noqa: E402
import kael_af_parts as P  # noqa: E402

_spec = importlib.util.spec_from_file_location("kael_build", os.path.join(HERE, "..", "kael_build.py"))
base = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(base)

NAME = "F001_Kael_AF"
FPS = 30

# --------------------------------------------------------------------------- #
# Proportions (Blender : Z haut, le personnage regarde vers -Y, sa gauche en +X)
# --------------------------------------------------------------------------- #
# Hauteur au sommet du crâne : 6,9 studs (cheveux jusqu'à ≈ 7,2). Tête ≈ 0,95 :
# 7,3 têtes. Entrejambe à 3,4 : jambes longues (≈ 49 % de la hauteur).
CROWN = 6.9
HEAD_HEIGHT = 0.95

# Mêmes os, mêmes noms et même hiérarchie que la production (BONES de kael_build.py).
BONES = {
    "Root": ((0, 0, 0), (0, 0, 0.6), None),
    "HumanoidRootPart": ((0, 0, 3.55), (0, 0, 3.85), "Root"),
    "LowerTorso": ((0, 0, 3.55), (0, 0, 4.3), "HumanoidRootPart"),
    "UpperTorso": ((0, 0, 4.3), (0, 0, 5.62), "LowerTorso"),
    "Head": ((0, 0, 5.78), (0, 0, 6.9), "UpperTorso"),
    "LeftUpperArm": ((0.66, 0, 5.42), (0.95, 0.04, 4.36), "UpperTorso"),
    "LeftLowerArm": ((0.95, 0.04, 4.36), (1.06, -0.04, 3.38), "LeftUpperArm"),
    "LeftHand": ((1.06, -0.04, 3.38), (1.1, -0.1, 2.98), "LeftLowerArm"),
    "RightUpperArm": ((-0.66, 0, 5.42), (-0.95, 0.04, 4.36), "UpperTorso"),
    "RightLowerArm": ((-0.95, 0.04, 4.36), (-1.06, -0.04, 3.38), "RightUpperArm"),
    "RightHand": ((-1.06, -0.04, 3.38), (-1.1, -0.1, 2.98), "RightLowerArm"),
    "LeftUpperLeg": ((0.3, 0, 3.55), (0.32, 0.02, 1.9), "LowerTorso"),
    "LeftLowerLeg": ((0.32, 0.02, 1.9), (0.33, 0.06, 0.32), "LeftUpperLeg"),
    "LeftFoot": ((0.33, 0.06, 0.32), (0.33, -0.5, 0.06), "LeftLowerLeg"),
    "RightUpperLeg": ((-0.3, 0, 3.55), (-0.32, 0.02, 1.9), "LowerTorso"),
    "RightLowerLeg": ((-0.32, 0.02, 1.9), (-0.33, 0.06, 0.32), "RightUpperLeg"),
    "RightFoot": ((-0.33, 0.06, 0.32), (-0.33, -0.5, 0.06), "RightLowerLeg"),
}


def bp(name, end=False):
    head, tail, _ = BONES[name]
    return Vector(tail if end else head)


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    out = argv[argv.index("--out") + 1] if "--out" in argv else os.path.join(HERE, "build")
    stage = argv[argv.index("--stage") + 1] if "--stage" in argv else "full"
    return os.path.abspath(out), stage


# --------------------------------------------------------------------------- #
# Squelette
# --------------------------------------------------------------------------- #


def build_armature():
    data = bpy.data.armatures.new("F001_Kael_Rig")
    rig = L.link(bpy.data.objects.new("F001_Kael", data))
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")
    for name, (head, tail, _) in BONES.items():
        bone = data.edit_bones.new(name)
        bone.head, bone.tail = Vector(head), Vector(tail)
        bone.roll = 0.0
    for name, (_, _, parent) in BONES.items():
        if parent:
            data.edit_bones[name].parent = data.edit_bones[parent]
            data.edit_bones[name].use_connect = False
    bpy.ops.object.mode_set(mode="OBJECT")
    return rig


# --------------------------------------------------------------------------- #
# Étape A : corps (sous-armure noire) et tête
# --------------------------------------------------------------------------- #


SKIN_COMPENSATION = 1.45


def build_body():
    """Corps continu par modificateur Skin : un graphe d'articulations avec des
    rayons, subdivisé. Bonne topologie aux articulations, entièrement déformable."""
    nodes = []  # (position, (rayon x, rayon y))
    edges = []

    # La subdivision contracte les sections du Skin d'environ 30 % : rayons compensés.
    def node(p, r):
        nodes.append((Vector(p), (r[0] * SKIN_COMPENSATION, r[1] * SKIN_COMPENSATION)))
        return len(nodes) - 1

    def link_nodes(a, b):
        edges.append((a, b))

    pelvis = node((0, 0.02, 3.62), (0.36, 0.24))
    waist = node((0, 0.02, 4.18), (0.29, 0.2))
    chest = node((0, 0.0, 4.8), (0.42, 0.26))
    upper = node((0, 0.02, 5.28), (0.47, 0.25))
    neck_base = node((0, 0.03, 5.6), (0.12, 0.11))
    neck_top = node((0, 0.04, 5.92), (0.1, 0.1))
    for a, b in ((pelvis, waist), (waist, chest), (chest, upper), (upper, neck_base), (neck_base, neck_top)):
        link_nodes(a, b)
    for sign in (1, -1):
        shoulder = node((0.58 * sign, 0.02, 5.4), (0.14, 0.14))
        bicep = node((0.8 * sign, 0.03, 4.9), (0.12, 0.12))
        elbow = node((0.95 * sign, 0.04, 4.36), (0.09, 0.09))
        forearm = node((1.01 * sign, 0.0, 3.9), (0.1, 0.09))
        wrist = node((1.06 * sign, -0.04, 3.38), (0.065, 0.055))
        hand = node((1.1 * sign, -0.1, 2.98), (0.07, 0.04))
        for a, b in ((upper, shoulder), (shoulder, bicep), (bicep, elbow), (elbow, forearm), (forearm, wrist), (wrist, hand)):
            link_nodes(a, b)
        hip = node((0.27 * sign, 0.02, 3.42), (0.19, 0.19))
        thigh = node((0.31 * sign, 0.0, 2.75), (0.19, 0.18))
        knee = node((0.32 * sign, 0.02, 1.9), (0.12, 0.12))
        calf = node((0.33 * sign, 0.07, 1.3), (0.13, 0.12))
        ankle = node((0.33 * sign, 0.06, 0.34), (0.075, 0.075))
        toe = node((0.33 * sign, -0.42, 0.08), (0.07, 0.045))
        for a, b in ((pelvis, hip), (hip, thigh), (thigh, knee), (knee, calf), (calf, ankle), (ankle, toe)):
            link_nodes(a, b)
    mesh = bpy.data.meshes.new("Body")
    mesh.from_pydata([tuple(p) for p, _ in nodes], edges, [])
    obj = L.link(bpy.data.objects.new("Body", mesh))
    skin = obj.modifiers.new("Skin", "SKIN")
    skin.branch_smoothing = 0.6
    skin.use_smooth_shade = True
    for i, (_, r) in enumerate(nodes):
        obj.data.skin_vertices[0].data[i].radius = r
    obj.data.skin_vertices[0].data[pelvis].use_root = True
    sub = obj.modifiers.new("Subdivision", "SUBSURF")
    sub.levels = sub.render_levels = 1
    # Le corps est en grande partie sous l'armure : réduction douce (passe 2)
    dec = obj.modifiers.new("Decimate", "DECIMATE")
    dec.ratio = 0.65
    L.apply_modifiers(obj)
    obj.data.materials.append(L.material("Under"))
    for poly in obj.data.polygons:
        poly.use_smooth = True
    return obj


HEAD_CENTER = Vector((0, 0.02, 6.43))
HEAD_RADII = (0.31, 0.34, 0.47)


def head_shape(v):
    """Tête anime adulte : crâne arrondi, face plus plate, mâchoire anguleuse,
    menton marqué, pommettes."""
    d = v - HEAD_CENTER
    zf = d.z / HEAD_RADII[2]
    x, y, z = d.x, d.y, d.z
    if zf < -0.05:  # mâchoire anguleuse (passe 2) : joues droites, angle marqué, menton net
        k1 = min(1.0, (-zf - 0.05) / 0.45)
        k2 = max(0.0, min(1.0, (-zf - 0.5) / 0.5))
        x *= 1 - 0.1 * k1 - 0.34 * k2 ** 1.2
        if y < 0:
            y *= 1 - 0.06 * k1 - 0.1 * k2
    if y < 0:  # visage plus plat que l'arrière du crâne
        y *= 0.9
        if -0.35 < zf < 0.05:  # pommettes légèrement saillantes
            x *= 1.03
    else:
        y *= 1.06 if zf > -0.3 else 1.0
    if zf > 0.3:  # sommet un peu plus large (volume des cheveux)
        x *= 1.02
    return HEAD_CENTER + Vector((x, y, z))


def head_front_y(head_bvh, x, z):
    hit = head_bvh.ray_cast(Vector((x, -2, z)), Vector((0, 1, 0)), 4)
    return hit[0].y if hit[0] is not None else HEAD_CENTER.y - HEAD_RADII[1]


def build_head():
    verts, faces = L.ellipsoid(HEAD_CENTER, HEAD_RADII, rings=14, segments=20)
    verts = [head_shape(v) for v in verts]
    head = L.object_from_data("Head", verts, faces, "Skin")
    # Avant du visage : matériau à part, plus de pixels dans l'atlas (yeux, sourcils, bouche)
    head.data.materials.append(L.material("Face"))
    for poly in head.data.polygons:
        if poly.center.y < HEAD_CENTER.y - 0.12 and 5.98 < poly.center.z < 6.72:
            poly.material_index = 1
    # Nez : arête fine et pointe, projetés depuis la surface du visage
    bvh = L.surface_bvh(head)
    tip_z, root_z = 6.28, 6.46
    tip_y = head_front_y(bvh, 0, tip_z) - 0.035
    root_y = head_front_y(bvh, 0, root_z) - 0.005
    nose = [
        Vector((0, root_y, root_z)),
        Vector((0, tip_y, tip_z)),
        Vector((0.035, head_front_y(bvh, 0.035, tip_z - 0.02) + 0.01, tip_z - 0.02)),
        Vector((-0.035, head_front_y(bvh, -0.035, tip_z - 0.02) + 0.01, tip_z - 0.02)),
        Vector((0, head_front_y(bvh, 0, tip_z - 0.06) + 0.005, tip_z - 0.06)),
    ]
    nose_obj = L.object_from_data("Nose", nose, [[0, 1, 2], [0, 3, 1], [1, 3, 4], [1, 4, 2]], "Face", smooth=True)
    # Oreilles (en grande partie sous les cheveux)
    ears = []
    for sign in (1, -1):
        v, f = L.ellipsoid((0.285 * sign, 0.05, 6.36), (0.035, 0.08, 0.12), rings=5, segments=8)
        ears.append(L.object_from_data("Ear", v, f, "Skin"))
    neck_v, neck_f = L.tube([(0, 0.04, 5.55), (0, 0.04, 6.1)], [0.15, 0.13], segments=12)
    neck = L.object_from_data("Neck", neck_v, neck_f, "Skin")
    return head, [nose_obj, neck] + ears


# --------------------------------------------------------------------------- #
# Rendus rapides (Workbench) pour juger les volumes
# --------------------------------------------------------------------------- #


def quick_renders(out_dir, tag):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "MATERIAL"
    scene.display.shading.show_cavity = True
    scene.display.shading.show_shadows = True
    scene.render.resolution_x, scene.render.resolution_y = 640, 800
    world = bpy.data.worlds.new("W")
    world.color = (0.03, 0.035, 0.07)
    scene.world = world
    cam = L.link(bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam")))
    cam.data.lens = 70
    scene.camera = cam
    os.makedirs(os.path.join(out_dir, "stages"), exist_ok=True)
    views = {"front": ((0, -17, 3.7), (0, 0, 3.6), 70), "side": ((17, 0, 3.7), (0, 0, 3.6), 70), "three_quarter": ((-10.5, -13.5, 4.6), (0, 0, 3.6), 70), "back": ((0, 17, 3.7), (0, 0, 3.6), 70),
             "face": ((-1.2, -4.0, 6.5), (0, 0, 6.35), 85), "head_back": ((1.8, 3.6, 7.0), (0, 0.1, 6.4), 70)}
    for view, (loc, target, lens) in views.items():
        cam.data.lens = lens
        cam.location = Vector(loc)
        cam.rotation_euler = (Vector(target) - cam.location).to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = os.path.join(out_dir, "stages", f"{tag}_{view}.png")
        bpy.ops.render.render(write_still=True)


VIEWPORT = {
    "Under": (0.05, 0.05, 0.08, 1),
    "Skin": (0.95, 0.75, 0.62, 1),
    "ArmorRed": (0.45, 0.05, 0.03, 1),
    "ArmorDark": (0.18, 0.03, 0.03, 1),
    "Gold": (0.9, 0.62, 0.2, 1),
    "Leather": (0.12, 0.07, 0.05, 1),
    "Ember": (1.0, 0.45, 0.1, 1),
    "Cloth": (0.35, 0.03, 0.05, 1),
    "Cape": (0.4, 0.03, 0.05, 1),
    "CapeInner": (0.08, 0.02, 0.03, 1),
    "Blade": (0.75, 0.78, 0.85, 1),
    "Hair": (0.8, 0.12, 0.05, 1),
    "Eye": (0.2, 0.05, 0.03, 1),
    "Brow": (0.3, 0.05, 0.03, 1),
    "Mouth": (0.6, 0.3, 0.25, 1),
    "Face": (0.95, 0.75, 0.62, 1),
}


def set_viewport_colors():
    colors = VIEWPORT
    for name, color in colors.items():
        mat = bpy.data.materials.get(name)
        if mat:
            mat.diffuse_color = color


def main():
    out_dir, stage = parse_args()
    os.makedirs(out_dir, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.render.fps = FPS
    rig = build_armature()
    body = build_body()
    remove_hidden_body(body)
    head, head_parts = build_head()
    pieces = []
    for builder in (lambda: P.build_torso_armor(bp), P.build_chest_core, P.build_tassets, lambda: P.build_pauldrons(bp), lambda: P.build_arms(bp), lambda: P.build_legs(bp), lambda: P.build_sword(bp), P.build_cape):
        pieces += builder()
    hair = H.build_hair()
    pieces += [(o, L.rigid("Head")) for o in hair]
    set_viewport_colors()
    print("[AF] pièces", len(pieces), "triangles", sum(L.triangles(o) for o, _ in pieces))
    groups = {}
    for o, _ in pieces:
        key = "".join(ch for ch in o.name.split(".")[0] if not ch.isdigit()).replace("Left", "").replace("Right", "")
        groups[key] = groups.get(key, 0) + L.triangles(o)
    print("[AF] par pièce", sorted(groups.items(), key=lambda kv: -kv[1]))
    print("[AF] corps", L.triangles(body), "tête", L.triangles(head))
    if stage in ("A", "B"):
        quick_renders(out_dir, stage)
        return

    mesh = assemble(rig, body, head, head_parts, pieces)
    textures = {k: os.path.join(out_dir, "textures", k + ".png") for k in ("eye", "brow", "mouth", "nose", "cape", "blade", "blade_emit", "filigree")}
    M.build_source_materials(textures)
    M.atlas_uv(mesh)
    maps = M.bake(mesh, out_dir)
    print("[AF] cuisson", maps["device"])
    mat = M.final_material(mesh, maps)
    # Supprimer par nom : une référence de couche devient invalide après chaque suppression.
    for name in [l.name for l in mesh.data.uv_layers if l.name != "AtlasUV"]:
        mesh.data.uv_layers.remove(mesh.data.uv_layers[name])
    assert [l.name for l in mesh.data.uv_layers] == ["AtlasUV"]
    actions = build_animations(rig)
    ground_fix = fix_ground(mesh, rig, actions)
    report = validate(mesh, rig, actions)
    report["groundFix"] = ground_fix
    report["files"] = export(rig, mesh, mat, out_dir)
    for image in maps.values():
        if hasattr(image, "pack"):
            image.pack()
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(out_dir, NAME + ".blend"))
    report["files"]["blend"] = NAME + ".blend"
    with open(os.path.join(out_dir, "kael_af_report.json"), "w", encoding="utf-8") as handle:
        json.dump(report, handle, indent=2, ensure_ascii=False)
    print("[AF] contrôles", json.dumps(report["checks"]), "valide =", report["valid"])
    print("[AF] triangles", report["triangles"], "LOD", report["files"]["lodTriangles"], "hauteur", report["height"])


# --------------------------------------------------------------------------- #
# Assemblage, poids, animations, validation, exports
# --------------------------------------------------------------------------- #


def skin_body(rig, body):
    """Poids automatiques (chaleur des os) pour le corps continu ; Root et
    HumanoidRootPart ne déforment rien (comme en production)."""
    for name in ("Root", "HumanoidRootPart"):
        rig.data.bones[name].use_deform = False
    bpy.ops.object.select_all(action="DESELECT")
    body.select_set(True)
    rig.select_set(True)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.parent_set(type="ARMATURE_AUTO")
    unweighted = sum(1 for v in body.data.vertices if not any(g.weight > 0 for g in v.groups))
    print("[AF] corps : sommets sans poids après chaleur", unweighted)
    # (Un lissage des poids a été essayé en passe 2 : il étale les poids du bras sur le
    # torse et aggrave l'étirement bras levé ; les poids de chaleur bruts sont meilleurs.)
    if unweighted:
        # Repli : poids par chaînes d'os pour les sommets oubliés
        for v in body.data.vertices:
            if not any(g.weight > 0 for g in v.groups):
                p = v.co
                bone = nearest_bone(p)
                group = body.vertex_groups.get(bone) or body.vertex_groups.new(name=bone)
                group.add([v.index], 1.0, "REPLACE")


def nearest_bone(p):
    best, best_d = "UpperTorso", math.inf
    for name, (head, tail, _) in BONES.items():
        if name in ("Root", "HumanoidRootPart"):
            continue
        h, t = Vector(head), Vector(tail)
        d = (p - h.lerp(t, L.segment_param(p, h, t))).length
        if d < best_d:
            best, best_d = name, d
    return best


PARTS = {"body": 0, "armor": 1, "cape": 2, "sword": 3, "hair": 4, "head": 5}
SWORD_PREFIXES = ("Blade", "Guard", "Grip", "Pommel")


def part_of(name, body, head, head_parts):
    if name == body.name:
        return PARTS["body"]
    if name == head.name or name in {p.name for p in head_parts}:
        return PARTS["head"]
    if name.startswith(("Lock", "HairCap")):
        return PARTS["hair"]
    if name.startswith("Cape") and not name.startswith(("CapeClasp", "CapeCord")):
        return PARTS["cape"]
    if name.startswith(SWORD_PREFIXES):
        return PARTS["sword"]
    return PARTS["armor"]


def tag_part(obj, value):
    attr = obj.data.attributes.get("kael_part") or obj.data.attributes.new("kael_part", "INT", "FACE")
    for item in attr.data:
        item.value = value


def assemble(rig, body, head, head_parts, pieces):
    skin_body(rig, body)
    L.set_weights(head, L.rigid("Head"))
    for part in head_parts:
        if part.name.startswith("Neck"):
            L.set_weights(part, L.chain([Vector((0, 0, 5.4)), Vector((0, 0, 5.85)), Vector((0, 0, 6.3))], ["UpperTorso", "Head"], 0.12))
        else:
            L.set_weights(part, L.rigid("Head"))
    for obj, weight in pieces:
        L.set_weights(obj, weight)
    # Étiquette de pièce par face (contrôles d'intersection après assemblage)
    for obj in [body, head] + head_parts + [o for o, _ in pieces]:
        tag_part(obj, part_of(obj.name, body, head, head_parts))
    mesh = L.join([body, head] + head_parts + [o for o, _ in pieces], NAME + "_Mesh")
    bpy.context.view_layer.objects.active = mesh
    bpy.ops.object.vertex_group_limit_total(group_select_mode="ALL", limit=4)
    bpy.ops.object.vertex_group_normalize_all(group_select_mode="ALL", lock_active=False)
    mesh.parent = rig
    if not any(m.type == "ARMATURE" for m in mesh.modifiers):
        mod = mesh.modifiers.new("Armature", "ARMATURE")
        mod.object = rig
    return mesh


# Les intentions d'animation de la production (kael_build.ANIMATIONS) sont exprimées
# en rotations dans les axes du personnage : elles s'appliquent telles quelles au
# nouveau squelette. Seuls les déplacements du bassin (« loc », en studs) sont mis à
# l'échelle des nouvelles jambes (hanche à 3,55 au lieu de 2,85).
LEG_RATIO = 3.55 / 2.85


def remove_hidden_body(body):
    """Supprime les faces du corps entièrement cachées sous une armure fermée :
    torse (plastron + dossière), avant-bras (canons), avant des tibias (grèves)."""
    import bmesh

    def hidden(p):
        if 4.62 < p.z < 5.36 and abs(p.x) < 0.5:
            return True
        for side in ("Left", "Right"):
            for a, b, radius, back_open in (
                (bp(side + "LowerArm"), bp(side + "LowerArm", True), 0.13, False),
                (bp(side + "LowerLeg"), bp(side + "LowerLeg", True), 0.17, True),
            ):
                t = L.segment_param(p, a, b)
                c = a.lerp(b, t)
                if 0.2 < t < 0.85 and (p - c).length < radius and not (back_open and (p - c).y > 0.05):
                    return True
        return False

    bm = bmesh.new()
    bm.from_mesh(body.data)
    faces = [f for f in bm.faces if all(hidden(v.co) for v in f.verts)]
    bmesh.ops.delete(bm, geom=faces, context="FACES")
    bm.to_mesh(body.data)
    bm.free()
    print("[AF] faces du corps cachées supprimées", len(faces))


def fix_ground(mesh, rig, actions, passes=2):
    """Relève le bassin aux images-clés où le maillage passe sous le sol (les
    déplacements de la production ne correspondent plus exactement aux nouvelles
    jambes). Les sauts (point bas au-dessus du sol) ne sont pas touchés."""
    scene = bpy.context.scene
    hrp = rig.pose.bones["HumanoidRootPart"]
    to_local = hrp.bone.matrix_local.to_3x3().inverted()
    path = 'pose.bones["HumanoidRootPart"].location'
    changes = {}
    # Seul le corps compte pour le sol : l'épée et les mains peuvent le frôler
    hands = {g.index for g in mesh.vertex_groups if g.name in ("RightHand", "LeftHand")}
    body_vertices = {v.index for v in mesh.data.vertices if sum(g.weight for g in v.groups if g.group in hands) < 0.5}
    for name, action in actions.items():
        rig.animation_data.action = action
        curves = [action.fcurves.find(path, index=i) for i in range(3)]
        for _ in range(passes):
            frames = sorted({int(k.co.x) for c in curves if c for k in c.keyframe_points})
            for frame in frames:
                scene.frame_set(frame)
                depsgraph = bpy.context.evaluated_depsgraph_get()
                evaluated = mesh.evaluated_get(depsgraph)
                data = evaluated.to_mesh()
                low = min((mesh.matrix_world @ v.co).z for i, v in enumerate(data.vertices) if i in body_vertices)
                evaluated.to_mesh_clear()
                if low < -0.005:
                    delta = to_local @ Vector((0, 0, -low))
                    for i, curve in enumerate(curves):
                        for k in curve.keyframe_points:
                            if int(k.co.x) == frame:
                                k.co.y += delta[i]
                                k.handle_left.y += delta[i]
                                k.handle_right.y += delta[i]
                    for curve in curves:
                        curve.update()
                    changes.setdefault(name, {})[frame] = round(changes.get(name, {}).get(frame, 0) - low, 3)
    rig.animation_data.action = None
    scene.frame_set(1)
    return changes


def build_animations(rig):
    scaled = {}
    for name, spec in base.ANIMATIONS.items():
        keys = {}
        for frame, pose in spec["keys"].items():
            pose = dict(pose)
            if "loc" in pose:
                pose["loc"] = tuple(c * LEG_RATIO for c in pose["loc"])
            keys[frame] = pose
        scaled[name] = dict(spec, keys=keys)
    # Défense (passe 2) : la garde est tenue puis relâchée vers la pose neutre, pour un
    # retour fluide vers l'attente au lieu d'un saut à la fin de la piste.
    defend = scaled["Defend"]
    defend["keys"][30] = base.pose()
    defend["length"] = 30
    original = base.ANIMATIONS
    base.ANIMATIONS = scaled
    try:
        actions = base.build_actions(rig)
    finally:
        base.ANIMATIONS = original
    return actions


def ground_check(mesh, rig, actions):
    """Plus bas point du maillage déformé à chaque image-clé (pieds au sol, aucune
    pénétration du sol au-delà de 8 cm)."""
    scene = bpy.context.scene
    result = {}
    hands = {g.index for g in mesh.vertex_groups if g.name in ("RightHand", "LeftHand")}
    held = {v.index for v in mesh.data.vertices if sum(g.weight for g in v.groups if g.group in hands) >= 0.5}
    for name, action in actions.items():
        rig.animation_data.action = action
        keys = sorted({int(k.co.x) for c in action.fcurves for k in c.keyframe_points})
        lows, sword_lows = [], []
        for frame in keys:
            scene.frame_set(frame)
            depsgraph = bpy.context.evaluated_depsgraph_get()
            evaluated = mesh.evaluated_get(depsgraph)
            data = evaluated.to_mesh()
            zs = [(i, (mesh.matrix_world @ v.co).z) for i, v in enumerate(data.vertices)]
            lows.append(round(min(z for i, z in zs if i not in held), 3))
            sword_lows.append(round(min(z for i, z in zs if i in held), 3))
            evaluated.to_mesh_clear()
        result[name] = {"frames": keys, "lowestZ": lows, "swordAndHandsLowestZ": sword_lows}
    rig.animation_data.action = None
    scene.frame_set(1)
    return result


def validate(mesh, rig, actions):
    data = mesh.data
    triangles = L.triangles(mesh)
    influences, unweighted = 0, 0
    for v in data.vertices:
        count = sum(1 for g in v.groups if g.weight > 0)
        influences = max(influences, count)
        unweighted += count == 0
    zs = [v.co.z for v in data.vertices]
    xs = [v.co.x for v in data.vertices]
    ground = ground_check(mesh, rig, actions)
    worst = min(min(g["lowestZ"]) for g in ground.values())
    production = {name: parent for name, (_, _, parent) in base.BONES.items()}
    hierarchy = {b.name: (b.parent.name if b.parent else None) for b in rig.data.bones}
    report = {
        "blender": bpy.app.version_string,
        "model": NAME,
        "height": round(max(zs) - min(zs), 3),
        "crown": CROWN,
        "headsTall": round(CROWN / HEAD_HEIGHT, 2),
        "width": round(max(xs) - min(xs), 3),
        "minZ": round(min(zs), 3),
        "vertices": len(data.vertices),
        "triangles": triangles,
        "bones": list(hierarchy),
        "boneCount": len(hierarchy),
        "sameBoneNamesAndHierarchy": hierarchy == production,
        "restPositionsChanged": True,
        "maxInfluencesPerVertex": influences,
        "unweightedVertices": unweighted,
        "materials": len(data.materials),
        "uvLayers": [l.name for l in data.uv_layers],
        "textureSize": 1024,
        "animations": {name: {"frames": base.ANIMATIONS[name]["length"], "fps": FPS} for name in actions},
        "groundCheck": ground,
        "lowestPointAllKeys": worst,
    }
    checks = {
        "trianglesMain": triangles <= 15000,
        "bones": len(hierarchy) == 17,
        "sameBoneNamesAndHierarchy": hierarchy == production,
        "influences": influences <= 4,
        "allVerticesWeighted": unweighted == 0,
        "oneMaterial": len(data.materials) == 1,
        "feetOnGround": abs(min(zs)) < 0.05,
        "heightNear7": abs((max(zs) - min(zs)) - 7.0) < 0.5,
        "noGroundPenetration": worst > -0.08,
    }
    report["checks"] = checks
    report["valid"] = all(checks.values())
    return report


def export(rig, mesh, mat, out_dir):
    files = {}
    rig.animation_data.action = None
    for pb in rig.pose.bones:
        pb.location = (0, 0, 0)
        pb.rotation_euler = (0, 0, 0)
    M.roblox_only(mat, True)
    bpy.ops.object.select_all(action="DESELECT")
    rig.select_set(True)
    mesh.select_set(True)
    bpy.context.view_layer.objects.active = rig
    fbx_options = dict(
        use_selection=True,
        object_types={"ARMATURE", "MESH"},
        add_leaf_bones=False,
        bake_anim=False,
        axis_forward="-Z",
        axis_up="Y",
        apply_scale_options="FBX_SCALE_UNITS",
        path_mode="COPY",
        embed_textures=True,
        mesh_smooth_type="OFF",
    )
    path = os.path.join(out_dir, NAME + ".fbx")
    bpy.ops.export_scene.fbx(filepath=path, **fbx_options)
    files["modelFbx"] = os.path.basename(path)
    path = os.path.join(out_dir, NAME + ".glb")
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_animations=False)
    files["modelGlb"] = os.path.basename(path)
    # Variante optimisée (LOD) : réduction automatique, mêmes UV, mêmes poids
    lod = mesh.copy()
    lod.data = mesh.data.copy()
    lod.name = NAME + "_LOD_Mesh"
    bpy.context.scene.collection.objects.link(lod)
    target = 5200
    dec = lod.modifiers.new("Decimate", "DECIMATE")
    dec.ratio = min(1.0, target / max(L.triangles(mesh), 1))
    bpy.context.view_layer.objects.active = lod
    bpy.ops.object.modifier_move_to_index(modifier="Decimate", index=0)
    bpy.ops.object.modifier_apply(modifier="Decimate")
    files["lodTriangles"] = L.triangles(lod)
    bpy.ops.object.select_all(action="DESELECT")
    rig.select_set(True)
    lod.select_set(True)
    bpy.context.view_layer.objects.active = rig
    path = os.path.join(out_dir, NAME + "_LOD.fbx")
    bpy.ops.export_scene.fbx(filepath=path, **fbx_options)
    files["lodFbx"] = os.path.basename(path)
    lod.hide_render = True
    lod.hide_set(True)
    M.roblox_only(mat, False)
    return files


if __name__ == "__main__":
    main()
