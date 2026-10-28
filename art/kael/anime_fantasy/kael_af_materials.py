"""Matières de Kael Anime Fantasy et cuisson de l'atlas (Cycles, GPU si disponible).

Chaque matière source est un shader procédural (Cycles) :
  - « lumière peinte » : dégradé selon l'orientation de la surface (lumière haute
    et avant), pour que le volume se lise même sous l'éclairage plat de Roblox ;
  - reflets d'arête (courbure « pointiness ») sur le métal et l'or ;
  - fissures de braise (Voronoi, distance aux bords) sur l'armure rouge ;
  - textures peintes (yeux, sourcils, bouche, cape, lame) par leurs UV sources.
Tout est ensuite cuit dans un atlas unique (UV « AtlasUV ») :
  couleur, émission, rugosité, métal, normales (biseaux du shader) et occlusion.
"""

import math
import os

import bpy
import numpy as np

LIGHT = (-0.35, -0.45, 0.82)  # lumière peinte (haut, avant, gauche de l'image)

# Rampe de couleur par matière : (position, couleur hex)
RAMPS = {
    "ArmorRed": [(0.0, "#200405"), (0.45, "#560C0A"), (0.78, "#861C12"), (0.93, "#B23620"), (1.0, "#DE6A48")],
    "ArmorDark": [(0.0, "#100304"), (0.5, "#2A0708"), (0.85, "#48100C"), (1.0, "#7E2E20")],
    "Gold": [(0.0, "#4A2A0C"), (0.4, "#9A6626"), (0.75, "#E0A848"), (0.92, "#FFE090"), (1.0, "#FFF6D8")],
    # Passe 3 : sous-armure noir chaud (lue bleu marine sous l'ambiance violette du
    # jeu), cuir plus clair et plus chaud, peau moins rose.
    "Under": [(0.0, "#0E0807"), (0.5, "#221312"), (0.85, "#3A221E"), (1.0, "#583631")],
    "Leather": [(0.0, "#1E0E07"), (0.5, "#4A2410"), (0.85, "#764420"), (1.0, "#A06838")],
    "Skin": [(0.0, "#946050"), (0.4, "#C99476"), (0.8, "#E4BA9A"), (1.0, "#F2D4BC")],
    "Cloth": [(0.0, "#260408"), (0.6, "#5E0E16"), (1.0, "#8E1C26")],
    "CapeInner": [(0.0, "#0E0306"), (0.7, "#26080C"), (1.0, "#3A1016")],
    "Ember": [(0.0, "#C8300A"), (0.5, "#FF6A1A"), (0.85, "#FFB040"), (1.0, "#FFF0B0")],
}
HAIR_RAMP = [(0.0, "#3E0604"), (0.3, "#8A140A"), (0.55, "#C42814"), (0.8, "#F05420"), (0.93, "#FF9030"), (1.0, "#FFC868")]
METAL = {"ArmorRed": 0.6, "ArmorDark": 0.55, "Gold": 0.9, "Blade": 0.85}
ROUGH = {"ArmorRed": 0.42, "ArmorDark": 0.48, "Gold": 0.3, "Blade": 0.26, "Under": 0.8, "Leather": 0.62, "Skin": 0.55,
         "Cloth": 0.9, "Cape": 0.88, "CapeInner": 0.92, "Hair": 0.42, "Ember": 0.3, "Eye": 0.2, "Brow": 0.6, "Mouth": 0.5}
EMBER_CRACKS = {"ArmorRed": 0.71, "ArmorDark": 0.8}  # seuil du masque (plus haut = plus rare)
EMIT_WEIGHT = 0.9  # poids de l'émission cuite dans la couleur Roblox


def srgb(value):
    value = value.lstrip("#")
    return tuple((int(value[i : i + 2], 16) / 255) ** 2.2 for i in (0, 2, 4)) + (1.0,)


class Graph:
    def __init__(self, mat):
        mat.use_nodes = True
        self.tree = mat.node_tree
        self.nodes, self.links = self.tree.nodes, self.tree.links
        self.nodes.clear()
        self.out = self.node("ShaderNodeOutputMaterial")
        self.bsdf = self.node("ShaderNodeBsdfPrincipled")
        self.link(self.bsdf, "BSDF", self.out, "Surface")

    def node(self, kind, **props):
        n = self.nodes.new(kind)
        for key, value in props.items():
            setattr(n, key, value)
        return n

    def link(self, a, a_out, b, b_in):
        self.links.new(a.outputs[a_out], b.inputs[b_in])

    def math(self, op, a=None, b=None, va=None, vb=None, clamp=False):
        n = self.node("ShaderNodeMath", operation=op, use_clamp=clamp)
        for index, (src, val) in enumerate(((a, va), (b, vb))):
            if src is not None:
                self.links.new(src, n.inputs[index])
            elif val is not None:
                n.inputs[index].default_value = val
        return n.outputs[0]

    def ramp(self, fac, stops):
        n = self.node("ShaderNodeValToRGB")
        elements = n.color_ramp.elements
        elements[0].position, elements[0].color = stops[0][0], srgb(stops[0][1])
        elements[1].position, elements[1].color = stops[-1][0], srgb(stops[-1][1])
        for position, color in stops[1:-1]:
            e = elements.new(position)
            e.color = srgb(color)
        self.links.new(fac, n.inputs["Fac"])
        return n.outputs["Color"]

    def mix(self, fac, a, b, blend="MIX"):
        n = self.node("ShaderNodeMix", data_type="RGBA", blend_type=blend)
        if isinstance(fac, float):
            n.inputs[0].default_value = fac
        else:
            self.links.new(fac, n.inputs[0])
        for socket, value in ((6, a), (7, b)):
            if isinstance(value, tuple):
                n.inputs[socket].default_value = value
            else:
                self.links.new(value, n.inputs[socket])
        return n.outputs[2]

    def light(self):
        """Facteur de lumière peinte (0 à 1) selon la normale."""
        geo = self.node("ShaderNodeNewGeometry")
        dot = self.node("ShaderNodeVectorMath", operation="DOT_PRODUCT")
        self.links.new(geo.outputs["Normal"], dot.inputs[0])
        length = math.sqrt(sum(c * c for c in LIGHT))
        dot.inputs[1].default_value = tuple(c / length for c in LIGHT)
        return self.remap(dot.outputs["Value"], -1, 1)

    def remap(self, value, a, b, c=0.0, d=1.0):
        n = self.node("ShaderNodeMapRange", clamp=True)
        self.links.new(value, n.inputs["Value"])
        n.inputs["From Min"].default_value, n.inputs["From Max"].default_value = a, b
        n.inputs["To Min"].default_value, n.inputs["To Max"].default_value = c, d
        return n.outputs["Result"]

    def edges(self, lo=0.57, hi=0.7):
        geo = self.node("ShaderNodeNewGeometry")
        return self.remap(geo.outputs["Pointiness"], lo, hi)

    def uv(self, name):
        n = self.node("ShaderNodeUVMap", uv_map=name)
        return n.outputs["UV"]

    def image(self, path, uv_name, alpha=False):
        n = self.node("ShaderNodeTexImage")
        n.image = bpy.data.images.load(path, check_existing=True)
        n.extension = "CLIP" if alpha else "EXTEND"
        self.links.new(self.uv(uv_name), n.inputs["Vector"])
        return n

    def finish(self, color, rough, metal=0.0, emission=None, strength=3.0, bevel=0.012):
        self.links.new(color, self.bsdf.inputs["Base Color"])
        self.bsdf.inputs["Roughness"].default_value = rough
        self.bsdf.inputs["Metallic"].default_value = metal
        if emission is not None:
            self.links.new(emission, self.bsdf.inputs["Emission Color"])
            self.bsdf.inputs["Emission Strength"].default_value = strength
        if bevel:
            b = self.node("ShaderNodeBevel", samples=8)
            b.inputs["Radius"].default_value = bevel
            self.links.new(b.outputs["Normal"], self.bsdf.inputs["Normal"])


# Traits du visage peints sur la tête par projection frontale (pas de géométrie
# de décalque : aucune couture, aucun triangle en plus).
# (texture, centre x, centre z, largeur, hauteur, miroir)
FACE_FEATURES = [
    ("eye", 0.115, 6.41, 0.19, 0.125, False),
    ("eye", -0.115, 6.41, 0.19, 0.125, True),
    ("brow", 0.12, 6.53, 0.17, 0.055, False),
    ("brow", -0.12, 6.53, 0.17, 0.055, True),
    ("mouth", 0.0, 6.12, 0.1, 0.038, False),
    ("nose", 0.0, 6.33, 0.14, 0.2, False),
]


def paint_face(g, color, textures):
    coords = g.node("ShaderNodeTexCoord").outputs["Object"]
    sep = g.node("ShaderNodeSeparateXYZ")
    g.links.new(coords, sep.inputs[0])
    front = g.remap(sep.outputs["Y"], -0.12, -0.2)  # face avant de la tête seulement
    for key, cx, cz, width, height, mirror in FACE_FEATURES:
        u = g.math("MULTIPLY", g.math("SUBTRACT", sep.outputs["X"], None, vb=cx), None, vb=(-1 if mirror else 1) / width)
        u = g.math("ADD", u, None, vb=0.5)
        v = g.math("ADD", g.math("MULTIPLY", g.math("SUBTRACT", sep.outputs["Z"], None, vb=cz), None, vb=1 / height), None, vb=0.5)
        vec = g.node("ShaderNodeCombineXYZ")
        g.links.new(u, vec.inputs[0])
        g.links.new(v, vec.inputs[1])
        tex = g.node("ShaderNodeTexImage", extension="CLIP")
        tex.image = bpy.data.images.load(textures[key], check_existing=True)
        g.links.new(vec.outputs[0], tex.inputs["Vector"])
        color = g.mix(g.math("MULTIPLY", tex.outputs["Alpha"], front), color, tex.outputs["Color"])
    return color


def back_lift(g, color, amount, tint="#FFFFFF"):
    """Contre-jour peint : éclaircit doucement les surfaces tournées vers l'arrière
    et le haut (silhouette lisible de dos, sans dépendre de l'éclairage du jeu)."""
    geo = g.node("ShaderNodeNewGeometry")
    dot = g.node("ShaderNodeVectorMath", operation="DOT_PRODUCT")
    g.links.new(geo.outputs["Normal"], dot.inputs[0])
    dot.inputs[1].default_value = (0.0, 0.7071, 0.7071)
    lift = g.math("MULTIPLY", g.remap(dot.outputs["Value"], 0.35, 1.0), None, vb=amount)
    return g.mix(lift, color, srgb(tint), "SCREEN")  # teinté : la matière garde sa couleur


def engraving(g, color, textures, strength):
    """Ornements gravés : motif doré répétable (filigree.png) projeté en boîte sur
    l'armure, présent par zones (bruit large), plus marqué sur le plastron."""
    coords = g.node("ShaderNodeTexCoord").outputs["Object"]
    mapping = g.node("ShaderNodeMapping")
    mapping.inputs["Scale"].default_value = (0.95, 0.95, 0.95)
    g.links.new(coords, mapping.inputs["Vector"])
    tex = g.node("ShaderNodeTexImage", projection="BOX", projection_blend=0.25, extension="REPEAT")
    tex.image = bpy.data.images.load(textures["filigree"], check_existing=True)
    g.links.new(mapping.outputs["Vector"], tex.inputs["Vector"])
    # Zones choisies (passe 2) : plastron autour du cristal, dômes des épaulières
    sep = g.node("ShaderNodeSeparateXYZ")
    g.links.new(coords, sep.inputs[0])
    chest = g.math("MULTIPLY", g.math("MULTIPLY", g.remap(sep.outputs["Z"], 4.62, 4.75), g.remap(sep.outputs["Z"], 5.4, 5.28)), g.remap(sep.outputs["Y"], -0.1, -0.25))
    side = g.math("ABSOLUTE", sep.outputs["X"])
    shoulders = g.math("MULTIPLY", g.remap(side, 0.7, 0.8), g.remap(sep.outputs["Z"], 5.25, 5.4))
    mask = g.math("MAXIMUM", chest, shoulders)
    amount = g.math("MULTIPLY", g.math("MULTIPLY", tex.outputs["Alpha"], mask), None, vb=strength)
    return g.mix(amount, color, srgb("#B8862E"))


def ember_cracks(g, threshold):
    """Fissures de braise : bords de cellules Voronoi, masquées par un bruit large."""
    coords = g.node("ShaderNodeTexCoord").outputs["Object"]
    vor = g.node("ShaderNodeTexVoronoi", feature="DISTANCE_TO_EDGE")
    vor.inputs["Scale"].default_value = 7.0
    g.links.new(coords, vor.inputs["Vector"])
    line = g.remap(vor.outputs["Distance"], 0.0, 0.012, 1.0, 0.0)
    noise = g.node("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 2.2
    noise.inputs["Detail"].default_value = 3.0
    g.links.new(coords, noise.inputs["Vector"])
    mask = g.remap(noise.outputs["Fac"], threshold, threshold + 0.06)
    return g.math("MULTIPLY", line, mask)


def build_source_materials(textures):
    for name in list(RAMPS) + ["Hair", "Cape", "Blade", "Face"]:
        mat = bpy.data.materials.get(name)
        if mat is None:
            continue
        g = Graph(mat)
        light = g.light()
        rough = ROUGH.get(name, 0.5)
        metal = METAL.get(name, 0.0)
        if name in ("ArmorRed", "ArmorDark", "Gold"):
            color = g.ramp(light, RAMPS[name])
            edge = g.edges()
            color = g.mix(g.math("MULTIPLY", edge, None, vb=0.28), color, srgb("#F08A68") if name != "Gold" else srgb("#FFF0C8"))
            if name != "Gold":
                color = engraving(g, color, textures, 0.6 if name == "ArmorRed" else 0.45)
            color = back_lift(g, color, 0.1, "#C03A24")
            emission = None
            if name in EMBER_CRACKS:
                crack = ember_cracks(g, EMBER_CRACKS[name])
                color = g.mix(crack, color, srgb("#FF8A2A"))
                emission = g.mix(crack, (0, 0, 0, 1), srgb("#FF6A1A"))
            g.finish(color, rough, metal, emission, 4.0)
        elif name in ("Under", "Leather", "Cloth", "CapeInner", "Skin"):
            color = g.ramp(light, RAMPS[name])
            if name != "Skin":  # trame de tissu / grain de cuir
                noise = g.node("ShaderNodeTexNoise")
                noise.inputs["Scale"].default_value = 60.0
                color = g.mix(0.12, color, noise.outputs["Color"], "OVERLAY")
            if name in ("Under", "CapeInner"):
                color = back_lift(g, color, 0.12, "#5A3A34")
            g.finish(color, rough, metal, bevel=0.0 if name == "Skin" else 0.008)
        elif name == "Ember":
            color = g.ramp(light, RAMPS[name])
            g.finish(color, rough, 0.0, color, 4.0, bevel=0.0)
        elif name == "Hair":
            uv = g.node("ShaderNodeSeparateXYZ")
            g.links.new(g.uv("SrcUV"), uv.inputs[0])
            base = g.ramp(uv.outputs["Y"], HAIR_RAMP)
            shade = g.remap(light, 0.0, 1.0, 0.45, 1.15)
            shade_color = g.node("ShaderNodeCombineColor")
            for i in range(3):
                g.links.new(shade, shade_color.inputs[i])
            color = g.mix(1.0, base, shade_color.outputs[0], "MULTIPLY")
            # Reflet anime : bande claire sur les surfaces les plus éclairées
            sheen = g.math("MULTIPLY", g.remap(light, 0.8, 0.86), g.remap(light, 0.93, 0.97, 1.0, 0.0))
            color = g.mix(g.math("MULTIPLY", sheen, None, vb=0.35), color, srgb("#FFB070"))
            # Relief et séparation des mèches : bords sombres, arête claire
            edge = g.remap(uv.outputs["X"], 0.45, 1.0)
            color = g.mix(g.math("MULTIPLY", edge, None, vb=0.55), color, srgb("#2A0504"), "MULTIPLY")
            ridge = g.math("MULTIPLY", g.remap(uv.outputs["X"], 0.25, 0.0), g.remap(light, 0.55, 0.9))
            color = g.mix(g.math("MULTIPLY", ridge, None, vb=0.25), color, srgb("#FF9A50"))
            color = back_lift(g, color, 0.12, "#FF6A30")
            g.finish(color, rough, 0.0, bevel=0.0)
        elif name == "Cape":
            tex = g.image(textures["cape"], "SrcUV")
            shade = g.remap(light, 0.0, 1.0, 0.55, 1.1)
            shade_color = g.node("ShaderNodeCombineColor")
            for i in range(3):
                g.links.new(shade, shade_color.inputs[i])
            color = g.mix(1.0, tex.outputs["Color"], shade_color.outputs[0], "MULTIPLY")
            color = back_lift(g, color, 0.12, "#B02A30")
            sep = g.node("ShaderNodeSeparateXYZ")
            g.links.new(g.uv("SrcUV"), sep.inputs[0])
            hem = g.remap(sep.outputs["Y"], 0.22, 0.0)  # v = 1 au col, 0 à l'ourlet
            emission = g.mix(g.math("MULTIPLY", hem, None, vb=0.85), (0, 0, 0, 1), tex.outputs["Color"])
            g.finish(color, rough, 0.0, emission, 2.0, bevel=0.0)
        elif name == "Blade":
            tex = g.image(textures["blade"], "SrcUV")
            shade = g.remap(light, 0.0, 1.0, 0.6, 1.2)
            shade_color = g.node("ShaderNodeCombineColor")
            for i in range(3):
                g.links.new(shade, shade_color.inputs[i])
            color = g.mix(1.0, tex.outputs["Color"], shade_color.outputs[0], "MULTIPLY")
            sep = g.node("ShaderNodeSeparateXYZ")
            g.links.new(g.uv("SrcUV"), sep.inputs[0])
            # Âme et fissures incandescentes peintes (blade_emit.png), intensité contrôlée
            emit = g.image(textures["blade_emit"], "SrcUV")
            g.finish(color, rough, METAL["Blade"], emit.outputs["Color"], 2.5, bevel=0.0)
        else:  # « Face » : peau + traits peints par projection frontale
            color = paint_face(g, g.ramp(light, RAMPS["Skin"]), textures)
            g.finish(color, ROUGH["Skin"], 0.0, bevel=0.0)


# --------------------------------------------------------------------------- #
# Atlas : UV et cuisson
# --------------------------------------------------------------------------- #

UV_IMPORTANCE = {"Face": 12.0, "Skin": 2.0, "Blade": 1.5, "Hair": 1.2, "Ember": 1.3, "Gold": 1.1}


def atlas_uv(obj, size=1024):
    mesh = obj.data
    mesh.uv_layers.new(name="AtlasUV")
    # La nouvelle couche copie la couche active : on la rend active ET de rendu
    # (dépliage, cuisson et export l'utilisent), puis on la relit par son nom.
    mesh.uv_layers.active_index = len(mesh.uv_layers) - 1
    atlas = mesh.uv_layers["AtlasUV"]
    atlas.active_render = True
    assert mesh.uv_layers.active.name == "AtlasUV"
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(72), island_margin=0.002, area_weight=0.0, correct_aspect=True, scale_to_bounds=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    # Plus de pixels pour le visage, les yeux, la lame : agrandit leurs îlots avant le rangement.
    # Relire la couche après le mode édition (l'ancienne référence pointe vers des données périmées).
    atlas = mesh.uv_layers["AtlasUV"]
    names = [m.name for m in mesh.materials]
    for poly in mesh.polygons:
        factor = UV_IMPORTANCE.get(names[poly.material_index], 1.0)
        if factor != 1.0:
            for li in poly.loop_indices:
                atlas.data[li].uv = (atlas.data[li].uv[0] * factor, atlas.data[li].uv[1] * factor)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.context.scene.tool_settings.use_uv_select_sync = True
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.pack_islands(rotate=True, margin=0.004)
    bpy.ops.object.mode_set(mode="OBJECT")
    atlas = mesh.uv_layers["AtlasUV"]
    assert mesh.uv_layers.active.name == "AtlasUV"
    return atlas


def new_image(name, size, non_color):
    image = bpy.data.images.get(name) or bpy.data.images.new(name, size, size, alpha=False, float_buffer=False)
    image.colorspace_settings.name = "Non-Color" if non_color else "sRGB"
    return image


def set_targets(obj, image):
    for mat in obj.data.materials:
        nodes = mat.node_tree.nodes
        node = nodes.get("BakeTarget") or nodes.new("ShaderNodeTexImage")
        node.name = "BakeTarget"
        node.image = image
        for n in nodes:
            n.select = False
        node.select = True
        nodes.active = node


def use_gpu(scene):
    scene.render.engine = "CYCLES"
    prefs = bpy.context.preferences.addons["cycles"].preferences
    for kind in ("OPTIX", "CUDA"):
        try:
            prefs.compute_device_type = kind
            prefs.get_devices()
            if any(d.type == kind for d in prefs.devices):
                for d in prefs.devices:
                    d.use = d.type == kind
                scene.cycles.device = "GPU"
                return kind
        except TypeError:
            continue
    scene.cycles.device = "CPU"
    return "CPU"


def bake(obj, out_dir, size=1024):
    scene = bpy.context.scene
    device = use_gpu(scene)
    scene.cycles.samples = 32
    scene.render.bake.margin = 8
    scene.render.bake.use_clear = True
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    def run(kind, image_name, non_color, **kwargs):
        image = new_image(image_name, size, non_color)
        set_targets(obj, image)
        bpy.ops.object.bake(type=kind, **kwargs)
        path = os.path.join(out_dir, image_name + ".png")
        image.filepath_raw = path
        image.file_format = "PNG"
        image.save()
        return image

    # La passe de couleur diffuse vaut couleur × (1 − métal) : métal à 0 le temps de la cuisson
    metals = {}
    for mat in obj.data.materials:
        bsdf = mat.node_tree.nodes.get("Principled BSDF")
        metals[mat.name] = bsdf.inputs["Metallic"].default_value
        bsdf.inputs["Metallic"].default_value = 0.0
    albedo = run("DIFFUSE", "F001_Kael_AF_BaseColor", False, pass_filter={"COLOR"})
    for mat in obj.data.materials:
        mat.node_tree.nodes.get("Principled BSDF").inputs["Metallic"].default_value = metals[mat.name]
    strengths = {}
    for mat in obj.data.materials:  # émission normalisée (0 à 1) dans la carte
        bsdf = mat.node_tree.nodes.get("Principled BSDF")
        strengths[mat.name] = bsdf.inputs["Emission Strength"].default_value
        bsdf.inputs["Emission Strength"].default_value = min(1.0, strengths[mat.name])
    emission = run("EMIT", "F001_Kael_AF_Emission", False)
    for mat in obj.data.materials:
        mat.node_tree.nodes.get("Principled BSDF").inputs["Emission Strength"].default_value = strengths[mat.name]
    rough = run("ROUGHNESS", "F001_Kael_AF_Roughness", True)
    scene.cycles.samples = 64
    world = scene.world or bpy.data.worlds.new("BakeWorld")
    scene.world = world
    world.light_settings.distance = 0.35  # occlusion de contact, pas d'assombrissement global
    ao = run("AO", "F001_Kael_AF_AO", True)
    scene.cycles.samples = 16
    normal = run("NORMAL", "F001_Kael_AF_Normal", True, normal_space="TANGENT")
    # Métal : valeur constante par matière, cuite via l'émission
    saved = {}
    for mat in obj.data.materials:
        bsdf = mat.node_tree.nodes.get("Principled BSDF")
        socket = bsdf.inputs["Emission Color"]
        saved[mat.name] = ([l.from_socket for l in socket.links], bsdf.inputs["Emission Strength"].default_value)
        for l in list(socket.links):
            mat.node_tree.links.remove(l)
        value = METAL.get(mat.name, 0.0)
        socket.default_value = (value, value, value, 1)
        bsdf.inputs["Emission Strength"].default_value = 1.0
    metal = run("EMIT", "F001_Kael_AF_Metalness", True)
    for mat in obj.data.materials:
        bsdf = mat.node_tree.nodes.get("Principled BSDF")
        sources, strength = saved[mat.name]
        for src in sources:
            mat.node_tree.links.new(src, bsdf.inputs["Emission Color"])
        bsdf.inputs["Emission Strength"].default_value = strength
    # Couleur finale pour Roblox : occlusion intégrée, braises rehaussées. Roblox
    # n'a pas d'émission par texel : la lueur est cuite en « superposition » (screen),
    # à 0,9 (passe 3 ; 0,5 en addition avant : lame et ourlet éteints en jeu).
    a = np.array(albedo.pixels[:]).reshape(-1, 4)
    o = np.array(ao.pixels[:]).reshape(-1, 4)[:, :1]
    e = np.array(emission.pixels[:]).reshape(-1, 4)[:, :3]
    final = a.copy()
    lit = np.clip(a[:, :3] * (0.42 + 0.58 * o), 0, 1)
    final[:, :3] = 1 - (1 - lit) * (1 - np.clip(e * EMIT_WEIGHT, 0, 1))
    color = new_image("F001_Kael_AF_Color", size, False)
    color.pixels = final.ravel().tolist()
    color.filepath_raw = os.path.join(out_dir, "F001_Kael_AF_Color.png")
    color.file_format = "PNG"
    color.save()
    return {"device": device, "color": color, "emission": emission, "roughness": rough, "metalness": metal, "normal": normal, "ao": ao}


def final_material(obj, maps):
    """Un seul matériau : la couleur cuite (Roblox) + cartes Blender (émission,
    rugosité, métal, normales), aussi utilisables par une SurfaceAppearance."""
    mat = bpy.data.materials.new("F001_Kael_AF")
    g = Graph(mat)
    uv = g.uv("AtlasUV")
    nodes = {}
    for key, socket in (("color", "Base Color"), ("emission", "Emission Color"), ("roughness", "Roughness"), ("metalness", "Metallic")):
        n = g.node("ShaderNodeTexImage", name=key.capitalize() + "Map")
        n.image = maps[key]
        g.links.new(uv, n.inputs["Vector"])
        nodes[key] = n
        g.links.new(n.outputs["Color"], g.bsdf.inputs[socket])
    g.bsdf.inputs["Emission Strength"].default_value = 3.0
    n = g.node("ShaderNodeTexImage", name="NormalMap")
    n.image = maps["normal"]
    g.links.new(uv, n.inputs["Vector"])
    nm = g.node("ShaderNodeNormalMap", uv_map="AtlasUV")
    g.links.new(n.outputs["Color"], nm.inputs["Color"])
    g.links.new(nm.outputs["Normal"], g.bsdf.inputs["Normal"])
    obj.data.materials.clear()
    obj.data.materials.append(mat)
    for poly in obj.data.polygons:
        poly.material_index = 0
    return mat


def roblox_only(mat, enabled):
    """Le FBX ne porte que la couleur : on débranche les autres cartes à l'export."""
    tree = mat.node_tree
    bsdf = tree.nodes["Principled BSDF"]
    wiring = {"EmissionMap": "Emission Color", "RoughnessMap": "Roughness", "MetalnessMap": "Metallic"}
    for node_name, socket_name in wiring.items():
        socket = bsdf.inputs[socket_name]
        for l in list(socket.links):
            tree.links.remove(l)
        if not enabled:
            tree.links.new(tree.nodes[node_name].outputs["Color"], socket)
    normal_socket = bsdf.inputs["Normal"]
    for l in list(normal_socket.links):
        tree.links.remove(l)
    if not enabled:
        tree.links.new(tree.nodes["Normal Map"].outputs["Normal"], normal_socket)
