"""Planches de la validation Studio (captures réelles de Roblox Studio).

    python art/kael/anime_fantasy/studio_sheets.py

Lit build/studio/*.jpg (captures prises dans Studio avec Dev/ArenaBench) et écrit
build/sheets/studio_*.png. Les images ne sont pas retouchées : seulement
assemblées et légendées.
"""

import os

from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "build", "studio")
OUT = os.path.join(HERE, "build", "sheets")
BG = (18, 20, 34)
FG = (235, 235, 245)
MUTED = (160, 165, 190)
PAD = 14


def font(size):
    for name in ("segoeui.ttf", "arial.ttf"):
        try:
            return ImageFont.truetype(os.path.join("C:/Windows/Fonts", name), size)
        except OSError:
            continue
    return ImageFont.load_default()


TITLE, LABEL, NOTE = font(30), font(20), font(16)


def load(name, height=None):
    image = Image.open(os.path.join(SRC, name + ".jpg")).convert("RGB")
    if height and image.height != height:
        image = image.resize((round(image.width * height / image.height), height), Image.LANCZOS)
    return image


def sheet(path, title, note, rows):
    """rows : liste de (légende de ligne, [(image, légende)])."""
    label_h = 30
    row_w = [sum(img.width for img, _ in cells) + PAD * (len(cells) - 1) for _, cells in rows]
    width = max(row_w) + PAD * 2
    height = 90 + sum(max(img.height for img, _ in cells) + label_h + 40 for _, cells in rows) + 30
    canvas = Image.new("RGB", (width, height), BG)
    draw = ImageDraw.Draw(canvas)
    draw.text((PAD, 12), title, font=TITLE, fill=FG)
    draw.text((PAD, 52), note, font=NOTE, fill=MUTED)
    y = 90
    for caption, cells in rows:
        draw.text((PAD, y), caption, font=LABEL, fill=(255, 200, 140))
        y += 30
        x = PAD
        for img, label in cells:
            canvas.paste(img, (x, y))
            draw.text((x, y + img.height + 4), label, font=NOTE, fill=FG)
            x += img.width + PAD
        y += max(img.height for img, _ in cells) + label_h + 10
    canvas.save(path)
    print(path, canvas.size)


def main():
    os.makedirs(OUT, exist_ok=True)
    sheet(
        os.path.join(OUT, "studio_combat_pc.png"),
        "Studio : caméra de combat, densité 1080p (recadrage central à taille réelle)",
        "Arène réelle, 5 contre 5, plaques du jeu. Kael allié de dos (devant) et ennemi de face (derrière la plaque).",
        [
            (
                "Effets complets",
                [
                    (load("pc_V022_A_full"), "V0.2.2 (production), A"),
                    (load("pc_P1_A_full"), "Passe 1, A"),
                    (load("pc_P2_A_full"), "Passe 2, A : éclairage actuel"),
                    (load("pc_P2_B5_full"), "Passe 2, B : contre-jour (SpotLight 5)"),
                    (load("pc_P2_C_full"), "Passe 2, C : contour fin des alliés"),
                ],
            ),
            (
                "Effets réduits (lumières dynamiques et particules coupées)",
                [
                    (load("pc_V022_A_reduced"), "V0.2.2, A"),
                    (load("pc_P1_A_reduced"), "Passe 1, A"),
                    (load("pc_P2_A_reduced"), "Passe 2, A"),
                    (load("pc_P2_C_reduced"), "Passe 2, C (B = A : lumières coupées)"),
                    (load("pc_P2_C_reduced_arenalight"), "Passe 2, C + lumière d'arène gardée"),
                ],
            ),
        ],
    )
    sheet(
        os.path.join(OUT, "studio_combat_mobile.png"),
        "Studio : émulateur iPhone 13, paysage 844 × 390 (zone sûre 749 × 389)",
        "Captures agrandies × 1,37 par l'affichage de l'émulateur.",
        [
            (
                "Effets complets",
                [
                    (load("mobile_V022_A_full", 360), "V0.2.2, A"),
                    (load("mobile_P2_A_full", 360), "Passe 2, A"),
                    (load("mobile_P2_C_full", 360), "Passe 2, C"),
                ],
            ),
            (
                "Effets réduits",
                [
                    (load("mobile_P2_A_reduced", 360), "Passe 2, A : Kael allié se fond dans le sol"),
                    (load("mobile_P2_C_reduced", 360), "Passe 2, C : silhouette conservée"),
                ],
            ),
        ],
    )
    sheet(
        os.path.join(OUT, "studio_versions.png"),
        "Studio : V0.2.2, passe 1 et passe 2 côte à côte (éclairage de l'arène)",
        "De face, de gauche à droite : V0.2.2, passe 1, passe 2. De dos, l'ordre est inversé.",
        [
            ("Face et trois-quarts", [(load("versions_front", 380), "Face"), (load("versions_three", 380), "Trois-quarts")]),
            ("Dos", [(load("versions_back", 380), "Dos : passe 2, passe 1, V0.2.2")]),
            ("Visages", [(load("versions_faces", 420), "V0.2.2, passe 1, passe 2")]),
        ],
    )
    sheet(
        os.path.join(OUT, "studio_animations.png"),
        "Studio : les 7 animations converties, jouées par l'Animator sur le maillage importé",
        "Ligne 1 : figées à l'instant clé (Kael ennemi, Highlight corail du jeu). "
        "Ligne 2 : captures pendant la lecture, caméra de combat 1080p.",
        [
            (
                "Poses figées",
                [
                    (load("close_enemy_front", 413), "Idle"),
                    (load("anim_Attack"), "Attack 0,27 s"),
                    (load("anim_Skill"), "Skill 0,53 s"),
                    (load("anim_Ultimate"), "Ultimate 0,8 s"),
                    (load("anim_Defend"), "Defend 0,45 s"),
                    (load("anim_Hit"), "Hit 0,2 s"),
                    (load("anim_Defeat"), "Defeat 1,3 s"),
                ],
            ),
            (
                "En lecture (deux Kael)",
                [
                    (load("live_Ultimate"), "Ultimate"),
                    (load("live_Skill"), "Skill"),
                    (load("live_Attack"), "Attack"),
                    (load("check_Skill_cape", 379), "Skill 0,67 s : bras dans la cape"),
                    (load("check_Defeat_end", 379), "Defeat, fin"),
                ],
            ),
        ],
    )
    sheet(
        os.path.join(OUT, "studio_closeups.png"),
        "Studio : gros plans et matières (éclairage du jeu, effets complets)",
        "Kael ennemi : teinte corail du Highlight du jeu (remplissage 85 % transparent).",
        [
            (
                "Gros plans",
                [
                    (load("close_face", 560), "Visage (ennemi)"),
                    (load("close_enemy_front", 560), "Face (ennemi)"),
                    (load("close_ally_back", 560), "Dos (allié)"),
                ],
            )
        ],
    )

    sheet(
        os.path.join(OUT, "studio_pass3.png"),
        "Studio : passe 2 contre passe 3 (retouche de texture), mêmes cadrages et éclairage du jeu",
        "Passe 3 : lame à âme incandescente, sous-armure noir chaud, cuir plus clair, flammes de l'ourlet éclaircies, "
        "traits du visage plus marqués, lueur cuite en superposition à 0,9.",
        [
            (
                "Gros plans, effets complets",
                [
                    (load("p3cmp_enemy_P2", 470), "Passe 2"),
                    (load("p3cmp_enemy_P3", 470), "Passe 3"),
                    (load("p3cmp_back_P2_full", 470), "Passe 2, dos"),
                    (load("p3cmp_back_P3_full", 470), "Passe 3, dos"),
                    (load("p3cmp_back_P2_reduced", 470), "Passe 2, dos, effets réduits"),
                    (load("p3cmp_back_P3_reduced", 470), "Passe 3, dos, effets réduits"),
                ],
            ),
            (
                "Visage (ennemi : remplissage corail du Highlight)",
                [(load("p3cmp_face_P2", 420), "Passe 2"), (load("p3cmp_face_P3", 420), "Passe 3")],
            ),
            (
                "Caméra de combat, densité 1080p",
                [
                    (load("pc_P2_A_full"), "Passe 2, A, complets"),
                    (load("pc_P3_A_full"), "Passe 3, A, complets"),
                    (load("pc_P2_A_reduced"), "Passe 2, A, réduits"),
                    (load("pc_P3_A_reduced"), "Passe 3, A, réduits"),
                    (load("pc_P3_C_reduced"), "Passe 3, C, réduits"),
                    (load("pc_P3_C_reduced_arenalight"), "Passe 3, C, réduits + lumière d'arène"),
                ],
            ),
            (
                "Mobile 844 × 390",
                [
                    (load("mobile_P2_A_reduced", 300), "Passe 2, A, réduits"),
                    (load("mobile_P3_A_reduced", 300), "Passe 3, A, réduits"),
                    (load("mobile_P3_C_reduced", 300), "Passe 3, C, réduits"),
                ],
            ),
        ],
    )

    sheet(
        os.path.join(OUT, "studio_game_outline.png"),
        "Studio, vrai combat (Play) : contour fin des alliés et lumière d'arène gardée en effets réduits",
        "Jeu réel : équipe du profil de test (Kael V0.2.2 de production), rencontre « Faille instable », caméra et interface du jeu.",
        [
            (
                "Effets complets",
                [
                    (load("game_full", 420), "Tour 1"),
                    (load("game_full_turn", 420), "Résolution du tour (impacts)"),
                ],
            ),
            (
                "Effets réduits (option du joueur) : lumières des combattants coupées, lumière d'arène gardée",
                [
                    (load("game_reduced", 420), "Tour 1"),
                    (load("game_reduced_crop", 420), "Détail"),
                ],
            ),
            ("Mobile 844 × 390, effets réduits", [(load("game_mobile_reduced", 420), "iPhone 13 (émulateur)")]),
        ],
    )

    sheet(
        os.path.join(OUT, "studio_finalisation.png"),
        "Studio : finalisation avant intégration (Skill, LOD, plaques)",
        "Captures réelles de Roblox Studio. Skill et LOD : banc d'essai ; plaques : vrai combat (Play) et banc.",
        [
            (
                "Skill : bras devant la cape (avant : passe 2, après : correction)",
                [
                    (load("check_Skill_cape", 380), "Avant, 0,67 s : bras dans la cape"),
                    (load("fix_Skill_027", 380), "Après, 0,27 s"),
                    (load("fix_Skill_067_three", 380), "Après, 0,67 s"),
                    (load("fix_Skill_100", 380), "Après, 1,0 s"),
                    (load("fix_Skill_067_front", 380), "Après, 0,67 s, de face"),
                ],
            ),
            (
                "Modèle principal (13 266 triangles) contre LOD (5 199)",
                [
                    (load("lod_front", 360), "Face : principal à gauche, LOD à droite"),
                    (load("lod_faces", 360), "Visages : principal, LOD"),
                    (load("lod_combat_main_crop", 360), "Combat 1080p : principal"),
                    (load("lod_combat_lod_crop", 360), "Combat 1080p : LOD"),
                ],
            ),
            (
                "Plaques : avant (au-dessus de tous) et après (alliés avant au sol), vrai combat",
                [
                    (load("game_full", 380), "Avant : la plaque de l'allié central masque l'ennemi central"),
                    (load("plates_game_pc", 380), "Après : ennemis dégagés"),
                    (load("plates_game_select", 380), "Après : sélection de Terra par sa plaque"),
                ],
            ),
            (
                "Mobile 844 × 390",
                [
                    (load("plates_game_mobile", 330), "Vrai combat, après"),
                    (load("plates_bench_mobile", 330), "Banc, Kael AF des deux côtés"),
                    (load("plates_bench_mobile_reduced_lod", 330), "Banc, effets réduits + LOD"),
                ],
            ),
        ],
    )


if __name__ == "__main__":
    main()
