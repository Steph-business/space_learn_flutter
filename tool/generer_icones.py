"""Fabrique les carrés d'icône et de splash à partir du logo sans écriture.

Android et iOS refusent — ou déforment — une source rectangulaire, et le logo
livré fait 3508x2480 dont un bon tiers de bordure transparente. On la retire,
puis on recentre le dessin dans un carré, avec la marge que réclame chaque
cible :

  app_icon.png             1024  88 %  icône iOS et icône Android héritée
  app_icon_foreground.png  1024  54 %  premier plan adaptatif : la zone sûre
                                       est un cercle de 72 dp sur 108, donc
                                       c'est la diagonale du logo, pas sa
                                       largeur, qui doit y tenir
  splash_logo.png          1152  52 %  splash Android 12
  splash_icon.png           704  85 %  splash des versions antérieures et iOS

Les deux dernières valeurs ne sont pas libres : elles sont choisies pour que le
logo mesure 150 dp de large partout, y compris sur le SplashScreen Dart qui
prend le relais. Android 12 rend l'icône sans fond sur un carré de 288 dp, soit
4 px par dp ici : 1152 x 0,52 / 4 = 150 dp, et le dessin tient dans le cercle
de 192 dp (768 px) auquel le système peut le réduire. Le splash hérité et iOS
prennent la source pour du xxxhdpi et la divisent par quatre : 704 x 0,85 / 4 =
150 dp. Sans cet accord le logo grossissait de moitié d'un écran à l'autre.

Après exécution :
    flutter pub get
    dart run flutter_launcher_icons
    dart run flutter_native_splash:create
"""

from pathlib import Path

from PIL import Image

RACINE = Path(__file__).resolve().parent.parent
SOURCE = RACINE / "asset" / "logo_sp.png"

# Le fichier livré porte, hors du dessin, des poussières à peine opaques. Un
# recadrage sur alpha > 0 les gardait et rendait la bordure transparente d'un
# quart plus large que le dessin : toutes les tailles calculées ensuite étaient
# trop petites d'autant.
SEUIL_ALPHA = 32

CIBLES = [
    ("app_icon.png", 1024, 0.88),
    ("app_icon_foreground.png", 1024, 0.54),
    ("splash_logo.png", 1152, 0.52),
    ("splash_icon.png", 704, 0.85),
]


def main() -> None:
    source = Image.open(SOURCE).convert("RGBA")
    opaque = source.split()[3].point(lambda v: 255 if v > SEUIL_ALPHA else 0)
    logo = source.crop(opaque.getbbox())

    for nom, taille, ratio in CIBLES:
        largeur, hauteur = logo.size
        echelle = taille * ratio / max(largeur, hauteur)
        redimensionne = logo.resize(
            (round(largeur * echelle), round(hauteur * echelle)), Image.LANCZOS
        )
        carre = Image.new("RGBA", (taille, taille), (0, 0, 0, 0))
        carre.paste(
            redimensionne,
            ((taille - redimensionne.width) // 2, (taille - redimensionne.height) // 2),
            redimensionne,
        )
        destination = RACINE / "asset" / nom
        carre.save(destination)
        print(f"{destination.relative_to(RACINE)} : {taille}x{taille}")


if __name__ == "__main__":
    main()
