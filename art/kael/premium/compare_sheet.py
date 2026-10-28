"""Planches avant / après de la passe premium de Kael (V0.2.4).

    python art/kael/premium/compare_sheet.py

Lit les rendus déjà produits (aucun rendu ici) :
  - art/kael/build/renders/            : contrôle Workbench du modèle de production ;
  - art/kael/premium/build/renders/    : même contrôle Workbench, modèle premium ;
  - art/kael/premium/build/lookdev/    : look-dev Eevee identique pour toutes les versions
    (before = production, v1 = premium validé en direction, after = premium retouché) ;
et écrit dans art/kael/premium/build/sheets/ :
  - compare_workbench.png : contrôle Workbench, production / premium actuel ;
  - compare_lookdev.png : 4 vues, production / premium v1 / premium v2 (retouches) ;
  - compare_distance.png : vignettes 96 × 120 agrandies sans lissage ;
  - compare_combat.png : vue de la vraie caméra de combat, taille réelle PC et mobile ;
  - poses_after.png : toutes les images-clés des 7 animations (modèle premium).
"""

import os
import re

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
PRODUCTION = os.path.join(ROOT, "art", "kael", "build", "renders")
PREMIUM = os.path.join(ROOT, "art", "kael", "premium", "build")
OUT = os.path.join(PREMIUM, "sheets")
BACKGROUND = (16, 20, 38)
GOLD = (240, 191, 97)
VIEWS = [("front", "Face"), ("three_quarter", "Trois quarts"), ("side", "Profil"), ("back", "Dos")]
LABEL = 30


def _font(size):
    for name in ("segoeui.ttf", "arial.ttf", "DejaVuSans.ttf"):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            continue
    return ImageFont.load_default()


FONT = _font(15)


def paste_row(sheet, draw, images, y, title, thumb):
    draw.text((12, y + 8), title, fill=GOLD, font=FONT)
    for i, (path, label) in enumerate(images):
        x = i * thumb[0]
        if os.path.exists(path):
            sheet.paste(Image.open(path).convert("RGB").resize(thumb), (x, y + LABEL))
        draw.text((x + 12, y + LABEL + 8), label, fill=(220, 225, 240), font=FONT)


VERSIONS = [
    ("before", "PRODUCTION V0.2.2 (F001_Kael, en jeu)"),
    ("v1", "PREMIUM v1 (direction validée)"),
    ("after", "PREMIUM v2 (retouches : visage, épée, matières, cape)"),
]


def rows_sheet(rows, out_name, thumb=(320, 400)):
    width = thumb[0] * max(len(images) for _, images in rows)
    sheet = Image.new("RGB", (width, len(rows) * (thumb[1] + LABEL)), BACKGROUND)
    draw = ImageDraw.Draw(sheet)
    for index, (title, images) in enumerate(rows):
        paste_row(sheet, draw, images, index * (thumb[1] + LABEL), title, thumb)
    path = os.path.join(OUT, out_name)
    sheet.save(path)
    return path


def combat_sheet():
    """Taille réelle (1:1) puis agrandissement × 3 sans lissage pour le mobile."""
    lookdev = os.path.join(PREMIUM, "lookdev")
    cases = [("ally", "pc", "Allié, de dos · PC 1080p"), ("enemy", "pc", "Écho, de face · PC 1080p"),
             ("ally", "mobile", "Allié · mobile 844 × 390 (× 3)"), ("enemy", "mobile", "Écho · mobile (× 3)")]
    cell_w, cell_h = 300, 300
    sheet = Image.new("RGB", (220 + cell_w * len(cases), LABEL + len(VERSIONS) * (cell_h + 8)), BACKGROUND)
    draw = ImageDraw.Draw(sheet)
    for c, (_, _, label) in enumerate(cases):
        draw.text((220 + c * cell_w + 8, 8), label, fill=GOLD, font=FONT)
    for r, (tag, title) in enumerate(VERSIONS):
        y = LABEL + r * (cell_h + 8)
        draw.text((10, y + cell_h // 2 - 20), title.split(" (")[0], fill=GOLD, font=FONT)
        draw.text((10, y + cell_h // 2), "(" + title.split(" (")[1] if " (" in title else "", fill=(160, 168, 200), font=_font(12))
        for c, (slot, screen, _) in enumerate(cases):
            path = os.path.join(lookdev, f"{tag}_combat_{slot}_{screen}.png")
            if not os.path.exists(path):
                continue
            image = Image.open(path).convert("RGB")
            if screen == "mobile":
                image = image.resize((image.width * 3, image.height * 3), Image.NEAREST)
            image.thumbnail((cell_w - 10, cell_h - 10))  # ne réduit que si nécessaire
            x = 220 + c * cell_w + (cell_w - image.width) // 2
            sheet.paste(image, (x, y + (cell_h - image.height) // 2))
    path = os.path.join(OUT, "compare_combat.png")
    sheet.save(path)
    return path


def distance_sheet():
    scale = 3
    lookdev = os.path.join(PREMIUM, "lookdev")
    cells = []
    for tag, title in (("before", "Production"), ("after", "Premium v2")):
        for view in ("front", "three_quarter"):
            cells.append((os.path.join(lookdev, f"{tag}_distance_{view}.png"), f"{title} · {view.replace('_', ' ')}"))
    cell = (96 * scale, 120 * scale)
    sheet = Image.new("RGB", (cell[0] * len(cells), cell[1] + LABEL), BACKGROUND)
    draw = ImageDraw.Draw(sheet)
    for i, (path, label) in enumerate(cells):
        if os.path.exists(path):
            image = Image.open(path).convert("RGB").resize(cell, Image.NEAREST)
            sheet.paste(image, (i * cell[0], LABEL))
        draw.text((i * cell[0] + 8, 8), label, fill=GOLD, font=FONT)
    path = os.path.join(OUT, "compare_distance.png")
    sheet.save(path)
    return path


def poses_sheet():
    folder = os.path.join(PREMIUM, "lookdev", "after_poses")
    if not os.path.isdir(folder):
        return None
    pattern = re.compile(r"(\w+?)_(\d+)_(tq|side)\.png")
    order = ["Idle", "Attack", "Skill", "Ultimate", "Defend", "Hit", "Defeat"]
    rows = {}
    for name in os.listdir(folder):
        match = pattern.fullmatch(name)
        if match:
            rows.setdefault(match.group(1), []).append((int(match.group(2)), match.group(3), name))
    thumb = (160, 200)
    columns = max(len(v) for v in rows.values())
    sheet = Image.new("RGB", (120 + columns * thumb[0], len(order) * (thumb[1] + 4)), BACKGROUND)
    draw = ImageDraw.Draw(sheet)
    for r, animation in enumerate(order):
        y = r * (thumb[1] + 4)
        draw.text((10, y + thumb[1] // 2), animation, fill=GOLD, font=FONT)
        for c, (frame, view, name) in enumerate(sorted(rows.get(animation, []), key=lambda e: (e[0], e[1] != "tq"))):
            x = 120 + c * thumb[0]
            sheet.paste(Image.open(os.path.join(folder, name)).convert("RGB").resize(thumb), (x, y))
            draw.text((x + 6, y + 6), f"image {frame} · {view}", fill=(220, 225, 240), font=FONT)
    path = os.path.join(OUT, "poses_after.png")
    sheet.save(path)
    return path


def main():
    os.makedirs(OUT, exist_ok=True)
    lookdev = os.path.join(PREMIUM, "lookdev")
    outputs = [
        rows_sheet(
            [
                ("PRODUCTION V0.2.2 (F001_Kael) · contrôle Workbench", [(os.path.join(PRODUCTION, f"kael_{v}.png"), l) for v, l in VIEWS]),
                ("PREMIUM v2 (F001_Kael_Premium) · contrôle Workbench", [(os.path.join(PREMIUM, "renders", f"kael_{v}.png"), l) for v, l in VIEWS]),
            ],
            "compare_workbench.png",
        ),
        rows_sheet(
            [(title, [(os.path.join(lookdev, f"{tag}_{v}.png"), l) for v, l in VIEWS]) for tag, title in VERSIONS],
            "compare_lookdev.png",
        ),
        distance_sheet(),
        combat_sheet(),
        poses_sheet(),
    ]
    for path in outputs:
        if path:
            print(path)


if __name__ == "__main__":
    main()
