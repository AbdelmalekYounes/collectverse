"""Textures peintes de Kael Anime Fantasy (Pillow) : yeux, sourcils, bouche, cape, lame.

    python art/kael/anime_fantasy/paint_textures.py art/kael/anime_fantasy/build/textures

Ces images sont des sources : elles sont posées sur leurs pièces (UV « SrcUV » ou
« DecalUV ») puis cuites dans l'atlas final avec le reste des matières.
"""

import math
import os
import random
import sys

from PIL import Image, ImageDraw, ImageFilter

SS = 4  # suréchantillonnage : bords nets après réduction


def canvas(w, h, color=(0, 0, 0, 0)):
    return Image.new("RGBA", (w * SS, h * SS), color)


def finish(image, w, h):
    return image.resize((w, h), Image.LANCZOS)


def bezier(points, steps=40):
    out = []
    for s in range(steps + 1):
        t = s / steps
        work = list(points)
        while len(work) > 1:
            work = [((1 - t) * a[0] + t * b[0], (1 - t) * a[1] + t * b[1]) for a, b in zip(work, work[1:])]
        out.append(work[0])
    return out


def stroke(draw, pts, width_fn, color):
    """Trait à épaisseur variable (pinceau) le long d'une polyligne."""
    count = len(pts) - 1
    for i in range(count):
        (x0, y0), (x1, y1) = pts[i], pts[i + 1]
        r0 = width_fn(i / count)
        steps = max(1, int(math.hypot(x1 - x0, y1 - y0) / max(r0 * 0.3, 1)))
        for k in range(steps):
            t = (i + k / steps) / count
            r = width_fn(t)
            x, y = x0 + (x1 - x0) * k / steps, y0 + (y1 - y0) * k / steps
            draw.ellipse([x - r, y - r, x + r, y + r], fill=color)


def eye(path):
    """Œil anime masculin, sérieux (passe 2) : amande étirée, paupière supérieure
    épaisse en aile avec cils, pli de paupière, iris ambre strié à lueur de braise
    en bas, pupille étroite, trois reflets, cil inférieur. Extérieur à droite."""
    import numpy as np

    w, h = 512, 320
    img = canvas(w, h)
    d = ImageDraw.Draw(img)
    s = SS
    top = bezier([(58 * s, 192 * s), (150 * s, 72 * s), (360 * s, 66 * s), (472 * s, 148 * s)])
    bottom = bezier([(472 * s, 148 * s), (380 * s, 246 * s), (170 * s, 252 * s), (58 * s, 192 * s)])
    almond = top + bottom
    almond_mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(almond_mask).polygon(almond, fill=255)
    d.polygon(almond, fill=(244, 238, 236, 255))
    # Iris : dégradé (sombre en haut, braise en bas), stries radiales, anneau
    cx, cy, rx, ry = 266 * s, 168 * s, 84 * s, 100 * s
    iris = Image.new("RGBA", img.size, (0, 0, 0, 0))
    di = ImageDraw.Draw(iris)
    for k in range(ry * 2):
        t = k / (ry * 2)
        di.line([(cx - rx, cy - ry + k), (cx + rx, cy - ry + k)], fill=(int(96 + 159 * min(1, t * 1.3)), int(20 + 150 * t ** 1.3), int(6 + 40 * t ** 2), 255))
    for a in range(0, 360, 9):
        rad = math.radians(a)
        inner, outer = 30 * s, 80 * s
        shade = (255, 210, 120, 70) if a % 18 == 0 else (60, 10, 4, 60)
        di.line([(cx + math.cos(rad) * inner, cy + math.sin(rad) * inner * 1.18), (cx + math.cos(rad) * outer, cy + math.sin(rad) * outer * 1.18)], fill=shade, width=3 * s)
    di.ellipse([cx - rx, cy - ry, cx + rx, cy + ry], outline=(50, 8, 4, 255), width=10 * s)
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).ellipse([cx - rx, cy - ry, cx + rx, cy + ry], fill=255)
    mask = Image.fromarray(np.minimum(np.array(mask), np.array(almond_mask)))
    img.paste(iris, (0, 0), mask)
    d = ImageDraw.Draw(img)
    d.ellipse([cx - 20 * s, cy - 54 * s, cx + 20 * s, cy + 46 * s], fill=(26, 5, 4, 255))
    d.ellipse([cx - 56 * s, cy - 62 * s, cx - 14 * s, cy - 20 * s], fill=(255, 255, 255, 255))
    d.ellipse([cx + 24 * s, cy + 28 * s, cx + 44 * s, cy + 48 * s], fill=(255, 232, 190, 255))
    d.ellipse([cx + 40 * s, cy - 40 * s, cx + 50 * s, cy - 30 * s], fill=(255, 255, 255, 230))
    # Ombre de la paupière sur le haut du globe
    shade = Image.new("RGBA", img.size, (0, 0, 0, 0))
    ImageDraw.Draw(shade).polygon(top + bezier([(472 * s, 148 * s), (330 * s, 128 * s), (150 * s, 130 * s), (58 * s, 192 * s)]), fill=(70, 18, 20, 120))
    shade = shade.filter(ImageFilter.GaussianBlur(6 * s))
    shade.putalpha(Image.fromarray(np.minimum(np.array(shade.split()[3]), np.array(almond_mask))))
    img = Image.alpha_composite(img, shade)
    d = ImageDraw.Draw(img)
    # Paupière supérieure épaisse, aile, cils
    lid = bezier([(46 * s, 198 * s), (140 * s, 62 * s), (360 * s, 54 * s), (480 * s, 138 * s), (508 * s, 108 * s)], 90)
    stroke(d, lid, lambda t: (9 + 20 * math.sin(math.pi * min(1, t * 1.1))) * s, (16, 4, 6, 255))  # passe 3 : plus épaisse
    for k, (x0, y0) in enumerate(((430, 100), (455, 112), (476, 126))):
        flick = bezier([(x0 * s, y0 * s), ((x0 + 22) * s, (y0 - 22 + 4 * k) * s), ((x0 + 40) * s, (y0 - 30 + 6 * k) * s)], 20)
        stroke(d, flick, lambda t: (5 * (1 - t) + 1) * s, (22, 6, 8, 255))
    # Pli de paupière et cil inférieur
    crease = bezier([(140 * s, 44 * s), (300 * s, 16 * s), (450 * s, 66 * s)], 40)
    stroke(d, crease, lambda t: (2 + 3 * math.sin(math.pi * t)) * s, (110, 44, 38, 170))
    low = bezier([(150 * s, 250 * s), (330 * s, 254 * s), (470 * s, 152 * s)], 60)
    stroke(d, low, lambda t: (2.5 + 5 * t) * s, (46, 12, 12, 255))
    finish(img, w, h).save(path)


def brow(path):
    """Sourcil anime (passe 2) : faisceau de traits effilés, épais et bas à
    l'intérieur (gauche), cassé et pointu vers l'extérieur."""
    w, h = 512, 160
    img = canvas(w, h)
    d = ImageDraw.Draw(img)
    s = SS
    base = [(30, 122), (170, 70), (330, 46), (492, 72)]
    for k in range(7):
        offset = (k - 3) * 4
        pts = bezier([(x * s, (y + offset * (1 - i / 3)) * s) for i, (x, y) in enumerate(base)], 80)
        stroke(d, pts, lambda t, k=k: ((12 - abs(k - 3) * 2) * (1 - t) ** 0.7 + 2.5) * s, (28 + 5 * k, 6, 5, 255))
    finish(img, w, h).save(path)


def nose(path):
    """Ombre de nez peinte (passe 2) : ombre douce côté opposé à la lumière, arête
    claire, narines discrètes. Centre de l'image = arête du nez."""
    import numpy as np

    w, h = 256, 320
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    a = np.zeros((h, w), dtype=float)
    yy, xx = np.mgrid[0:h, 0:w]
    side = np.clip((xx - 132) / 30, 0, 1) * np.clip(1 - (xx - 162) / 30, 0, 1)
    along = np.clip((yy - 40) / 160, 0, 1) * np.clip(1 - (yy - 250) / 40, 0, 1)
    a += 0.5 * side * along
    shadow = Image.fromarray((a * 255).astype("uint8"))
    img = Image.new("RGBA", (w, h), (150, 70, 52, 0))
    img.putalpha(shadow.filter(ImageFilter.GaussianBlur(6)))
    d = ImageDraw.Draw(img)
    d.arc([96, 250, 132, 276], 200, 330, fill=(110, 46, 38, 200), width=4)
    d.arc([132, 250, 168, 276], 210, 340, fill=(110, 46, 38, 200), width=4)
    img.save(path)


def filigree(path):
    """Ornements gravés (motif répétable) : volutes et langues de flamme dorées,
    sur fond transparent ; posés sur l'armure par projection et cuits."""
    w = h = 512
    img = canvas(w, h)
    d = ImageDraw.Draw(img)
    s = SS
    motifs = []
    for k in range(4):
        cx, cy = (128 + 256 * (k % 2)) * s, (128 + 256 * (k // 2)) * s
        flip = -1 if k % 2 else 1
        motifs.append(bezier([(cx - 90 * s * flip, cy + 70 * s), (cx - 20 * s * flip, cy + 80 * s), (cx + 10 * s * flip, cy - 10 * s), (cx + 70 * s * flip, cy - 60 * s), (cx + 40 * s * flip, cy - 100 * s)], 60))
        motifs.append(bezier([(cx - 40 * s * flip, cy + 20 * s), (cx - 70 * s * flip, cy - 20 * s), (cx - 40 * s * flip, cy - 60 * s), (cx - 10 * s * flip, cy - 40 * s)], 40))
        motifs.append(bezier([(cx + 20 * s * flip, cy + 60 * s), (cx + 60 * s * flip, cy + 40 * s), (cx + 80 * s * flip, cy + 80 * s)], 30))
    for pts in motifs:
        for dx in (-w * s, 0, w * s):
            for dy in (-h * s, 0, h * s):
                shifted = [(x + dx, y + dy) for x, y in pts]
                stroke(d, shifted, lambda t: (2.5 + 3 * math.sin(math.pi * t)) * s, (255, 210, 120, 255))
    finish(img, w, h).save(path)


def mouth(path):
    """Bouche discrète, sérieuse : trait fin légèrement tombant, ombre de lèvre."""
    w, h = 256, 96
    img = canvas(w, h)
    d = ImageDraw.Draw(img)
    s = SS
    pts = bezier([(28 * s, 46 * s), (128 * s, 38 * s), (228 * s, 50 * s)], 40)
    stroke(d, pts, lambda t: (3 + 4 * math.sin(math.pi * t)) * s, (88, 30, 28, 255))
    d.ellipse([96 * s, 58 * s, 160 * s, 74 * s], fill=(200, 120, 100, 90))
    finish(img, w, h).save(path)


def cape(path):
    """Cape : u en travers, v du col (haut) à l'ourlet (bas). Rouge profond, trame
    de tissu, bordure dorée et motifs de flammes près de l'ourlet."""
    w, h = 1024, 1024
    rng = random.Random(3)
    img = Image.new("RGB", (w, h))
    px = img.load()
    for y in range(h):
        v = y / (h - 1)
        for x in range(w):
            weave = 0.04 * math.sin(x * 1.3) * math.sin(y * 1.1)
            base = 0.32 + 0.12 * (1 - v) + weave
            px[x, y] = (int(150 * base + 40), int(18 * base + 6), int(26 * base + 8))
    d = ImageDraw.Draw(img)
    # Langues de feu le long de l'ourlet (bas)
    for k in range(26):
        x0 = k / 26 * w + rng.uniform(-10, 10)
        height = rng.uniform(140, 300)
        width = rng.uniform(40, 70)
        flame = bezier([(x0 - width, h), (x0 - width * 0.2, h - height * 0.5), (x0 + rng.uniform(-30, 30), h - height)], 30) + bezier([(x0 + rng.uniform(-30, 30), h - height), (x0 + width * 0.4, h - height * 0.45), (x0 + width, h)], 30)
        d.polygon(flame, fill=(236, 96, 24))  # passe 3 : plus clair (lisible en effets réduits)
        inner = [(x0 + (px_ - x0) * 0.55, h - (h - py) * 0.6) for px_, py in flame]
        d.polygon(inner, fill=(255, 190, 80))
    img = img.filter(ImageFilter.GaussianBlur(1.2))
    d = ImageDraw.Draw(img)
    d.rectangle([0, h - 18, w, h], fill=(255, 196, 96))
    d.rectangle([0, h - 34, w, h - 26], fill=(214, 150, 60))
    # Bords latéraux dorés et col
    for x0 in (0, w - 12):
        d.rectangle([x0, 0, x0 + 12, h], fill=(200, 140, 56))
    d.rectangle([0, 0, w, 16], fill=(200, 140, 56))
    img.save(path)


def blade(path):
    """Lame (passe 2) : u en travers (0 fil gauche, 0,5 arête, 1 fil droit), v de la
    garde (haut de l'image) à la pointe. Acier sombre au centre, fils clairs,
    gravures de flammes près de la garde, fissures de braise qui partent des fils.
    Écrit aussi blade_emit.png : âme et fissures incandescentes (émission)."""
    import numpy as np

    w, h = 256, 1024
    rng = random.Random(5)
    yy, xx = np.mgrid[0:h, 0:w].astype(float)
    u, v = xx / (w - 1), 1 - yy / (h - 1)  # v = 1 à la garde (haut)
    edge = np.abs(u - 0.5) * 2
    steel = 70 + 150 * edge ** 1.8
    # Passe 3 : en jeu, l'acier bleuté et l'âme étroite (6 %) se lisaient lilas-gris.
    # Acier chaud, âme incandescente sur ~30 % de la largeur, fils clairs gardés.
    along = np.clip((v - 0.06) / 0.94, 0, 1) ** 0.6
    core = np.clip(1 - np.abs(u - 0.5) / 0.16, 0, 1) ** 0.8 * along
    heat = np.clip(1 - np.abs(u - 0.5) / 0.34, 0, 1) ** 1.5 * along
    base = np.stack([steel * 1.0, steel * 0.86, steel * 0.74], -1)
    hot = np.array([236, 92, 22])
    base = base * (1 - heat[..., None]) + hot * heat[..., None]
    emit = np.zeros((h, w, 3))
    emit += core[..., None] * np.array([255, 128, 36]) * (0.6 + 0.4 * v[..., None])
    color = Image.fromarray(np.clip(base + core[..., None] * np.array([40, 60, 30]), 0, 255).astype("uint8"))
    emit_img = Image.fromarray(np.clip(emit, 0, 255).astype("uint8"))
    d, de = ImageDraw.Draw(color), ImageDraw.Draw(emit_img)
    for k in range(9):  # gravures de flammes près de la garde
        y0 = 40 + k * 70
        alpha = max(0.0, 1 - k / 9)
        for side in (-1, 1):
            x0 = 128 + side * 30
            flame = bezier([(x0, y0 + 50), (x0 + side * 34, y0 + 20), (x0 + side * rng.uniform(10, 30), y0 - 30)], 20)
            d.line(flame, fill=(int(255 * alpha + 70 * (1 - alpha)), int(110 * alpha + 70 * (1 - alpha)), int(40 * alpha + 80 * (1 - alpha))), width=5)
    for _ in range(26):  # fissures de braise : partent des fils, plus nombreuses près de la garde
        y = int(abs(rng.gauss(0, 380)))
        side = rng.choice((-1, 1))
        x = 128 + side * 120
        heat = max(0.25, 1 - y / 900)
        pts = [(x, y)]
        for _ in range(rng.randint(4, 8)):
            x -= side * rng.uniform(6, 14)
            y += rng.uniform(-10, 14)
            pts.append((x, y))
            if abs(x - 128) < 30:
                break
        glow = (int(255 * heat), int(150 * heat), int(40 * heat))
        d.line(pts, fill=(255, 170, 70), width=3)
        de.line(pts, fill=glow, width=4)
    color.filter(ImageFilter.GaussianBlur(0.8)).save(path)
    emit_img.filter(ImageFilter.GaussianBlur(1.2)).save(path.replace("blade.png", "blade_emit.png"))


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else "textures"
    os.makedirs(out, exist_ok=True)
    eye(os.path.join(out, "eye.png"))
    brow(os.path.join(out, "brow.png"))
    mouth(os.path.join(out, "mouth.png"))
    cape(os.path.join(out, "cape.png"))
    blade(os.path.join(out, "blade.png"))
    nose(os.path.join(out, "nose.png"))
    filigree(os.path.join(out, "filigree.png"))
    print(out)


if __name__ == "__main__":
    main()
