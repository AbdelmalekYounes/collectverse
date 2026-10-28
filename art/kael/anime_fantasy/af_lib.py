"""Outils de modélisation procédurale pour Kael Anime Fantasy (Blender 4.2).

Chaque pièce est un objet Blender à part (maillage, matériau, poids), assemblé à la
fin en un seul maillage skinné. Techniques utilisées :
  - corps : modificateur Skin (squelette d'arêtes + rayons) puis subdivision ;
  - armure : coques paramétriques épaissies (solidify) aux arêtes biseautées (bevel),
    ou découpées dans la surface du corps puis décalées ;
  - cheveux : mèches en courbes de Bézier à profil lenticulaire, rayon décroissant ;
  - visage : décalques posés sur la tête par lancer de rayons (BVH).
"""

import math

import bmesh
import bpy
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree

# --------------------------------------------------------------------------- #
# Objets, matériaux, poids
# --------------------------------------------------------------------------- #


def link(obj):
    bpy.context.scene.collection.objects.link(obj)
    return obj


def material(name):
    mat = bpy.data.materials.get(name)
    if mat is None:
        mat = bpy.data.materials.new(name)
        mat.use_nodes = True
    return mat


def object_from_bmesh(name, bm, material_name, smooth=True, sharp_angle=None):
    mesh = bpy.data.meshes.new(name)
    bm.normal_update()
    bm.to_mesh(mesh)
    bm.free()
    for poly in mesh.polygons:
        poly.use_smooth = smooth
    if sharp_angle is not None:
        mesh.set_sharp_from_angle(angle=math.radians(sharp_angle))
    obj = link(bpy.data.objects.new(name, mesh))
    obj.data.materials.append(material(material_name))
    return obj


def object_from_data(name, verts, faces, material_name, smooth=True, sharp_angle=None, recalc=True):
    bm = bmesh.new()
    bverts = [bm.verts.new(v) for v in verts]
    for face in faces:
        try:
            bm.faces.new([bverts[i] for i in face])
        except ValueError:
            pass  # face dupliquée
    if recalc:
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return object_from_bmesh(name, bm, material_name, smooth, sharp_angle)


def set_weights(obj, fn):
    """fn(position monde) -> {os: poids}. Remplace les poids existants."""
    for group in list(obj.vertex_groups):
        obj.vertex_groups.remove(group)
    groups = {}
    matrix = obj.matrix_world
    for vertex in obj.data.vertices:
        for bone, weight in fn(matrix @ vertex.co).items():
            if weight <= 0:
                continue
            if bone not in groups:
                groups[bone] = obj.vertex_groups.new(name=bone)
            groups[bone].add([vertex.index], weight, "REPLACE")


def rigid(bone):
    return lambda _p: {bone: 1.0}


def segment_param(point, a, b):
    ab = b - a
    return max(0.0, min(1.0, (point - a).dot(ab) / max(ab.length_squared, 1e-9)))


def chain(points, bones, width=0.15):
    """Poids le long d'une chaîne d'os : fondu linéaire autour des articulations."""
    pts = [Vector(p) for p in points]

    def fn(v):
        best, best_dist, best_t = 0, math.inf, 0.0
        for i in range(len(bones)):
            t = segment_param(v, pts[i], pts[i + 1])
            dist = (v - pts[i].lerp(pts[i + 1], t)).length
            if dist < best_dist:
                best, best_dist, best_t = i, dist, t
        seg = (pts[best + 1] - pts[best]).length
        fade = width / max(seg, 1e-6)
        if best_t > 1 - fade and best + 1 < len(bones):
            share = (best_t - (1 - fade)) / (2 * fade)
            return {bones[best]: 1 - share, bones[best + 1]: share}
        if best_t < fade and best > 0:
            share = (fade - best_t) / (2 * fade)
            return {bones[best]: 1 - share, bones[best - 1]: share}
        return {bones[best]: 1.0}

    return fn


def apply_modifiers(obj):
    bpy.context.view_layer.objects.active = obj
    for modifier in list(obj.modifiers):
        bpy.ops.object.modifier_apply(modifier=modifier.name)


# --------------------------------------------------------------------------- #
# Primitives de base
# --------------------------------------------------------------------------- #


def basis(axis):
    axis = Vector(axis).normalized()
    helper = Vector((0, 0, 1)) if abs(axis.z) < 0.9 else Vector((1, 0, 0))
    side = axis.cross(helper).normalized()
    up = side.cross(axis).normalized()
    return side, up


def tube(path, radii, segments=8, caps=True, squash=1.0, twist=0.0):
    """Tube le long d'un chemin, sections orientées par transport parallèle."""
    path = [Vector(p) for p in path]
    verts, faces = [], []
    previous_side = None
    for i, p in enumerate(path):
        axis = (path[min(i + 1, len(path) - 1)] - path[max(i - 1, 0)]).normalized()
        side, up = basis(axis)
        if previous_side is not None:  # continuité des sections (pas de vrille)
            side = (previous_side - axis * previous_side.dot(axis)).normalized()
            up = side.cross(axis).normalized()
        previous_side = side
        for j in range(segments):
            a = 2 * math.pi * j / segments + twist
            verts.append(p + side * math.cos(a) * radii[i] + up * math.sin(a) * radii[i] * squash)
    for i in range(len(path) - 1):
        for j in range(segments):
            a = i * segments + j
            b = i * segments + (j + 1) % segments
            faces.append([a, b, b + segments, a + segments])
    if caps:
        start = len(verts)
        verts += [path[0], path[-1]]
        last = (len(path) - 1) * segments
        for j in range(segments):
            faces.append([start, (j + 1) % segments, j])
            faces.append([start + 1, last + j, last + (j + 1) % segments])
    return verts, faces


def bezier(points, steps):
    """Courbe de Bézier (n points de contrôle), échantillonnée."""
    pts = [Vector(p) for p in points]
    out = []
    for s in range(steps):
        t = s / (steps - 1)
        work = list(pts)
        while len(work) > 1:
            work = [work[k].lerp(work[k + 1], t) for k in range(len(work) - 1)]
        out.append(work[0])
    return out


def ellipsoid(center, radii, rings=8, segments=12):
    cx, cy, cz = center
    rx, ry, rz = radii
    verts = [Vector((cx, cy, cz + rz))]
    faces = []
    for r in range(1, rings):
        phi = math.pi * r / rings
        for s in range(segments):
            theta = 2 * math.pi * s / segments
            verts.append(Vector((cx + rx * math.sin(phi) * math.cos(theta), cy + ry * math.sin(phi) * math.sin(theta), cz + rz * math.cos(phi))))
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


# --------------------------------------------------------------------------- #
# Coques d'armure : surface paramétrique, épaisseur, arêtes biseautées
# --------------------------------------------------------------------------- #


def shell(name, surface, u_steps, v_steps, thickness, material_name, bevel=0.012, sharp_angle=35):
    """surface(u, v) -> Vector, u et v dans [0, 1]. Grille ouverte épaissie vers
    l'intérieur, arêtes vives biseautées (accroche de la lumière)."""
    bm = bmesh.new()
    grid = []
    for i in range(v_steps + 1):
        row = []
        for j in range(u_steps + 1):
            row.append(bm.verts.new(surface(j / u_steps, i / v_steps)))
        grid.append(row)
    for i in range(v_steps):
        for j in range(u_steps):
            bm.faces.new([grid[i][j], grid[i][j + 1], grid[i + 1][j + 1], grid[i + 1][j]])
    bm.normal_update()
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    result = bmesh.ops.solidify(bm, geom=bm.faces[:], thickness=thickness)
    del result
    bm.normal_update()
    if bevel > 0:
        edges = [e for e in bm.edges if e.is_manifold and e.calc_face_angle(0) > math.radians(60)]
        if edges:
            bmesh.ops.bevel(bm, geom=edges, offset=bevel, offset_type="OFFSET", segments=1, profile=0.5, affect="EDGES", clamp_overlap=True)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return object_from_bmesh(name, bm, material_name, smooth=True, sharp_angle=sharp_angle)


def solid(name, verts, faces, material_name, bevel=0.0, sharp_angle=35, smooth=True):
    """Volume fermé, arêtes vives biseautées."""
    bm = bmesh.new()
    bverts = [bm.verts.new(v) for v in verts]
    for face in faces:
        try:
            bm.faces.new([bverts[i] for i in face])
        except ValueError:
            pass
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.normal_update()
    if bevel > 0:
        edges = [e for e in bm.edges if e.is_manifold and e.calc_face_angle(0) > math.radians(50)]
        if edges:
            bmesh.ops.bevel(bm, geom=edges, offset=bevel, offset_type="OFFSET", segments=1, profile=0.5, affect="EDGES", clamp_overlap=True)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return object_from_bmesh(name, bm, material_name, smooth=smooth, sharp_angle=sharp_angle)


def boundary_loops(obj):
    """Bords libres d'un maillage ouvert, en listes de positions ordonnées."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    edges = [e for e in bm.edges if e.is_boundary]
    neighbours = {}
    for e in edges:
        a, b = e.verts
        neighbours.setdefault(a.index, []).append(b.index)
        neighbours.setdefault(b.index, []).append(a.index)
    coords = {v.index: obj.matrix_world @ v.co.copy() for v in bm.verts}
    bm.free()
    loops, seen = [], set()
    for start in neighbours:
        if start in seen:
            continue
        loop, current, previous = [start], start, None
        seen.add(start)
        while True:
            options = [n for n in neighbours[current] if n != previous and n not in seen]
            if not options:
                break
            previous, current = current, options[0]
            seen.add(current)
            loop.append(current)
        loops.append([coords[i] for i in loop])
    return loops


# --------------------------------------------------------------------------- #
# Décalques posés sur une surface (visage)
# --------------------------------------------------------------------------- #


def surface_bvh(obj):
    depsgraph = bpy.context.evaluated_depsgraph_get()
    return BVHTree.FromObject(obj, depsgraph)


def conform_grid(bvh, center, right, up, size_x, size_y, nx, ny, offset, direction):
    """Grille posée sur la surface par lancer de rayons, légèrement décollée.
    Renvoie (sommets, faces, uvs) ; UV (0..1) dans le plan du décalque."""
    direction = Vector(direction).normalized()
    verts, uvs, faces = [], [], []
    for i in range(ny + 1):
        for j in range(nx + 1):
            u, v = j / nx, i / ny
            point = Vector(center) + Vector(right) * (u - 0.5) * size_x + Vector(up) * (v - 0.5) * size_y
            origin = point - direction * 1.0
            hit = bvh.ray_cast(origin, direction, 3.0)
            if hit[0] is not None:
                verts.append(hit[0] - direction * offset)
            else:
                verts.append(point)
            uvs.append((u, v))
    for i in range(ny):
        for j in range(nx):
            a = i * (nx + 1) + j
            faces.append([a, a + 1, a + nx + 2, a + nx + 1])
    return verts, faces, uvs


def object_with_uv(name, verts, faces, uvs, material_name, smooth=True):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata([tuple(v) for v in verts], [], faces)
    mesh.update(calc_edges=True)
    layer = mesh.uv_layers.new(name="DecalUV")
    for poly in mesh.polygons:
        poly.use_smooth = smooth
        for loop_index in poly.loop_indices:
            layer.data[loop_index].uv = uvs[mesh.loops[loop_index].vertex_index]
    obj = link(bpy.data.objects.new(name, mesh))
    obj.data.materials.append(material(material_name))
    return obj


# --------------------------------------------------------------------------- #
# Mèches de cheveux : courbes à profil lenticulaire
# --------------------------------------------------------------------------- #

_profile = None


def hair_profile():
    """Profil plat et effilé (lentille) : mèche anime, pas un cône."""
    global _profile
    if _profile and _profile.name in bpy.data.objects:
        return _profile
    curve = bpy.data.curves.new("HairProfile", "CURVE")
    curve.dimensions = "2D"
    spline = curve.splines.new("POLY")
    pts = [(1.0, 0.0), (0.35, 0.32), (-0.35, 0.32), (-1.0, 0.0), (-0.35, -0.22), (0.35, -0.22)]
    spline.points.add(len(pts) - 1)
    for p, (x, y) in zip(spline.points, pts):
        p.co = (x, y, 0, 1)
    spline.use_cyclic_u = True
    _profile = link(bpy.data.objects.new("HairProfile", curve))
    _profile.hide_render = True
    return _profile


def hair_lock(name, points, width, tilt=0.0, resolution=3, material_name="Hair"):
    """Mèche : Bézier passant par `points`, largeur décroissante vers la pointe."""
    curve = bpy.data.curves.new(name, "CURVE")
    curve.dimensions = "3D"
    curve.resolution_u = resolution
    curve.bevel_mode = "OBJECT"
    curve.bevel_object = hair_profile()
    curve.use_fill_caps = True
    spline = curve.splines.new("BEZIER")
    spline.bezier_points.add(len(points) - 1)
    count = len(points)
    for k, (bp, p) in enumerate(zip(spline.bezier_points, points)):
        bp.co = Vector(p)
        bp.handle_left_type = bp.handle_right_type = "AUTO"
        t = k / (count - 1)
        bp.radius = width * (1 - t) ** 0.9 + 0.004
        bp.tilt = tilt
    obj = link(bpy.data.objects.new(name, curve))
    obj.data.materials.append(material(material_name))
    bpy.context.view_layer.update()
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.convert(target="MESH")
    obj = bpy.context.view_layer.objects.active
    for poly in obj.data.polygons:
        poly.use_smooth = True
    return obj


def lock_mesh(path, widths, center, thickness=0.38, profile=6):
    """Mèche en maillage à section contrôlée : large dans le sens du crâne
    (tangent), fine vers l'extérieur (normale depuis `center`). Renvoie
    (sommets, faces, t) avec t = 0 racine, 1 pointe pour chaque sommet."""
    path = [Vector(p) for p in path]
    lens = [(math.cos(math.tau * k / profile), math.sin(math.tau * k / profile)) for k in range(profile)]
    verts, faces, ts, across = [], [], [], []
    count = len(path)
    for i, p in enumerate(path):
        tangent = (path[min(i + 1, count - 1)] - path[max(i - 1, 0)]).normalized()
        out = p - Vector(center)
        out = (out - tangent * out.dot(tangent)).normalized()
        side = tangent.cross(out).normalized()
        w = widths[i]
        for cx, cy in lens:
            # lentille : bord vif sur les côtés, dos bombé vers l'extérieur
            bulge = thickness * (1.0 if cy > 0 else 0.55)
            verts.append(p + side * cx * w + out * cy * w * bulge)
            ts.append(i / (count - 1))
            across.append(abs(cx))  # 0 au centre de la mèche, 1 sur ses bords
    for i in range(count - 1):
        for k in range(profile):
            a = i * profile + k
            b = i * profile + (k + 1) % profile
            faces.append([a, b, b + profile, a + profile])
    root = len(verts)
    verts.append(path[0])
    ts.append(0.0)
    across.append(0.0)
    for k in range(profile):
        faces.append([root, (k + 1) % profile, k])
    return verts, faces, ts, across


# --------------------------------------------------------------------------- #
# Assemblage
# --------------------------------------------------------------------------- #


def join(objects, name):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    result = bpy.context.view_layer.objects.active
    result.name = name
    result.data.name = name
    return result


def triangles(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)
