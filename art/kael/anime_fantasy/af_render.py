"""Rendus de Kael Anime Fantasy (et des anciennes versions, pour comparer).

    blender -b <fichier.blend> --python art/kael/anime_fantasy/af_render.py -- --out <dossier> --tag <nom> --mode <mode>

Modes :
  views     : face, trois quarts, profil, dos — éclairage commun « studio » (Eevee),
              identique pour toutes les versions comparées ;
  neutral   : mêmes vues, gris neutre sans texture ni effet, avec et sans fil de fer ;
  closeups  : visage, armure, épée, cape ;
  showcase  : présentation « anime fantasy » (contre-jours, braises, brume, halo) ;
  poses     : chaque image-clé des 7 animations ;
  combat    : vraie caméra de combat (Arena.luau), taille réelle PC et mobile,
              effets complets (émission + lumières de braise) et réduits (couleur seule),
              + masque de silhouette (contour façon Highlight ajouté sur la planche) ;
  lineup    : arène 5 contre 5 (Kael AF au centre des deux lignes, figurants V0.2.2),
              PC et mobile, positions des 10 plaques de vie.
Le .blend ouvert n'est jamais enregistré.
"""

import math
import os
import random
import sys

import bpy
from bpy_extras.object_utils import world_to_camera_view
from mathutils import Vector


def args():
    argv = sys.argv[sys.argv.index("--") + 1 :]
    get = lambda key, default=None: argv[argv.index(key) + 1] if key in argv else default
    return os.path.abspath(get("--out")), get("--tag", "af"), get("--mode", "views")


def srgb(value):
    value = value.lstrip("#")
    return tuple((int(value[i : i + 2], 16) / 255) ** 2.2 for i in (0, 2, 4))


def character_meshes():
    return [o for o in bpy.context.scene.objects if o.type == "MESH" and o.name.startswith("F001_Kael") and "LOD" not in o.name and not o.hide_render]


def clean_scene():
    scene = bpy.context.scene
    for obj in list(scene.objects):
        if obj.type in {"CAMERA", "LIGHT"}:
            bpy.data.objects.remove(obj)
    rig = bpy.data.objects["F001_Kael"]
    if rig.animation_data:
        rig.animation_data.action = None
    for pb in rig.pose.bones:
        pb.location = (0, 0, 0)
        pb.rotation_euler = (0, 0, 0)
        pb.rotation_mode = "XYZ"
    return rig


def area(name, location, target, color, energy, size):
    data = bpy.data.lights.new(name, "AREA")
    data.color, data.energy, data.size = srgb(color), energy, size
    light = bpy.data.objects.new(name, data)
    bpy.context.scene.collection.objects.link(light)
    light.location = Vector(location)
    light.rotation_euler = (Vector(target) - light.location).to_track_quat("-Z", "Y").to_euler()
    return light


def point(name, location, color, energy, radius=0.2):
    data = bpy.data.lights.new(name, "POINT")
    data.color, data.energy, data.shadow_soft_size = srgb(color), energy, radius
    light = bpy.data.objects.new(name, data)
    bpy.context.scene.collection.objects.link(light)
    light.location = Vector(location)
    return light


def studio(glare=True, world_strength=0.9):
    """Éclairage commun à toutes les versions : ciel doux (reflets du métal),
    lumière principale chaude, contre-jour cyan, débouchage froid, sol sombre."""
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE_NEXT"
    scene.eevee.taa_render_samples = 64
    try:
        scene.eevee.use_raytracing = True
    except AttributeError:
        pass
    scene.view_settings.view_transform = "AgX"
    try:
        scene.view_settings.look = "AgX - Punchy"
    except TypeError:
        pass
    world = bpy.data.worlds.new("Studio")
    world.use_nodes = True
    nodes, links = world.node_tree.nodes, world.node_tree.links
    sky = nodes.new("ShaderNodeTexGradient")
    coords = nodes.new("ShaderNodeTexCoord")
    sep = nodes.new("ShaderNodeSeparateXYZ")
    ramp = nodes.new("ShaderNodeValToRGB")
    links.new(coords.outputs["Generated"], sep.inputs[0])
    links.new(sep.outputs["Z"], ramp.inputs["Fac"])
    ramp.color_ramp.elements[0].color = (*srgb("#0B0E1C"), 1)
    ramp.color_ramp.elements[1].color = (*srgb("#4A5A86"), 1)
    links.new(ramp.outputs["Color"], nodes["Background"].inputs["Color"])
    nodes["Background"].inputs["Strength"].default_value = world_strength
    del sky
    scene.world = world
    bpy.ops.mesh.primitive_circle_add(vertices=64, radius=12, fill_type="NGON")
    ground = bpy.context.active_object
    mat = bpy.data.materials.new("Ground")
    mat.use_nodes = True
    mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (*srgb("#161A2C"), 1)
    mat.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.6
    ground.data.materials.append(mat)
    area("Key", (-5, -7, 8.5), (0, 0, 3.8), "#FFD2B0", 1500, 4)
    area("Rim", (4.5, 6.5, 7), (0, 0, 4.2), "#55D6FF", 1400, 3)
    area("Fill", (7, -5, 3), (0, 0, 3.5), "#8C9CFF", 350, 5)
    scene.use_nodes = True
    tree = scene.node_tree
    tree.nodes.clear()
    layers = tree.nodes.new("CompositorNodeRLayers")
    composite = tree.nodes.new("CompositorNodeComposite")
    if glare:
        g = tree.nodes.new("CompositorNodeGlare")
        g.glare_type, g.quality, g.threshold, g.size = "FOG_GLOW", "HIGH", 0.9, 7
        tree.links.new(layers.outputs["Image"], g.inputs["Image"])
        tree.links.new(g.outputs["Image"], composite.inputs["Image"])
    else:
        tree.links.new(layers.outputs["Image"], composite.inputs["Image"])
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    scene.collection.objects.link(cam)
    scene.camera = cam
    scene.render.image_settings.file_format = "PNG"
    return cam


def aim(cam, location, target, lens=70):
    cam.data.lens = lens
    cam.location = Vector(location)
    cam.rotation_euler = (Vector(target) - cam.location).to_track_quat("-Z", "Y").to_euler()


def render(path, w=640, h=800):
    scene = bpy.context.scene
    scene.render.resolution_x, scene.render.resolution_y, scene.render.resolution_percentage = w, h, 100
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


VIEWS = {
    "front": ((0, -18, 3.8), (0, 0, 3.7)),
    "three_quarter": ((-11.5, -14.5, 4.8), (0, 0, 3.7)),
    "side": ((18, 0, 3.8), (0, 0, 3.7)),
    "back": ((0, 18, 3.8), (0, 0, 3.7)),
    "three_quarter_back": ((11.5, 14.5, 4.8), (0, 0, 3.7)),
}


def views(out, tag):
    cam = studio()
    for name, (loc, target) in VIEWS.items():
        aim(cam, loc, target)
        render(os.path.join(out, f"{tag}_{name}.png"))


def neutral(out, tag):
    cam = studio(glare=False)
    grey = bpy.data.materials.new("Neutral")
    grey.use_nodes = True
    grey.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.55, 0.55, 0.58, 1)
    grey.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.6
    wire = bpy.data.materials.new("Wire")
    wire.use_nodes = True
    wire.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.02, 0.02, 0.03, 1)
    for mesh in character_meshes():
        for i in range(len(mesh.data.materials)):
            mesh.data.materials[i] = grey
    for name in ("front", "three_quarter", "side", "back"):
        loc, target = VIEWS[name]
        aim(cam, loc, target)
        render(os.path.join(out, f"{tag}_neutral_{name}.png"))
    for mesh in character_meshes():  # fil de fer par-dessus le gris
        copy = mesh.copy()
        copy.data = mesh.data.copy()
        bpy.context.scene.collection.objects.link(copy)
        mod = copy.modifiers.new("Wire", "WIREFRAME")
        mod.thickness = 0.006
        mod.use_replace = True
        mod.use_relative_offset = False
        bpy.context.view_layer.objects.active = copy
        bpy.ops.object.modifier_move_to_index(modifier="Wire", index=0)
        copy.data.materials.clear()
        copy.data.materials.append(wire)
    for name in ("front", "three_quarter"):
        loc, target = VIEWS[name]
        aim(cam, loc, target)
        render(os.path.join(out, f"{tag}_wire_{name}.png"))


def closeups(out, tag):
    cam = studio()
    shots = {
        "face": ((-0.7, -2.6, 6.55), (0, 0, 6.42), 85, (800, 800)),
        "armor": ((-1.6, -4.6, 5.0), (0, 0, 4.6), 70, (800, 800)),
        "sword": ((-4.6, -5.2, 3.0), (-1.55, -0.95, 1.95), 50, (800, 1000)),
        "cape": ((4.5, 7.5, 4.0), (0, 0.5, 3.3), 50, (800, 1000)),
    }
    for name, (loc, target, lens, (w, h)) in shots.items():
        aim(cam, loc, target, lens)
        render(os.path.join(out, f"{tag}_closeup_{name}.png"), w, h)


def showcase(out, tag):
    """Présentation : fond nuit, contre-jours, lumière de braise sur la lame, braises
    en suspension, brume. Personnage dans sa pose de repos (rig réel)."""
    scene = bpy.context.scene
    cam = studio(world_strength=0.35)
    for light in [o for o in scene.objects if o.type == "LIGHT"]:
        bpy.data.objects.remove(light)
    area("Key", (-4.5, -6.5, 7.5), (0, 0, 4.2), "#FFC08A", 1300, 3)
    area("RimCyan", (5, 5, 6.5), (0, 0, 4.5), "#45D8FF", 2400, 2.5)
    area("RimViolet", (-5, 5.5, 5), (0, 0, 4.3), "#9A6BFF", 1600, 2.5)
    area("Under", (0, -4, 0.4), (0, 0, 3.5), "#FF7A3A", 350, 2)
    rig = bpy.data.objects["F001_Kael"]
    hand = rig.pose.bones["RightHand"]
    blade_dir = Vector((0, -0.55, 1)).normalized()
    grip = (hand.bone.head_local + hand.bone.tail_local) / 2
    for t, energy in ((0.6, 500), (1.8, 350)):
        point(f"Blade{t}", grip + blade_dir * t + Vector((0, -0.3, 0)), "#FF8A3A", energy)
    point("Core", Vector((0, -0.8, 5.0)), "#FFB060", 120)
    world = scene.world
    scatter = world.node_tree.nodes.new("ShaderNodeVolumeScatter")
    scatter.inputs["Density"].default_value = 0.004
    world.node_tree.links.new(scatter.outputs["Volume"], world.node_tree.nodes["World Output"].inputs["Volume"])
    rng = random.Random(4)
    ember = bpy.data.materials.new("EmberFx")
    ember.use_nodes = True
    nodes = ember.node_tree.nodes
    nodes.clear()
    out_node = nodes.new("ShaderNodeOutputMaterial")
    emit = nodes.new("ShaderNodeEmission")
    emit.inputs["Color"].default_value = (*srgb("#FFA040"), 1)
    emit.inputs["Strength"].default_value = 18
    ember.node_tree.links.new(emit.outputs[0], out_node.inputs[0])
    verts, faces = [], []
    for _ in range(160):
        c = Vector((rng.uniform(-4, 4), rng.uniform(-2.5, 3.5), abs(rng.gauss(3.5, 2.2))))
        if (c - Vector((0, 0, 6.3))).length < 1.2:
            continue
        s = rng.uniform(0.01, 0.03)
        base = len(verts)
        verts += [c + Vector((s, 0, 0)), c + Vector((-s, 0, 0)), c + Vector((0, 0, s * 3)), c + Vector((0, 0, -s * 3)), c + Vector((0, s, 0))]
        faces += [[base, base + 2, base + 1], [base, base + 1, base + 3], [base + 4, base + 2, base], [base + 4, base, base + 3]]
    mesh = bpy.data.meshes.new("Embers")
    mesh.from_pydata([tuple(v) for v in verts], [], faces)
    obj = bpy.data.objects.new("Embers", mesh)
    scene.collection.objects.link(obj)
    obj.data.materials.append(ember)
    aim(cam, (-4.2, -12.5, 3.2), (0, 0, 4.0), 50)
    render(os.path.join(out, f"{tag}_showcase.png"), 1080, 1350)
    aim(cam, (7.5, -11, 3.6), (0, 0, 3.9), 50)
    render(os.path.join(out, f"{tag}_showcase_b.png"), 1080, 1350)


def poses(out, tag):
    cam = studio()
    rig = bpy.data.objects["F001_Kael"]
    scene = bpy.context.scene
    folder = os.path.join(out, f"{tag}_poses")
    os.makedirs(folder, exist_ok=True)
    for action in sorted(bpy.data.actions, key=lambda a: a.name):
        if not action.name.startswith("F001_Kael_"):
            continue
        rig.animation_data.action = action
        frames = sorted({int(k.co.x) for c in action.fcurves for k in c.keyframe_points})
        for frame in frames:
            scene.frame_set(frame)
            aim(cam, (-12, -15.5, 6.0), (0, 0, 4.0))
            render(os.path.join(folder, f"{action.name[len('F001_Kael_'):]}_{frame:02d}.png"), 360, 450)
    rig.animation_data.action = None


# Caméra de combat (Arena.luau / BattleLayout.luau), repère Roblox
FOV = 42
CAMERA = Vector((0, 32, 34))
TARGET = Vector((0, 0, -1))
SLOTS = {"ally": (Vector((0, 0, 4.5)), False), "enemy": (Vector((0, 0, -4.5)), True)}
SCREENS = {"pc": (1920, 1080), "mobile": (844, 390)}


def to_blender(v):
    return Vector((-v.x, v.z, v.y))


def relative(p, slot, turned):
    local = p - slot
    if turned:
        local = Vector((-local.x, local.y, -local.z))
    return to_blender(local)


def combat(out, tag):
    scene = bpy.context.scene
    cam = studio()
    cam.data.sensor_fit = "VERTICAL"
    bounds = []
    for mesh in character_meshes():
        bounds += [mesh.matrix_world @ Vector(c) for c in mesh.bound_box]
    rig = bpy.data.objects["F001_Kael"]
    hand = rig.pose.bones["RightHand"]
    lights = [point("FxBlade", (hand.bone.head_local + hand.bone.tail_local) / 2 + Vector((0, -0.5, 0.6)), "#FF7A3D", 160, 0.4), point("FxCore", Vector((0, -0.7, 5.0)), "#FFD27A", 60, 0.3)]
    emission_links = []
    for mesh in character_meshes():
        for mat in mesh.data.materials:
            if mat and mat.node_tree:
                bsdf = mat.node_tree.nodes.get("Principled BSDF")
                if bsdf:
                    emission_links.append((mat, bsdf, bsdf.inputs["Emission Strength"].default_value))
    for effects in ("full", "reduced"):
        for light in lights:
            light.hide_render = effects == "reduced"
        for mat, bsdf, strength in emission_links:
            bsdf.inputs["Emission Strength"].default_value = strength if effects == "full" else 0.0
        for slot_name, (slot, turned) in SLOTS.items():
            aim(cam, relative(CAMERA, slot, turned), relative(TARGET, slot, turned))
            for screen, (w, h) in SCREENS.items():
                scene.render.resolution_x, scene.render.resolution_y = w, h
                cam.data.angle_y = math.radians(FOV)
                bpy.context.view_layer.update()
                projected = [world_to_camera_view(scene, cam, p) for p in bounds]
                scene.render.use_border = scene.render.use_crop_to_border = True
                m = 0.01
                scene.render.border_min_x = max(0.0, min(p.x for p in projected) - m)
                scene.render.border_max_x = min(1.0, max(p.x for p in projected) + m)
                scene.render.border_min_y = max(0.0, min(p.y for p in projected) - m)
                scene.render.border_max_y = min(1.0, max(p.y for p in projected) + m)
                px = (max(p.y for p in projected) - min(p.y for p in projected)) * h
                print(f"[Combat] {tag} {effects} {slot_name} {screen} : {px:.0f} px")
                render(os.path.join(out, f"{tag}_combat_{effects}_{slot_name}_{screen}.png"), w, h)
                if effects == "full" and tag == "af":
                    render_mask(os.path.join(out, f"{tag}_combat_mask_{slot_name}_{screen}.png"), w, h, character_meshes())
                    scene.render.use_border = scene.render.use_crop_to_border = True
        if tag != "af":
            break  # anciennes versions : pas d'effets de braise à comparer


def render_mask(path, w, h, keep):
    """Masque du héros seul (alpha), pour simuler un Highlight Roblox (contour de
    silhouette en espace écran) sur la planche, sans tracer les pièces internes."""
    scene = bpy.context.scene
    saved = (scene.render.engine, scene.render.film_transparent, scene.render.use_border)
    hidden = []
    for obj in scene.objects:
        if obj.type in {"MESH", "CURVE"} and obj not in keep and not obj.hide_render:
            obj.hide_render = True
            hidden.append(obj)
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "FLAT"
    scene.display.shading.color_type = "SINGLE"
    scene.display.shading.single_color = (1, 1, 1)
    scene.render.film_transparent = True
    render(path, w, h)
    for obj in hidden:
        obj.hide_render = False
    scene.render.engine, scene.render.film_transparent, scene.render.use_border = saved


ARENA_ROWS = {"Front": ([-10, 0, 10], 4.5), "Back": ([-5, 5], 10)}


def lineup(out, tag):
    """Arène 5 contre 5 vue par la caméra du jeu : Kael AF au centre de la ligne
    avant des deux camps, l'ancien Kael (V0.2.2) comme figurant aux 8 autres places.
    Écrit aussi la position des 10 plaques (pixels) pour les dessiner sur la planche."""
    import json

    scene = bpy.context.scene
    cam = studio()
    cam.data.sensor_fit = "VERTICAL"
    sun = bpy.data.lights.new("ArenaSun", "SUN")
    sun.energy = 2.2
    sun.color = srgb("#FFE6D0")
    sun_obj = bpy.data.objects.new("ArenaSun", sun)
    scene.collection.objects.link(sun_obj)
    sun_obj.rotation_euler = (math.radians(50), 0, math.radians(200))
    hero = character_meshes()
    hero_height = max((m.matrix_world @ Vector(c)).z for m in hero for c in m.bound_box)
    legacy = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "build", "F001_Kael.blend")
    with bpy.data.libraries.load(legacy) as (src, dst):
        dst.objects = [n for n in src.objects if n == "F001_Kael_Mesh"]
    extra = dst.objects[0]
    extra.modifiers.clear()
    extra.parent = None
    extra_height = max(c[2] for c in extra.bound_box)
    slots = []
    for side, sign in (("Ally", 1), ("Enemy", -1)):
        for row, (xs, z) in ARENA_ROWS.items():
            for x in xs:
                slots.append((side, row, Vector((-x, z * sign, 0)), sign))
    for side, row, pos, sign in slots:
        is_hero = row == "Front" and pos.x == 0
        objs = hero if is_hero else [extra]
        for obj in objs:
            if is_hero and side == "Ally":
                inst = obj  # le vrai modèle reste en place (allié, centre)
                inst.location = pos
                continue
            inst = obj.copy()
            inst.parent = None
            inst.modifiers.clear()
            scene.collection.objects.link(inst)
            inst.matrix_world = obj.matrix_world.copy() if is_hero else inst.matrix_world
            inst.location = pos + (obj.matrix_world.translation if is_hero else Vector())
            inst.rotation_euler = (0, 0, math.pi if sign < 0 else 0)
    # Pads de l'arène (repères des emplacements)
    for side, row, pos, sign in slots:
        bpy.ops.mesh.primitive_cylinder_add(radius=2, depth=0.05, location=(pos.x, pos.y, 0.03))
        pad = bpy.context.active_object
        mat = bpy.data.materials.new("Pad")
        mat.use_nodes = True
        bsdf = mat.node_tree.nodes["Principled BSDF"]
        bsdf.inputs["Base Color"].default_value = (*srgb("#39CBE7" if sign > 0 else "#F36D79"), 1)
        bsdf.inputs["Emission Color"].default_value = (*srgb("#39CBE7" if sign > 0 else "#F36D79"), 1)
        bsdf.inputs["Emission Strength"].default_value = 0.6
        pad.data.materials.append(mat)
    eye = Vector((0, 34, 32))
    target = Vector((0, -1, 0))
    heroes = [o for o in scene.objects if o.type == "MESH" and o.data.name.startswith(hero[0].data.name)]
    for variant in ["plain"]:
        for screen, (w, h) in SCREENS.items():
            scene.render.resolution_x, scene.render.resolution_y = w, h
            aim(cam, eye, target)
            cam.data.angle_y = math.radians(FOV)
            scene.render.use_border = False
            bpy.context.view_layer.update()
            plates = []
            for side, row, pos, sign in slots:
                is_hero = row == "Front" and pos.x == 0
                height = hero_height if is_hero else extra_height
                center = Vector((pos.x, pos.y, height + 2.4))
                p = world_to_camera_view(scene, cam, center)
                depth = (center - cam.location).dot((target - eye).normalized())
                focal = (h / 2) / math.tan(math.radians(FOV) / 2)
                factor = min(1.0, max(0.35, h / 800))
                pw = focal * 4.4 / depth + 36 * factor
                ph = focal * 2.0 / depth + 10 * factor
                plates.append({"side": side, "hero": is_hero, "x": p.x * w, "y": (1 - p.y) * h, "w": pw, "h": ph})
            render(os.path.join(out, f"{tag}_lineup_{variant}_{screen}.png"), w, h)
            render_mask(os.path.join(out, f"{tag}_lineup_mask_{screen}.png"), w, h, heroes)
            with open(os.path.join(out, f"{tag}_lineup_{screen}_plates.json"), "w", encoding="utf-8") as handle:
                json.dump(plates, handle)
    print("[Lineup] hauteurs", round(hero_height, 2), round(extra_height, 2))


def main():
    out, tag, mode = args()
    os.makedirs(out, exist_ok=True)
    clean_scene()
    {"views": views, "neutral": neutral, "closeups": closeups, "showcase": showcase, "poses": poses, "combat": combat, "lineup": lineup}[mode](out, tag)
    print("[AFRender]", mode, tag, "->", out)


if __name__ == "__main__":
    main()
