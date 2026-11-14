// ==========================================================
// Barra superior (reemplaza a Waybar)
// Mismo diseno que tu Waybar: flotante, 52 px de alto, 15 px desde
// arriba y 10 px a los lados, con modulos en pildoras.
//
//   Izquierda: Arch · workspaces · multimedia
//   Centro:    reloj
//   Derecha:   bateria · bluetooth · volumen · red · CPU/RAM · apagar
// ==========================================================
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Comun

Scope {
    id: raiz

    readonly property string home: Quickshell.env("HOME")

    // Una barra por monitor
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: ventana

            required property var modelData
            screen: modelData

            color: "transparent"
            WlrLayershell.namespace: "barra"
            WlrLayershell.layer: WlrLayer.Top

            anchors {
                top: true
                left: true
                right: true
            }

            margins {
                top: Tema.barraMargenArriba
                left: Tema.barraMargenLados
                right: Tema.barraMargenLados
            }

            implicitHeight: Tema.barraAlto
            exclusionMode: ExclusionMode.Auto

            // ---------- Izquierda ----------
            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: Tema.barraEspacio

                Pildora {
                    icono: "󰣇"
                    colorIcono: Tema.cian
                    tamanoIcono: 18
                    relleno: 14
                    onClicIzquierdo: Quickshell.execDetached(["qs", "-c", "escritorio", "ipc", "call", "lanzador", "alternar"])
                }

                Workspaces {}
                ModuloMultimedia {}
            }

            // ---------- Centro ----------
            ModuloReloj {
                anchors.centerIn: parent
            }

            // ---------- Derecha ----------
            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: Tema.barraEspacio

                ModuloBateria {}
                ModuloBluetooth {}
                ModuloAudio {}
                ModuloRed {}
                ModuloHardware {}

                Pildora {
                    icono: "⏻"
                    colorIcono: Tema.error
                    colorHover: Tema.pildoraPeligro
                    relleno: 14
                    onClicIzquierdo: Quickshell.execDetached(["qs", "-c", "escritorio", "ipc", "call", "menuApagado", "alternar"])
                }
            }
        }
    }
}
