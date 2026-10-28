"""Proposition d'illustration de carte pour Kael (V0.2.4) : rendu Blender Eevee.

    blender -b art/kael/premium/build/F001_Kael_Premium.blend --python art/kael/premium/card_render.py -- \
        --out art/kael/premium/build/card [--preview]

Mise en scène construite par le script à partir du modèle premium (le .blend source
n'est pas modifié ; la scène de l'illustration est enregistrée à part) :
  - pose héroïque (os du rig, lame levée en diagonale, poing gauche en avant) ;
  - lumière de braise sous la lame, contre-jour cyan et violet de la Faille ;
  - langues de feu autour de la lame, braises en suspension, anneau de la Faille ;
  - brume volumétrique, halo et vignettage au compositing.

Format portrait 1024 × 1280. La fenêtre d'illustration de CardTile (rapport 1,108,
ScaleType Crop) garde toute la largeur et la bande centrale de 924 px : tête, lame
et buste y sont cadrés. Le reste (pieds, pointe des flammes) n'est qu'un débord.

C'est une proposition de direction artistique (rendu 3D), pas une illustration peinte.
"""

import importlib.util
import math
import os
import random
import sys

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location("kael_build", os.path.join(HERE, "..", "kael_build.py"))
base = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(base)

WIDTH, HEIGHT = 1024, 1280
SEED = 7

# Pose héroïque, dans les axes du personnage (voir kael_build.py, ANIMATIONS).
HERO_POSE = {
    "HumanoidRootPart": (0, 0, 18),
    "LowerTorso": (0, 0, 0),
    "UpperTorso": (4, 0, -15),
    "Head": (-4, 0, 12),
    "RightUpperArm": (-30, -18, 0),
    "RightLowerArm": (-55, 0, 0),
    "LeftUpperArm": (-60, -25, 0),
    "LeftLowerArm": (-60, 0, 0),
    "LeftUpperLeg": (-22, -10, 0),
    "LeftLowerLeg": (28, 0, 0),
    "RightUpperLeg": (14, 12, 0),
    "RightLowerLeg": (10, 0, 0),
    "loc": (0, 0, -0.18),
}


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    out = argv[argv.index("--out") + 1] if "--out" in argv else os.path.join(HERE, "build", "card")
    return os.path.abspath(out), "--preview" in argv


def srgb(value, alpha=None):
    value = value.lstrip("#")
    rgb = tuple((int(value[i : i + 2], 16) / 255) ** 2.2 for i in (0, 2, 4))
    return (*rgb, alpha) if alpha is not None else rgb


def link(obj):
    bpy.context.scene.collection.objects.link(obj)
    return obj


def mesh_object(name, verts, faces, uvs=None, material=None):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata([tuple(v) for v in verts], [], faces)
    mesh.update(calc_edges=True)
    if uvs is not None:
        layer = mesh.uv_layers.new(name="UVMap")
        for poly in mesh.polygons:
            for loop_index in poly.loop_indices:
                layer.data[loop_index].uv = uvs[mesh.loops[loop_index].vertex_index]
    for poly in mesh.polygons:
        poly.use_smooth = True
    obj = link(bpy.data.objects.new(name, mesh))
    if material:
        obj.data.materials.append(material)
    return obj


def emission_material(name, color, strength):
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    nodes, links = material.node_tree.nodes, material.node_tree.links
    nodes.clear()
    out = nodes.new("ShaderNodeOutputMaterial")
    emit = nodes.new("ShaderNodeEmission")
    emit.inputs["Color"].default_value = srgb(color, 1)
    emit.inputs["Strength"].default_value = strength
    links.new(emit.outputs["Emission"], out.inputs["Surface"])
    return material


def gradient_flame_material(name, stops, strength, fade_start=0.35):
    """Émission le long de V (0 base, 1 pointe), transparente vers la pointe et sur les bords."""
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    try:
        material.surface_render_method = "BLENDED"
    except AttributeError:
        material.blend_method = "BLEND"
    nodes, links = material.node_tree.nodes, material.node_tree.links
    nodes.clear()
    out = nodes.new("ShaderNodeOutputMaterial")
    uv = nodes.new("ShaderNodeUVMap")
    sep = nodes.new("ShaderNodeSeparateXYZ")
    links.new(uv.outputs["UV"], sep.inputs["Vector"])
    color_ramp = nodes.new("ShaderNodeValToRGB")
    elements = color_ramp.color_ramp.elements
    elements[0].position, elements[0].color = stops[0][0], srgb(stops[0][1], 1)
    elements[1].position, elements[1].color = stops[-1][0], srgb(stops[-1][1], 1)
    for position, color in stops[1:-1]:
        element = elements.new(position)
        element.color = srgb(color, 1)
    links.new(sep.outputs["Y"], color_ramp.inputs["Fac"])
    alpha_ramp = nodes.new("ShaderNodeValToRGB")
    a = alpha_ramp.color_ramp.elements
    a[0].position, a[0].color = fade_start, (1, 1, 1, 1)
    a[1].position, a[1].color = 1.0, (0, 0, 0, 1)
    links.new(sep.outputs["Y"], alpha_ramp.inputs["Fac"])
    # Bords plus transparents : facteur de Fresnel inversé
    layer = nodes.new("ShaderNodeLayerWeight")
    layer.inputs["Blend"].default_value = 0.45
    invert = nodes.new("ShaderNodeInvert")
    links.new(layer.outputs["Facing"], invert.inputs["Color"])
    multiply = nodes.new("ShaderNodeMath")
    multiply.operation = "MULTIPLY"
    links.new(alpha_ramp.outputs["Color"], multiply.inputs[0])
    links.new(invert.outputs["Color"], multiply.inputs[1])
    emit = nodes.new("ShaderNodeEmission")
    emit.inputs["Strength"].default_value = strength
    links.new(color_ramp.outputs["Color"], emit.inputs["Color"])
    transparent = nodes.new("ShaderNodeBsdfTransparent")
    mix = nodes.new("ShaderNodeMixShader")
    links.new(multiply.outputs["Value"], mix.inputs["Fac"])
    links.new(transparent.outputs["BSDF"], mix.inputs[1])
    links.new(emit.outputs["Emission"], mix.inputs[2])
    links.new(mix.outputs["Shader"], out.inputs["Surface"])
    return material


# --------------------------------------------------------------------------- #
# Pose
# --------------------------------------------------------------------------- #


def apply_pose(rig):
    if rig.animation_data:
        rig.animation_data.action = None
    for pb in rig.pose.bones:
        pb.rotation_mode = "XYZ"
        pb.location = (0, 0, 0)
        pb.rotation_euler = (0, 0, 0)
    for name, value in HERO_POSE.items():
        if name == "loc":
            pb = rig.pose.bones["HumanoidRootPart"]
            pb.location = pb.bone.matrix_local.to_3x3().inverted() @ Vector(value)
            continue
        pb = rig.pose.bones[name]
        pb.rotation_euler = base.local_rotation(pb, value, pb.rotation_euler)
    bpy.context.view_layer.update()


def posed_point(rig, bone_name, rest_point):
    """Position d'un point rigide d'un os (repos) après la pose."""
    pb = rig.pose.bones[bone_name]
    return pb.matrix @ pb.bone.matrix_local.inverted() @ Vector(rest_point)


def sword_axis(rig):
    grip = base.bone_point("RightHand", False).lerp(base.bone_point("RightHand", True), 0.55)
    a = Vector((0, -0.55, 1)).normalized()
    guard = grip + a * 0.3
    tip = guard + a * 3.0
    return posed_point(rig, "RightHand", guard), posed_point(rig, "RightHand", tip)


# --------------------------------------------------------------------------- #
# Effets : flammes, braises, Faille
# --------------------------------------------------------------------------- #


def flame_tongue(root, direction, length, radius, curl, rng, segments=8, steps=9):
    """Langue de feu : tube effilé et ondulé ; UV v = 0 à la base, 1 à la pointe."""
    direction = Vector(direction).normalized()
    helper = Vector((0, 0, 1)) if abs(direction.z) < 0.9 else Vector((1, 0, 0))
    side = direction.cross(helper).normalized()
    up = side.cross(direction).normalized()
    phase = rng.uniform(0, math.tau)
    verts, faces, uvs = [], [], []
    for i in range(steps):
        t = i / (steps - 1)
        wiggle = math.sin(phase + t * 5.0) * curl * t
        center = Vector(root) + direction * length * t + side * wiggle + Vector((0, 0, 0.6 * length * t * t))
        r = radius * (1 - t) ** 0.8 * (0.7 + 0.3 * math.sin(phase + t * 9))
        for j in range(segments):
            angle = math.tau * j / segments
            verts.append(center + side * math.cos(angle) * r + up * math.sin(angle) * r)
            uvs.append((j / segments, t))
    for i in range(steps - 1):
        for j in range(segments):
            a = i * segments + j
            b = i * segments + (j + 1) % segments
            faces.append([a, b, b + segments, a + segments])
    return verts, faces, uvs


def build_flames(rig, rng):
    guard, tip = sword_axis(rig)
    blade = tip - guard
    core = gradient_flame_material("FlameCore", [(0, "#FFF6D0"), (0.25, "#FFD060"), (0.6, "#FF7A2A"), (1, "#C8260E")], 9.0)
    outer = gradient_flame_material("FlameOuter", [(0, "#FFB040"), (0.4, "#FF5A1A"), (1, "#7A1006")], 3.0, fade_start=0.1)
    verts, faces, uvs = [], [], []
    overs, ofaces, ouvs = [], [], []
    for k in range(14):  # le long de la lame
        t = 0.08 + 0.85 * k / 13
        root = guard + blade * t + Vector((rng.uniform(-0.08, 0.08), rng.uniform(-0.08, 0.08), 0))
        direction = Vector((rng.uniform(-0.25, 0.25), rng.uniform(-0.2, 0.25), 1)) + blade.normalized() * 0.4
        v, f, u = flame_tongue(root, direction, rng.uniform(0.7, 1.4) * (1.1 - 0.4 * t), rng.uniform(0.09, 0.15), rng.uniform(0.08, 0.2), rng)
        base_index = len(verts)
        verts += v
        uvs += u
        faces += [[base_index + i for i in face] for face in f]
        v, f, u = flame_tongue(root, direction, rng.uniform(1.1, 2.0), rng.uniform(0.18, 0.28), rng.uniform(0.15, 0.3), rng)
        if k % 2:  # flammes extérieures une fois sur deux : la lame reste visible
            continue
        base_index = len(overs)
        overs += v
        ouvs += u
        ofaces += [[base_index + i for i in face] for face in f]
    mesh_object("FlamesCore", verts, faces, uvs, core)
    mesh_object("FlamesOuter", overs, ofaces, ouvs, outer)
    # Lumière de braise portée par la lame
    for t, energy in ((0.25, 900), (0.7, 600)):
        data = bpy.data.lights.new(f"Blade{t}", "POINT")
        data.color = srgb("#FF8A3A")
        data.energy = energy
        data.shadow_soft_size = 0.4
        light = link(bpy.data.objects.new(f"Blade{t}", data))
        light.location = guard + blade * t + Vector((0, -0.3, 0))


def build_embers(rig, rng, count=210):
    bright = emission_material("EmberBright", "#FFC060", 24)
    dim = emission_material("EmberDim", "#FF6A2A", 10)
    guard, tip = sword_axis(rig)
    head = posed_point(rig, "Head", (0, -0.02, 5.45))
    for material, n in ((bright, count // 3), (dim, count - count // 3)):
        verts, faces = [], []
        for _ in range(n):
            if rng.random() < 0.45:  # autour de la lame
                center = guard.lerp(tip, rng.random()) + Vector((rng.gauss(0, 0.9), rng.gauss(0, 0.8), rng.gauss(0.6, 1.0)))
            else:  # dans tout le cadre, plus dense en bas
                center = Vector((rng.uniform(-5, 5), rng.uniform(-3, 4), abs(rng.gauss(2.5, 2.4))))
            # Pas de braise devant le visage ni entre la caméra et le buste
            if (center - head).length < 1.3 or (center.y < -1.2 and abs(center.x) < 2.2 and 1.8 < center.z < 6.5):
                continue
            size = rng.uniform(0.008, 0.03)
            stretch = Vector((rng.uniform(-0.2, 0.2), rng.uniform(-0.1, 0.1), 1)).normalized() * size * rng.uniform(1.5, 3)
            v, f = base.ellipsoid(tuple(center), (size, size, size), rings=3, segments=4)
            v = [p + stretch * ((p - center).z / max(size, 1e-6)) for p in v]  # traînée verticale
            index = len(verts)
            verts += v
            faces += [[index + i for i in face] for face in f]
        mesh_object("Embers", verts, faces, None, material)


def build_rift():
    ring = emission_material("RiftRing", "#4FE0FF", 6)
    inner = gradient_flame_material("RiftVeil", [(0, "#7A4BFF"), (0.5, "#3AA8FF"), (1, "#10204A")], 0.7, fade_start=0.0)
    bpy.ops.mesh.primitive_torus_add(major_radius=4.6, minor_radius=0.07, major_segments=96, minor_segments=8, location=(1.2, 7.5, 5.7), rotation=(math.radians(78), math.radians(8), 0))
    torus = bpy.context.active_object
    torus.data.materials.append(ring)
    bpy.ops.mesh.primitive_torus_add(major_radius=4.95, minor_radius=0.025, major_segments=96, minor_segments=6, location=(1.2, 7.55, 5.7), rotation=(math.radians(78), math.radians(8), 0))
    bpy.context.active_object.data.materials.append(emission_material("RiftRing2", "#B07AFF", 5))
    # Voile intérieur : disque dont V va du centre (0) au bord (1)
    segments, rings = 64, 10
    verts, faces, uvs = [], [], []
    for r in range(rings + 1):
        for s in range(segments):
            angle = math.tau * s / segments
            radius = 4.6 * r / rings
            verts.append(Vector((math.cos(angle) * radius, math.sin(angle) * radius, 0)))
            uvs.append((s / segments, 1 - r / rings))
    for r in range(rings):
        for s in range(segments):
            a = r * segments + s
            b = r * segments + (s + 1) % segments
            faces.append([a, b, b + segments, a + segments])
    veil = mesh_object("RiftVeil", verts, faces, uvs, inner)
    veil.location = (1.2, 7.6, 5.7)
    veil.rotation_euler = (math.radians(78), math.radians(8), 0)


def build_ground():
    bpy.ops.mesh.primitive_circle_add(vertices=96, radius=30, fill_type="NGON", location=(0, 0, 0))
    ground = bpy.context.active_object
    material = bpy.data.materials.new("CardGround")
    material.use_nodes = True
    bsdf = material.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = srgb("#0C1022", 1)
    bsdf.inputs["Roughness"].default_value = 0.25
    bsdf.inputs["Metallic"].default_value = 0.3
    ground.data.materials.append(material)
    # Onde de braise sous les pieds
    glow = gradient_flame_material("GroundGlow", [(0, "#FF7A2A"), (0.6, "#B02A0E"), (1, "#300804")], 2.5, fade_start=0.0)
    segments, rings = 64, 6
    verts, faces, uvs = [], [], []
    for r in range(rings + 1):
        for s in range(segments):
            angle = math.tau * s / segments
            radius = 3.2 * r / rings
            verts.append(Vector((math.cos(angle) * radius, math.sin(angle) * radius * 0.8, 0.01)))
            uvs.append((s / segments, r / rings))
    for r in range(rings):
        for s in range(segments):
            a = r * segments + s
            b = r * segments + (s + 1) % segments
            faces.append([a, b, b + segments, a + segments])
    mesh_object("GroundGlow", verts, faces, uvs, glow)


# --------------------------------------------------------------------------- #
# Scène, lumière, caméra, compositing
# --------------------------------------------------------------------------- #


def area(name, location, target, color, energy, size):
    data = bpy.data.lights.new(name, "AREA")
    data.color = srgb(color)
    data.energy = energy
    data.size = size
    light = link(bpy.data.objects.new(name, data))
    light.location = Vector(location)
    light.rotation_euler = (Vector(target) - light.location).to_track_quat("-Z", "Y").to_euler()


def setup(preview):
    scene = bpy.context.scene
    for obj in list(scene.objects):
        if obj.type in {"CAMERA", "LIGHT"}:
            bpy.data.objects.remove(obj)
    scene.render.engine = "BLENDER_EEVEE_NEXT"
    scene.eevee.taa_render_samples = 24 if preview else 128
    try:
        scene.eevee.use_raytracing = True
        scene.eevee.volumetric_tile_size = "4"
        scene.eevee.volumetric_end = 40
    except (AttributeError, TypeError):
        pass
    scene.render.resolution_x, scene.render.resolution_y = WIDTH, HEIGHT
    scene.render.resolution_percentage = 50 if preview else 100
    scene.view_settings.view_transform = "AgX"
    try:
        scene.view_settings.look = "AgX - Punchy"
    except TypeError:
        pass
    world = bpy.data.worlds.new("CardWorld")
    world.use_nodes = True
    nodes, links = world.node_tree.nodes, world.node_tree.links
    nodes["Background"].inputs["Color"].default_value = srgb("#0A0C1C", 1)
    nodes["Background"].inputs["Strength"].default_value = 0.5
    scatter = nodes.new("ShaderNodeVolumeScatter")
    scatter.inputs["Color"].default_value = srgb("#9AA8FF", 1)
    scatter.inputs["Density"].default_value = 0.018
    links.new(scatter.outputs["Volume"], nodes["World Output"].inputs["Volume"])
    scene.world = world

    area("Key", (-4.5, -7, 6.5), (0, 0, 3.8), "#FFC08A", 1500, 3)
    area("RimCyan", (5, 5, 6), (0, 0, 4.2), "#45D8FF", 2600, 2.5)
    area("RimViolet", (-5, 5.5, 5), (0, 0, 4), "#9A6BFF", 1800, 2.5)
    area("Under", (0.5, -4, 0.4), (0, 0, 3.2), "#FF7A3A", 450, 2)

    camera_data = bpy.data.cameras.new("CardCamera")
    camera_data.lens = 40
    camera_data.dof.use_dof = True
    camera_data.dof.focus_distance = 11.2
    camera_data.dof.aperture_fstop = 4.0
    camera = link(bpy.data.objects.new("CardCamera", camera_data))
    camera.location = Vector((-3.0, -10.8, 2.6))
    camera.rotation_euler = (Vector((0.0, 0, 4.35)) - camera.location).to_track_quat("-Z", "Y").to_euler()
    scene.camera = camera

    scene.use_nodes = True
    tree = scene.node_tree
    tree.nodes.clear()
    layers = tree.nodes.new("CompositorNodeRLayers")
    glare = tree.nodes.new("CompositorNodeGlare")
    glare.glare_type = "FOG_GLOW"
    glare.quality = "HIGH"
    glare.threshold = 0.7
    glare.size = 8
    tree.links.new(layers.outputs["Image"], glare.inputs["Image"])
    # Vignettage : masque elliptique flouté, multiplié
    mask = tree.nodes.new("CompositorNodeEllipseMask")
    mask.width, mask.height = 0.95, 0.85
    blur = tree.nodes.new("CompositorNodeBlur")
    blur.filter_type = "FAST_GAUSS"
    blur.use_relative = True
    blur.factor_x = blur.factor_y = 30
    tree.links.new(mask.outputs["Mask"], blur.inputs["Image"])
    mix = tree.nodes.new("CompositorNodeMixRGB")
    mix.blend_type = "MULTIPLY"
    mix.inputs["Fac"].default_value = 0.55
    tree.links.new(glare.outputs["Image"], mix.inputs[1])
    tree.links.new(blur.outputs["Image"], mix.inputs[2])
    composite = tree.nodes.new("CompositorNodeComposite")
    tree.links.new(mix.outputs["Image"], composite.inputs["Image"])
    scene.render.image_settings.file_format = "PNG"
    return scene


def main():
    out_dir, preview = parse_args()
    os.makedirs(out_dir, exist_ok=True)
    rng = random.Random(SEED)
    rig = bpy.data.objects["F001_Kael"]
    scene = setup(preview)
    apply_pose(rig)
    build_ground()
    build_rift()
    build_flames(rig, rng)
    build_embers(rig, rng)
    name = "F001_Kael_card_preview.png" if preview else "F001_Kael_card_proposal.png"
    scene.render.filepath = os.path.join(out_dir, name)
    bpy.ops.render.render(write_still=True)
    if not preview:
        bpy.ops.wm.save_as_mainfile(filepath=os.path.join(out_dir, "F001_Kael_Card.blend"), copy=True)
    print("[KaelCard]", os.path.join(out_dir, name))


if __name__ == "__main__":
    main()
