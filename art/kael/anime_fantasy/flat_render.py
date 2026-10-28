"""Rendu à plat de la texture cuite (contrôle de l'atlas), sans éclairage.

    blender -b art/kael/anime_fantasy/build/F001_Kael_AF.blend --python art/kael/anime_fantasy/flat_render.py -- <dossier>
"""
import bpy, sys
from mathutils import Vector
out = sys.argv[sys.argv.index("--") + 1]
s = bpy.context.scene
s.render.engine = "BLENDER_WORKBENCH"
s.display.shading.light = "FLAT"
s.display.shading.color_type = "TEXTURE"
s.render.resolution_x, s.render.resolution_y = 640, 800
w = bpy.data.worlds.new("W"); w.color = (0.05, 0.06, 0.1); s.world = w
cam = bpy.data.objects.new("C", bpy.data.cameras.new("C")); s.collection.objects.link(cam); s.camera = cam; cam.data.lens = 70
for name, loc, tgt, lens in (("front", (0, -17, 3.7), (0, 0, 3.6), 70), ("back", (0, 17, 3.7), (0, 0, 3.6), 70), ("face", (-1.0, -4.2, 6.5), (0, 0, 6.35), 85)):
    cam.data.lens = lens; cam.location = Vector(loc); cam.rotation_euler = (Vector(tgt) - cam.location).to_track_quat("-Z", "Y").to_euler()
    s.render.filepath = f"{out}/flat_{name}.png"; bpy.ops.render.render(write_still=True)
