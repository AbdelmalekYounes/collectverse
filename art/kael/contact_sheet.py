"""Planche de contrôle : assemble les rendus de kael_build.py en une seule image.

    python art/kael/contact_sheet.py art/kael/build

Produit renders/kael_contact_sheet.png (vues + une pose clé par animation), pour
relire le modèle et les animations d'un coup d'œil.
"""

import os
import sys

from PIL import Image, ImageDraw

ORDER = [
    ("kael_front.png", "Face"),
    ("kael_three_quarter.png", "Trois quarts"),
    ("kael_side.png", "Profil"),
    ("kael_back.png", "Dos"),
    ("kael_pose_Idle.png", "Idle"),
    ("kael_pose_Attack.png", "Attack"),
    ("kael_pose_Skill.png", "Skill"),
    ("kael_pose_Ultimate.png", "Ultimate"),
    ("kael_pose_Defend.png", "Defend"),
    ("kael_pose_Hit.png", "Hit"),
    ("kael_pose_Defeat.png", "Defeat"),
]
COLUMNS = 4
THUMB = (320, 400)


def main():
    build = sys.argv[1] if len(sys.argv) > 1 else "art/kael/build"
    renders = os.path.join(build, "renders")
    rows = (len(ORDER) + COLUMNS - 1) // COLUMNS
    sheet = Image.new("RGB", (COLUMNS * THUMB[0], rows * (THUMB[1] + 28)), (16, 20, 38))
    draw = ImageDraw.Draw(sheet)
    for index, (name, label) in enumerate(ORDER):
        path = os.path.join(renders, name)
        if not os.path.exists(path):
            continue
        image = Image.open(path).convert("RGB").resize(THUMB)
        x = (index % COLUMNS) * THUMB[0]
        y = (index // COLUMNS) * (THUMB[1] + 28)
        sheet.paste(image, (x, y + 28))
        draw.text((x + 10, y + 8), label, fill=(240, 191, 97))
    out = os.path.join(renders, "kael_contact_sheet.png")
    sheet.save(out)
    print(out)


if __name__ == "__main__":
    main()
