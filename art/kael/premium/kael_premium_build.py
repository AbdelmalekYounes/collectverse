"""Kael (F001) : passe artistique premium (V0.2.4), sur une copie du modèle.

Script Blender reproductible (Blender 4.2 LTS), exécuté sans interface :

    blender -b --factory-startup --python art/kael/premium/kael_premium_build.py -- --out art/kael/premium/build

Le modèle de production (art/kael/kael_build.py, assets/Fighters/F001_Kael.rbxm)
n'est ni lu ni modifié. Ce script en réutilise uniquement le squelette et les
animations, pour que les 7 animations déjà publiées restent valables :

  - armature identique (BONES, mêmes noms, positions et orientations) ;
  - actions identiques (ANIMATIONS), vérifiables par kael_anim_export.py.

Ce qui change, c'est l'habillage :
  1. silhouette : épaulières à étages et pointes, cape à pans de braise, épée plus grande ;
  2. armure : plastron sculpté et filets dorés, tassettes inclinées, genouillères à aileron ;
  3. visage et cheveux : yeux anime (iris, pupille, reflets), sourcils, mèches courbes en dégradé ;
  4. matériaux : texture 128 × 128 en cases dégradées (éclairage peint, lisible sous
     tout éclairage) au lieu d'aplats 64 × 64 ;
  5. épée : lame à arête, âme de braise, garde ailée, gemmes ;
  6. braises : zones émissives (rendus Blender) ; dans Roblox, couleurs vives +
     lumières et particules posées sur les os par FighterAssetPrep (voir la doc V0.2.4).
"""

import importlib.util
import json
import math
import os
import sys

import bmesh
import bpy
from mathutils import Euler, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location("kael_build", os.path.join(HERE, "..", "kael_build.py"))
base = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(base)

NAME = "F001_Kael_Premium"
BONES = base.BONES  # inchangé : condition pour réutiliser les animations publiées
ANIMATIONS = base.ANIMATIONS
FPS = base.FPS
HEIGHT = 6.6
BUDGET = {"maxTriangles": 6000, "maxBones": 20, "maxInfluences": 4, "textureSize": 128}

# --------------------------------------------------------------------------- #
# Texture : cases dégradées
# --------------------------------------------------------------------------- #

TEXTURE_SIZE = 128
GRID = 8  # 8 × 8 cases de 16 px
MARGIN = 2  # px de couleur pleine aux extrémités de chaque case (aucune bavure)

# Dégradés verticaux : liste de (t, couleur), t = 0 en bas de la case, 1 en haut.
# Le paramètre t de chaque sommet est calculé par pièce (hauteur, longueur...).
# Matières lisibles même sans éclairage : le métal a des bandes franches et un
# reflet net (aspect poli), le tissu un dégradé doux et sourd, le cuir des tons
# chauds mats, les cheveux un anneau de reflet (codes anime).
SWATCHES = {
    "armor": [(0, "#4E120C"), (0.38, "#7E1E14"), (0.38, "#A82C1A"), (0.74, "#D0442A"), (0.74, "#F07A52"), (0.84, "#FFC2A0"), (0.9, "#E8603E"), (1, "#C8402A")],
    "armorDeep": [(0, "#2A0806"), (0.45, "#4E140C"), (0.45, "#6E1E12"), (0.82, "#9A3220"), (0.88, "#D86A48"), (1, "#7E2414")],
    "gold": [(0, "#6E4214"), (0.4, "#A8742A"), (0.4, "#D8A044"), (0.78, "#FFD878"), (0.86, "#FFFFFF"), (1, "#E8B858")],
    "under": [(0, "#141018"), (1, "#30242E")],
    "cloth": [(0, "#3A0E16"), (1, "#74202C")],
    "clothInner": [(0, "#1E080E"), (1, "#3A121A")],
    "cape": [(0, "#FFB050"), (0.08, "#E8501E"), (0.2, "#8A1C26"), (0.55, "#6A1620"), (1, "#7E1E2A")],
    "capeInner": [(0, "#E8601E"), (0.1, "#4A0E16"), (1, "#22080E")],
    "skin": [(0, "#D99A74"), (1, "#F8D2AE")],
    "hair": [(0, "#4E0C08"), (0.42, "#B02818"), (0.55, "#E0482A"), (0.6, "#FFB474"), (0.65, "#E8502C"), (0.85, "#FF7A2E"), (1, "#FFD27A")],
    "eyeWhite": [(0, "#DCD8E8"), (1, "#FFFFFF")],
    "iris": [(0, "#FFD26A"), (0.45, "#F27A22"), (0.8, "#A82A0C"), (1, "#4A0E06")],
    "pupil": [(0, "#160812"), (1, "#160812")],
    "eyeLight": [(0, "#FFFFFF"), (1, "#FFFFFF")],
    "brow": [(0, "#2A0604"), (1, "#4A0E08")],
    "mouth": [(0, "#6E2620"), (1, "#9A463A")],
    "steel": [(0, "#323846"), (0.42, "#5E6878"), (0.42, "#8E98AE"), (0.78, "#D4DAEA"), (0.86, "#FFFFFF"), (1, "#A8B0C4")],
    # Lame : t = 0 sur l'arête centrale (acier forgé, plus sombre), 1 sur le fil (acier clair)
    "bladeSteel": [(0, "#4A4858"), (0.5, "#6E6C80"), (0.56, "#C8D2E8"), (0.8, "#EEF2FC"), (1, "#FFFFFF")],
    "ember": [(0, "#FF3A10"), (0.5, "#FF8A2A"), (1, "#FFE69A")],
    "emberCore": [(0, "#FFF4C8"), (1, "#FFFBEA")],
    "leather": [(0, "#2A140C"), (0.6, "#553220"), (1, "#74503A")],
    "metalDark": [(0, "#1A1820"), (1, "#36343E")],
    # Âme de la lame : incandescence discrète, plus vive près de la garde (t = 1)
    "emberSoft": [(0, "#7A1A08"), (0.5, "#C8401A"), (1, "#FF8A3A")],
}
# Émission (rendus Blender uniquement) : même disposition, noir = pas d'émission.
EMISSION = {
    "ember": [(0, "#FF3A10"), (0.5, "#FF8A2A"), (1, "#FFE69A")],
    "emberCore": [(0, "#FFE9A8"), (1, "#FFF4C8")],
    "emberSoft": [(0, "#000000"), (0.45, "#200802"), (1, "#B8461A")],
    "cape": [(0, "#FF9A3A"), (0.08, "#A8300C"), (0.17, "#000000"), (1, "#000000")],
    "capeInner": [(0, "#A8300C"), (0.08, "#000000"), (1, "#000000")],
    "iris": [(0, "#5A2008"), (0.4, "#000000"), (1, "#000000")],
}
# Métal et rugosité par case (0 à 1) : cartes en niveaux de gris, même disposition.
# Utilisées par les rendus Blender ; dans Roblox, seulement avec une SurfaceAppearance
# (deux images de plus à téléverser), sinon la texture peinte porte seule les matières.
METALNESS = {"armor": 0.55, "armorDeep": 0.5, "gold": 0.8, "steel": 0.8, "bladeSteel": 0.7, "metalDark": 0.6}
ROUGHNESS = {
    "armor": 0.32, "armorDeep": 0.4, "gold": 0.25, "steel": 0.28, "bladeSteel": 0.22, "metalDark": 0.4,
    "cloth": 0.95, "clothInner": 0.95, "cape": 0.92, "capeInner": 0.95, "under": 0.85,
    "leather": 0.62, "hair": 0.5, "skin": 0.55, "eyeWhite": 0.2, "iris": 0.15, "pupil": 0.15, "eyeLight": 0.1,
}
SWATCH_ORDER = list(SWATCHES.keys())


def hex_rgb(value):
    value = value.lstrip("#")
    return tuple(int(value[i : i + 2], 16) / 255 for i in (0, 2, 4))


def sample_stops(stops, t):
    t = max(0.0, min(1.0, t))
    for (t0, c0), (t1, c1) in zip(stops, stops[1:]):
        if t <= t1:
            k = 0 if t1 == t0 else (t - t0) / (t1 - t0)
            a, b = hex_rgb(c0), hex_rgb(c1)
            return tuple(a[i] + (b[i] - a[i]) * k for i in range(3))
    return hex_rgb(stops[-1][1])


def swatch_uv(name, t):
    """UV d'un sommet : centre horizontal de la case, hauteur selon t."""
    index = SWATCH_ORDER.index(name)
    col, row = index % GRID, index // GRID
    cell = TEXTURE_SIZE // GRID
    base_px = (GRID - 1 - row) * cell  # bas de la case, en px depuis le bas de l'image
    t = max(0.0, min(1.0, t))
    v = (base_px + MARGIN + t * (cell - 2 * MARGIN)) / TEXTURE_SIZE
    return ((col + 0.5) / GRID, v)


def build_image(name, table, path):
    image = bpy.data.images.new(name, TEXTURE_SIZE, TEXTURE_SIZE, alpha=False)
    cell = TEXTURE_SIZE // GRID
    pixels = [0.0] * (TEXTURE_SIZE * TEXTURE_SIZE * 4)
    for i in range(TEXTURE_SIZE * TEXTURE_SIZE):
        pixels[i * 4 + 3] = 1.0
    for index, swatch in enumerate(SWATCH_ORDER):
        stops = table.get(swatch)
        if stops is None:
            continue
        if isinstance(stops, (int, float)):
            grey = "#%02X%02X%02X" % ((round(stops * 255),) * 3)
            stops = [(0, grey), (1, grey)]
        col, row = index % GRID, index // GRID
        base_px = (GRID - 1 - row) * cell
        for y in range(cell):
            t = (y + 0.5 - MARGIN) / (cell - 2 * MARGIN)
            r, g, b = sample_stops(stops, t)
            py = base_px + y
            for x in range(cell):
                offset = (py * TEXTURE_SIZE + col * cell + x) * 4
                pixels[offset : offset + 3] = [r, g, b]
    image.pixels = pixels
    image.filepath_raw = path
    image.file_format = "PNG"
    image.save()
    return image


# --------------------------------------------------------------------------- #
# Maillage
# --------------------------------------------------------------------------- #


class Builder:
    """Sommets, faces, case de texture, paramètre de dégradé et poids par sommet."""

    def __init__(self):
        self.verts, self.faces, self.face_swatch, self.face_smooth = [], [], [], []
        self.ts, self.weights, self.parts = [], [], {}

    def add(self, part, verts, faces, swatch, weight_fn, grad=None, smooth=True, face_swatches=None):
        verts = [Vector(v) for v in verts]
        if grad == "z" or grad == "-z":
            lo, hi = min(v.z for v in verts), max(v.z for v in verts)
            span = max(hi - lo, 1e-6)
            sign = 1 if grad == "z" else -1
            grad_fn = (lambda v: (v.z - lo) / span) if sign > 0 else (lambda v: (hi - v.z) / span)
        elif callable(grad):
            grad_fn = grad
        else:
            grad_fn = lambda _v: 0.5
        base_index = len(self.verts)
        for v in verts:
            self.verts.append(v)
            self.weights.append(weight_fn(v))
            self.ts.append(grad_fn(v))
        for i, f in enumerate(faces):
            self.faces.append([base_index + k for k in f])
            self.face_swatch.append(face_swatches[i] if face_swatches else swatch)
            self.face_smooth.append(smooth)
        tris = sum(len(f) - 2 for f in faces)
        self.parts[part] = self.parts.get(part, 0) + tris

    def build(self, name):
        mesh = bpy.data.meshes.new(name)
        mesh.from_pydata([tuple(v) for v in self.verts], [], self.faces)
        mesh.update(calc_edges=True)
        # Orientation cohérente des normales (pièces fermées) : Roblox masque les faces arrière.
        bm = bmesh.new()
        bm.from_mesh(mesh)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bm.to_mesh(mesh)
        bm.free()
        uv = mesh.uv_layers.new(name="UVMap")
        for poly, swatch, smooth in zip(mesh.polygons, self.face_swatch, self.face_smooth):
            poly.use_smooth = smooth
            for loop_index in poly.loop_indices:
                vertex = mesh.loops[loop_index].vertex_index
                uv.data[loop_index].uv = swatch_uv(swatch, self.ts[vertex])
        obj = bpy.data.objects.new(name, mesh)
        bpy.context.scene.collection.objects.link(obj)
        groups = {bone: obj.vertex_groups.new(name=bone) for bone in BONES if bone != "Root"}
        for index, weights in enumerate(self.weights):
            for bone, weight in weights.items():
                if weight > 0:
                    groups[bone].add([index], weight, "REPLACE")
        return obj


rigid = base.rigid
chain_weights = base.chain_weights
tube = base.tube
cone = base.cone
box = base.box
bone_point = base.bone_point


def ellipsoid(center, radii, rings=8, segments=12):
    return base.ellipsoid(tuple(center), tuple(radii), rings=rings, segments=segments)


def transform(verts, rotation_deg=(0, 0, 0), pivot=(0, 0, 0)):
    m = Euler(tuple(math.radians(a) for a in rotation_deg), "XYZ").to_matrix()
    p = Vector(pivot)
    return [p + m @ (Vector(v) - p) for v in verts]


def loft(sections, segments=16, caps=True):
    """Sections horizontales (cx, cy, z, rx, ry) : rx en X (largeur), ry en Y (profondeur)."""
    verts, faces = [], []
    for cx, cy, z, rx, ry in sections:
        for j in range(segments):
            a = 2 * math.pi * j / segments
            verts.append(Vector((cx + rx * math.cos(a), cy + ry * math.sin(a), z)))
    for i in range(len(sections) - 1):
        for j in range(segments):
            a = i * segments + j
            b = i * segments + (j + 1) % segments
            faces.append([a, b, b + segments, a + segments])
    if caps:
        first = sections[0]
        last = sections[-1]
        start = len(verts)
        verts.append(Vector((first[0], first[1], first[2])))
        verts.append(Vector((last[0], last[1], last[2])))
        top = (len(sections) - 1) * segments
        for j in range(segments):
            faces.append([start, (j + 1) % segments, j])
            faces.append([start + 1, top + j, top + (j + 1) % segments])
    return verts, faces


def torus(center, axis, major, minor, segments=16, sides=6, major_y=None):
    axis = Vector(axis).normalized()
    helper = Vector((0, 0, 1)) if abs(axis.z) < 0.9 else Vector((1, 0, 0))
    side = axis.cross(helper).normalized()
    up = side.cross(axis).normalized()
    if abs(axis.z) >= 0.9:  # anneau horizontal : major en X, major_y en Y
        side, up = Vector((1, 0, 0)), Vector((0, 1, 0))
    major_y = major if major_y is None else major_y
    center = Vector(center)
    verts, faces = [], []
    for i in range(segments):
        a = 2 * math.pi * i / segments
        radial = (side * math.cos(a) * major + up * math.sin(a) * major_y)
        direction = radial.normalized()
        ring_center = center + radial
        for j in range(sides):
            b = 2 * math.pi * j / sides
            verts.append(ring_center + direction * math.cos(b) * minor + axis * math.sin(b) * minor)
    for i in range(segments):
        for j in range(sides):
            a = i * sides + j
            b = i * sides + (j + 1) % sides
            c = ((i + 1) % segments) * sides + (j + 1) % sides
            d = ((i + 1) % segments) * sides + j
            faces.append([a, b, c, d])
    return verts, faces


def bezier(p0, p1, p2, steps):
    p0, p1, p2 = Vector(p0), Vector(p1), Vector(p2)
    return [(1 - t) ** 2 * p0 + 2 * (1 - t) * t * p1 + t * t * p2 for t in (i / (steps - 1) for i in range(steps))]


def diamond_strip(points, half_widths, half_thicks, w, n, tip=True):
    """Section en losange (lame, filet) le long d'un chemin ; largeur selon w, épaisseur selon n."""
    w, n = Vector(w).normalized(), Vector(n).normalized()
    verts, faces = [], []
    count = len(points) - 1 if tip else len(points)
    for i in range(count):
        p = Vector(points[i])
        hw, th = half_widths[i], half_thicks[i]
        verts += [p + w * hw, p + n * th, p - w * hw, p - n * th]
    for i in range(count - 1):
        for j in range(4):
            a = i * 4 + j
            b = i * 4 + (j + 1) % 4
            faces.append([a, b, b + 4, a + 4])
    faces.append([3, 2, 1, 0])  # base
    if tip:
        verts.append(Vector(points[-1]))
        t = len(verts) - 1
        last = (count - 1) * 4
        for j in range(4):
            faces.append([last + j, last + (j + 1) % 4, t])
    else:
        last = (count - 1) * 4
        faces.append([last, last + 1, last + 2, last + 3])
    return verts, faces


def shell(outer, inner):
    """Feuille épaisse fermée à partir de deux grilles (lignes × colonnes) de même taille."""
    rows, cols = len(outer), len(outer[0])
    verts = [Vector(p) for row in outer for p in row] + [Vector(p) for row in inner for p in row]
    off = rows * cols
    faces, swatch_side = [], []

    def idx(r, c, layer):
        return layer * off + r * cols + c

    for r in range(rows - 1):
        for c in range(cols - 1):
            faces.append([idx(r, c, 0), idx(r, c + 1, 0), idx(r + 1, c + 1, 0), idx(r + 1, c, 0)])
            swatch_side.append("outer")
            faces.append([idx(r, c, 1), idx(r + 1, c, 1), idx(r + 1, c + 1, 1), idx(r, c + 1, 1)])
            swatch_side.append("inner")
    for c in range(cols - 1):  # bords haut et bas
        faces.append([idx(0, c, 0), idx(0, c, 1), idx(0, c + 1, 1), idx(0, c + 1, 0)])
        swatch_side.append("outer")
        r = rows - 1
        faces.append([idx(r, c, 0), idx(r, c + 1, 0), idx(r, c + 1, 1), idx(r, c, 1)])
        swatch_side.append("outer")
    for r in range(rows - 1):  # bords latéraux
        faces.append([idx(r, 0, 0), idx(r + 1, 0, 0), idx(r + 1, 0, 1), idx(r, 0, 1)])
        swatch_side.append("outer")
        c = cols - 1
        faces.append([idx(r, c, 0), idx(r, c, 1), idx(r + 1, c, 1), idx(r + 1, c, 0)])
        swatch_side.append("outer")
    return verts, faces, swatch_side


# Tête : ellipsoïde « en œuf » (mâchoire affinée), pour placer le visage sur la surface.
HEAD_CENTER = Vector((0, -0.02, 5.45))
HEAD_RADII = (0.66, 0.62, 0.74)
JAW = 0.22


def jaw_scale(z):
    dz = HEAD_CENTER.z - z
    return 1 - JAW * max(0.0, dz) / HEAD_RADII[2]


def head_front_y(x, z):
    """Y de la surface avant du visage (le personnage regarde vers -Y)."""
    dz = (z - HEAD_CENTER.z) / HEAD_RADII[2]
    s = math.sqrt(max(0.0, 1 - dz * dz)) * jaw_scale(z)
    rx, ry = HEAD_RADII[0] * s, HEAD_RADII[1] * s
    k = 1 - (x / max(rx, 1e-6)) ** 2
    return HEAD_CENTER.y - ry * math.sqrt(max(0.0, k))


def tabard_weights(v):
    """Pan avant : suit le bassin en haut, la moyenne des cuisses en bas (3 influences)."""
    if v.z >= 2.95:
        return {"LowerTorso": 1.0}
    s = min(0.7, (2.95 - v.z) / 0.9 * 0.7)
    return {"LowerTorso": 1 - s, "LeftUpperLeg": s / 2, "RightUpperLeg": s / 2}


def build_character():
    mb = Builder()

    # ---------------- Jambes : combinaison, cuissards, genouillères, bottes ----------------
    for side, sign in (("Left", 1), ("Right", -1)):
        hip = bone_point(side + "UpperLeg", False)
        knee = bone_point(side + "UpperLeg", True)
        ankle = bone_point(side + "LowerLeg", True)
        legs = chain_weights([hip, knee, ankle], [side + "UpperLeg", side + "LowerLeg"])
        path = [hip + Vector((0, 0, 0.1)), hip.lerp(knee, 0.5), knee, knee.lerp(ankle, 0.5), ankle + Vector((0, 0, 0.25))]
        verts, faces = tube(path, [0.35, 0.3, 0.25, 0.24, 0.22], segments=8)
        mb.add("legs", verts, faces, "under", legs, grad="z")
        # Cuissard : plaque bombée devant la cuisse
        verts, faces = ellipsoid((hip.x + 0.02 * sign, -0.2, 2.25), (0.25, 0.09, 0.34), rings=5, segments=8)
        mb.add("armor", verts, faces, "armor", rigid(side + "UpperLeg"), grad="z")
        # Genouillère à aileron
        verts, faces = ellipsoid((knee.x, knee.y - 0.23, knee.z), (0.19, 0.08, 0.2), rings=5, segments=8)
        mb.add("armor", verts, faces, "armor", rigid(side + "LowerLeg"), grad="z")
        verts, faces = cone((knee.x, knee.y - 0.3, knee.z + 0.05), (knee.x, knee.y - 0.42, knee.z + 0.34), 0.07, segments=5)
        mb.add("armor", verts, faces, "gold", rigid(side + "LowerLeg"), grad="z", smooth=False)
        # Botte : tige évasée, revers doré, pied, coque de pointe, semelle
        top = knee.lerp(ankle, 0.3)
        verts, faces = tube([top, knee.lerp(ankle, 0.65), ankle - Vector((0, 0.04, 0.12))], [0.32, 0.28, 0.27], segments=8)
        mb.add("boots", verts, faces, "leather", rigid(side + "LowerLeg"), grad="z")
        verts, faces = torus(top, (0, 0, 1), 0.31, 0.045, segments=8, sides=4)
        mb.add("boots", verts, faces, "gold", rigid(side + "LowerLeg"), grad="z")
        verts, faces = box((ankle.x, ankle.y - 0.2, 0.2), (0.44, 0.8, 0.3), taper=0.85)
        mb.add("boots", verts, faces, "leather", rigid(side + "Foot"), grad="z", smooth=False)
        verts, faces = ellipsoid((ankle.x, ankle.y - 0.43, 0.31), (0.22, 0.27, 0.07), rings=4, segments=8)
        mb.add("boots", verts, faces, "armor", rigid(side + "Foot"), grad="z")
        verts, faces = box((ankle.x, ankle.y - 0.22, 0.04), (0.47, 0.86, 0.08))
        mb.add("boots", verts, faces, "metalDark", rigid(side + "Foot"), smooth=False)

    # ---------------- Torse : combinaison (plus large que profonde) ----------------
    torso = chain_weights([Vector((0, 0, 2.5)), Vector((0, 0, 3.55)), Vector((0, 0, 4.75))], ["LowerTorso", "UpperTorso"], width=0.2)
    verts, faces = loft(
        [
            (0, 0, 2.55, 0.5, 0.36),
            (0, 0, 2.9, 0.55, 0.38),
            (0, 0, 3.3, 0.5, 0.34),
            (0, 0, 3.8, 0.62, 0.4),
            (0, 0, 4.25, 0.72, 0.44),
            (0, 0, 4.55, 0.6, 0.38),
            (0, 0, 4.72, 0.3, 0.27),
        ],
        segments=12,
    )
    mb.add("torso", verts, faces, "under", torso, grad="z")
    # Plastron, dossière, plaque abdominale
    verts, faces = ellipsoid((0, -0.12, 4.15), (0.76, 0.4, 0.55), rings=6, segments=12)
    mb.add("armor", verts, faces, "armor", rigid("UpperTorso"), grad="z")
    verts, faces = ellipsoid((0, 0.1, 4.15), (0.72, 0.38, 0.5), rings=4, segments=10)
    mb.add("armor", verts, faces, "armorDeep", rigid("UpperTorso"), grad="z")
    verts, faces = ellipsoid((0, -0.3, 3.64), (0.5, 0.12, 0.2), rings=5, segments=8)
    mb.add("armor", verts, faces, "armor", rigid("UpperTorso"), grad="z")
    # Filets dorés en V, col, cœur de braise
    for sign in (1, -1):
        path = [(0.56 * sign, -0.24, 4.52), (0.36 * sign, -0.48, 4.3), (0.15 * sign, -0.53, 4.07)]
        verts, faces = tube(path, [0.035, 0.035, 0.03], segments=5)
        mb.add("armor", verts, faces, "gold", rigid("UpperTorso"), grad="z")
    verts, faces = torus((0, 0, 4.64), (0, 0, 1), 0.42, 0.06, segments=14, sides=5, major_y=0.36)
    mb.add("armor", verts, faces, "gold", rigid("UpperTorso"), grad="z")
    verts, faces = torus((0, -0.5, 4.2), (0, -1, 0), 0.16, 0.035, segments=10, sides=4)
    mb.add("ember", verts, faces, "gold", rigid("UpperTorso"), grad="z")
    verts, faces = ellipsoid((0, -0.53, 4.2), (0.13, 0.07, 0.16), rings=5, segments=8)
    mb.add("ember", verts, faces, "ember", rigid("UpperTorso"), grad="z")

    # ---------------- Ceinture, boucle, tassettes, pan avant ----------------
    verts, faces = loft([(0, 0, 3.08, 0.57, 0.41), (0, 0, 3.3, 0.56, 0.4)], segments=16)
    mb.add("belt", verts, faces, "leather", rigid("LowerTorso"), grad="z")
    verts, faces = box((0, -0.43, 3.19), (0.32, 0.07, 0.24))
    mb.add("belt", verts, faces, "gold", rigid("LowerTorso"), grad="z", smooth=False)
    verts, faces = ellipsoid((0, -0.47, 3.19), (0.08, 0.04, 0.08), rings=4, segments=8)
    mb.add("ember", verts, faces, "ember", rigid("LowerTorso"), grad="z")
    for sign in (1, -1):
        for z, size, drop in ((2.82, (0.12, 0.66, 0.56), 0.0), (2.5, (0.11, 0.56, 0.36), 0.05)):
            verts, faces = box((0.62 * sign + drop * sign, -0.02, z), size, taper=1.15)
            verts = transform(verts, (0, -14 * sign, 0), (0.6 * sign, 0, 3.1))
            swatch = "armor" if z > 2.6 else "armorDeep"
            mb.add("belt", verts, faces, swatch, rigid("LowerTorso"), grad="z", smooth=False)
        verts, faces = tube([(0.58 * sign, -0.36, 3.05), (0.74 * sign, -0.36, 2.56)], [0.025, 0.025], segments=4)
        verts = transform(verts, (0, -14 * sign, 0), (0.6 * sign, 0, 3.1))
        mb.add("belt", verts, faces, "gold", rigid("LowerTorso"))
    # Pan avant : polygone extrudé, légèrement incliné vers l'avant, liseré doré
    outline = [(-0.24, 3.12), (0.24, 3.12), (0.3, 2.25), (0.0, 1.96), (-0.3, 2.25)]

    def tabard_y(z):
        return -0.43 - (3.12 - z) * 0.07

    front = [Vector((x, tabard_y(z) - 0.03, z)) for x, z in outline]
    back = [Vector((x, tabard_y(z) + 0.03, z)) for x, z in outline]
    verts = front + back + [Vector((0, tabard_y(2.6) - 0.03, 2.6)), Vector((0, tabard_y(2.6) + 0.03, 2.6))]
    cf, cb = len(verts) - 2, len(verts) - 1
    count = len(outline)
    faces = []
    for i in range(count):
        j = (i + 1) % count
        faces.append([cf, i, j])
        faces.append([cb, count + j, count + i])
        faces.append([i, count + i, count + j, j])
    mb.add("cloth", verts, faces, "cloth", tabard_weights, grad="-z", smooth=False)
    edge = [Vector((x, tabard_y(z) - 0.045, z)) for x, z in outline[1:] + outline[:1]]
    verts, faces = tube(edge, [0.025] * len(edge), segments=4, caps=True)
    mb.add("cloth", verts, faces, "gold", tabard_weights, grad="z")
    verts, faces = ellipsoid((0, tabard_y(2.62) - 0.06, 2.62), (0.09, 0.03, 0.13), rings=4, segments=6)
    mb.add("ember", verts, faces, "ember", tabard_weights, grad="z")

    # ---------------- Cape : évasée, plis stylisés, ourlet de braise irrégulier ----------------
    cols, rows = 13, 8
    top = 4.6
    outer, inner = [], []
    cape_t = {}  # dégradé depuis l'ourlet (0) vers les épaules (1), colonne par colonne
    for r in range(rows):
        row_o, row_i = [], []
        for c in range(cols):
            theta = math.radians(-74 + 148 * c / (cols - 1))
            # Ourlet : trois pointes souples (pas de dents régulières), plus long au centre
            hem = 2.5 - 0.26 * max(0.0, math.sin(theta * 3.4 + 0.5)) ** 2 - 0.1 * math.cos(theta) + 0.06 * math.cos(theta * 7)
            z = top + (hem - top) * r / (rows - 1)
            drop = top - z
            # Étroite aux épaules, évasée vers le bas ; plis qui se creusent en descendant
            rx, ry = 0.52 + drop * 0.2, 0.46 + drop * 0.2
            fold = 1 + 0.07 * drop * math.cos(theta * 9)
            sweep = 0.06 * drop * drop
            for layer, k in ((row_o, 1.0), (row_i, 0.94)):
                point = Vector((rx * k * fold * math.sin(theta), 0.05 + ry * k * fold * math.cos(theta) + sweep, z))
                cape_t[tuple(round(value, 5) for value in point)] = 1 - r / (rows - 1)
                layer.append(point)
        outer.append(row_o)
        inner.append(row_i)
    verts, faces, sides_ = shell(outer, inner)
    swatches = ["cape" if s == "outer" else "capeInner" for s in sides_]
    cape_weights = chain_weights([Vector((0, 0, 4.75)), Vector((0, 0, 3.4)), Vector((0, 0, 1.6))], ["UpperTorso", "LowerTorso"], width=0.35)
    mb.add("cape", verts, faces, "cape", cape_weights, grad=lambda v: cape_t[tuple(round(value, 5) for value in v)], face_swatches=swatches)

    # ---------------- Bras : peau, brassard, gantelets, gants ----------------
    for side, sign in (("Left", 1), ("Right", -1)):
        shoulder = bone_point(side + "UpperArm", False)
        elbow = bone_point(side + "UpperArm", True)
        wrist = bone_point(side + "LowerArm", True)
        arm = chain_weights([shoulder, elbow, wrist], [side + "UpperArm", side + "LowerArm"])
        verts, faces = tube([shoulder, shoulder.lerp(elbow, 0.5), elbow, elbow.lerp(wrist, 0.5), wrist], [0.25, 0.22, 0.2, 0.19, 0.17], segments=8)
        mb.add("arms", verts, faces, "skin", arm, grad="z")
        verts, faces = tube([shoulder.lerp(elbow, 0.55), shoulder.lerp(elbow, 0.72)], [0.235, 0.225], segments=8)
        mb.add("arms", verts, faces, "leather", rigid(side + "UpperArm"), grad="z")
        a, b = elbow.lerp(wrist, 0.18), wrist + Vector((0, 0, 0.04))
        verts, faces = tube([a, a.lerp(b, 0.3), b], [0.29, 0.24, 0.23], segments=8)
        mb.add("arms", verts, faces, "steel", rigid(side + "LowerArm"), grad="z")
        verts, faces = torus(a, (a - b).normalized(), 0.29, 0.04, segments=8, sides=4)
        mb.add("arms", verts, faces, "gold", rigid(side + "LowerArm"), grad="z")
        hand = bone_point(side + "Hand", False).lerp(bone_point(side + "Hand", True), 0.5)
        verts, faces = ellipsoid(hand, (0.17, 0.15, 0.22), rings=5, segments=8)
        mb.add("arms", verts, faces, "leather", rigid(side + "Hand"), grad="z")

        # Épaulières à deux étages, liseré doré, pointe
        up = rigid(side + "UpperArm")
        verts, faces = ellipsoid((shoulder.x + 0.1 * sign, 0, shoulder.z + 0.08), (0.47, 0.43, 0.32), rings=6, segments=12)
        mb.add("pauldrons", verts, faces, "armor", up, grad="z")
        verts, faces = ellipsoid((shoulder.x + 0.22 * sign, 0, shoulder.z - 0.14), (0.4, 0.38, 0.24), rings=5, segments=10)
        mb.add("pauldrons", verts, faces, "armorDeep", up, grad="z")
        verts, faces = torus((shoulder.x + 0.12 * sign, 0, shoulder.z - 0.02), (0.35 * sign, 0, 1), 0.44, 0.04, segments=10, sides=4)
        mb.add("pauldrons", verts, faces, "gold", up, grad="z")
        verts, faces = cone((shoulder.x + 0.16 * sign, 0.02, shoulder.z + 0.3), (shoulder.x + 0.5 * sign, 0.08, shoulder.z + 0.78), 0.1, segments=6)
        mb.add("pauldrons", verts, faces, "gold", up, grad="z", smooth=False)

    # ---------------- Tête : cou, visage, yeux anime ----------------
    neck = chain_weights([Vector((0, 0, 4.5)), Vector((0, 0, 4.75)), Vector((0, 0, 5.0))], ["UpperTorso", "Head"])
    verts, faces = tube([Vector((0, 0, 4.6)), Vector((0, 0, 4.95))], [0.21, 0.2], segments=8)
    mb.add("head", verts, faces, "skin", neck, grad="z")
    head = rigid("Head")
    verts, faces = ellipsoid(HEAD_CENTER, HEAD_RADII, rings=9, segments=14)
    shaped = []
    for v in verts:
        k = jaw_scale(v.z)
        shaped.append(Vector((HEAD_CENTER.x + (v.x - HEAD_CENTER.x) * k, HEAD_CENTER.y + (v.y - HEAD_CENTER.y) * k, v.z)))
    mb.add("head", shaped, faces, "skin", head, grad=lambda v: 0.25 + 0.75 * (v.z - 4.8) / 1.3)
    for sign in (1, -1):
        x, z = 0.24 * sign, 5.4
        y = head_front_y(x, z)
        rx, rz = 0.16, 0.2
        verts, faces = ellipsoid((x, y + 0.01, z), (rx, 0.05, rz), rings=5, segments=8)
        mb.add("face", verts, faces, "eyeWhite", head, grad="z")
        verts, faces = ellipsoid((x, y - 0.025, z - 0.025), (0.115, 0.035, 0.16), rings=5, segments=8)
        mb.add("face", verts, faces, "iris", head, grad="z")
        verts, faces = ellipsoid((x, y - 0.045, z - 0.035), (0.055, 0.02, 0.09), rings=4, segments=6)
        mb.add("face", verts, faces, "pupil", head)
        verts, faces = ellipsoid((x - 0.05 * sign, y - 0.06, z + 0.06), (0.04, 0.012, 0.05), rings=3, segments=5)
        mb.add("face", verts, faces, "eyeLight", head)
        verts, faces = ellipsoid((x + 0.035 * sign, y - 0.055, z - 0.1), (0.022, 0.01, 0.022), rings=3, segments=5)
        mb.add("face", verts, faces, "eyeLight", head)
        # Trait de paupière : arc épais au-dessus de l'œil, finissant en pointe vers l'extérieur
        lid = []
        for i in range(5):
            angle = math.pi * (0.9 - 0.75 * i / 4)
            px, pz = x + sign * rx * 1.06 * math.cos(angle), z + rz * 0.98 * math.sin(angle)
            lid.append(Vector((px, head_front_y(px, pz) - 0.045, pz)))
        px, pz = x + sign * rx * 1.42, z + rz * 0.5
        lid.append(Vector((px, head_front_y(px, pz) - 0.03, pz)))
        verts, faces = diamond_strip(lid, [0.02, 0.03, 0.034, 0.032, 0.026, 0.0], [0.012] * 5 + [0.0], (0, 0, 1), (0, -1, 0))
        mb.add("face", verts, faces, "brow", head, smooth=False)
        # Sourcil décidé : épais, bas à l'intérieur, cassé vers l'extérieur
        brow = [(0.07, 5.63), (0.22, 5.71), (0.36, 5.73), (0.46, 5.68)]
        brow = [Vector((bx * sign, head_front_y(bx, bz) - 0.03, bz)) for bx, bz in brow]
        verts, faces = diamond_strip(brow, [0.042, 0.048, 0.036, 0.0], [0.02, 0.02, 0.018, 0.0], (0, 0, 1), (0, -1, 0))
        mb.add("face", verts, faces, "brow", head, smooth=False)
    # Nez discret, sourire en coin assuré
    verts, faces = cone((0, head_front_y(0, 5.24) + 0.02, 5.26), (0, head_front_y(0, 5.24) - 0.06, 5.22), 0.04, segments=4)
    mb.add("face", verts, faces, "skin", head, grad=lambda _v: 0.3, smooth=False)
    mouth = [Vector((mx, head_front_y(mx, mz) - 0.012, mz)) for mx, mz in ((-0.1, 5.11), (-0.02, 5.095), (0.06, 5.1), (0.13, 5.14))]
    verts, faces = tube(mouth, [0.016, 0.022, 0.02, 0.012], segments=4)
    mb.add("face", verts, faces, "mouth", head)

    # ---------------- Cheveux : calotte et mèches courbes en dégradé ----------------
    verts, faces = ellipsoid((0, 0.14, 5.7), (0.75, 0.72, 0.6), rings=8, segments=14)
    mb.add("hair", verts, faces, "hair", head, grad=lambda v: 0.1 + 0.55 * (v.z - 5.1) / 1.2)
    # Masse arrière : couvre la nuque sous la calotte
    verts, faces = ellipsoid((0, 0.24, 5.35), (0.66, 0.5, 0.52), rings=5, segments=10)
    mb.add("hair", verts, faces, "hair", head, grad=lambda v: 0.05 + 0.4 * (v.z - 4.85) / 1.0)
    spikes = [
        # (base, extrémité, rayon, courbure)
        ((0, -0.3, 6.1), (0, -0.05, 6.74), 0.26, (0, -0.12, 0.08)),
        ((0.32, -0.15, 6.08), (0.58, 0.18, 6.62), 0.24, (0, -0.05, 0.12)),
        ((-0.32, -0.15, 6.08), (-0.58, 0.18, 6.62), 0.24, (0, -0.05, 0.12)),
        ((0, 0.25, 6.1), (0, 0.88, 6.5), 0.27, (0, 0, 0.16)),
        ((0.45, 0.3, 5.95), (0.98, 0.78, 6.22), 0.24, (0, 0, 0.14)),
        ((-0.45, 0.3, 5.95), (-0.98, 0.78, 6.22), 0.24, (0, 0, 0.14)),
        ((0.25, 0.55, 5.7), (0.52, 1.18, 5.62), 0.22, (0, 0, 0.12)),
        ((-0.25, 0.55, 5.7), (-0.52, 1.18, 5.62), 0.22, (0, 0, 0.12)),
        ((0, 0.6, 5.45), (0, 1.2, 5.22), 0.2, (0, 0, 0.1)),
        ((0.62, -0.05, 5.78), (1.06, -0.08, 5.98), 0.17, (0, 0, 0.08)),
        ((-0.62, -0.05, 5.78), (-1.06, -0.08, 5.98), 0.17, (0, 0, 0.08)),
        ((0.6, -0.28, 5.62), (0.63, -0.46, 5.02), 0.12, (0.04, -0.04, 0)),
        ((-0.6, -0.28, 5.62), (-0.63, -0.46, 5.02), 0.12, (-0.04, -0.04, 0)),
        ((0.1, -0.56, 5.98), (0.04, -0.8, 5.62), 0.13, (0, -0.08, 0.02)),
        ((-0.2, -0.54, 5.98), (-0.33, -0.77, 5.66), 0.13, (0, -0.08, 0.02)),
        ((0.38, -0.47, 5.95), (0.5, -0.71, 5.7), 0.12, (0, -0.06, 0.02)),
    ]
    for root, tip, radius, bend in spikes:
        root, tip = Vector(root), Vector(tip)
        control = root.lerp(tip, 0.5) + Vector(bend)
        path = bezier(root, control, tip, 4)
        verts, faces = tube(path, [radius, radius * 0.72, radius * 0.36, 0.012], segments=5)
        length = (tip - root).length

        def along(v, root=root, tip=tip, length=length):
            return 0.35 + 0.65 * max(0.0, min(1.0, (v - root).dot(tip - root) / (length * length)))

        mb.add("hair", verts, faces, "hair", head, grad=along)
    # Bandeau doré, gemme de braise frontale, rubans flottants
    verts, faces = loft([(0, 0.1, 5.76, 0.755, 0.715), (0, 0.1, 5.87, 0.755, 0.715)], segments=20, caps=False)
    mb.add("head", verts, faces, "gold", head, grad="z")
    verts, faces = ellipsoid((0, -0.63, 5.815), (0.085, 0.045, 0.075), rings=5, segments=8)
    mb.add("ember", verts, faces, "ember", head, grad="z")
    for sign in (1, -1):
        ribbon = bezier((0.1 * sign, 0.8, 5.82), (0.24 * sign, 1.15, 5.8), (0.36 * sign, 1.38, 5.42), 4)
        verts, faces = diamond_strip(ribbon, [0.075, 0.07, 0.06, 0.0], [0.015, 0.015, 0.012, 0.0], (0, 0, 1), (1, 0, 0))
        mb.add("head", verts, faces, "armor", head, grad="z", smooth=False)

    # ---------------- Épée de braises (main droite) ----------------
    # Repère de l'épée : a = axe de la lame (inchangé), w = largeur, n = épaisseur.
    sword = rigid("RightHand")
    grip = bone_point("RightHand", False).lerp(bone_point("RightHand", True), 0.55)
    a = Vector((0, -0.55, 1)).normalized()
    w = Vector((1, 0, 0))
    n = a.cross(w).normalized()
    guard = grip + a * 0.3
    pommel = grip - a * 0.38

    def local(center, x, y, z):
        return center + w * x + n * y + a * z

    def oriented_ellipsoid(center, radii, rings=4, segments=8):
        verts, faces = base.ellipsoid((0, 0, 0), radii, rings=rings, segments=segments)
        return [local(center, v.x, v.y, v.z) for v in verts], faces

    # Lame large, renflée avant la pointe puis taillée en croc : silhouette reconnaissable
    length = 3.1
    stations = [0.0, 0.1, 0.4, 1.2, 2.0, 2.45, 2.75, length]
    widths = [0.17, 0.24, 0.22, 0.2, 0.19, 0.2, 0.12, 0.0]
    thicks = [0.05, 0.06, 0.055, 0.05, 0.045, 0.04, 0.03, 0.0]
    points = [guard + a * st for st in stations]
    verts, faces = diamond_strip(points, widths, thicks, w, n)
    # Arête centrale sombre (t = 0), fil clair (t = 1) : deux tons lisibles de loin
    mb.add("sword", verts, faces, "bladeSteel", sword, grad=lambda v: 0.0 if abs((v - guard).dot(n)) > 0.004 else 1.0, smooth=False)
    for k in (1, -1):  # âme incandescente sur les deux faces, qui s'éteint vers la pointe
        core_s = [0.12, 0.8, 1.5, 2.1]
        core = [guard + a * st + n * k * (0.008 + 0.055 * (1 - st / length)) for st in core_s]
        verts, faces = diamond_strip(core, [0.045, 0.04, 0.028, 0.0], [0.01, 0.01, 0.008, 0.0], w, n)
        mb.add("sword", verts, faces, "emberSoft", sword, grad=lambda v: 1 - (v - guard).dot(a) / 2.1, smooth=False)
    # Garde : barre dorée, ailes en flammes (deux pointes par côté), gemme sertie
    verts, faces = tube([local(guard, -0.16, 0, 0), local(guard, 0.16, 0, 0)], [0.075, 0.075], segments=6)
    mb.add("sword", verts, faces, "gold", sword, grad=lambda _v: 0.7)
    for k in (1, -1):
        wing = bezier(local(guard, 0.1 * k, 0, 0), local(guard, 0.46 * k, 0, -0.04), local(guard, 0.5 * k, 0, 0.34), 4)
        verts, faces = tube(wing, [0.07, 0.055, 0.032, 0.006], segments=6)
        mb.add("sword", verts, faces, "gold", sword, grad=lambda v: 0.45 + 0.5 * max(0.0, (v - guard).dot(a)) / 0.34)
        prong = bezier(local(guard, 0.2 * k, 0, 0.02), local(guard, 0.32 * k, 0, 0.06), local(guard, 0.27 * k, 0, 0.26), 4)
        verts, faces = tube(prong, [0.04, 0.03, 0.016, 0.004], segments=5)
        mb.add("sword", verts, faces, "gold", sword, grad=lambda v: 0.5 + 0.45 * max(0.0, (v - guard).dot(a)) / 0.26)
        verts, faces = oriented_ellipsoid(local(guard, 0, 0.045 * k, 0.02), (0.11, 0.035, 0.11), rings=4, segments=8)
        mb.add("sword", verts, faces, "gold", sword, grad=lambda _v: 0.8)
        verts, faces = oriented_ellipsoid(local(guard, 0, 0.075 * k, 0.02), (0.065, 0.03, 0.065), rings=4, segments=8)
        mb.add("sword", verts, faces, "ember", sword, grad=lambda _v: 0.75)
    # Poignée de cuir, pommeau doré et pointe de braise
    verts, faces = tube([guard - a * 0.02, pommel + a * 0.05], [0.066, 0.062], segments=8)
    mb.add("sword", verts, faces, "leather", sword, grad=lambda v: 0.5)
    verts, faces = ellipsoid(pommel, (0.11, 0.11, 0.11), rings=5, segments=8)
    mb.add("sword", verts, faces, "gold", sword, grad="z")
    verts, faces = cone(pommel - a * 0.08, pommel - a * 0.24, 0.05, segments=4)
    mb.add("sword", verts, faces, "ember", sword, grad=lambda _v: 0.6, smooth=False)

    return mb


# --------------------------------------------------------------------------- #
# Matériau, validation, exports, rendus
# --------------------------------------------------------------------------- #


def build_material(color_image, emission_image, metal_image, rough_image):
    material = bpy.data.materials.new(NAME + "_Material")
    material.use_nodes = True
    nodes, links = material.node_tree.nodes, material.node_tree.links
    bsdf = nodes.get("Principled BSDF")
    color = nodes.new("ShaderNodeTexImage")
    color.image = color_image
    color.interpolation = "Linear"
    links.new(color.outputs["Color"], bsdf.inputs["Base Color"])
    for name, image, colorspace in (
        ("EmissionMap", emission_image, "sRGB"),
        ("MetalnessMap", metal_image, "Non-Color"),
        ("RoughnessMap", rough_image, "Non-Color"),
    ):
        node = nodes.new("ShaderNodeTexImage")
        node.name = name
        node.image = image
        node.image.colorspace_settings.name = colorspace
    bsdf.inputs["Emission Strength"].default_value = 4.0
    set_blender_maps(material, True)
    return material


BLENDER_MAPS = {"EmissionMap": "Emission Color", "MetalnessMap": "Metallic", "RoughnessMap": "Roughness"}


def set_blender_maps(material, enabled):
    """Le FBX destiné à Roblox ne porte que la couleur : émission, métal et rugosité
    restent dans Blender (dans Roblox : SurfaceAppearance, après validation)."""
    nodes, links = material.node_tree.nodes, material.node_tree.links
    bsdf = nodes.get("Principled BSDF")
    defaults = {"Emission Color": (0, 0, 0, 1), "Metallic": 0.0, "Roughness": 0.5}
    for node_name, socket_name in BLENDER_MAPS.items():
        socket = bsdf.inputs[socket_name]
        for link in list(socket.links):
            links.remove(link)
        if enabled:
            links.new(nodes[node_name].outputs["Color"], socket)
        else:
            socket.default_value = defaults[socket_name]


def validate(mesh_obj, rig, mb):
    mesh = mesh_obj.data
    triangles = sum(len(p.vertices) - 2 for p in mesh.polygons)
    influences, unweighted = 0, 0
    for v in mesh.vertices:
        count = sum(1 for g in v.groups if g.weight > 0)
        influences = max(influences, count)
        unweighted += count == 0
    zs = [v.co.z for v in mesh.vertices]
    xs = [v.co.x for v in mesh.vertices]
    ys = [v.co.y for v in mesh.vertices]
    production_bones = {name: (tuple(head), tuple(tail), parent) for name, (head, tail, parent) in BONES.items()}
    rig_bones = {
        b.name: (tuple(round(c, 5) for c in b.head_local), tuple(round(c, 5) for c in b.tail_local), b.parent.name if b.parent else None)
        for b in rig.data.bones
    }
    same_rig = all(
        name in rig_bones
        and all(abs(rig_bones[name][0][i] - head[i]) < 1e-4 and abs(rig_bones[name][1][i] - tail[i]) < 1e-4 for i in range(3))
        and rig_bones[name][2] == parent
        for name, (head, tail, parent) in production_bones.items()
    )
    report = {
        "blender": bpy.app.version_string,
        "model": NAME,
        "height": round(max(zs) - min(zs), 3),
        "minZ": round(min(zs), 3),
        "width": round(max(xs) - min(xs), 3),
        "depth": round(max(ys) - min(ys), 3),
        "vertices": len(mesh.vertices),
        "triangles": triangles,
        "trianglesByPart": dict(sorted(mb.parts.items(), key=lambda item: -item[1])),
        "bones": [b.name for b in rig.data.bones],
        "boneCount": len(rig.data.bones),
        "sameRigAsProduction": same_rig,
        "maxInfluencesPerVertex": influences,
        "unweightedVertices": unweighted,
        "materials": len(mesh_obj.material_slots),
        "texture": NAME + "_Palette.png",
        "textureSize": TEXTURE_SIZE,
        "swatches": len(SWATCH_ORDER),
        "animations": {name: {"frames": ANIMATIONS[name]["length"], "fps": FPS, "loop": ANIMATIONS[name].get("loop", False)} for name in ANIMATIONS},
        "budget": BUDGET,
    }
    checks = {
        "triangles": triangles <= BUDGET["maxTriangles"],
        "bones": len(rig.data.bones) <= BUDGET["maxBones"],
        "sameRigAsProduction": same_rig,
        "influences": influences <= BUDGET["maxInfluences"],
        "allVerticesWeighted": unweighted == 0,
        "feetOnGround": abs(min(zs)) < 0.05,
        "height": abs((max(zs) - min(zs)) - HEIGHT) < 0.6,
    }
    report["checks"] = checks
    report["valid"] = all(checks.values())
    return report


def export_model(rig, mesh_obj, material, out_dir):
    rig.animation_data.action = None
    for pb in rig.pose.bones:
        pb.location = (0, 0, 0)
        pb.rotation_euler = (0, 0, 0)
    set_blender_maps(material, False)
    base.select_only([rig, mesh_obj])
    files = {}
    fbx = os.path.join(out_dir, NAME + ".fbx")
    bpy.ops.export_scene.fbx(
        filepath=fbx,
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
    files["modelFbx"] = os.path.basename(fbx)
    glb = os.path.join(out_dir, NAME + ".glb")
    bpy.ops.export_scene.gltf(filepath=glb, export_format="GLB", use_selection=True, export_animations=False)
    files["modelGlb"] = os.path.basename(glb)
    set_blender_maps(material, True)
    return files


def main():
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    out_dir = os.path.abspath(argv[argv.index("--out") + 1] if "--out" in argv else os.path.join(HERE, "build"))
    os.makedirs(out_dir, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.scale_length = 1.0
    scene.render.fps = FPS

    color = build_image(NAME + "_Palette", SWATCHES, os.path.join(out_dir, NAME + "_Palette.png"))
    emission = build_image(NAME + "_Emission", EMISSION, os.path.join(out_dir, NAME + "_Emission.png"))
    metal = build_image(NAME + "_Metalness", METALNESS, os.path.join(out_dir, NAME + "_Metalness.png"))
    rough = build_image(NAME + "_Roughness", ROUGHNESS, os.path.join(out_dir, NAME + "_Roughness.png"))
    material = build_material(color, emission, metal, rough)
    rig = base.build_armature()  # mêmes os que la production
    mb = build_character()
    mesh_obj = mb.build(NAME + "_Mesh")
    mesh_obj.data.materials.append(material)
    mesh_obj.parent = rig
    modifier = mesh_obj.modifiers.new("Armature", "ARMATURE")
    modifier.object = rig
    base.build_actions(rig)  # mêmes animations que la production

    report = validate(mesh_obj, rig, mb)
    report["files"] = export_model(rig, mesh_obj, material, out_dir)
    camera = base.setup_render(out_dir)  # mêmes rendus de contrôle que la production
    report["renders"] = base.render_views(camera, rig, {name: bpy.data.actions["F001_Kael_" + name] for name in ANIMATIONS}, out_dir)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(out_dir, NAME + ".blend"))
    report["files"]["blend"] = NAME + ".blend"
    with open(os.path.join(out_dir, "kael_premium_report.json"), "w", encoding="utf-8") as handle:
        json.dump(report, handle, indent=2, ensure_ascii=False)
    print("[KaelPremium] Contrôles :", json.dumps(report["checks"]), "valide =", report["valid"])
    print("[KaelPremium] Triangles :", report["triangles"], "| sommets :", report["vertices"], "| hauteur :", report["height"])
    print("[KaelPremium] Par pièce :", json.dumps(report["trianglesByPart"]))


if __name__ == "__main__":
    main()
