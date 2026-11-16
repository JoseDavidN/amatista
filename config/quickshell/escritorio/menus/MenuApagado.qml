// ==========================================================
// Menu de apagado (reemplaza al powermenu de rofi)
// - Bloquear, suspender, cerrar sesion, reiniciar, apagar
// - Cerrar sesion, reiniciar y apagar piden confirmacion
// - Teclas: flechas o Tab para moverse, 1-5 para elegir directo,
//   Enter para ejecutar, Escape para cancelar o cerrar
//
//   qs -c escritorio ipc call menuApagado alternar
// ==========================================================
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Comun

Scope {
    id: menu

    readonly property string home: Quickshell.env("HOME")
    readonly property int tamanoBoton: 64
    readonly property int espacio: 12

    property int seleccion: 0
    property string porConfirmar: ""
    property string tiempoEncendido: ""

    readonly property var opciones: [
        { id: "bloquear",  icono: "",    texto: "Bloquear",      confirmar: false, peligro: false },
        { id: "suspender", icono: "󰤄",   texto: "Suspender",     confirmar: false, peligro: false },
        { id: "salir",     icono: "",  texto: "Cerrar sesión", confirmar: true,  peligro: false },
        { id: "reiniciar", icono: "󰜉", texto: "Reiniciar",     confirmar: true,  peligro: false },
        { id: "apagar",    icono: "⏻",   texto: "Apagar",        confirmar: true,  peligro: true }
    ]

    readonly property var actual: opciones[seleccion]

    function mover(paso) {
        seleccion = (seleccion + paso + opciones.length) % opciones.length;
        porConfirmar = ""
    }

    function ejecutar(o) {
        if (!o) return;
        if (o.confirmar && porConfirmar !== o.id) {
            porConfirmar = o.id;
            return;
        }
        sup.cerrar();

        if (o.id === "bloquear") {
            Quickshell.execDetached([home + "/.local/bin/bloquear"]);
        } else if (o.id === "suspender") {
            Quickshell.execDetached(["sh", "-c", "\"$HOME/.local/bin/bloquear\" & sleep 1; systemctl suspend"]);
        } else if (o.id === "salir") {
            // Cierra Hyprland de forma ordenada; greetd vuelve a mostrar el inicio de sesion.
            // Con uwsm se usa "uwsm stop"; si Hyprland no responde, se termina la sesion de logind.
            Quickshell.execDetached(["sh", "-c", "if command -v uwsm >/dev/null 2>&1 && uwsm check is-active >/dev/null 2>&1; then uwsm stop; else hyprctl dispatch 'hl.dsp.exit()' || loginctl terminate-session \"$XDG_SESSION_ID\"; fi"]);
        } else if (o.id === "reiniciar") {
            Quickshell.execDetached(["systemctl", "reboot"]);
        } else if (o.id === "apagar") {
            Quickshell.execDetached(["systemctl", "poweroff"]);
        }
    }

    // Tiempo encendido: "3h 12m"
    Process {
        id: lecturaUptime
        command: ["cat", "/proc/uptime"]
        stdout: StdioCollector {
            onStreamFinished: {
                const s = Math.floor(parseFloat(this.text) || 0);
                const h = Math.floor(s / 3600);
                const m = Math.floor((s % 3600) / 60);
                menu.tiempoEncendido = h > 0 ? h + "h " + m + "m" : m + "m";
            }
        }
    }

    IpcHandler {
        target: "menuApagado"
        function alternar(): void { sup.alternar(); }
        function abrir(): void { sup.abrir(); }
        function cerrar(): void { sup.cerrar(); }
    }

    Superposicion {
        id: sup
        ancho: menu.opciones.length * menu.tamanoBoton + (menu.opciones.length - 1) * menu.espacio + 36

        onAbrio: {
            menu.seleccion = 0;
            menu.porConfirmar = "";
            lecturaUptime.runnig = true;
            Qt.callLater(() => teclado.forceActiveFocus());
        }

        // ---------- Encabezado ----------
        Item {
            width: parent.width
            height: 20

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "Sesión"
                color: Tema.acento
                font.family: Tema.fuenteBarra
                font.pixelSize: 14
                font.bold: true
            }

            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: menu.tiempoEncendido
                color: Tema.tenue
                font.family: Tema.fuenteBarra
                font.pixelSize: 12
            }
        }
        
        // ---------- Botones ----------
        Row {
            id: teclado

            anchors.horizontalCenter: parent.horizontalCenter
            spacing: menu.espacio
            focus: true

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    if (menu.porConfirmar !== "") menu.porConfirmar = "";
                    else sup.cerrar();
                } else if (event.key === Qt.Key_Right || event.key === Qt.Key.Tab || event.key === Qt.Key_L) {
                    menu.mover(1);
                } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Backtab || event.key === Qt.Key_H) {
                    menu.mover(-1);
                } else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_5) {
                    menu.seleccion = event.key - Qt.Key_1;
                    menu.porConfirmar = "";
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                    menu.ejecutar(menu.actual);
                } else {
                    return;
                }
                event.accepted = true;
            }

            Repeater {
                model: menu.opciones

                delegate: Rectangle {
                    id: boton

                    required property var modelData
                    required property int index

                    readonly property bool elegido: index === menu.seleccion
                    readonly property bool confirmando: menu.porConfirmar === modelData.id

                    width: menu.tamanoBoton
                    height: menu.tamanoBoton
                    radius: 16
                    color: confirmando ? Tema.error
                         : elegido ? (modelData.peligro ? Tema.conAlfa(Tema.error, 0.30) : Tema.acento)
                         : zona.containsMouse ? Tema.campoHover
                         : Tema.campo
                    border.width: elegido && !confirmando ? 0 : 1
                    border.color: modelData.peligro ? Tema.conAlfa(Tema.error, 0.45) : Tema.borde
                    scale: zona.pressed ? 0.94 : elegido ? 1.06 : 1

                    Behavior on color { ColorAnimation {duration: 140 } }
                    Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

                    Text {
                        anchors.centerIn: parent
                        text: boton.confirmando ? "󰀪" : boton.modelData.icono
                        color: boton.confirmando || (boton.elegido && !boton.modelData.peligro) ? Tema.fondo
                             : boton.modelData.peligro ? Tema.error
                             : Tema.texto
                        font.family: Tema.fuenteBarra
                        font.pixelSize: 26
                    }

                    MouseArea {
                        id: zona
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: {
                            if (menu.seleccion !== boton.index) menu.porConfirmar = "";
                            menu.seleccion = boton.index;
                        }
                        onClicked: menu.ejecutar(boton.modelData)
                    }
                }
            }
        }

        // ---------- Nombre de la opcion elegida ----------
        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: menu.porConfirmar !== ""
                ? menu.actual.texto + ": preciona otra vez para confirmar"
                : menu.actual.texto
            color: menu.porConfirmar !== "" || menu.actual.peligro ? Tema.error : Tema.texto
            font.family: Tema.fuenteBarra
            font.pixelSize: 13
            font.bold: true
        }

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: "←→ moverse   ·   1-5 elegir   ·   Enter   ·   Esc"
            color: Tema.tenue
            font.family: Tema.fuenteBarra
            font.pixelSize: 11
        }
    }
}
