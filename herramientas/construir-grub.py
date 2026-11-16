#!/usr/bin/env python3
"""Construye las imágenes y fuentes del tema de GRUB "Amatista".

Uso: construir-grub.py [salida] [fondo]
     (por defecto: sistema/grub/amatista y assets/amatista.png del repo)

Genera, en la carpeta del tema:
  - fondo.png           el fondo del tema a 1920x1080, oscurecido para que el
                        menú se lea bien.
  - menu_*.png          caja de 9 piezas del panel del menú (translúcido).
  - seleccion_*.png     caja de 9 piezas de la entrada seleccionada.
  - barra_*.png         fondo de la barra del temporizador.
  - barra_luz_*.png     relleno de la barra del temporizador.
  - desliz_*.png        marco y pulgar de la barra de desplazamiento.
  - *.pf2               fuentes de GRUB (grub-mkfont) en los tamaños del tema.

theme.txt no se genera: se mantiene a mano en la carpeta del tema. Si cambias
un tamaño de fuente aquí, cámbialo también allí (el nombre interno de cada
.pf2 es "Familia Estilo Tamaño", por ejemplo "Noto Sans Bold 20").

Necesita: rsvg-convert (librsvg) y grub-mkfont (grub).
"""
import base64, os, subprocess, sys, tempfile

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SALIDA = sys.argv[1] if len(sys.argv) > 1 else os.path.join(REPO, "sistema/grub/amatista")
FONDO = sys.argv[2] if len(sys.argv) > 2 else os.path.join(REPO, "assets/amatista.png")

ANCHO, ALTO = 1920, 1080

# Paleta del tema (config/quickshell/escritorio/Comun/Tema.qml)
FONDO_OSCURO = "#1e1530"
FONDO_BASE = "#2a1f3d"
CAMPO = "#40305c"
BORDE = "#52406f"
ACENTO = "#b98cff"

# Fuentes: (archivo .ttf, nombre del .pf2, tamaño, rango de glifos o None)
NOTO = "/usr/share/fonts/noto/NotoSans-%s.ttf"
JETBRAINS = "/usr/share/fonts/TTF/JetBrainsMonoNerdFont-Regular.ttf"
# Latín, latín extendido, puntuación, flechas y cajas: suficiente para GRUB
# y mucho más ligero que meter la fuente entera.
RANGOS = ["0x20-0x24F", "0x2000-0x206F", "0x20AC-0x20AC", "0x2190-0x21FF", "0x2300-0x23FF",
          "0x2500-0x259F", "0x25A0-0x25FF"]
FUENTES = [
    (NOTO % "Regular", "noto_regular_16", 16),
    (NOTO % "Regular", "noto_regular_20", 20),
    (NOTO % "Bold", "noto_bold_20", 20),
    (NOTO % "Bold", "noto_bold_40", 40),
    (JETBRAINS, "jetbrains_regular_16", 16),  # línea de ayuda (tiene flechas)
    (JETBRAINS, "jetbrains_regular_18", 18),  # consola y editor de GRUB
]


def rasterizar(svg, destino, ancho=None, alto=None):
    """Convierte un SVG (texto) en PNG con rsvg-convert."""
    orden = ["rsvg-convert", "-o", destino]
    if ancho:
        orden += ["-w", str(ancho), "-h", str(alto)]
    subprocess.run(orden, input=svg.encode(), check=True)


def caja_9_piezas(prefijo, lado, radio, relleno, opacidad=1.0, borde=None, grosor=0):
    """Dibuja un rectángulo redondeado y lo corta en las 9 piezas de GRUB.

    Las esquinas miden `radio` px; los bordes n/s/e/w y el centro son tiras
    de 1 px que GRUB estira. Cada pieza se rasteriza recortando el mismo SVG
    con un viewBox distinto, así no hace falta decodificar PNG.
    """
    t = lado
    m = grosor / 2
    trazo = f'stroke="{borde}" stroke-width="{grosor}"' if borde else ""
    figura = (f'<rect x="{m}" y="{m}" width="{t - grosor}" height="{t - grosor}" '
              f'rx="{radio - m}" fill="{relleno}" fill-opacity="{opacidad}" {trazo}/>')
    c, r = t / 2, radio
    piezas = {  # nombre: (x, y, ancho, alto)
        "nw": (0, 0, r, r), "n": (c, 0, 1, r), "ne": (t - r, 0, r, r),
        "w": (0, c, r, 1), "c": (c, c, 1, 1), "e": (t - r, c, r, 1),
        "sw": (0, t - r, r, r), "s": (c, t - r, 1, r), "se": (t - r, t - r, r, r),
    }
    for nombre, (x, y, w, h) in piezas.items():
        svg = (f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" '
               f'viewBox="{x} {y} {w} {h}">{figura}</svg>')
        rasterizar(svg, os.path.join(SALIDA, f"{prefijo}_{nombre}.png"))


def fondo():
    """Fondo de pantalla a 1920x1080 con un velo oscuro y viñeta central."""
    with open(FONDO, "rb") as f:
        datos = base64.b64encode(f.read()).decode()
    svg = f'''<svg xmlns="http://www.w3.org/2000/svg"
      xmlns:xlink="http://www.w3.org/1999/xlink" width="{ANCHO}" height="{ALTO}">
  <defs>
    <radialGradient id="vineta" cx="50%" cy="48%" r="60%">
      <stop offset="0" stop-color="{FONDO_OSCURO}" stop-opacity="0.55"/>
      <stop offset="1" stop-color="{FONDO_OSCURO}" stop-opacity="0.15"/>
    </radialGradient>
  </defs>
  <image width="{ANCHO}" height="{ALTO}" preserveAspectRatio="xMidYMid slice"
         xlink:href="data:image/png;base64,{datos}"/>
  <rect width="100%" height="100%" fill="{FONDO_OSCURO}" fill-opacity="0.30"/>
  <rect width="100%" height="100%" fill="url(#vineta)"/>
</svg>'''
    rasterizar(svg, os.path.join(SALIDA, "fondo.png"), ANCHO, ALTO)


def fuentes():
    for ttf, nombre, tamano in FUENTES:
        destino = os.path.join(SALIDA, nombre + ".pf2")
        orden = ["grub-mkfont", "-s", str(tamano), "-o", destino]
        for rango in RANGOS:
            orden += ["-r", rango]
        # grub-mkfont avisa de muchas características OpenType que ignora;
        # solo se muestra su salida si falla.
        r = subprocess.run(orden + [ttf], capture_output=True, text=True)
        if r.returncode != 0:
            sys.exit(f"grub-mkfont falló con {ttf}:\n{r.stderr}")


def main():
    os.makedirs(SALIDA, exist_ok=True)
    fondo()
    # Panel translúcido del menú, con borde fino.
    caja_9_piezas("menu", 64, 20, FONDO_OSCURO, 0.82, BORDE, 2)
    # Entrada seleccionada: campo morado con borde de acento.
    caja_9_piezas("seleccion", 40, 10, CAMPO, 1.0, ACENTO, 2)
    # Barra del temporizador (fondo y relleno).
    caja_9_piezas("barra", 12, 3, CAMPO)
    caja_9_piezas("barra_luz", 12, 3, ACENTO)
    # Barra de desplazamiento del menú (marco casi invisible y pulgar).
    caja_9_piezas("desliz_marco", 12, 3, FONDO_BASE, 0.6)
    caja_9_piezas("desliz_pulgar", 12, 3, BORDE)
    fuentes()
    print("Tema de GRUB construido en", SALIDA)


if __name__ == "__main__":
    main()
