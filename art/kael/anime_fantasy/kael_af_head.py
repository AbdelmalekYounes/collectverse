"""Cheveux et visage de Kael Anime Fantasy.

Cheveux : calotte qui suit le crâne + mèches en courbes de Bézier à profil plat
(lentille), en couches : frange, mèches latérales, couronne balayée vers l'arrière
et le haut, pointes arrière, nuque. Chaque mèche porte un paramètre de longueur
(UV « SrcUV », v = 0 racine, 1 pointe) pour le dégradé rouge sombre → orange.

Visage : décalques (yeux, sourcils, bouche) posés sur la tête par lancer de rayons,
texturés par les images peintes (paint_textures.py), cuits ensuite dans l'atlas.
"""

import math

import bmesh
import bpy
from mathutils import Vector

import af_lib as L

HEAD_CENTER = Vector((0, 0.02, 6.43))
SCALP = (0.345, 0.375, 0.5)  # un peu plus grand que la tête


def scalp_point(az_deg, el_deg, inset=0.02):
    """Point du cuir chevelu. az : 0 = avant (-Y), 90 = gauche (+X) ; el : élévation."""
    az, el = math.radians(az_deg), math.radians(el_deg)
    d = Vector((math.sin(az) * math.cos(el), -math.cos(az) * math.cos(el), math.sin(el)))
    p = HEAD_CENTER + Vector((d.x * SCALP[0], d.y * SCALP[1], d.z * SCALP[2]))
    return p - d * inset, d


def hairline(az_deg):
    """Élévation de la ligne des cheveux selon l'azimut (front haut, nuque basse)."""
    a = abs(((az_deg + 180) % 360) - 180)  # 0 avant, 180 arrière
    if a < 60:
        return 32 - a * 0.25
    if a < 120:
        return 17 - (a - 60) * 0.45
    return -10 - (a - 120) * 0.25


def build_cap():
    verts, faces = L.ellipsoid(HEAD_CENTER, (SCALP[0] - 0.012, SCALP[1] - 0.012, SCALP[2] - 0.015), rings=11, segments=18)
    keep = []
    for v in verts:
        d = v - HEAD_CENTER
        az = math.degrees(math.atan2(d.x, -d.y))
        el = math.degrees(math.asin(max(-1, min(1, d.z / (SCALP[2] - 0.015)))))
        keep.append(el >= hairline(az) - 4)
    faces = [f for f in faces if all(keep[i] for i in f)]
    cap = L.object_from_data("HairCap", verts, faces, "Hair", recalc=False)
    bm = bmesh.new()
    bm.from_mesh(cap.data)
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    for face in bm.faces:  # normales vers l'extérieur
        if face.normal.dot(face.calc_center_median() - HEAD_CENTER) < 0:
            face.normal_flip()
    bm.to_mesh(cap.data)
    bm.free()
    set_strand_uv(cap, lambda p: 0.08)
    return cap


def set_strand_uv(obj, t_fn):
    layer = obj.data.uv_layers.get("SrcUV") or obj.data.uv_layers.new(name="SrcUV")
    for poly in obj.data.polygons:
        for li in poly.loop_indices:
            co = obj.matrix_world @ obj.data.vertices[obj.data.loops[li].vertex_index].co
            layer.data[li].uv = (0.5, t_fn(co))


# (azimut, élévation, longueur, largeur, direction (x, y, z) dans le repère tête, courbure)
# direction : x vers la gauche du personnage, y vers l'arrière, z vers le haut.
_FRONT = [
    # Frange : tombe sur le front jusqu'aux sourcils, sans couvrir les yeux
    (-30, 52, 0.36, 0.12, (-0.45, -0.55, -0.7), 0.05),
    (-8, 56, 0.4, 0.13, (-0.15, -0.6, -0.78), 0.06),
    (14, 56, 0.38, 0.13, (0.2, -0.6, -0.78), 0.06),
    (34, 52, 0.34, 0.11, (0.5, -0.55, -0.7), 0.05),
]
_SYMMETRIC = [
    # Mèches latérales
    (75, 22, 0.6, 0.11, (0.2, -0.2, -1.0), 0.04),
    (100, 15, 0.55, 0.12, (0.4, 0.3, -0.85), 0.05),
    # Couronne balayée vers l'arrière et le haut
    (28, 60, 0.72, 0.2, (0.35, 0.65, 0.68), -0.06),
    (42, 52, 0.5, 0.1, (0.6, 0.55, 0.55), -0.04),
    (55, 45, 0.68, 0.19, (0.75, 0.45, 0.5), -0.06),
    # Arrière
    (150, 50, 0.72, 0.21, (0.35, 0.85, 0.4), -0.06),
    (120, 35, 0.65, 0.2, (0.7, 0.6, 0.2), -0.05),
    (165, 15, 0.65, 0.2, (0.25, 0.9, -0.05), -0.05),
    # Nuque
    (160, -12, 0.42, 0.14, (0.25, 0.5, -0.85), 0.03),
]
_CENTER = [
    (0, 65, 0.75, 0.22, (0.0, 0.7, 0.7), -0.05),
    (0, 85, 0.6, 0.18, (0.0, 0.85, 0.5), -0.05),
    # Sous-mèches (passe 2) : couches intermédiaires, séparation et relief
    (-12, 70, 0.55, 0.1, (-0.15, 0.7, 0.62), -0.04),
    (165, 30, 0.6, 0.11, (0.15, 0.9, 0.3), -0.05),
    (-165, 30, 0.6, 0.11, (-0.15, 0.9, 0.3), -0.05),
    (180, 45, 0.75, 0.22, (0.0, 0.95, 0.3), -0.06),
    (180, -8, 0.45, 0.16, (0.0, 0.5, -0.85), 0.03),
]
LOCKS = _FRONT + _CENTER + _SYMMETRIC + [(-az, el, length, width, (-d[0], d[1], d[2]), curl) for az, el, length, width, d, curl in _SYMMETRIC]


def push_outside(p, margin=1.06):
    d = p - HEAD_CENTER
    value = (d.x / SCALP[0]) ** 2 + (d.y / SCALP[1]) ** 2 + (d.z / SCALP[2]) ** 2
    if value < margin * margin:
        return HEAD_CENTER + d * (margin / math.sqrt(max(value, 1e-6)))
    return p


def build_hair():
    objects = [build_cap()]
    for k, (az, el, length, width, direction, curl) in enumerate(LOCKS):
        root, normal = scalp_point(az, el, inset=0.03)
        d = Vector(direction).normalized()
        tangent = d - normal * d.dot(normal)
        tangent = tangent.normalized() if tangent.length > 1e-3 else d
        side = tangent.cross(normal).normalized()
        # Couchée sur le crâne au départ, puis se détache vers sa direction
        c1 = root + tangent * length * 0.32 + normal * 0.05
        c2 = root + tangent * length * 0.62 + d * length * 0.12 + normal * 0.1
        tip = root + (tangent * 0.55 + d * 0.45).normalized() * length + side * curl
        path = L.bezier([root, c1, c2, tip], 7)
        path = [path[0]] + [push_outside(p) for p in path[1:]]
        widths = [width * (1 - i / 6) ** 0.85 * (1 + 0.25 * math.sin(math.pi * i / 6)) + 0.004 for i in range(7)]
        verts, faces, ts, across = L.lock_mesh(path, widths, HEAD_CENTER, thickness=0.36, profile=5)
        lock = L.object_from_data(f"Lock{k}", verts, faces, "Hair")
        layer = lock.data.uv_layers.new(name="SrcUV")
        for poly in lock.data.polygons:
            for li in poly.loop_indices:
                vi = lock.data.loops[li].vertex_index
                # u : position en travers (bords assombris = séparation des mèches), v : racine → pointe
                layer.data[li].uv = (across[vi], 0.25 + 0.75 * ts[vi])
        objects.append(lock)
    return objects


# --------------------------------------------------------------------------- #
# Visage : décalques
# --------------------------------------------------------------------------- #


def flip_if_inward(obj, outward):
    mesh = obj.data
    normal = sum((p.normal for p in mesh.polygons), Vector())
    if normal.dot(Vector(outward)) < 0:
        bm = bmesh.new()
        bm.from_mesh(mesh)
        bmesh.ops.reverse_faces(bm, faces=bm.faces, flip_multires=False)
        bm.to_mesh(mesh)
        bm.free()


def build_face(head):
    bvh = L.surface_bvh(head)
    decals = []
    specs = [
        # (nom, centre, largeur, hauteur, matériau, miroir)
        ("EyeL", (0.112, 0, 6.42), 0.17, 0.106, "Eye", False),
        ("EyeR", (-0.112, 0, 6.42), 0.17, 0.106, "Eye", True),
        ("BrowL", (0.12, 0, 6.53), 0.17, 0.055, "Brow", False),
        ("BrowR", (-0.12, 0, 6.53), 0.17, 0.055, "Brow", True),
        ("Mouth", (0.0, 0, 6.12), 0.1, 0.038, "Mouth", False),
    ]
    for name, center, width, height, mat, mirror in specs:
        right = Vector((-1, 0, 0)) if mirror else Vector((1, 0, 0))
        verts, faces, uvs = L.conform_grid(bvh, Vector(center), right, Vector((0, 0, 1)), width, height, 8, 5, 0.004, (0, 1, 0))
        obj = L.object_with_uv(name, verts, faces, uvs, mat)
        flip_if_inward(obj, (0, -1, 0))
        decals.append(obj)
    return decals
