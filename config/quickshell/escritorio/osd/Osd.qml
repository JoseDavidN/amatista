// ==========================================================
// Indicador en pantalla (OSD) de volumen y brillo
// - Volumen: aparece solo, cada vez que cambia (teclas, rueda, panel...)
// - Brillo: con las teclas, a traves de IPC:
//     qs -c escritorio ipc call osd brillo subir
//     qs -c escritorio ipc call osd brillo bajar
// ==========================================================
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import qs.Comun

Scope {
    id: osd

    property string tipo: "volumen"
    property real valor: 0
    property bool silenciado: false
    property bool mostrando: false

    // No mostrar nada mientras el escritorio arranca
    property bool listo: false

    readonly property var salida: Pipewire.defaultAudioSink

    PwObjectTracker {
        objects: osd.salida ? [osd.salida] : []
    }

    Timer {
        interval: 2000
        running: true
        onTriggered: osd.listo = true
    }

    function mostrar(t, v, mudo) {
        if (!listo) return;
        tipo = t;
        valor = Math.max(0, Math.min(1, v));
        silenciado = mudo;
        if (!mostrando) ventana.screen = pantallaEnfocada();
        mostrando = true;
        ocultar.restart();
    }

    function pantallaEnfocada() {
        const m = Hyprland.focusedMonitor;
        const pantallas = Quickshell.screens;
        for (let i = 0; i < pantallas.length; i++) {
            if (m && pantallas[i].name === m.name) return pantallas[i];
        }
        return pantallas.length > 0 ? pantallas[0] : null;
    }

    Connections {
        target: osd.salida && osd.salida.audio ? osd.salida.audio : null
        function onVolumeChanged() { osd.mostrar("volumen", osd.salida.audio.volume, osd.salida.audio.muted); }
        function onMutedChanged() { osd.mostrar("volumen", osd.salida.audio.volume, osd.salida.audio.muted); }
    }

    // ---------- Brillo ----------
    function cambiarBrillo(direccion) {
        const paso = direccion === "bajar" ? "5%-" : "5%+";
        procesoBrillo.command = ["sh", "-c", "brightnessctl set " + paso + " >/dev/null; brightnessctl -m"];
        procesoBrillo.running = true;
    }

    Process {
        id: procesoBrillo
        stdout: StdioCollector {
            onStreamFinished: {
                // Formato: dispositivo,clase,actual,porcentaje%,maximo
                const c = this.text.trim().split(",");
                const pct = parseInt(String(c[3] || "0").replace("%", "")) || 0;
                osd.mostrar("brillo", pct / 100, false);
            }
        }
    }

    IpcHandler {
        target: "osd"
        function brillo(direccion: string): void { osd.cambiarBrillo(direccion); }
    }

    Timer {
        id: ocultar
        interval: 1500
        onTriggered: osd.mostrando = false
    }

    // ---------- Ventana ----------
    PanelWindow {
        id: ventana

        visible: osd.mostrando || tarjeta.opacity > 0
        color: "transparent"

        WlrLayershell.namespace: "osd"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore

        anchors.bottom: true
        margins.bottom: 90

        implicitWidth: 320
        implicitHeight: 60

        // No recibe clics: todo pasa a la ventana de abajo
        mask: Region {}

        Rectangle {
            id: tarjeta

            anchors.fill: parent
            radius: height / 2
            color: Tema.fondoTarjeta
            border.width: 1
            border.color: Tema.borde
            opacity: osd.mostrando ? 1 : 0
            scale: osd.mostrando ? 1 : 0.92

            Behavior on opacity { NumberAnimation { duration: 180 } }
            Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

            Text {
                id: icono
                anchors.left: parent.left
                anchors.leftMargin: 22
                anchors.verticalCenter: parent.verticalCenter
                width: 24
                horizontalAlignment: Text.AlignHCenter
                text: osd.tipo === "brillo" ? "󰃟"
                    : osd.silenciado ? "󰖁"
                    : osd.valor < 0.34 ? "󰕿"
                    : osd.valor < 0.67 ? "󰖀"
                    : "󰕾"
                color: osd.tipo === "brillo" ? Tema.ambar : osd.silenciado ? Tema.error : Tema.verde
                font.family: Tema.fuenteBarra
                font.pixelSize: 22
            }

            Rectangle {
                id: pista
                anchors.left: icono.right
                anchors.leftMargin: 16
                anchors.right: porcentaje.left
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                height: 8
                radius: 4
                color: Tema.campo

                Rectangle {
                    width: Math.max(parent.height, parent.width * osd.valor)
                    height: parent.height
                    radius: 4
                    color: osd.tipo === "brillo" ? Tema.ambar : osd.silenciado ? Tema.tenue : Tema.verde

                    Behavior on width { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
                }
            }

            Text {
                id: porcentaje
                anchors.right: parent.right
                anchors.rightMargin: 22
                anchors.verticalCenter: parent.verticalCenter
                width: 42
                horizontalAlignment: Text.AlignRight
                text: osd.silenciado && osd.tipo === "volumen" ? "mute" : Math.round(osd.valor * 100) + "%"
                color: Tema.texto
                font.family: Tema.fuenteBarra
                font.pixelSize: 14
                font.bold: true
            }
        }
    }
}
