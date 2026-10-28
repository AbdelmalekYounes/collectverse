"""Rendus « look-dev » Eevee identiques pour deux versions de Kael (avant / après).

    blender -b art/kael/build/F001_Kael.blend --python art/kael/premium/lookdev_render.py -- \
        --out art/kael/premium/build/lookdev --tag before
    blender -b art/kael/premium/build/F001_Kael_Premium.blend --python art/kael/premium/lookdev_render.py -- \
        --out art/kael/premium/build/lookdev --tag after

Même scène pour les deux fichiers : sol sombre, lumière principale chaude, contre-jour
cyan (couleurs de la Faille), caméra et cadrages identiques. Le .blend ouvert n'est
jamais enregistré (lecture seule). Produit :
  - <tag>_front / three_quarter / side / back .png (640 × 800) ;
  - <tag>_distance_front / three_quarter .png (96 × 120) : lisibilité à distance,
    à peu près la taille d'un combattant à l'écran sur mobile.

Ce sont des rendus de contrôle du modèle, pas une illustration finale.
"""

import math
import os
import sys

import bpy
from mathutils import Vector


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    out = argv[argv.index("--out") + 1] if "--out" in argv else "lookdev"
    tag = argv[argv.index("--tag") + 1] if "--tag" in argv else "render"
    return os.path.abspath(out), tag


def hex_rgb(value):
    value = value.lstrip("#")
    return tuple((int(value[i : i + 2], 16) / 255) ** 2.2 for i in (0, 2, 4))  # sRGB -> linéaire


def add_area(name, location, target, color, energy, size):
    data = bpy.data.lights.new(name, "AREA")
    data.color = hex_rgb(color)
    data.energy = energy
    data.size = size
    light = bpy.data.objects.new(name, data)
    bpy.context.scene.collection.objects.link(light)
    light.location = Vector(location)
    light.rotation_euler = (Vector(target) - light.location).to_track_quat("-Z", "Y").to_euler()
    return light


def setup_scene():
    scene = bpy.context.scene
    # Ne garder que le personnage (rig + maillage) : caméras et lumières du fichier retirées.
    for obj in list(scene.objects):
        if obj.type in {"CAMERA", "LIGHT"}:
            bpy.data.objects.remove(obj)
    rig = bpy.data.objects["F001_Kael"]
    if rig.animation_data:
        rig.animation_data.action = None
    for pb in rig.pose.bones:
        pb.location = (0, 0, 0)
        pb.rotation_euler = (0, 0, 0)

    scene.render.engine = "BLENDER_EEVEE_NEXT"
    scene.eevee.taa_render_samples = 64
    try:
        scene.eevee.use_raytracing = True
    except AttributeError:
        pass
    scene.render.film_transparent = False
    scene.view_settings.view_transform = "AgX"
    try:
        scene.view_settings.look = "AgX - Punchy"
    except TypeError:
        pass

    world = bpy.data.worlds.new("LookdevWorld")
    world.use_nodes = True
    background = world.node_tree.nodes["Background"]
    background.inputs["Color"].default_value = (*hex_rgb("#0E1224"), 1)
    background.inputs["Strength"].default_value = 0.6
    scene.world = world

    # Sol sombre qui reçoit les ombres
    bpy.ops.mesh.primitive_circle_add(vertices=48, radius=9, fill_type="NGON", location=(0, 0, 0))
    ground = bpy.context.active_object
    material = bpy.data.materials.new("LookdevGround")
    material.use_nodes = True
    bsdf = material.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*hex_rgb("#1A2038"), 1)
    bsdf.inputs["Roughness"].default_value = 0.55
    ground.data.materials.append(material)

    add_area("Key", (-5, -6, 8), (0, 0, 3.4), "#FFC8A0", 1400, 4)
    add_area("Rim", (4.5, 6, 6.5), (0, 0, 4), "#55D6FF", 1500, 3)
    add_area("Fill", (7, -4, 3), (0, 0, 3), "#8C96FF", 250, 5)

    # Halo : léger éclat sur les zones lumineuses (braises, reflets)
    scene.use_nodes = True
    tree = scene.node_tree
    for node in list(tree.nodes):
        tree.nodes.remove(node)
    layers = tree.nodes.new("CompositorNodeRLayers")
    glare = tree.nodes.new("CompositorNodeGlare")
    glare.glare_type = "FOG_GLOW"
    glare.quality = "HIGH"
    glare.threshold = 0.9
    glare.size = 7
    composite = tree.nodes.new("CompositorNodeComposite")
    tree.links.new(layers.outputs["Image"], glare.inputs["Image"])
    tree.links.new(glare.outputs["Image"], composite.inputs["Image"])

    camera_data = bpy.data.cameras.new("LookdevCamera")
    camera_data.lens = 70
    camera = bpy.data.objects.new("LookdevCamera", camera_data)
    scene.collection.objects.link(camera)
    scene.camera = camera
    scene.render.image_settings.file_format = "PNG"
    return camera


def aim(camera, location, target=(0, 0, 3.4)):
    camera.location = Vector(location)
    camera.rotation_euler = (Vector(target) - camera.location).to_track_quat("-Z", "Y").to_euler()


def render(path, width, height):
    scene = bpy.context.scene
    scene.render.resolution_x, scene.render.resolution_y = width, height
    scene.render.resolution_percentage = 100
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


def main():
    out_dir, tag = parse_args()
    os.makedirs(out_dir, exist_ok=True)
    camera = setup_scene()
    views = {
        "front": (0, -16, 3.6),
        "three_quarter": (-10, -12.5, 4.4),
        "side": (16, 0, 3.6),
        "back": (0, 16, 3.6),
    }
    for name, location in views.items():
        aim(camera, location)
        render(os.path.join(out_dir, f"{tag}_{name}.png"), 640, 800)
    # Lisibilité à distance : caméra de combat (légère plongée), très petite image
    for name, location in {"front": (0, -16, 6.5), "three_quarter": (-10, -12.5, 7.0)}.items():
        aim(camera, location, target=(0, 0, 3.3))
        render(os.path.join(out_dir, f"{tag}_distance_{name}.png"), 96, 120)
    if "--poses" in sys.argv:
        render_key_poses(camera, out_dir, tag)
    print("[Lookdev]", tag, "->", out_dir)


def render_key_poses(camera, out_dir, tag):
    """Chaque image-clé de chaque animation (contrôle des interpénétrations)."""
    rig = bpy.data.objects["F001_Kael"]
    scene = bpy.context.scene
    pose_dir = os.path.join(out_dir, f"{tag}_poses")
    os.makedirs(pose_dir, exist_ok=True)
    for action in sorted(bpy.data.actions, key=lambda a: a.name):
        if not action.name.startswith("F001_Kael_"):
            continue
        rig.animation_data.action = action
        frames = sorted({int(k.co.x) for curve in action.fcurves for k in curve.keyframe_points})
        for frame in frames:
            scene.frame_set(frame)
            for view, location in {"tq": (-11, -14, 5.2), "side": (16, 0, 4.0)}.items():
                aim(camera, location, target=(0, 0, 3.6))
                name = f"{action.name[len('F001_Kael_'):]}_{frame:02d}_{view}.png"
                render(os.path.join(pose_dir, name), 320, 400)
    rig.animation_data.action = None


if __name__ == "__main__":
    main()
