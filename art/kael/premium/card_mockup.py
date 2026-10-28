"""Maquette de l'illustration de Kael dans le cadre CardTile (V0.2.4).

    python art/kael/premium/card_mockup.py

À partir de build/card/F001_Kael_card_proposal.png (proposition conservée), écrit
dans build/card/ :
  - card_crop_guides.png : zones gardées par la fenêtre d'illustration de CardTile
    (ScaleType Crop : toute la largeur, bande centrale) en Standard / Large et en
    Compact, et la bande de sécurité de 70 % où le sujet doit tenir ;
  - card_mockup.png : la carte simulée aux trois classes de taille du jeu, comme
    CardTile depuis les retouches V0.2.4 :
      * rareté (Commune) : cadre, gemme, libellé « COMMUNE » en bas de carte ;
      * finition (Holo) : pastille irisée « HOLO » dans l'illustration + reflet ;
      * Compact : illustration et nom plus grands, élément seul, sans libellé.

C'est une maquette d'intégration : rien n'est téléversé, aucun Asset ID n'est
renseigné. Les valeurs reprennent src/shared/Visuals/CardStyle.luau.
"""

import os

from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
CARD_DIR = os.path.join(HERE, "build", "card")
SOURCE = os.path.join(CARD_DIR, "F001_Kael_card_proposal.png")

# CardStyle.luau
ASPECT = 112 / 158
LAYOUTS = {
    "Standard": {
        "art": {"x": 0.07, "y": 0.05, "width": 0.86, "height": 0.55},
        "gems": {"y": 0.6, "height": 0.075},
        "name": {"y": 0.655, "height": 0.1},
        "subtitle": {"y": 0.755, "height": 0.075},
        "footer": {"y": 0.855, "height": 0.08},
    },
    "Compact": {
        "art": {"x": 0.06, "y": 0.045, "width": 0.88, "height": 0.6},
        "gems": {"y": 0.645, "height": 0.07},
        "name": {"y": 0.69, "height": 0.15},
        "subtitle": {"y": 0.84, "height": 0.1},
        "footer": None,  # libellé de rareté masqué en Compact
    },
}
LAYOUTS["Large"] = LAYOUTS["Standard"]
FINISH_BADGE = {"x": 0.04, "y": 0.04, "width": 0.42, "height": 0.15}
SAFE_BAND = 0.7
COMMON = {"border": ["#C9CFEA", "#7E87B5"], "background": ["#232A52", "#101426"], "plate": "#151A33", "accent": "#AEB6D9"}
FIRE = "#FF7A3D"
MUTED = "#9AA2CC"
HOLO = ["#A8F1FF", "#D2C4FF", "#FFE9A8"]


def rgb(value):
    value = value.lstrip("#")
    return tuple(int(value[i : i + 2], 16) for i in (0, 2, 4))


def font(size, bold=False):
    for name in (("segoeuib.ttf" if bold else "segoeui.ttf"), "arial.ttf"):
        try:
            return ImageFont.truetype(name, max(6, size))
        except OSError:
            continue
    return ImageFont.load_default()


def art_ratio(size_class):
    art = LAYOUTS[size_class]["art"]
    return (art["width"] * 112) / (art["height"] * 158)


def crop_to_art(image, ratio):
    """Comme ScaleType.Crop : remplit la fenêtre en gardant le centre."""
    w, h = image.size
    if w / h > ratio:
        new_w = int(h * ratio)
        left = (w - new_w) // 2
        return image.crop((left, 0, left + new_w, h))
    new_h = int(w / ratio)
    top = (h - new_h) // 2
    return image.crop((0, top, w, top + new_h))


def gradient(size, colors, horizontal=False):
    w, h = size
    image = Image.new("RGB", size)
    draw = ImageDraw.Draw(image)
    stops = [rgb(c) for c in colors]
    steps = w if horizontal else h
    for i in range(steps):
        k = i / max(steps - 1, 1) * (len(stops) - 1)
        a, b = stops[int(k)], stops[min(int(k) + 1, len(stops) - 1)]
        f = k - int(k)
        color = tuple(int(a[j] + (b[j] - a[j]) * f) for j in range(3))
        draw.line([(i, 0), (i, h)] if horizontal else [(0, i), (w, i)], fill=color)
    return image


def crop_guides(source):
    w, h = source.size
    overlay = source.copy().convert("RGBA")
    shade = Image.new("RGBA", source.size, (5, 6, 13, 0))
    sd = ImageDraw.Draw(shade)
    keep = int(w / art_ratio("Standard"))
    top = (h - keep) // 2
    sd.rectangle([0, 0, w, top], fill=(5, 6, 13, 170))
    sd.rectangle([0, top + keep, w, h], fill=(5, 6, 13, 170))
    overlay = Image.alpha_composite(overlay, shade)
    draw = ImageDraw.Draw(overlay)
    label = font(26, True)
    draw.rectangle([2, top, w - 3, top + keep], outline=rgb("#39CBE7") + (255,), width=4)
    draw.text((20, top + 12), f"Standard / Large : {w} × {keep} (rapport {art_ratio('Standard'):.3f})", font=label, fill=rgb("#39CBE7"))
    keep_c = int(w / art_ratio("Compact"))
    top_c = (h - keep_c) // 2
    draw.rectangle([10, top_c, w - 11, top_c + keep_c], outline=rgb("#F0BF61") + (255,), width=3)
    draw.text((20, top_c + keep_c - 40), f"Compact : {w} × {keep_c} (rapport {art_ratio('Compact'):.3f})", font=label, fill=rgb("#F0BF61"))
    safe = int(h * SAFE_BAND)
    top_s = (h - safe) // 2
    for y in (top_s, top_s + safe):
        for x in range(0, w, 28):
            draw.line([(x, y), (x + 14, y)], fill=rgb("#F36D79"), width=3)
    draw.text((w - 330, top_s + 8), "Bande de sécurité 70 %", font=font(24, True), fill=rgb("#F36D79"))
    draw.text((20, 20), "Débord (non affiché en jeu)", font=font(24), fill=rgb(MUTED))
    draw.text((20, h - 50), "Proposition 3D (Blender Eevee) - non téléversée", font=font(24), fill=rgb(MUTED))
    path = os.path.join(CARD_DIR, "card_crop_guides.png")
    overlay.convert("RGB").save(path)
    return path


def card(source, width, size_class, quantity=None):
    layout = LAYOUTS[size_class]
    height = round(width / ASPECT)
    scale = 3  # suréchantillonnage, puis réduction : bords nets
    W, H = width * scale, height * scale
    radius = int(W * 0.07)
    canvas = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    mask = Image.new("L", (W, H), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, W - 1, H - 1], radius=radius, fill=255)
    canvas.paste(gradient((W, H), COMMON["background"]), (0, 0), mask)
    thickness = max(2, int(1.5 * scale * width / 112))
    ring = Image.new("L", (W, H), 0)
    rd = ImageDraw.Draw(ring)
    rd.rounded_rectangle([0, 0, W - 1, H - 1], radius=radius, fill=255)
    rd.rounded_rectangle([thickness, thickness, W - 1 - thickness, H - 1 - thickness], radius=radius - thickness, fill=0)
    canvas.paste(gradient((W, H), COMMON["border"]), (0, 0), ring)
    draw = ImageDraw.Draw(canvas)

    # Illustration (Crop) et reflet holographique léger
    a = layout["art"]
    ax, ay, aw, ah = int(a["x"] * W), int(a["y"] * H), int(a["width"] * W), int(a["height"] * H)
    art = crop_to_art(source, art_ratio(size_class)).resize((aw, ah), Image.LANCZOS).convert("RGBA")
    foil = Image.new("RGBA", (aw, ah), (0, 0, 0, 0))
    ImageDraw.Draw(foil).polygon([(aw * 0.15, ah), (aw * 0.45, 0), (aw * 0.62, 0), (aw * 0.32, ah)], fill=(200, 240, 255, 38))
    art = Image.alpha_composite(art, foil.filter(ImageFilter.GaussianBlur(W * 0.02)))
    # Pastille de finition HOLO (coin haut gauche de l'illustration)
    b = FINISH_BADGE
    bx, by, bw, bh = int(b["x"] * aw), int(b["y"] * ah), int(b["width"] * aw), int(b["height"] * ah)
    pill = Image.new("L", (bw, bh), 0)
    ImageDraw.Draw(pill).rounded_rectangle([0, 0, bw - 1, bh - 1], radius=bh // 2, fill=255)
    art.paste(gradient((bw, bh), HOLO, horizontal=True), (bx, by), pill)
    ImageDraw.Draw(art).text((bx + bw // 2, by + bh // 2), "HOLO", font=font(int(bh * 0.62), True), fill=rgb("#101426"), anchor="mm")
    art_mask = Image.new("L", (aw, ah), 0)
    ImageDraw.Draw(art_mask).rounded_rectangle([0, 0, aw - 1, ah - 1], radius=int(W * 0.035), fill=255)
    canvas.paste(art, (ax, ay), art_mask)

    # Gemme de rareté (Commune : 1), centrée sur le bas de l'illustration
    g = layout["gems"]
    gy, gh = int(g["y"] * H), int(g["height"] * H)
    cx = W // 2
    draw.rounded_rectangle([cx - gh, gy - gh // 2, cx + gh, gy + gh // 2], radius=gh // 2, fill=rgb(COMMON["plate"]), outline=rgb(COMMON["accent"]))
    d = int(gh * 0.34)
    draw.polygon([(cx, gy - d), (cx + d, gy), (cx, gy + d), (cx - d, gy)], fill=rgb(COMMON["accent"]))

    # Nom, sous-titre, libellé de rareté seule
    n = layout["name"]
    draw.text((W // 2, int((n["y"] + n["height"] / 2) * H)), "Kael", font=font(int(n["height"] * H * 0.6), True), fill=rgb("#EEF0FF"), anchor="mm")
    s = layout["subtitle"]
    sub_font = font(int(s["height"] * H * 0.62))
    sy = int((s["y"] + s["height"] / 2) * H)
    if size_class == "Compact":
        draw.text((W // 2, sy), "Feu", font=sub_font, fill=rgb(FIRE), anchor="mm")
    else:
        left, rest = "Feu", " · Guerrier"
        total = draw.textlength(left + rest, font=sub_font)
        x0 = W // 2 - total / 2
        draw.text((x0, sy), left, font=sub_font, fill=rgb(FIRE), anchor="lm")
        draw.text((x0 + draw.textlength(left, font=sub_font), sy), rest, font=sub_font, fill=rgb(MUTED), anchor="lm")
    f = layout["footer"]
    if f:
        draw.text((W // 2, int((f["y"] + f["height"] / 2) * H)), "COMMUNE", font=font(int(f["height"] * H * 0.6), True), fill=rgb(COMMON["accent"]), anchor="mm")
    if quantity:
        qw, qh = int(0.27 * W), int(0.125 * H)
        qx, qy = W - qw - 4 * scale, 4 * scale
        draw.rounded_rectangle([qx, qy, qx + qw, qy + qh], radius=qh // 2, fill=rgb("#101426"), outline=rgb("#F0BF61"), width=scale)
        draw.text((qx + qw // 2, qy + qh // 2), f"x{quantity}", font=font(int(qh * 0.6), True), fill=rgb("#F0BF61"), anchor="mm")
    return canvas.resize((width, height), Image.LANCZOS)


def mockup(source):
    sizes = [
        ("Large (fiche, révélation)", 336, "Large", 5),
        ("Standard (grilles)", 150, "Standard", 5),
        ("Compact (équipe, mobile)", 100, "Compact", None),
    ]
    cards = [(label, card(source, width, size_class, quantity)) for label, width, size_class, quantity in sizes]
    pad = 40
    width = max(900, sum(c.size[0] for _, c in cards) + pad * (len(cards) + 1) + 140)
    height = max(c.size[1] for _, c in cards) + 200
    sheet = Image.new("RGB", (width, height), rgb("#101426"))
    draw = ImageDraw.Draw(sheet)
    draw.text((pad, 16), "Maquette CardTile - Kael (proposition V0.2.4, non intégrée, non téléversée)", font=font(20, True), fill=rgb("#F0BF61"))
    x = pad
    for label, image in cards:
        y = 64
        sheet.paste(image, (x, y), image)
        draw.text((x, y + image.size[1] + 12), label, font=font(15), fill=rgb(MUTED))
        draw.text((x, y + image.size[1] + 32), f"{image.size[0]} × {image.size[1]} px", font=font(13), fill=rgb("#646C99"))
        x += image.size[0] + pad
    legend_y = height - 64
    draw.text((pad, legend_y), "Rareté : cadre, gemmes et libellé « COMMUNE » en bas de carte (masqué en Compact).", font=font(14), fill=rgb("#EEF0FF"))
    draw.text((pad, legend_y + 22), "Finition : pastille irisée « HOLO » sur l'illustration + reflet. Les deux ne sont jamais mêlés.", font=font(14), fill=rgb("#EEF0FF"))
    path = os.path.join(CARD_DIR, "card_mockup.png")
    sheet.save(path)
    return path


def main():
    source = Image.open(SOURCE).convert("RGB")
    print(crop_guides(source))
    print(mockup(source))


if __name__ == "__main__":
    main()
