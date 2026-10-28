"""Réimporte le FBX exporté dans un Blender vierge et vérifie ce que Roblox recevra.

    blender -b --factory-startup --python art/kael/anime_fantasy/fbx_check.py -- <fichier.fbx>
"""
import json
import sys

import bpy

path = sys.argv[sys.argv.index("--") + 1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.fbx(filepath=path)
rigs = [o for o in bpy.context.scene.objects if o.type == "ARMATURE"]
meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
mesh = meshes[0]
influences = max(sum(1 for g in v.groups if g.weight > 0) for v in mesh.data.vertices)
images = [i.name for i in bpy.data.images if i.has_data or i.packed_file]
zs = [(mesh.matrix_world @ v.co) for v in mesh.data.vertices]
report = {
    "file": path.split("\\")[-1].split("/")[-1],
    "armatures": len(rigs),
    "bones": len(rigs[0].data.bones) if rigs else 0,
    "boneNames": [b.name for b in rigs[0].data.bones] if rigs else [],
    "meshes": len(meshes),
    "skinned": any(m.type == "ARMATURE" for m in mesh.modifiers),
    "vertexGroups": len(mesh.vertex_groups),
    "maxInfluences": influences,
    "triangles": sum(len(p.vertices) - 2 for p in mesh.data.polygons),
    "materials": len(mesh.data.materials),
    "uvLayers": [l.name for l in mesh.data.uv_layers],
    "embeddedTextures": images,
    "heightAfterImport": round(max(p.z for p in zs) - min(p.z for p in zs), 3),
}
print("[FBXCheck]", json.dumps(report, ensure_ascii=False))
