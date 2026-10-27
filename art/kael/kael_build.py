"""Production du modèle 3D de Kael (F001) pour COLLECTVERSE.

Script Blender reproductible (testé avec Blender 4.2 LTS), exécuté sans interface :

    blender -b --factory-startup --python art/kael/kael_build.py -- --out art/kael/build

Il construit entièrement le personnage à partir de primitives paramétrées :
  1. maillage stylisé unique (corps, armure, tête, cheveux, épée) ;
  2. texture « palette » 64 × 64 (une couleur par zone, UV regroupés) ;
  3. armature aux noms d'os R15 (vrai rig : maillage déformé par les os) ;
  4. poids de skinning calculés (fondu aux articulations, au plus 2 os par sommet) ;
  5. animations Idle, Attack, Skill, Ultimate, Defend, Hit, Defeat (images-clés) ;
  6. exports : modèle FBX + GLB, une animation par FBX ;
  7. rendus de contrôle (Workbench) et rapport de validation JSON.

Unité : 1 unité Blender = 1 stud Roblox. Le personnage regarde vers -Y dans
Blender (exporté vers -Z, l'avant attendu par ModelFactory).
"""

import json
import math
import os
import sys

import bpy
from mathutils import Matrix, Vector

# --------------------------------------------------------------------------- #
# Spécification (voir art/kael/KAEL_SPEC.md)
# --------------------------------------------------------------------------- #

HEIGHT = 6.5  # studs, comme le modèle provisoire
FPS = 30

# Palette de Kael : corps et armure, finitions, peau, lueur des braises, etc.
PALETTE = {
    "armor": "#7A2418",
    "trim": "#2B1C1A",
    "skin": "#E8B48A",
    "ember": "#FF7A3D",
    "hair": "#B8321C",
    "hairTip": "#FF9A4D",
    "steel": "#8C93A8",
    "gold": "#F0BF61",
    "eye": "#1A1020",
    "eyeLight": "#FFFFFF",
    "cloth": "#3A1C17",
    "leather": "#4A2A1E",
    "blade": "#FFC48A",
    "mouth": "#9A4A3A",
    "bladeSteel": "#DDE3F0",
}
SWATCH_ORDER = list(PALETTE.keys())
GRID = 4  # 4 × 4 cases dans la texture
TEXTURE_SIZE = 64

# Os (noms R15). Positions en studs : (tête de l'os, queue de l'os, parent).
# Gauche du personnage = +X (il regarde vers -Y).
BONES = {
    "Root": ((0, 0, 0), (0, 0, 0.6), None),
    "HumanoidRootPart": ((0, 0, 2.85), (0, 0, 3.15), "Root"),
    "LowerTorso": ((0, 0, 2.85), (0, 0, 3.55), "HumanoidRootPart"),
    "UpperTorso": ((0, 0, 3.55), (0, 0, 4.6), "LowerTorso"),
    "Head": ((0, 0, 4.7), (0, 0, 6.2), "UpperTorso"),
    "LeftUpperArm": ((0.82, 0, 4.4), (1.12, 0, 3.55), "UpperTorso"),
    "LeftLowerArm": ((1.12, 0, 3.55), (1.3, -0.05, 2.75), "LeftUpperArm"),
    "LeftHand": ((1.3, -0.05, 2.75), (1.36, -0.08, 2.35), "LeftLowerArm"),
    "RightUpperArm": ((-0.82, 0, 4.4), (-1.12, 0, 3.55), "UpperTorso"),
    "RightLowerArm": ((-1.12, 0, 3.55), (-1.3, -0.05, 2.75), "RightUpperArm"),
    "RightHand": ((-1.3, -0.05, 2.75), (-1.36, -0.08, 2.35), "RightLowerArm"),
    "LeftUpperLeg": ((0.4, 0, 2.85), (0.42, 0.02, 1.62), "LowerTorso"),
    "LeftLowerLeg": ((0.42, 0.02, 1.62), (0.42, 0.05, 0.42), "LeftUpperLeg"),
    "LeftFoot": ((0.42, 0.05, 0.42), (0.42, -0.5, 0.1), "LeftLowerLeg"),
    "RightUpperLeg": ((-0.4, 0, 2.85), (-0.42, 0.02, 1.62), "LowerTorso"),
    "RightLowerLeg": ((-0.42, 0.02, 1.62), (-0.42, 0.05, 0.42), "RightUpperLeg"),
    "RightFoot": ((-0.42, 0.05, 0.42), (-0.42, -0.5, 0.1), "RightLowerLeg"),
}

# Budget mobile (voir KAEL_SPEC.md)
BUDGET = {"maxTriangles": 6000, "maxBones": 20, "maxInfluences": 4, "textureSize": 64}

# --------------------------------------------------------------------------- #
# Outils
# --------------------------------------------------------------------------- #


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    out = "art/kael/build"
    for index, value in enumerate(argv):
        if value == "--out" and index + 1 < len(argv):
            out = argv[index + 1]
    return os.path.abspath(out)


def hex_rgb(value):
    value = value.lstrip("#")
    return tuple(int(value[i : i + 2], 16) / 255 for i in (0, 2, 4))


def swatch_uv(color_name):
    """Centre de la case de la palette correspondant à une couleur."""
    index = SWATCH_ORDER.index(color_name)
    col, row = index % GRID, index // GRID
    return ((col + 0.5) / GRID, 1 - (row + 0.5) / GRID)


class MeshBuilder:
    """Accumule sommets, faces, couleur et poids par sommet, puis crée un objet."""

    def __init__(self):
        self.verts = []
        self.faces = []
        self.face_colors = []
        self.weights = []  # liste de dict {os: poids} par sommet

    def add(self, verts, faces, color, weight_fn):
        base = len(self.verts)
        for v in verts:
            self.verts.append(Vector(v))
            self.weights.append(weight_fn(Vector(v)))
        for f in faces:
            self.faces.append([base + i for i in f])
            self.face_colors.append(color)

    def build(self, name):
        mesh = bpy.data.meshes.new(name)
        mesh.from_pydata([tuple(v) for v in self.verts], [], self.faces)
        mesh.update(calc_edges=True)
        uv = mesh.uv_layers.new(name="UVMap")
        for poly, color in zip(mesh.polygons, self.face_colors):
            u, v = swatch_uv(color)
            for loop_index in poly.loop_indices:
                uv.data[loop_index].uv = (u, v)
        for poly in mesh.polygons:
            poly.use_smooth = True
        obj = bpy.data.objects.new(name, mesh)
        bpy.context.scene.collection.objects.link(obj)
        groups = {bone: obj.vertex_groups.new(name=bone) for bone in BONES if bone != "Root"}
        for index, weights in enumerate(self.weights):
            for bone, weight in weights.items():
                if weight > 0:
                    groups[bone].add([index], weight, "REPLACE")
        return obj


def rigid(bone):
    return lambda _v: {bone: 1.0}


def segment_param(point, a, b):
    """Position de `point` projetée sur le segment a-b (0 en a, 1 en b)."""
    ab = b - a
    return max(0.0, min(1.0, (point - a).dot(ab) / ab.length_squared))


def chain_weights(points, bones, width=0.14):
    """Poids le long d'une chaîne d'os (épaule → coude → poignet par exemple).
    Chaque sommet est projeté sur le segment le plus proche ; près d'une
    articulation, les deux os voisins se partagent le poids (fondu linéaire)."""
    pts = [Vector(p) for p in points]

    def fn(v):
        best, best_dist, best_t = 0, math.inf, 0.0
        for i in range(len(bones)):
            t = segment_param(v, pts[i], pts[i + 1])
            dist = (v - pts[i].lerp(pts[i + 1], t)).length
            if dist < best_dist:
                best, best_dist, best_t = i, dist, t
        seg_len = (pts[best + 1] - pts[best]).length
        fade = width / max(seg_len, 1e-6)
        if best_t > 1 - fade and best + 1 < len(bones):
            share = (best_t - (1 - fade)) / (2 * fade)
            return {bones[best]: 1 - share, bones[best + 1]: share}
        if best_t < fade and best > 0:
            share = (fade - best_t) / (2 * fade)
            return {bones[best]: 1 - share, bones[best - 1]: share}
        return {bones[best]: 1.0}

    return fn


def ring(center, axis, radius_x, radius_y, segments, twist=0.0):
    """Cercle (ellipse) de sommets perpendiculaire à `axis`."""
    axis = Vector(axis).normalized()
    helper = Vector((0, 0, 1)) if abs(axis.z) < 0.9 else Vector((1, 0, 0))
    side = axis.cross(helper).normalized()
    up = side.cross(axis).normalized()
    out = []
    for i in range(segments):
        angle = 2 * math.pi * i / segments + twist
        out.append(Vector(center) + side * math.cos(angle) * radius_x + up * math.sin(angle) * radius_y)
    return out


def tube(path, radii, segments=10, caps=True, squash=1.0):
    """Tube lissé le long d'un chemin, rayon variable ; squash aplatit la section."""
    verts, faces = [], []
    path = [Vector(p) for p in path]
    for i, p in enumerate(path):
        axis = (path[min(i + 1, len(path) - 1)] - path[max(i - 1, 0)]).normalized()
        verts += ring(p, axis, radii[i], radii[i] * squash, segments)
    for i in range(len(path) - 1):
        for j in range(segments):
            a = i * segments + j
            b = i * segments + (j + 1) % segments
            faces.append([a, b, b + segments, a + segments])
    if caps:
        start, end = len(verts), len(verts) + 1
        verts += [path[0], path[-1]]
        last = (len(path) - 1) * segments
        for j in range(segments):
            faces.append([start, (j + 1) % segments, j])
            faces.append([end, last + j, last + (j + 1) % segments])
    return verts, faces


def ellipsoid(center, radii, rings=8, segments=12):
    verts, faces = [], []
    cx, cy, cz = center
    rx, ry, rz = radii
    verts.append(Vector((cx, cy, cz + rz)))
    for r in range(1, rings):
        phi = math.pi * r / rings
        for s in range(segments):
            theta = 2 * math.pi * s / segments
            verts.append(
                Vector((cx + rx * math.sin(phi) * math.cos(theta), cy + ry * math.sin(phi) * math.sin(theta), cz + rz * math.cos(phi)))
            )
    verts.append(Vector((cx, cy, cz - rz)))
    bottom = len(verts) - 1
    for s in range(segments):
        faces.append([0, 1 + (s + 1) % segments, 1 + s])
    for r in range(rings - 2):
        for s in range(segments):
            a = 1 + r * segments + s
            b = 1 + r * segments + (s + 1) % segments
            faces.append([a, b, b + segments, a + segments])
    last = 1 + (rings - 2) * segments
    for s in range(segments):
        faces.append([bottom, last + s, last + (s + 1) % segments])
    return verts, faces


def box(center, size, taper=1.0):
    """Pavé (le haut peut être rétréci par `taper`)."""
    cx, cy, cz = center
    sx, sy, sz = (s / 2 for s in size)
    verts = []
    for z, k in ((-sz, 1.0), (sz, taper)):
        for x, y in ((-sx, -sy), (sx, -sy), (sx, sy), (-sx, sy)):
            verts.append(Vector((cx + x * k, cy + y * k, cz + z)))
    faces = [[0, 3, 2, 1], [4, 5, 6, 7], [0, 1, 5, 4], [1, 2, 6, 5], [2, 3, 7, 6], [3, 0, 4, 7]]
    return verts, faces


def cone(base_center, tip, radius, segments=6):
    base_center, tip = Vector(base_center), Vector(tip)
    axis = (tip - base_center).normalized()
    verts = ring(base_center, axis, radius, radius, segments) + [tip, base_center]
    t, b = segments, segments + 1
    faces = []
    for j in range(segments):
        faces.append([j, (j + 1) % segments, t])
        faces.append([(j + 1) % segments, j, b])
    return verts, faces


def bone_point(name, end):
    head, tail, _ = BONES[name]
    return Vector(tail if end else head)


# --------------------------------------------------------------------------- #
# Construction du personnage
# --------------------------------------------------------------------------- #


def build_character():
    mb = MeshBuilder()

    # Jambes (cuisse → genou → cheville), bottes
    for side, sign in (("Left", 1), ("Right", -1)):
        hip = bone_point(side + "UpperLeg", False)
        knee = bone_point(side + "UpperLeg", True)
        ankle = bone_point(side + "LowerLeg", True)
        bones = [side + "UpperLeg", side + "LowerLeg"]
        weights = chain_weights([hip, knee, ankle], bones)
        path = [hip + Vector((0, 0, 0.1)), hip.lerp(knee, 0.5), knee, knee.lerp(ankle, 0.5), ankle + Vector((0, 0, 0.25))]
        verts, faces = tube(path, [0.36, 0.3, 0.25, 0.24, 0.23], segments=10)
        mb.add(verts, faces, "cloth", weights)
        # Botte : tige et pied
        verts, faces = tube([knee.lerp(ankle, 0.35), ankle + Vector((0, 0, 0.05))], [0.29, 0.3], segments=10)
        mb.add(verts, faces, "leather", rigid(side + "LowerLeg"))
        verts, faces = box((ankle.x, ankle.y - 0.18, 0.17), (0.44, 0.78, 0.34), taper=0.85)
        mb.add(verts, faces, "trim", rigid(side + "Foot"))
        # Genouillère (plaque bombée devant le genou)
        verts, faces = ellipsoid((knee.x, knee.y - 0.24, knee.z), (0.2, 0.07, 0.23), rings=6, segments=10)
        mb.add(verts, faces, "armor", rigid(side + "LowerLeg"))

    # Bassin et torse (fondu LowerTorso / UpperTorso)
    pelvis = Vector((0, 0, 2.7))
    waist = Vector((0, 0, 3.55))
    chest = Vector((0, 0, 4.25))
    neck = Vector((0, 0, 4.7))
    torso_weights = chain_weights([pelvis, waist, neck], ["LowerTorso", "UpperTorso"], width=0.2)
    verts, faces = tube([pelvis, Vector((0, 0, 3.1)), waist, chest, neck], [0.62, 0.6, 0.55, 0.72, 0.36], segments=14, squash=0.72)
    mb.add(verts, faces, "cloth", torso_weights)
    # Plastron (cuirasse avant) et dossière
    verts, faces = ellipsoid((0, -0.25, 4.1), (0.7, 0.42, 0.56), rings=7, segments=14)
    mb.add(verts, faces, "armor", rigid("UpperTorso"))
    # Ceinture et boucle de braise
    verts, faces = tube([Vector((0, 0, 3.12)), Vector((0, 0, 3.32))], [0.64, 0.64], segments=14, squash=0.76)
    mb.add(verts, faces, "trim", rigid("LowerTorso"))
    verts, faces = ellipsoid((0, -0.5, 3.22), (0.14, 0.06, 0.14), rings=5, segments=8)
    mb.add(verts, faces, "ember", rigid("LowerTorso"))
    # Tassettes (pans d'armure sur les hanches)
    for sign in (1, -1):
        verts, faces = box((0.68 * sign, -0.05, 2.8), (0.12, 0.72, 0.62), taper=1.1)
        mb.add(verts, faces, "armor", rigid("LowerTorso"))
    # Tabard avant (pan de tissu)
    verts, faces = box((0, -0.43, 2.55), (0.42, 0.06, 0.9), taper=1.25)
    mb.add(verts, faces, "cloth", rigid("LowerTorso"))

    # Bras (épaule → coude → poignet), épaulières, gantelets, mains
    for side, sign in (("Left", 1), ("Right", -1)):
        shoulder = bone_point(side + "UpperArm", False)
        elbow = bone_point(side + "UpperArm", True)
        wrist = bone_point(side + "LowerArm", True)
        weights = chain_weights([shoulder, elbow, wrist], [side + "UpperArm", side + "LowerArm"])
        verts, faces = tube([shoulder, shoulder.lerp(elbow, 0.5), elbow, elbow.lerp(wrist, 0.5), wrist], [0.25, 0.22, 0.2, 0.19, 0.17], segments=10)
        mb.add(verts, faces, "skin", weights)
        verts, faces = ellipsoid((shoulder.x + 0.08 * sign, 0, shoulder.z + 0.05), (0.42, 0.38, 0.3), rings=6, segments=12)
        mb.add(verts, faces, "armor", rigid(side + "UpperArm"))
        verts, faces = ellipsoid((shoulder.x + 0.12 * sign, 0, shoulder.z + 0.2), (0.12, 0.12, 0.08), rings=4, segments=8)
        mb.add(verts, faces, "gold", rigid(side + "UpperArm"))
        verts, faces = tube([elbow.lerp(wrist, 0.3), wrist + Vector((0, 0, 0.05))], [0.24, 0.23], segments=10)
        mb.add(verts, faces, "steel", rigid(side + "LowerArm"))
        hand = bone_point(side + "Hand", False).lerp(bone_point(side + "Hand", True), 0.5)
        verts, faces = ellipsoid(tuple(hand), (0.17, 0.15, 0.22), rings=5, segments=8)
        mb.add(verts, faces, "leather", rigid(side + "Hand"))

    # Tête (proportions anime : grande tête), visage, yeux, cheveux en mèches
    head_center = Vector((0, -0.02, 5.45))
    verts, faces = tube([Vector((0, 0, 4.62)), Vector((0, 0, 4.92))], [0.22, 0.22], segments=10)
    mb.add(verts, faces, "skin", chain_weights([Vector((0, 0, 4.5)), Vector((0, 0, 4.75)), Vector((0, 0, 5.0))], ["UpperTorso", "Head"]))
    verts, faces = ellipsoid(tuple(head_center), (0.68, 0.64, 0.74), rings=10, segments=16)
    mb.add(verts, faces, "skin", rigid("Head"))
    for sign in (1, -1):
        verts, faces = ellipsoid((0.25 * sign, -0.6, 5.42), (0.12, 0.04, 0.17), rings=5, segments=8)
        mb.add(verts, faces, "eye", rigid("Head"))
        verts, faces = ellipsoid((0.21 * sign, -0.635, 5.49), (0.04, 0.015, 0.05), rings=4, segments=6)
        mb.add(verts, faces, "eyeLight", rigid("Head"))
        verts, faces = box((0.25 * sign, -0.6, 5.66), (0.24, 0.04, 0.05))
        mb.add(verts, faces, "hair", rigid("Head"))
    verts, faces = box((0, -0.62, 5.12), (0.16, 0.03, 0.035))
    mb.add(verts, faces, "mouth", rigid("Head"))
    # Calotte de cheveux puis mèches en pointes vers l'arrière et le haut
    verts, faces = ellipsoid((0, 0.08, 5.62), (0.76, 0.73, 0.64), rings=8, segments=16)
    mb.add(verts, faces, "hair", rigid("Head"))
    spikes = [
        ((0, -0.35, 6.1), (0, -0.55, 6.6)),
        ((0.35, -0.2, 6.05), (0.62, -0.35, 6.5)),
        ((-0.35, -0.2, 6.05), (-0.62, -0.35, 6.5)),
        ((0.5, 0.25, 5.9), (0.95, 0.45, 6.25)),
        ((-0.5, 0.25, 5.9), (-0.95, 0.45, 6.25)),
        ((0, 0.45, 5.95), (0, 0.95, 6.3)),
        ((0.25, 0.5, 5.6), (0.45, 1.0, 5.55)),
        ((-0.25, 0.5, 5.6), (-0.45, 1.0, 5.55)),
    ]
    for base, tip in spikes:
        verts, faces = cone(base, tip, 0.24, segments=6)
        mb.add(verts, faces, "hair", rigid("Head"))
        verts, faces = cone(Vector(base).lerp(Vector(tip), 0.6), tip, 0.1, segments=5)
        mb.add(verts, faces, "hairTip", rigid("Head"))
    # Bandeau frontal doré
    verts, faces = tube([Vector((0, -0.02, 5.78)), Vector((0, -0.02, 5.86))], [0.7, 0.7], segments=16, squash=0.94)
    mb.add(verts, faces, "gold", rigid("Head"))

    # Épée de braises, tenue dans la main droite (lame vers l'avant et le haut)
    grip = bone_point("RightHand", False).lerp(bone_point("RightHand", True), 0.55)
    blade_dir = Vector((0, -0.55, 1)).normalized()
    pommel = grip - blade_dir * 0.35
    guard = grip + blade_dir * 0.3
    tip = guard + blade_dir * 2.6
    sword = rigid("RightHand")
    verts, faces = tube([pommel, guard], [0.07, 0.07], segments=8)
    mb.add(verts, faces, "trim", sword)
    verts, faces = ellipsoid(tuple(pommel), (0.1, 0.1, 0.1), rings=4, segments=8)
    mb.add(verts, faces, "gold", sword)
    verts, faces = tube([guard - Vector((0.36, 0, 0)), guard + Vector((0.36, 0, 0))], [0.08, 0.08], segments=8)
    mb.add(verts, faces, "gold", sword)
    verts, faces = tube([guard, guard.lerp(tip, 0.5), tip], [0.14, 0.12, 0.01], segments=4, squash=0.25)
    mb.add(verts, faces, "bladeSteel", sword)
    verts, faces = tube([guard + blade_dir * 0.1, guard.lerp(tip, 0.85)], [0.035, 0.02], segments=4)
    mb.add(verts, faces, "ember", sword)

    return mb.build("F001_Kael_Mesh")


def build_armature():
    data = bpy.data.armatures.new("F001_Kael_Rig")
    rig = bpy.data.objects.new("F001_Kael", data)
    bpy.context.scene.collection.objects.link(rig)
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


def build_texture(out_dir):
    image = bpy.data.images.new("F001_Kael_Palette", TEXTURE_SIZE, TEXTURE_SIZE, alpha=False)
    cell = TEXTURE_SIZE // GRID
    pixels = [0.0] * (TEXTURE_SIZE * TEXTURE_SIZE * 4)
    for index, name in enumerate(SWATCH_ORDER):
        r, g, b = hex_rgb(PALETTE[name])
        col, row = index % GRID, index // GRID
        for y in range(cell):
            for x in range(cell):
                px = col * cell + x
                py = TEXTURE_SIZE - 1 - (row * cell + y)
                offset = (py * TEXTURE_SIZE + px) * 4
                pixels[offset : offset + 4] = [r, g, b, 1.0]
    image.pixels = pixels
    path = os.path.join(out_dir, "F001_Kael_Palette.png")
    image.filepath_raw = path
    image.file_format = "PNG"
    image.save()
    return image, path


def build_material(image):
    material = bpy.data.materials.new("F001_Kael_Material")
    material.use_nodes = True
    nodes = material.node_tree.nodes
    bsdf = nodes.get("Principled BSDF")
    tex = nodes.new("ShaderNodeTexImage")
    tex.image = image
    tex.interpolation = "Closest"  # aplats nets : aucune bavure entre cases
    material.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.65
    return material


# --------------------------------------------------------------------------- #
# Animations
# --------------------------------------------------------------------------- #

# Les poses sont décrites dans les axes du personnage, communs à tous les os :
#   tangage (X) : positif = pencher en avant (buste) ; négatif = lever un membre
#                 pendant vers l'avant (-90 : horizontal devant, -170 : au-dessus) ;
#   roulis  (Y) : écarter sur le côté (bras gauche : négatif, bras droit : positif) ;
#   lacet   (Z) : pivoter autour de la verticale (positif = sens antihoraire vu de dessus).
# Chaque rotation s'applique depuis la pose de repos de l'os, puis est convertie
# dans le repère local de l'os (dont l'orientation dépend de sa direction).
# "loc" : déplacement de HumanoidRootPart en studs (X gauche, Y arrière, Z haut).
NEUTRAL = {
    "UpperTorso": (0, 0, 0),
    "LowerTorso": (0, 0, 0),
    "HumanoidRootPart": (0, 0, 0),
    "Head": (0, 0, 0),
    "LeftUpperArm": (0, 0, 0),
    "RightUpperArm": (0, 0, 0),
    "LeftLowerArm": (-15, 0, 0),
    "RightLowerArm": (-25, 0, 0),
    "LeftUpperLeg": (0, 0, 0),
    "RightUpperLeg": (0, 0, 0),
    "LeftLowerLeg": (0, 0, 0),
    "RightLowerLeg": (0, 0, 0),
    "loc": (0, 0, 0),
}


def pose(**changes):
    """Pose complète : neutre + changements (évite les os oubliés entre deux clés)."""
    result = dict(NEUTRAL)
    result.update(changes)
    return result


ANIMATIONS = {
    "Idle": {
        "length": 60,
        "loop": True,
        "keys": {
            0: pose(),
            30: pose(UpperTorso=(3, 0, 0), Head=(-3, 0, 0), LeftLowerArm=(-20, 0, 0), RightLowerArm=(-30, 0, 0), loc=(0, 0, -0.05)),
            60: pose(),
        },
    },
    "Attack": {
        "length": 24,
        "keys": {
            0: pose(),
            7: pose(UpperTorso=(0, 0, -30), RightUpperArm=(-160, 20, 0), RightLowerArm=(-35, 0, 0)),
            12: pose(UpperTorso=(15, 0, 25), RightUpperArm=(-75, 10, 0), RightLowerArm=(-5, 0, 0), loc=(0, -0.5, 0)),
            24: pose(),
        },
    },
    "Skill": {
        "length": 36,
        "keys": {
            0: pose(),
            8: pose(HumanoidRootPart=(0, 0, -30), RightUpperArm=(0, 80, 0), RightLowerArm=(0, 0, 0), LeftUpperArm=(0, -60, 0)),
            20: pose(HumanoidRootPart=(0, 0, 160), RightUpperArm=(0, 85, 0), RightLowerArm=(0, 0, 0), LeftUpperArm=(0, -60, 0), loc=(0, 0, 0.3)),
            30: pose(HumanoidRootPart=(0, 0, 330), RightUpperArm=(0, 60, 0), LeftUpperArm=(0, -40, 0)),
            36: pose(HumanoidRootPart=(0, 0, 360)),
        },
    },
    "Ultimate": {
        "length": 60,
        "keys": {
            0: pose(),
            12: pose(UpperTorso=(25, 0, 0), RightUpperArm=(-40, 10, 0), LeftUpperArm=(-40, -10, 0),
                     LeftUpperLeg=(-45, 0, 0), RightUpperLeg=(-45, 0, 0), LeftLowerLeg=(80, 0, 0), RightLowerLeg=(80, 0, 0), loc=(0, 0, -0.65)),
            26: pose(UpperTorso=(-10, 0, 0), RightUpperArm=(-170, 5, 0), LeftUpperArm=(-165, -5, 0), RightLowerArm=(-10, 0, 0),
                     LeftUpperLeg=(-25, 0, 0), RightUpperLeg=(-25, 0, 0), LeftLowerLeg=(50, 0, 0), RightLowerLeg=(50, 0, 0), loc=(0, 0, 2.0)),
            38: pose(UpperTorso=(40, 0, 0), RightUpperArm=(-55, 5, 0), LeftUpperArm=(-55, -5, 0), RightLowerArm=(-5, 0, 0),
                     LeftUpperLeg=(-55, 0, 0), RightUpperLeg=(-55, 0, 0), LeftLowerLeg=(90, 0, 0), RightLowerLeg=(90, 0, 0), loc=(0, -0.3, -0.75)),
            60: pose(),
        },
    },
    "Defend": {
        "length": 20,
        "keys": {
            0: pose(),
            8: pose(UpperTorso=(12, 0, 0), RightUpperArm=(-70, -15, 0), RightLowerArm=(-60, 0, 40), LeftUpperArm=(-60, 10, 0), LeftLowerArm=(-60, 0, -30),
                    LeftUpperLeg=(-25, 0, 0), RightUpperLeg=(-25, 0, 0), LeftLowerLeg=(40, 0, 0), RightLowerLeg=(40, 0, 0), loc=(0, 0, -0.3)),
            20: pose(UpperTorso=(12, 0, 0), RightUpperArm=(-70, -15, 0), RightLowerArm=(-60, 0, 40), LeftUpperArm=(-60, 10, 0), LeftLowerArm=(-60, 0, -30),
                     LeftUpperLeg=(-25, 0, 0), RightUpperLeg=(-25, 0, 0), LeftLowerLeg=(40, 0, 0), RightLowerLeg=(40, 0, 0), loc=(0, 0, -0.3)),
        },
    },
    "Hit": {
        "length": 14,
        "keys": {
            0: pose(),
            4: pose(UpperTorso=(-20, 0, 8), Head=(-15, 0, 0), LeftUpperArm=(0, -25, 0), RightUpperArm=(0, 25, 0), loc=(0, 0.45, 0)),
            14: pose(),
        },
    },
    "Defeat": {
        "length": 40,
        "keys": {
            0: pose(),
            14: pose(UpperTorso=(25, 0, 0), Head=(20, 0, 0), LeftUpperLeg=(-15, 0, 0), RightUpperLeg=(-15, 0, 0),
                     LeftLowerLeg=(95, 0, 0), RightLowerLeg=(95, 0, 0), LeftUpperArm=(10, -10, 0), RightUpperArm=(10, 10, 0), loc=(0, 0, -1.25)),
            40: pose(UpperTorso=(60, 0, 0), Head=(25, 0, 0), LeftUpperLeg=(-15, 0, 0), RightUpperLeg=(-15, 0, 0),
                     LeftLowerLeg=(95, 0, 0), RightLowerLeg=(95, 0, 0), LeftUpperArm=(30, -25, 0), RightUpperArm=(30, 25, 0), loc=(0, -0.2, -1.4)),
        },
    },
}


def local_rotation(pose_bone, angles, compat):
    """Rotation exprimée dans les axes du personnage -> rotation locale de l'os."""
    pitch, roll, yaw = (math.radians(a) for a in angles)
    world = Matrix.Rotation(yaw, 3, "Z") @ Matrix.Rotation(roll, 3, "Y") @ Matrix.Rotation(pitch, 3, "X")
    rest = pose_bone.bone.matrix_local.to_3x3()
    return (rest.inverted() @ world @ rest).to_euler("XYZ", compat)


def build_actions(rig):
    rig.animation_data_create()
    actions = {}
    for name, spec in ANIMATIONS.items():
        action = bpy.data.actions.new("F001_Kael_" + name)
        action.use_fake_user = True
        rig.animation_data.action = action
        previous = {}  # continuité des angles d'Euler (rotations > 180°)
        for frame in sorted(spec["keys"]):
            for bone_name, value in spec["keys"][frame].items():
                if bone_name == "loc":
                    pb = rig.pose.bones["HumanoidRootPart"]
                    rest = pb.bone.matrix_local.to_3x3()
                    pb.location = rest.inverted() @ Vector(value)
                    pb.keyframe_insert("location", frame=frame + 1)
                    continue
                pb = rig.pose.bones[bone_name]
                pb.rotation_mode = "XYZ"
                euler = local_rotation(pb, value, previous.get(bone_name, pb.rotation_euler))
                pb.rotation_euler = euler
                previous[bone_name] = euler.copy()
                pb.keyframe_insert("rotation_euler", frame=frame + 1)
        action.frame_range = (1, spec["length"] + 1)
        actions[name] = action
        # Remise à zéro de la pose pour l'animation suivante
        for pb in rig.pose.bones:
            pb.location = (0, 0, 0)
            pb.rotation_euler = (0, 0, 0)
    rig.animation_data.action = None
    return actions


# --------------------------------------------------------------------------- #
# Validation, exports, rendus
# --------------------------------------------------------------------------- #


def validate(mesh_obj, rig, actions, texture_path):
    mesh = mesh_obj.data
    triangles = sum(len(p.vertices) - 2 for p in mesh.polygons)
    influences, unweighted = 0, 0
    for v in mesh.vertices:
        count = sum(1 for g in v.groups if g.weight > 0)
        influences = max(influences, count)
        if count == 0:
            unweighted += 1
    zs = [v.co.z for v in mesh.vertices]
    report = {
        "blender": bpy.app.version_string,
        "height": round(max(zs) - min(zs), 3),
        "minZ": round(min(zs), 3),
        "vertices": len(mesh.vertices),
        "triangles": triangles,
        "bones": [b.name for b in rig.data.bones],
        "boneCount": len(rig.data.bones),
        "maxInfluencesPerVertex": influences,
        "unweightedVertices": unweighted,
        "materials": len(mesh_obj.material_slots),
        "texture": os.path.basename(texture_path),
        "textureSize": TEXTURE_SIZE,
        "animations": {name: {"frames": ANIMATIONS[name]["length"], "fps": FPS, "loop": ANIMATIONS[name].get("loop", False)} for name in actions},
        "budget": BUDGET,
    }
    checks = {
        "triangles": triangles <= BUDGET["maxTriangles"],
        "bones": len(rig.data.bones) <= BUDGET["maxBones"],
        "influences": influences <= BUDGET["maxInfluences"],
        "allVerticesWeighted": unweighted == 0,
        "feetOnGround": abs(min(zs)) < 0.05,
        "height": abs((max(zs) - min(zs)) - HEIGHT) < 0.6,
    }
    report["checks"] = checks
    report["valid"] = all(checks.values())
    return report


def select_only(objects):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]


def export_all(rig, mesh_obj, actions, out_dir):
    files = {}
    rig.animation_data.action = None
    for pb in rig.pose.bones:
        pb.location = (0, 0, 0)
        pb.rotation_euler = (0, 0, 0)
    select_only([rig, mesh_obj])
    model_fbx = os.path.join(out_dir, "F001_Kael.fbx")
    bpy.ops.export_scene.fbx(
        filepath=model_fbx,
        use_selection=True,
        object_types={"ARMATURE", "MESH"},
        add_leaf_bones=False,
        bake_anim=False,
        axis_forward="-Z",
        axis_up="Y",
        apply_scale_options="FBX_SCALE_UNITS",
        path_mode="COPY",
        embed_textures=True,
        mesh_smooth_type="FACE",
    )
    files["modelFbx"] = os.path.basename(model_fbx)
    model_glb = os.path.join(out_dir, "F001_Kael.glb")
    bpy.ops.export_scene.gltf(filepath=model_glb, export_format="GLB", use_selection=True, export_animations=False)
    files["modelGlb"] = os.path.basename(model_glb)

    anim_dir = os.path.join(out_dir, "animations")
    os.makedirs(anim_dir, exist_ok=True)
    files["animations"] = {}
    for name, action in actions.items():
        rig.animation_data.action = action
        start, end = (int(f) for f in action.frame_range)
        bpy.context.scene.frame_start, bpy.context.scene.frame_end = start, end
        select_only([rig, mesh_obj])
        path = os.path.join(anim_dir, "F001_Kael_" + name + ".fbx")
        bpy.ops.export_scene.fbx(
            filepath=path,
            use_selection=True,
            object_types={"ARMATURE", "MESH"},
            add_leaf_bones=False,
            bake_anim=True,
            bake_anim_use_all_actions=False,
            bake_anim_use_nla_strips=False,
            bake_anim_force_startend_keying=True,
            axis_forward="-Z",
            axis_up="Y",
            apply_scale_options="FBX_SCALE_UNITS",
            path_mode="COPY",
            embed_textures=True,
            mesh_smooth_type="FACE",
        )
        files["animations"][name] = "animations/" + os.path.basename(path)
    rig.animation_data.action = None
    return files


def setup_render(out_dir):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "TEXTURE"
    scene.display.shading.show_shadows = True
    scene.display.shading.show_cavity = True
    scene.render.resolution_x = 640
    scene.render.resolution_y = 800
    scene.render.film_transparent = False
    world = bpy.data.worlds.new("World")
    world.color = hex_rgb("#101426")
    scene.world = world
    scene.render.image_settings.file_format = "PNG"
    camera_data = bpy.data.cameras.new("ControlCamera")
    camera_data.lens = 70
    camera = bpy.data.objects.new("ControlCamera", camera_data)
    scene.collection.objects.link(camera)
    scene.camera = camera
    return camera


def aim(camera, location, target=(0, 0, 3.4)):
    camera.location = Vector(location)
    direction = Vector(target) - camera.location
    camera.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()


def render_views(camera, rig, actions, out_dir):
    renders = []
    render_dir = os.path.join(out_dir, "renders")
    os.makedirs(render_dir, exist_ok=True)
    rig.animation_data.action = None
    for pb in rig.pose.bones:
        pb.location = (0, 0, 0)
        pb.rotation_euler = (0, 0, 0)
    views = {
        "front": (0, -16, 3.6),
        "three_quarter": (-10, -12.5, 4.4),
        "side": (16, 0, 3.6),
        "back": (0, 16, 3.6),
    }
    for name, location in views.items():
        aim(camera, location)
        path = os.path.join(render_dir, "kael_" + name + ".png")
        bpy.context.scene.render.filepath = path
        bpy.ops.render.render(write_still=True)
        renders.append("renders/" + os.path.basename(path))
    # Poses clés des animations, vue de trois quarts plus large (sauts compris)
    aim(camera, (-13, -16.5, 5.6), target=(0, 0, 4.2))
    for name, action in actions.items():
        rig.animation_data.action = action
        keys = sorted(ANIMATIONS[name]["keys"].keys())
        key = keys[len(keys) // 2] if len(keys) > 2 else keys[-1]
        bpy.context.scene.frame_set(key + 1)
        path = os.path.join(render_dir, "kael_pose_" + name + ".png")
        bpy.context.scene.render.filepath = path
        bpy.ops.render.render(write_still=True)
        renders.append("renders/" + os.path.basename(path))
    rig.animation_data.action = None
    return renders


def main():
    out_dir = parse_args()
    os.makedirs(out_dir, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.scale_length = 1.0
    scene.render.fps = FPS

    image, texture_path = build_texture(out_dir)
    material = build_material(image)
    rig = build_armature()
    mesh_obj = build_character()
    mesh_obj.data.materials.append(material)
    mesh_obj.parent = rig
    modifier = mesh_obj.modifiers.new("Armature", "ARMATURE")
    modifier.object = rig
    actions = build_actions(rig)

    report = validate(mesh_obj, rig, actions, texture_path)
    report["files"] = export_all(rig, mesh_obj, actions, out_dir)
    camera = setup_render(out_dir)
    report["renders"] = render_views(camera, rig, actions, out_dir)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(out_dir, "F001_Kael.blend"))
    report["files"]["blend"] = "F001_Kael.blend"

    with open(os.path.join(out_dir, "kael_report.json"), "w", encoding="utf-8") as handle:
        json.dump(report, handle, indent=2, ensure_ascii=False)
    print("[Kael] Rapport :", json.dumps(report["checks"]), "valide =", report["valid"])
    print("[Kael] Triangles :", report["triangles"], "| os :", report["boneCount"], "| hauteur :", report["height"])


if __name__ == "__main__":
    main()
