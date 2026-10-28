"""Pièces de Kael Anime Fantasy : armure, cheveux, visage, épée, cape.

Chaque fonction renvoie une liste de (objet, poids) ; poids(p) -> {os: poids}.
Repère : Z haut, le personnage regarde vers -Y, sa gauche est en +X.
"""

import math

import bmesh
import bpy
from mathutils import Vector

import af_lib as L

# Profil du torse (visuel, après subdivision) : z, demi-largeur, demi-profondeur, centre y
TORSO = [
    (3.25, 0.35, 0.25, 0.02),
    (3.62, 0.37, 0.25, 0.02),
    (4.18, 0.3, 0.21, 0.02),
    (4.8, 0.43, 0.27, 0.0),
    (5.28, 0.48, 0.26, 0.02),
    (5.48, 0.34, 0.22, 0.03),
    (5.62, 0.14, 0.12, 0.03),
]


def torso(z):
    if z <= TORSO[0][0]:
        return TORSO[0][1:]
    for (z0, *a), (z1, *b) in zip(TORSO, TORSO[1:]):
        if z <= z1:
            k = (z - z0) / (z1 - z0)
            return tuple(a[i] + (b[i] - a[i]) * k for i in range(3))
    return TORSO[-1][1:]


def vertical_wrap(rfun, zfun):
    """Surface autour du torse. u -> angle (0 = face avant), v -> hauteur via zfun(u, v).
    rfun(z, angle) -> (rx, ry, cy)."""

    def surface(u, v, a0, a1):
        angle = a0 + (a1 - a0) * u
        z = zfun(u, v)
        rx, ry, cy = rfun(z, angle)
        return Vector((rx * math.sin(angle), cy - ry * math.cos(angle), z))

    return surface


def axis_frame(p0, p1):
    axis = (p1 - p0).normalized()
    front = Vector((0, -1, 0))
    f = (front - axis * front.dot(axis)).normalized()
    s = axis.cross(f).normalized()
    return axis, s, f


def limb_wrap(p0, p1, rfun, a0, a1, tfun=None):
    """Coque autour d'un membre (p0 -> p1). rfun(t, angle) -> (rx, ry)."""
    p0, p1 = Vector(p0), Vector(p1)
    _, s, f = axis_frame(p0, p1)

    def surface(u, v):
        angle = a0 + (a1 - a0) * u
        t = tfun(u, v) if tfun else v
        c = p0.lerp(p1, t)
        rx, ry = rfun(t, angle)
        return c + s * math.sin(angle) * rx + f * math.cos(angle) * ry

    return surface


def edge_trim(name, surface, v, steps, radius, outward_center, material="Gold"):
    """Filet doré le long d'un bord de coque (v fixe)."""
    pts = []
    for i in range(steps + 1):
        p = surface(i / steps, v)
        c = outward_center(p)
        pts.append(p + (p - c).normalized() * radius * 0.8)
    verts, faces = L.tube(pts, [radius] * len(pts), segments=3)
    return L.object_from_data(name, verts, faces, material)


def lerp(a, b, t):
    return a + (b - a) * t


# --------------------------------------------------------------------------- #
# Torse : plastron, dossière, plaques abdominales, gorgerin, ceinture
# --------------------------------------------------------------------------- #


def build_torso_armor(bp):
    parts = []
    upper = L.rigid("UpperTorso")
    lower = L.rigid("LowerTorso")

    def chest_r(z, angle):
        rx, ry, cy = torso(z)
        # pectoraux bombés devant, plaque plus épaisse au centre
        bulge = 0.045 * math.sin(math.pi * max(0.0, min(1.0, (z - 4.55) / 0.85))) * max(0.0, math.cos(angle)) ** 2
        return rx + 0.07, ry + 0.07 + bulge, cy

    def chest_z(u, v):
        angle = math.radians(-105 + 210 * u)
        bottom = 4.52 - 0.14 * math.cos(angle) ** 6  # pointe basse au centre
        top = 5.44 - 0.16 * max(0.0, math.cos(angle)) ** 4  # encolure en V
        return lerp(bottom, top, v)

    wrap = vertical_wrap(chest_r, chest_z)
    chest_surface = lambda u, v: wrap(u, v, math.radians(-105), math.radians(105))
    parts.append((L.shell("ChestPlate", chest_surface, 16, 7, 0.05, "ArmorRed", bevel=0), upper))
    center = lambda p: Vector((0, torso(p.z)[2], p.z))
    parts.append((edge_trim("ChestTrimTop", chest_surface, 1.0, 16, 0.022, center), upper))
    parts.append((edge_trim("ChestTrimBottom", chest_surface, 0.0, 16, 0.022, center), upper))

    def back_z(u, v):
        return lerp(4.58, 5.42, v)

    back = vertical_wrap(lambda z, a: (torso(z)[0] + 0.065, torso(z)[1] + 0.065, torso(z)[2]), back_z)
    back_surface = lambda u, v: back(u, v, math.radians(100), math.radians(260))
    parts.append((L.shell("BackPlate", back_surface, 10, 5, 0.045, "ArmorDark", bevel=0), upper))

    # Plaques abdominales en lames superposées (articulées sur le bas du torse)
    for k, (z0, z1) in enumerate(((4.34, 4.56), (4.1, 4.36))):
        growth = 0.06 + 0.012 * k

        def lame_r(z, angle, growth=growth):
            rx, ry, cy = torso(z)
            return rx + growth, ry + growth, cy

        lame = vertical_wrap(lame_r, lambda u, v, z0=z0, z1=z1: lerp(z0, z1, v) - 0.03 * math.cos(math.radians(-80 + 160 * u)) ** 4)
        surface = lambda u, v, lame=lame: lame(u, v, math.radians(-80), math.radians(80))
        weight = upper if k == 0 else L.chain([Vector((0, 0, 3.5)), Vector((0, 0, 4.3)), Vector((0, 0, 5.3))], ["LowerTorso", "UpperTorso"], 0.25)
        parts.append((L.shell(f"AbLame{k}", surface, 10, 1, 0.035, "ArmorRed", bevel=0), weight))
        parts.append((edge_trim(f"AbTrim{k}", surface, 0.0, 10, 0.014, center), weight))

    # Gorgerin (protège-cou) ouvert à l'arrière
    def gorget_surface(u, v):
        angle = math.radians(-150 + 300 * u)
        z = lerp(5.45, 5.9, v)
        r = lerp(0.3, 0.2, v)
        return Vector((r * math.sin(angle), 0.03 - r * 0.92 * math.cos(angle), z))

    parts.append((L.shell("Gorget", gorget_surface, 12, 2, 0.03, "ArmorDark", bevel=0), upper))
    parts.append((edge_trim("GorgetTrim", gorget_surface, 1.0, 12, 0.016, lambda p: Vector((0, 0.03, p.z))), upper))

    # Ceinture et boucle
    def belt_surface(u, v):
        angle = math.radians(-180 + 360 * u)
        z = lerp(3.86, 4.04, v)
        rx, ry, cy = torso(z)
        return Vector(((rx + 0.07) * math.sin(angle), cy - (ry + 0.07) * math.cos(angle), z))

    parts.append((L.shell("Belt", belt_surface, 18, 1, 0.03, "Leather", bevel=0), lower))
    buckle_center = Vector((0, torso(3.95)[2] - torso(3.95)[1] - 0.1, 3.95))
    v, f = L.ellipsoid(buckle_center, (0.15, 0.04, 0.12), rings=4, segments=10)
    parts.append((L.solid("Buckle", v, f, "Gold", bevel=0.0), lower))
    v, f = L.ellipsoid(buckle_center + Vector((0, -0.035, 0)), (0.065, 0.03, 0.07), rings=4, segments=8)
    parts.append((L.solid("BuckleGem", v, f, "Ember"), lower))
    return parts


def build_chest_core():
    """Cristal incandescent au centre du torse, serti d'or."""
    parts = []
    upper = L.rigid("UpperTorso")
    z = 5.02
    rx, ry, cy = torso(z)
    front = cy - ry - 0.07 - 0.045 - 0.03
    v, f = L.ellipsoid((0, front, z), (0.17, 0.05, 0.2), rings=5, segments=12)
    parts.append((L.solid("CoreSetting", v, f, "Gold"), upper))
    # Cristal taillé : bipyramide à 6 faces
    tip_top, tip_bottom = Vector((0, front - 0.06, z + 0.15)), Vector((0, front - 0.06, z - 0.15))
    ring = [Vector((0.08 * math.cos(a), front - 0.06 - 0.05 * abs(math.sin(a)), z + 0.08 * math.sin(a) * 0.4)) for a in (math.tau * i / 6 for i in range(6))]
    verts = [tip_top, tip_bottom] + ring
    faces = []
    for i in range(6):
        faces.append([0, 2 + i, 2 + (i + 1) % 6])
        faces.append([1, 2 + (i + 1) % 6, 2 + i])
    parts.append((L.solid("CoreCrystal", verts, faces, "Ember", smooth=False), upper))
    return parts


# --------------------------------------------------------------------------- #
# Tassettes, pan avant
# --------------------------------------------------------------------------- #


def thigh_follow(side):
    def fn(p):
        if p.z >= 3.7:
            return {"LowerTorso": 1.0}
        s = min(0.75, (3.7 - p.z) / 0.8 * 0.75)
        return {"LowerTorso": 1 - s, side + "UpperLeg": s}

    return fn


def both_thighs(p):
    if p.z >= 3.7:
        return {"LowerTorso": 1.0}
    s = min(0.75, (3.7 - p.z) / 0.9 * 0.75)
    return {"LowerTorso": 1 - s, "LeftUpperLeg": s / 2, "RightUpperLeg": s / 2}


def build_tassets():
    parts = []
    plates = [
        # (angle centre, demi-ouverture, haut, bas, matériau)
        (62, 26, 3.9, 3.0, "ArmorRed"),
        (100, 22, 3.9, 3.1, "ArmorDark"),
        (130, 20, 3.86, 3.2, "ArmorRed"),
    ]
    for sign, side in ((1, "Left"), (-1, "Right")):
        for k, (center_deg, half, top, bottom, mat) in enumerate(plates):
            a0 = math.radians(sign * (center_deg - half))
            a1 = math.radians(sign * (center_deg + half))
            if sign < 0:
                a0, a1 = a1, a0

            def zfun(u, v, top=top, bottom=bottom):
                point = 0.14 * (1 - abs(2 * u - 1))  # bas en pointe
                return lerp(top, bottom - point, v)

            def rfun(z, angle):
                rx, ry, cy = torso(min(z, 3.62))
                flare = 0.08 + 0.2 * max(0.0, 3.9 - z)
                return rx + flare, ry + flare, cy

            wrap = vertical_wrap(rfun, zfun)
            surface = lambda u, v, wrap=wrap, a0=a0, a1=a1: wrap(u, v, a0, a1)
            weight = thigh_follow(side) if k < 2 else L.rigid("LowerTorso")
            parts.append((L.shell(f"Tasset{side}{k}", surface, 4, 4, 0.03, mat, bevel=0), weight))
            if mat == "ArmorRed":
                center = lambda p: Vector((0, 0.02, p.z))
                parts.append((edge_trim(f"TassetTrim{side}{k}", surface, 1.0, 6, 0.014, center), weight))
    # Pan avant (tissu rouge à liseré doré), suit les deux cuisses
    def loin(u, v):
        x = lerp(-0.2, 0.2, u) * lerp(1.0, 1.25, v)
        z = lerp(3.88, 2.55 - 0.18 * (1 - abs(2 * u - 1)), v)
        y = torso(min(z, 3.9))[2] - torso(min(z, 3.9))[1] - 0.12 - 0.12 * v * v
        return Vector((x, y, z))

    parts.append((L.shell("Loincloth", loin, 4, 7, 0.02, "Cloth", bevel=0.0, sharp_angle=None), both_thighs))
    center = lambda p: Vector((p.x, p.y + 0.2, p.z))
    for u in (0.0, 1.0):
        pts = [loin(u, i / 7) for i in range(8)]
        verts, faces = L.tube([p + Vector((0, -0.012, 0)) for p in pts], [0.016] * 8, segments=4)
        parts.append((L.object_from_data("LoinTrim", verts, faces, "Gold"), both_thighs))
    return parts


# --------------------------------------------------------------------------- #
# Épaulières asymétriques
# --------------------------------------------------------------------------- #


def cap_surface(center, out, radii, az_range, pol_range):
    """Calotte : az autour de la verticale (0 = vers l'extérieur), pol depuis le haut."""
    center = Vector(center)
    out = Vector(out).normalized()
    up = Vector((0, 0, 1))
    fwd = up.cross(out).normalized()
    if fwd.y > 0:
        fwd = -fwd  # fwd vers l'avant (-Y)

    def surface(u, v):
        az = lerp(az_range[0], az_range[1], u)
        pol = lerp(pol_range[0], pol_range[1], v)
        return center + out * math.cos(az) * math.sin(pol) * radii[0] + fwd * math.sin(az) * math.sin(pol) * radii[1] + up * math.cos(pol) * radii[2]

    return surface


def build_pauldrons(bp):
    parts = []
    for sign, side, big in ((1, "Left", True), (-1, "Right", False)):
        weight = L.rigid(side + "UpperArm")
        shoulder = bp(side + "UpperArm")
        out = Vector((sign, 0, -0.25))
        layers = 3 if big else 2
        scale = 1.0 if big else 0.86
        for k in range(layers):
            c = shoulder + Vector((sign * (0.06 + 0.06 * k), 0.0, 0.06 - 0.22 * k))
            radii = (0.46 * scale - 0.02 * k, 0.42 * scale - 0.02 * k, 0.36 * scale - 0.04 * k)
            pol = (0.1, 1.45) if k == 0 else (0.75, 1.55)  # dôme, puis lames qui descendent sur le bras
            az = math.radians(118 if k == 0 else 100)
            surface = cap_surface(c, out, radii, (-az, az), pol)
            mat = "ArmorRed" if k % 2 == 0 else "ArmorDark"
            parts.append((L.shell(f"Pauldron{side}{k}", surface, 9, 4 if k == 0 else 2, 0.045, mat, bevel=0), weight))
            parts.append((edge_trim(f"PauldronTrim{side}{k}", surface, 1.0, 9, 0.018, lambda p, c=c: c), weight))
        top = shoulder + Vector((sign * 0.08, 0, 0.36 * scale))
        v, f = L.ellipsoid(top, (0.07, 0.07, 0.05), rings=4, segments=8)
        parts.append((L.solid(f"PauldronStud{side}", v, f, "Gold"), weight))
        # Crête de flammes : cornes dorées recourbées vers l'arrière et le haut
        crests = [(0.0, 0.55, 0.11), (0.12, 0.42, 0.08)] if big else [(0.0, 0.32, 0.07)]
        for k, (dy, length, radius) in enumerate(crests):
            root = shoulder + Vector((sign * 0.18, dy, 0.28 * scale))
            pts = L.bezier([root, root + Vector((sign * 0.12, 0.12, length * 0.55)), root + Vector((sign * 0.05, 0.35, length))], 6)
            verts, faces = L.tube(pts, [radius * (1 - i / 5) ** 0.8 + 0.004 for i in range(6)], segments=6, squash=0.55)
            parts.append((L.object_from_data(f"Crest{side}{k}", verts, faces, "Gold"), weight))
    return parts


# --------------------------------------------------------------------------- #
# Bras : canons d'avant-bras, cubitières, gantelets
# --------------------------------------------------------------------------- #


def build_arms(bp):
    parts = []
    for sign, side in ((1, "Left"), (-1, "Right")):
        elbow, wrist = bp(side + "LowerArm"), bp(side + "LowerArm", True)
        hand_head, hand_tail = bp(side + "Hand"), bp(side + "Hand", True)
        lower = L.rigid(side + "LowerArm")
        surface = limb_wrap(elbow.lerp(wrist, 0.12), wrist + (wrist - elbow).normalized() * 0.04, lambda t, a: (lerp(0.17, 0.125, t) + 0.015 * math.cos(a), lerp(0.16, 0.12, t)), math.radians(-160), math.radians(160))
        parts.append((L.shell(f"Vambrace{side}", surface, 10, 3, 0.03, "ArmorRed", bevel=0), lower))
        center = lambda p, e=elbow, w=wrist: e + (w - e) * L.segment_param(p, e, w)
        parts.append((edge_trim(f"VambraceTrim{side}A", surface, 0.0, 10, 0.016, center), lower))
        # Canon d'arrière-bras, côté extérieur
        shoulder = bp(side + "UpperArm")
        a0, a1 = (math.radians(-170), math.radians(30)) if sign > 0 else (math.radians(-30), math.radians(170))
        surface = limb_wrap(shoulder.lerp(elbow, 0.38), shoulder.lerp(elbow, 0.92), lambda t, a: (lerp(0.17, 0.14, t), lerp(0.16, 0.13, t)), a0, a1)
        parts.append((L.shell(f"Rerebrace{side}", surface, 8, 3, 0.03, "ArmorDark", bevel=0), L.rigid(side + "UpperArm")))
        # Cubitière pointue vers l'arrière
        tip = elbow + Vector((sign * 0.04, 0.2, 0.02))
        v, f = L.ellipsoid(elbow + Vector((0, 0.06, 0)), (0.12, 0.1, 0.13), rings=5, segments=8)
        parts.append((L.solid(f"Couter{side}", v, f, "ArmorDark"), L.rigid(side + "LowerArm")))  # métal rigide, pas étiré
        verts, faces = L.tube([elbow + Vector((0, 0.1, 0)), tip], [0.05, 0.005], segments=5)
        parts.append((L.object_from_data(f"CouterSpike{side}", verts, faces, "Gold"), L.rigid(side + "LowerArm")))
        # Gantelet : poing articulé (dos de la main, doigts en lames, pouce)
        hand = L.rigid(side + "Hand")
        axis = (hand_tail - hand_head).normalized()
        c = hand_head.lerp(hand_tail, 0.45)
        v, f = L.ellipsoid(c, (0.085, 0.075, 0.13), rings=5, segments=10)
        parts.append((L.solid(f"Fist{side}", v, f, "Under"), hand))
        for k in range(2):
            pc = hand_head.lerp(hand_tail, 0.28 + 0.36 * k) + Vector((sign * 0.03, -0.035, 0))
            v, f = L.ellipsoid(pc, (0.095, 0.06, 0.06), rings=4, segments=8)
            parts.append((L.solid(f"FingerPlate{side}{k}", v, f, "ArmorDark" if k % 2 else "ArmorRed", bevel=0.0), hand))
        v, f = L.ellipsoid(hand_head.lerp(hand_tail, 0.35) + Vector((-sign * 0.05, -0.07, 0)), (0.04, 0.04, 0.07), rings=4, segments=6)
        parts.append((L.solid(f"Thumb{side}", v, f, "Under"), hand))
        del axis
    return parts


# --------------------------------------------------------------------------- #
# Jambes : cuissards, genouillères, grèves, solerets
# --------------------------------------------------------------------------- #


def build_legs(bp):
    parts = []
    for sign, side in ((1, "Left"), (-1, "Right")):
        hip, knee, ankle = bp(side + "UpperLeg"), bp(side + "LowerLeg"), bp(side + "LowerLeg", True)
        upper, lower, foot = L.rigid(side + "UpperLeg"), L.rigid(side + "LowerLeg"), L.rigid(side + "Foot")
        # Cuissard (avant et côté de la cuisse)
        surface = limb_wrap(hip.lerp(knee, 0.28), hip.lerp(knee, 0.92), lambda t, a: (lerp(0.25, 0.2, t), lerp(0.25, 0.19, t)), math.radians(-40 if sign > 0 else -110), math.radians(110 if sign > 0 else 40))
        parts.append((L.shell(f"Cuisse{side}", surface, 8, 4, 0.03, "ArmorRed", bevel=0), upper))
        center = lambda p, a=hip, b=knee: a + (b - a) * L.segment_param(p, a, b)
        parts.append((edge_trim(f"CuisseTrim{side}", surface, 1.0, 8, 0.014, center), upper))
        # Genouillère pointue
        kc = knee + Vector((0, -0.17, 0.03))
        v, f = L.ellipsoid(kc, (0.15, 0.08, 0.17), rings=5, segments=10)
        parts.append((L.solid(f"Poleyn{side}", v, f, "ArmorDark"), lower))
        verts, faces = L.tube([kc + Vector((0, -0.05, 0.05)), kc + Vector((0, -0.13, 0.26))], [0.05, 0.004], segments=5, squash=0.5)
        parts.append((L.object_from_data(f"PoleynSpike{side}", verts, faces, "Gold"), lower))
        # Grève (tibia), ouverte à l'arrière
        surface = limb_wrap(knee.lerp(ankle, 0.1), ankle + Vector((0, 0, 0.02)), lambda t, a: (0.14 + 0.06 * math.exp(-(((t - 0.3) / 0.25) ** 2)) + 0.06 * (1 - t) ** 4, 0.15 + 0.06 * math.exp(-(((t - 0.3) / 0.25) ** 2)) + 0.07 * (1 - t) ** 4), math.radians(-150), math.radians(150))
        parts.append((L.shell(f"Greave{side}", surface, 8, 5, 0.03, "ArmorRed", bevel=0), lower))
        center = lambda p, a=knee, b=ankle: a + (b - a) * L.segment_param(p, a, b)
        parts.append((edge_trim(f"GreaveTrim{side}", surface, 0.0, 10, 0.016, center), lower))
        # Arête centrale du tibia
        verts, faces = L.tube([knee.lerp(ankle, 0.15) + Vector((0, -0.21, 0)), knee.lerp(ankle, 0.85) + Vector((0, -0.16, 0))], [0.02, 0.015], segments=4, squash=0.6)
        parts.append((L.object_from_data(f"GreaveRidge{side}", verts, faces, "Gold"), lower))
        # Soleret : pied blindé à pointe
        toe = Vector((ankle.x, -0.72, 0.01))
        heel = Vector((ankle.x, 0.16, 0.04))
        rings_ = []
        for k, t in enumerate((0.0, 0.25, 0.55, 0.8, 1.0)):
            c = heel.lerp(toe, t)
            w = lerp(0.16, 0.13, t) * (1 - 0.85 * max(0.0, t - 0.8) / 0.2)
            h = lerp(0.26, 0.08, t)
            rings_.append([c + Vector((w * math.cos(a), 0, (h * max(0.0, math.sin(a)) if math.sin(a) > 0 else -0.05 * 1.0) + 0.05)) for a in (math.tau * i / 10 for i in range(10))])
        verts = [p for ring in rings_ for p in ring] + [heel + Vector((0, 0.02, 0.07)), toe + Vector((0, -0.04, 0.0))]
        faces = []
        for r in range(len(rings_) - 1):
            for i in range(10):
                a = r * 10 + i
                b = r * 10 + (i + 1) % 10
                faces.append([a, b, b + 10, a + 10])
        cap0, cap1 = len(verts) - 2, len(verts) - 1
        for i in range(10):
            faces.append([cap0, (i + 1) % 10, i])
            faces.append([cap1, 40 + i, 40 + (i + 1) % 10])
        parts.append((L.solid(f"Sabaton{side}", verts, faces, "ArmorDark", bevel=0.008), foot))
        v, f = L.ellipsoid(toe.lerp(heel, 0.18) + Vector((0, 0, 0.1)), (0.1, 0.13, 0.05), rings=4, segments=8)
        parts.append((L.solid(f"ToeCap{side}", v, f, "Gold"), foot))
    return parts


# --------------------------------------------------------------------------- #
# Épée — Lame des Braises
# --------------------------------------------------------------------------- #


def build_sword(bp):
    parts = []
    hand = L.rigid("RightHand")
    grip = bp("RightHand").lerp(bp("RightHand", True), 0.5)
    # Épée tenue basse, en diagonale vers l'avant et l'extérieur (pointe vers le sol) :
    # elle ne coupe plus le visage au repos ni dans les vues de face.
    a = Vector((-0.3, -0.5, -0.8)).normalized()
    w = Vector((1, 0, 0))
    w = (w - a * w.dot(a)).normalized()
    n = a.cross(w).normalized()
    guard = grip + a * 0.3
    pommel = grip - a * 0.42

    def local(c, x, y, z):
        return c + w * x + n * y + a * z

    # Lame en flammes : base large, langues de feu sur les deux fils, pointe effilée
    length = 2.9
    stations, half_widths = [], []
    count = 26
    for i in range(count):
        t = i / (count - 1)
        s = 0.04 + t * (length - 0.04)
        base = lerp(0.19, 0.11, t) * (1 - max(0.0, t - 0.82) / 0.18 * 0.9)
        stations.append(s)
        half_widths.append(base)
    edge_l, edge_r = [], []
    for i, (s, hw) in enumerate(zip(stations, half_widths)):
        t = s / length
        # dents de flamme orientées vers la pointe, plus marquées au milieu de la lame
        tongue = 0.11 * math.sin(math.pi * min(1.0, t * 1.15)) * (1 if i % 3 == 0 else 0.2)
        edge_l.append(hw + (tongue if t < 0.92 else 0))
        edge_r.append(hw + (0.11 * math.sin(math.pi * min(1.0, t * 1.15)) * (1 if i % 3 == 1 else 0.2) if t < 0.92 else 0))
    verts, faces = [], []
    for i, s in enumerate(stations):
        c = guard + a * s
        thick = lerp(0.055, 0.025, s / length)
        verts += [c + w * edge_l[i], c + n * thick, c - w * edge_r[i], c - n * thick]
    tip = guard + a * (length + 0.25)
    verts.append(tip)
    for i in range(count - 1):
        for j in range(4):
            p, q = i * 4 + j, i * 4 + (j + 1) % 4
            faces.append([p, q, q + 4, p + 4])
    faces.append([3, 2, 1, 0])
    last = (count - 1) * 4
    for j in range(4):
        faces.append([last + j, last + (j + 1) % 4, len(verts) - 1])
    blade = L.object_from_data("Blade", verts, faces, "Blade", smooth=False)
    # UV source : u à travers la lame (0 fil gauche, 0.5 arête, 1 fil droit), v le long
    layer = blade.data.uv_layers.new(name="SrcUV")
    for poly in blade.data.polygons:
        for li in poly.loop_indices:
            vi = blade.data.loops[li].vertex_index
            if vi == len(verts) - 1:
                layer.data[li].uv = (0.5, 0.0)
                continue
            station, corner = divmod(vi, 4)
            layer.data[li].uv = ((0.0, 0.5, 1.0, 0.5)[corner], 1 - stations[station] / (length + 0.25))  # v = 1 à la garde
    parts.append((blade, hand))
    # Garde dorée sculptée : manchon, quillons en ailes de flamme, cristal
    v, f = L.ellipsoid(guard, (0.16, 0.09, 0.09), rings=5, segments=10)
    v = [local(guard, *(q - guard)) for q in v]  # rayons exprimés dans le repère de l'épée
    parts.append((L.solid("GuardCore", v, f, "Gold"), hand))
    for k in (1, -1):
        wing = L.bezier([local(guard, 0.12 * k, 0, 0), local(guard, 0.42 * k, 0, -0.1), local(guard, 0.62 * k, 0, 0.12), local(guard, 0.5 * k, 0, 0.42)], 9)
        verts, faces = L.tube(wing, [0.075 * (1 - i / 8) ** 0.7 + 0.006 for i in range(9)], segments=6, squash=0.45)
        parts.append((L.object_from_data("GuardWing", verts, faces, "Gold"), hand))
        prong = L.bezier([local(guard, 0.18 * k, 0, 0.02), local(guard, 0.3 * k, 0, 0.12), local(guard, 0.24 * k, 0, 0.32)], 6)
        verts, faces = L.tube(prong, [0.04 * (1 - i / 5) + 0.004 for i in range(6)], segments=5, squash=0.5)
        parts.append((L.object_from_data("GuardProng", verts, faces, "Gold"), hand))
        down = L.bezier([local(guard, 0.1 * k, 0, -0.02), local(guard, 0.22 * k, 0, -0.12), local(guard, 0.16 * k, 0, -0.22)], 5)
        verts, faces = L.tube(down, [0.03 * (1 - i / 4) + 0.004 for i in range(5)], segments=5, squash=0.5)
        parts.append((L.object_from_data("GuardDrop", verts, faces, "Gold"), hand))
        v, f = L.ellipsoid(local(guard, 0, 0.07 * k, 0.03), (0.06, 0.03, 0.08), rings=4, segments=8)
        parts.append((L.solid("GuardGem", v, f, "Ember"), hand))
    # Poignée sombre filetée, pommeau doré à cristal
    grip_pts = [guard - a * 0.03 + a * 0 - a * (0.39 * i / 6) for i in range(7)]
    verts, faces = L.tube(grip_pts, [0.06 if i % 2 else 0.068 for i in range(7)], segments=8)
    parts.append((L.object_from_data("Grip", verts, faces, "Leather"), hand))
    v, f = L.ellipsoid(pommel, (0.1, 0.1, 0.11), rings=5, segments=10)
    parts.append((L.solid("Pommel", v, f, "Gold"), hand))
    verts, faces = L.tube([pommel - a * 0.06, pommel - a * 0.24], [0.055, 0.004], segments=6)
    parts.append((L.object_from_data("PommelTip", verts, faces, "Ember"), hand))
    return parts


# --------------------------------------------------------------------------- #
# Cape
# --------------------------------------------------------------------------- #


def build_cape():
    """Cape double face (extérieur rouge, intérieur sombre), plis, ourlet irrégulier.
    UV source : u en travers, v du col (0) à l'ourlet (1), pour le motif de braises."""
    cols, rows = 15, 10
    top = 5.42
    outer, inner, uvs = [], [], []
    for r in range(rows):
        row_o, row_i = [], []
        for c in range(cols):
            u = c / (cols - 1)
            theta = math.radians(-82 + 164 * u)
            hem = 1.55 - 0.22 * max(0.0, math.sin(theta * 3.1 + 0.4)) ** 2 - 0.18 * math.cos(theta) + 0.07 * math.cos(theta * 8)
            v = r / (rows - 1)
            z = lerp(top, hem, v ** 1.05)
            drop = top - z
            rx = 0.5 + drop * 0.19
            ry = 0.33 + drop * 0.16
            # Plis irréguliers (passe 2) : grands plis + plis secondaires, phase variable
            fold = 1 + 0.05 * drop * math.cos(theta * 9 + 0.6 * math.sin(drop * 2.3)) + 0.018 * drop * math.cos(theta * 19 + 1.7)
            sweep = 0.045 * drop * drop
            for layer, k in ((row_o, 1.0), (row_i, 0.955)):
                layer.append(Vector((rx * k * fold * math.sin(theta), 0.06 + ry * k * fold * math.cos(theta) + sweep, z)))
            uvs.append((u, 1 - v))  # v = 1 au col (haut de l'image), 0 à l'ourlet
        outer.append(row_o)
        inner.append(row_i)
    verts = [p for row in outer for p in row] + [p for row in inner for p in row]
    src_uv = uvs + uvs
    off = rows * cols
    faces, inner_flags = [], []

    def idx(r, c, layer):
        return layer * off + r * cols + c

    for r in range(rows - 1):
        for c in range(cols - 1):
            faces.append([idx(r, c, 0), idx(r, c + 1, 0), idx(r + 1, c + 1, 0), idx(r + 1, c, 0)])
            inner_flags.append(False)
            faces.append([idx(r, c, 1), idx(r + 1, c, 1), idx(r + 1, c + 1, 1), idx(r, c + 1, 1)])
            inner_flags.append(True)
    for c in range(cols - 1):
        faces.append([idx(0, c, 0), idx(0, c, 1), idx(0, c + 1, 1), idx(0, c + 1, 0)])
        inner_flags.append(False)
        r = rows - 1
        faces.append([idx(r, c, 0), idx(r, c + 1, 0), idx(r, c + 1, 1), idx(r, c, 1)])
        inner_flags.append(False)
    for r in range(rows - 1):
        faces.append([idx(r, 0, 0), idx(r + 1, 0, 0), idx(r + 1, 0, 1), idx(r, 0, 1)])
        inner_flags.append(False)
        c = cols - 1
        faces.append([idx(r, c, 0), idx(r, c, 1), idx(r + 1, c, 1), idx(r + 1, c, 0)])
        inner_flags.append(False)
    mesh = bpy.data.meshes.new("Cape")
    mesh.from_pydata([tuple(p) for p in verts], [], faces)
    mesh.update(calc_edges=True)
    obj = L.link(bpy.data.objects.new("Cape", mesh))
    obj.data.materials.append(L.material("Cape"))
    obj.data.materials.append(L.material("CapeInner"))
    layer = mesh.uv_layers.new(name="SrcUV")
    for poly, is_inner in zip(mesh.polygons, inner_flags):
        poly.use_smooth = True
        poly.material_index = 1 if is_inner else 0
        for li in poly.loop_indices:
            layer.data[li].uv = src_uv[mesh.loops[li].vertex_index]
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()
    # Haut fixé au torse, bas qui suit le bassin (cape rigide par morceaux, sans simulation)
    weight = L.chain([Vector((0, 0, 5.6)), Vector((0, 0, 4.3)), Vector((0, 0, 1.0))], ["UpperTorso", "LowerTorso"], 0.45)
    parts = [(obj, weight)]
    upper = L.rigid("UpperTorso")
    # Col roulé de la cape le long du bord supérieur
    collar = []
    for c in range(cols):
        theta = math.radians(-82 + 164 * c / (cols - 1))
        collar.append(Vector((0.53 * math.sin(theta), 0.06 + 0.36 * math.cos(theta), top + 0.02)))
    verts, faces = L.tube(collar, [0.045] * len(collar), segments=5)
    parts.append((L.object_from_data("CapeCollar", verts, faces, "Cape"), upper))
    # Attaches : fermoirs dorés à gemme sur le haut du torse, reliés à la cape
    for sign in (1, -1):
        clasp = Vector((0.36 * sign, -0.27, 5.36))
        v, f = L.ellipsoid(clasp, (0.085, 0.035, 0.085), rings=4, segments=10)
        parts.append((L.solid("CapeClasp", v, f, "Gold"), upper))
        v, f = L.ellipsoid(clasp + Vector((0, -0.03, 0)), (0.04, 0.025, 0.04), rings=3, segments=8)
        parts.append((L.solid("CapeClaspGem", v, f, "Ember"), upper))
        corner = Vector((0.5 * sign, 0.12, top))
        cord = L.bezier([clasp + Vector((0.04 * sign, 0.02, 0)), clasp + Vector((0.16 * sign, 0.0, 0.1)), corner], 6)
        verts, faces = L.tube(cord, [0.022] * 6, segments=4)
        parts.append((L.object_from_data("CapeCord", verts, faces, "Gold"), upper))
    return parts
