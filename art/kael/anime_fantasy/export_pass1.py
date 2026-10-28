"""Exporte la passe 1 archivée en FBX Roblox, pour la comparer en jeu (Studio).

    blender -b art/kael/anime_fantasy/build/archive/F001_Kael_AF_pass1.blend --python art/kael/anime_fantasy/export_pass1.py

Mêmes options que kael_af_build.export ; le .blend archivé n'est pas enregistré.
Les objets sont renommés « F001_Kael_AF_P1 » pour ne pas se confondre avec la
passe 2 une fois importés.
"""

import os
import sys

import bpy

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import kael_af_materials as M  # noqa: E402

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "build", "archive", "F001_Kael_AF_pass1.fbx")

rig = next(o for o in bpy.data.objects if o.type == "ARMATURE")
mesh = next(o for o in bpy.data.objects if o.type == "MESH" and o.find_armature() == rig and not o.hide_render)
mat = mesh.data.materials[0]
rig.animation_data.action = None
for pb in rig.pose.bones:
    pb.location = (0, 0, 0)
    pb.rotation_euler = (0, 0, 0)
rig.name = "F001_Kael_AF_P1"
mesh.name = "F001_Kael_AF_P1_Mesh"
M.roblox_only(mat, True)
bpy.ops.object.select_all(action="DESELECT")
rig.select_set(True)
mesh.select_set(True)
bpy.context.view_layer.objects.active = rig
bpy.ops.export_scene.fbx(
    filepath=OUT,
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
print("EXPORTED", OUT, len(mesh.data.polygons))
