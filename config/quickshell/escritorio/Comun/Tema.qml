// ==========================================================
// Tema compartido por todos los modulos del escritorio
// Paleta: Amatista (violeta de tono medio, propia)
//
// Para cambiar de tema solo se edita este archivo.
// ==========================================================
pragma Singleton

import QtQuick
import Quickshell

Singleton {
    // ---------- Fondos ----------
    readonly property color fondo:        "#2a1f3d"
    readonly property color fondoTarjeta: Qt.rgba(42 / 255, 31 / 255, 61 / 255, 0.95)
    readonly property color fondoPanel:   Qt.rgba(42 / 255, 31 / 255, 61 / 255, 0.97)
    readonly property color fondoTooltip: "#2a1f3d"
    readonly property color campo:        "#40305c"
    readonly property color campoHover:   "#4a3868"
    readonly property color borde:        "#52406f"
    readonly property color bordeFuerte:  "#6b5a8a"

    // ---------- Texto ----------
    readonly property color texto:      "#f3eaff"
    readonly property color textoBarra: "#f3eaff"
    readonly property color suave:      "#d4c2f0"
    readonly property color tenue:      "#a08cc0"

    // ---------- Acentos y estados ----------
    readonly property color acento:  "#b98cff"
    readonly property color morado:  "#d0a8ff"
    readonly property color rosa:    "#ff9ad5"
    readonly property color cian:    "#8fd3ff"
    readonly property color verde:   "#9ee6b0"
    readonly property color exito:   "#9ee6b0"
    readonly property color lima:    "#c8eba0"
    readonly property color ambar:   "#ffcf85"
    readonly property color naranja: "#ffa477"
    readonly property color durazno: "#e8b48a"
    readonly property color error:   "#ff7a9a"

    // ---------- Barra ----------
    readonly property color pildora:        "#34264b"
    readonly property color pildoraHover:   "#40305c"
    readonly property color pildoraPeligro: "#4d2a48"

    // ---------- Velo detras del lanzador y los menus ----------
    readonly property color velo: Qt.rgba(18 / 255, 10 / 255, 30 / 255, 0.40)

    // ---------- Fondo de pantalla (hyprpaper y pantalla de bloqueo) ----------
    readonly property string fondoPantalla: Quickshell.env("HOME") + "/.local/share/fondos/amatista.png"

    // Mismo color con otra transparencia: Tema.conAlfa(Tema.error, 0.3)
    function conAlfa(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a);
    }

    // ---------- Tipografia ----------
    readonly property string fuente:       "JetBrains Mono"
    readonly property string fuenteIconos: "Symbols Nerd Font"
    readonly property string fuenteBarra:  "JetBrainsMono Nerd Font"

    // ---------- Formas y medidas ----------
    readonly property int radio:             14
    readonly property int radioPequeno:      8
    readonly property int margenPantalla:    12
    readonly property int anchoNotificacion: 360

    readonly property int barraAlto:         52
    readonly property int barraMargenArriba: 15
    readonly property int barraMargenLados:  10
    readonly property int barraEspacio:      8
    readonly property int altoPildora:       40
    readonly property int radioPildora:      18
}
