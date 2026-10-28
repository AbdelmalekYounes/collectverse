"""Planches de Kael Anime Fantasy (V0.2.5), à partir des rendus de af_render.py.

    python art/kael/anime_fantasy/af_sheets.py

Écrit dans art/kael/anime_fantasy/build/sheets/ :
  - compare_ABC.png     : A V0.2.2 / B Premium V2 / C Anime Fantasy, mêmes vues, même éclairage ;
  - combat_ABC.png      : caméra de combat réelle, taille réelle PC et mobile (× 3) ;
  - combat_effects.png  : Anime Fantasy, effets complets / réduits ;
  - neutral.png         : gris neutre et fil de fer (jugement du maillage) ;
  - presentation.png    : planche de présentation (vitrine, gros plans, tour, palette, chiffres) ;
  - poses.png           : images-clés des 7 animations reconstruites.
"""

import json
import os
import re

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
BUILD = os.path.join(HERE, "build")
RENDERS = os.path.join(BUILD, "renders")
OUT = os.path.join(BUILD, "sheets")
BG = (12, 15, 30)
GOLD = (240, 191, 97)
TEXT = (226, 230, 245)
MUTED = (150, 158, 196)


def font(size, bold=False):
    for name in (("segoeuib.ttf" if bold else "segoeui.ttf"), "arial.ttf"):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            continue
    return ImageFont.load_default()


def load(name, size=None):
    path = os.path.join(RENDERS, name)
    if not os.path.exists(path):
        return None
    image = Image.open(path).convert("RGB")
    return image.resize(size, Image.LANCZOS) if size else image


VERSIONS = [
    ("v022", "A · V0.2.2 — stylisé (en jeu)"),
    ("v2", "B · Premium V2 (V0.2.4, non intégré)"),
    ("af", "C · Anime Fantasy (V0.2.5, nouveau modèle)"),
]


def compare_abc():
    views = [("front", "Face"), ("three_quarter", "Trois quarts"), ("side", "Profil"), ("back", "Dos")]
    tw, th, label = 360, 450, 34
    sheet = Image.new("RGB", (tw * len(views), len(VERSIONS) * (th + label) + 40), BG)
    d = ImageDraw.Draw(sheet)
    d.text((12, 8), "Kael — comparatif, même éclairage (Eevee « studio »), même caméra, même échelle", font=font(20, True), fill=GOLD)
    for r, (tag, title) in enumerate(VERSIONS):
        y = 40 + r * (th + label)
        d.text((12, y + 6), title, font=font(18, True), fill=TEXT)
        for c, (view, name) in enumerate(views):
            image = load(f"{tag}_{view}.png", (tw, th))
            if image:
                sheet.paste(image, (c * tw, y + label))
            d.text((c * tw + 10, y + label + 8), name, font=font(14), fill=MUTED)
    sheet.save(os.path.join(OUT, "compare_ABC.png"))


def combat_abc():
    cases = [("ally", "pc", "Allié, de dos · PC 1080p (1:1)"), ("enemy", "pc", "Ennemi, de face · PC (1:1)"),
             ("ally", "mobile", "Allié · mobile 844 × 390 (× 3)"), ("enemy", "mobile", "Ennemi · mobile (× 3)")]
    cw, ch = 330, 330
    sheet = Image.new("RGB", (260 + cw * len(cases), 40 + len(VERSIONS) * (ch + 8)), BG)
    d = ImageDraw.Draw(sheet)
    for c, (_, _, label) in enumerate(cases):
        d.text((260 + c * cw + 8, 10), label, font=font(15, True), fill=GOLD)
    for r, (tag, title) in enumerate(VERSIONS):
        y = 40 + r * (ch + 8)
        d.multiline_text((10, y + ch // 2 - 20), title.replace(" — ", "\n").replace(" (", "\n("), font=font(14, True), fill=TEXT)
        for c, (slot, screen, _) in enumerate(cases):
            image = load(f"{tag}_combat_full_{slot}_{screen}.png")
            if image is None:
                continue
            if screen == "mobile":
                image = image.resize((image.width * 3, image.height * 3), Image.NEAREST)
            image.thumbnail((cw - 10, ch - 10))
            sheet.paste(image, (260 + c * cw + (cw - image.width) // 2, y + (ch - image.height) // 2))
    sheet.save(os.path.join(OUT, "combat_ABC.png"))


def combat_effects():
    cases = [("full", "ally"), ("reduced", "ally"), ("full", "enemy"), ("reduced", "enemy")]
    cw, ch = 330, 330
    sheet = Image.new("RGB", (cw * 4, 2 * (ch + 40)), BG)
    d = ImageDraw.Draw(sheet)
    for r, screen in enumerate(("pc", "mobile")):
        for c, (effects, slot) in enumerate(cases):
            image = load(f"af_combat_{effects}_{slot}_{screen}.png")
            if image is None:
                continue
            if screen == "mobile":
                image = image.resize((image.width * 3, image.height * 3), Image.NEAREST)
            image.thumbnail((cw - 10, ch - 10))
            y = r * (ch + 40) + 34
            sheet.paste(image, (c * cw + (cw - image.width) // 2, y))
            label = f"{'Effets complets' if effects == 'full' else 'Effets réduits'} · {'allié' if slot == 'ally' else 'ennemi'} · {'PC' if screen == 'pc' else 'mobile × 3'}"
            d.text((c * cw + 8, r * (ch + 40) + 8), label, font=font(14, True), fill=GOLD)
    sheet.save(os.path.join(OUT, "combat_effects.png"))


def neutral():
    names = ["af_neutral_front.png", "af_neutral_three_quarter.png", "af_neutral_side.png", "af_neutral_back.png", "af_wire_front.png", "af_wire_three_quarter.png"]
    tw, th = 320, 400
    sheet = Image.new("RGB", (tw * 3, th * 2 + 40), BG)
    d = ImageDraw.Draw(sheet)
    d.text((10, 8), "Vue neutre (sans texture, sans effet) et fil de fer", font=font(18, True), fill=GOLD)
    for i, name in enumerate(names):
        image = load(name, (tw, th))
        if image:
            sheet.paste(image, ((i % 3) * tw, 40 + (i // 3) * th))
    sheet.save(os.path.join(OUT, "neutral.png"))


def silhouette(image):
    """Silhouette noire à partir de la vue neutre (fond sombre, personnage gris)."""
    gray = image.convert("L")
    mask = gray.point(lambda v: 255 if v > 70 else 0)
    out = Image.new("RGB", image.size, (236, 222, 205))
    out.paste((14, 10, 12), mask=mask)
    return out


def presentation():
    report = json.load(open(os.path.join(BUILD, "kael_af_report.json"), encoding="utf-8"))
    W, H = 2400, 1500
    sheet = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(sheet)
    d.text((30, 20), "COLLECTVERSE — Kael, Lame des Braises · Anime Fantasy (V0.2.5)", font=font(34, True), fill=GOLD)
    d.text((30, 66), "Modèle 3D réel (Blender → Roblox), rendus du vrai maillage — prototype de référence, non intégré", font=font(18), fill=MUTED)
    show = load("af_showcase.png", (720, 900))
    if show:
        sheet.paste(show, (30, 110))
    d.text((40, 1020), "Présentation (Eevee, éclairage anime fantasy)", font=font(15), fill=MUTED)
    x0 = 780
    for i, (name, label) in enumerate([("face", "Visage"), ("armor", "Armure"), ("sword", "Épée des braises"), ("cape", "Cape")]):
        w, h = (380, 380) if name in ("face", "armor") else (380, 475)
        image = load(f"af_closeup_{name}.png", (w, h))
        x = x0 + (i % 2) * 395
        y = 110 if i < 2 else 520
        if image:
            sheet.paste(image, (x, y))
        d.text((x + 8, y + 6), label, font=font(16, True), fill=GOLD)
    # Tour du personnage
    tx = 1590
    d.text((tx, 110), "Tour", font=font(18, True), fill=GOLD)
    for i, view in enumerate(["front", "three_quarter", "side", "back", "three_quarter_back"]):
        image = load(f"af_{view}.png", (152, 190))
        if image:
            sheet.paste(image, (tx + (i % 5) * 156, 140))
    neutral_front = load("af_neutral_front.png", (240, 300))
    wire = load("af_wire_three_quarter.png", (240, 300))
    if neutral_front:
        sheet.paste(neutral_front, (tx, 360))
        sheet.paste(silhouette(neutral_front), (tx + 500, 360))
    if wire:
        sheet.paste(wire, (tx + 250, 360))
    d.text((tx, 665), "Neutre · fil de fer · silhouette", font=font(15), fill=MUTED)
    # Palette
    palette = [("#5E0E0A", "Armure"), ("#B23620", "Armure (lumière)"), ("#E0A848", "Or"), ("#12141F", "Sous-armure"),
               ("#6E1620", "Cape"), ("#F05420", "Cheveux"), ("#FF8A30", "Braise"), ("#EAB898", "Peau")]
    d.text((tx, 700), "Palette", font=font(18, True), fill=GOLD)
    for i, (color, name) in enumerate(palette):
        x, y = tx + (i % 4) * 196, 730 + (i // 4) * 70
        d.rectangle([x, y, x + 50, y + 50], fill=color)
        d.text((x + 58, y + 14), name, font=font(14), fill=TEXT)
    # Chiffres
    lines = [
        f"Hauteur : {report['height']} studs (≈ {report['headsTall']} têtes)",
        f"Triangles : {report['triangles']} (LOD : {report['files']['lodTriangles']})",
        f"Os : {report['boneCount']} (noms et hiérarchie de production)",
        f"Influences max : {report['maxInfluencesPerVertex']} · sommets sans poids : {report['unweightedVertices']}",
        f"Matériaux : {report['materials']} · atlas 1024 × 1024",
        "Cartes : couleur, émission, rugosité, métal, normales, occlusion",
        "Animations : 7 reconstruites (données KeyframeSequence, non publiées)",
    ]
    d.text((tx, 880), "Chiffres (rapport de validation)", font=font(18, True), fill=GOLD)
    for i, line in enumerate(lines):
        d.text((tx, 912 + i * 28), line, font=font(15), fill=TEXT)
    # Taille réelle de combat
    d.text((x0, 1020), "En combat, taille réelle (PC 1:1, mobile × 3)", font=font(18, True), fill=GOLD)
    for i, name in enumerate(["af_combat_full_ally_pc.png", "af_combat_full_enemy_pc.png", "af_combat_full_ally_mobile.png", "af_combat_full_enemy_mobile.png"]):
        image = load(name)
        if image is None:
            continue
        if "mobile" in name:
            image = image.resize((image.width * 3, image.height * 3), Image.NEAREST)
        image.thumbnail((190, 300))
        sheet.paste(image, (x0 + i * 200, 1055))
    sheet.save(os.path.join(OUT, "presentation.png"))


def poses():
    folder = os.path.join(RENDERS, "af_poses")
    pattern = re.compile(r"(\w+?)_(\d+)\.png")
    rows = {}
    for name in os.listdir(folder):
        m = pattern.fullmatch(name)
        if m:
            rows.setdefault(m.group(1), []).append((int(m.group(2)), name))
    order = ["Idle", "Attack", "Skill", "Ultimate", "Defend", "Hit", "Defeat"]
    tw, th = 180, 225
    cols = max(len(v) for v in rows.values())
    sheet = Image.new("RGB", (120 + cols * tw, len(order) * (th + 4)), BG)
    d = ImageDraw.Draw(sheet)
    for r, anim in enumerate(order):
        y = r * (th + 4)
        d.text((10, y + th // 2), anim, font=font(16, True), fill=GOLD)
        for c, (frame, name) in enumerate(sorted(rows.get(anim, []))):
            sheet.paste(Image.open(os.path.join(folder, name)).convert("RGB").resize((tw, th)), (120 + c * tw, y))
            d.text((120 + c * tw + 6, y + 4), f"image {frame}", font=font(12), fill=TEXT)
    sheet.save(os.path.join(OUT, "poses.png"))


def outlined(image, mask_name, color=(255, 216, 168), opacity=0.55, width=2):
    """Contour de silhouette façon Highlight Roblox : masque dilaté moins masque."""
    from PIL import ImageChops, ImageFilter

    path = os.path.join(RENDERS, mask_name)
    if not os.path.exists(path):
        return image
    alpha = Image.open(path).convert("RGBA").split()[3].resize(image.size)
    ring = ImageChops.subtract(alpha.filter(ImageFilter.MaxFilter(2 * width + 1)), alpha)
    ring = ring.point(lambda v: int(v * opacity))
    out = image.copy()
    out.paste(Image.new("RGB", image.size, color), (0, 0), ring)
    return out


def before_after():
    views = [("front", "Face"), ("three_quarter", "Trois quarts"), ("side", "Profil"), ("back", "Dos")]
    tw, th, label = 360, 450, 34
    rows = [("p1", "AVANT · passe 1 (V0.2.5 validée)"), ("af", "APRÈS · passe 2 (Art Pass 2)")]
    sheet = Image.new("RGB", (tw * 4, 40 + 2 * (th + label)), BG)
    d = ImageDraw.Draw(sheet)
    d.text((12, 8), "Kael Anime Fantasy — avant / après, mêmes angles, même éclairage, même échelle", font=font(20, True), fill=GOLD)
    for r, (tag, title) in enumerate(rows):
        y = 40 + r * (th + label)
        d.text((12, y + 6), title, font=font(18, True), fill=TEXT)
        for c, (view, name) in enumerate(views):
            image = load(f"{tag}_{view}.png", (tw, th))
            if image:
                sheet.paste(image, (c * tw, y + label))
            d.text((c * tw + 10, y + label + 8), name, font=font(14), fill=MUTED)
    sheet.save(os.path.join(OUT, "before_after.png"))
    shots = [("face", "Visage"), ("armor", "Armure et matières"), ("sword", "Épée"), ("cape", "Cape et attaches")]
    tw, th = 400, 440
    sheet = Image.new("RGB", (tw * 4, 40 + 2 * (th + label)), BG)
    d = ImageDraw.Draw(sheet)
    d.text((12, 8), "Gros plans — avant (passe 1) / après (passe 2)", font=font(20, True), fill=GOLD)
    for r, (tag, title) in enumerate(rows):
        y = 40 + r * (th + label)
        d.text((12, y + 6), title, font=font(18, True), fill=TEXT)
        for c, (shot, name) in enumerate(shots):
            image = load(f"{tag}_closeup_{shot}.png")
            if image:
                image.thumbnail((tw, th))
                sheet.paste(image, (c * tw + (tw - image.width) // 2, y + label))
            d.text((c * tw + 10, y + label + 8), name, font=font(14, True), fill=GOLD)
    sheet.save(os.path.join(OUT, "closeups_before_after.png"))


def combat_pass2():
    cases = [("ally", "pc", "Allié de dos · PC 1:1"), ("enemy", "pc", "Ennemi de face · PC 1:1"), ("ally", "mobile", "Allié · mobile × 3"), ("enemy", "mobile", "Ennemi · mobile × 3")]
    rows = [("p1", "full", None, "Passe 1"), ("af", "full", None, "Passe 2"), ("af", "full", "outline", "Passe 2 + contour (Highlight simulé)"), ("af", "reduced", None, "Passe 2 · effets réduits")]
    cw, ch = 330, 330
    sheet = Image.new("RGB", (240 + cw * 4, 40 + len(rows) * (ch + 8)), BG)
    d = ImageDraw.Draw(sheet)
    for c, (_, _, label) in enumerate(cases):
        d.text((240 + c * cw + 8, 10), label, font=font(15, True), fill=GOLD)
    for r, (tag, effects, extra, title) in enumerate(rows):
        y = 40 + r * (ch + 8)
        d.multiline_text((10, y + ch // 2 - 20), title.replace(" (", "\n("), font=font(14, True), fill=TEXT)
        for c, (slot, screen, _) in enumerate(cases):
            image = load(f"{tag}_combat_{effects}_{slot}_{screen}.png")
            if image is None:
                continue
            if extra == "outline":
                image = outlined(image, f"af_combat_mask_{slot}_{screen}.png", width=2 if screen == "pc" else 1)
            if screen == "mobile":
                image = image.resize((image.width * 3, image.height * 3), Image.NEAREST)
            image.thumbnail((cw - 10, ch - 10))
            sheet.paste(image, (240 + c * cw + (cw - image.width) // 2, y + (ch - image.height) // 2))
    sheet.save(os.path.join(OUT, "combat_pass2.png"))


def lineup_sheet():
    tiles = []
    for screen in ("pc", "mobile"):
        for variant in ("plain", "outline"):
            image = load(f"af_lineup_plain_{screen}.png")
            if image is None:
                continue
            if variant == "outline":
                image = outlined(image, f"af_lineup_mask_{screen}.png", width=2 if screen == "pc" else 1)
            plates = json.load(open(os.path.join(RENDERS, f"af_lineup_{screen}_plates.json")))
            d = ImageDraw.Draw(image)
            for p in plates:
                x, y, w, h = p["x"], p["y"], p["w"], p["h"]
                d.rectangle([x - w / 2, y - h / 2, x + w / 2, y + h / 2], outline=(255, 210, 120) if p["hero"] else (150, 160, 200), width=2 if screen == "pc" else 1)
            if screen == "mobile":
                image = image.resize((image.width * 2, image.height * 2), Image.NEAREST)
            tiles.append((image, f"{'PC 1920 × 1080' if screen == 'pc' else 'Mobile 844 × 390 (× 2)'} · {'sans contour' if variant == 'plain' else 'contour Highlight simulé'}"))
    W = 1920
    y = 50
    sheet = Image.new("RGB", (W, 50 + sum(int(t.height * (W / 2) / t.width) + 40 for t, _ in tiles[::2])), BG)
    d = ImageDraw.Draw(sheet)
    d.text((12, 10), "Arène 5 contre 5, caméra du jeu — Kael Anime Fantasy au centre des deux lignes avant, figurants V0.2.2 ; cadres = plaques de vie", font=font(18, True), fill=GOLD)
    for i, (image, label) in enumerate(tiles):
        image = image.resize((W // 2, int(image.height * (W / 2) / image.width)))
        x = (i % 2) * (W // 2)
        d.text((x + 10, y + 6), label, font=font(15, True), fill=TEXT)
        sheet.paste(image, (x, y + 30))
        if i % 2 == 1:
            y += image.height + 40
    sheet.save(os.path.join(OUT, "lineup_10.png"))


def main():
    os.makedirs(OUT, exist_ok=True)
    for fn in (compare_abc, combat_abc, combat_effects, neutral, presentation, poses, before_after, combat_pass2, lineup_sheet):
        fn()
    print(OUT)


if __name__ == "__main__":
    main()
