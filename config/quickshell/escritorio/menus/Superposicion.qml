// ==========================================================
// Ventana centrada sobre la pantalla con fondo oscurecido
// (base del lanzador y del portapapeles)
// - Se abre en el monitor que tiene el foco
// - Clic fuera de la tarjeta o Escape = cerrar
// ==========================================================
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.Comun

PanelWindow {
    id: sup

    property bool abierto: false
    property int ancho: 560
    property real posicionY: 0.22 // altura de la tarjeta (fraccion de la pantalla)
    default property alias contenido: cuerpo.data

    signal abrio()
    signal cerro()

    function pantallaEnfocada() {
        const m = Hyprland.focusedMonitor;
        const pantallas = Quickshell.screens;
        for (let i = 0; i < pantallas.length; i++) {
            if (m && pantallas[i].name === m.name) return pantallas[i];
        }
        return pantallas.length > 0 ? pantallas[0] : null;
    }

    function abrir() {
        screen = pantallaEnfocada();
        abierto = true;
        abrio();
    }

    function cerrar() {
        if (!abierto) return;
        abierto = false;
        cerro();
    }

    function alternar() {
        if (abierto) cerrar();
        else abrir();
    }

    visible: abierto
    color: "transparent"

    WlrLayershell.namespace: "superposicion"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: abierto ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    onVisibleChanged: {
        if (visible) {
            velo.opacity = 0;
            tarjeta.opacity = 0;
            tarjeta.scale = 0.96;
            entrada.restart();
        }
    }

    ParallelAnimation {
        id: entrada
        NumberAnimation { target: velo; property: "opacity"; to: 1; duration: 160 }
        NumberAnimation { target: tarjeta; property: "opacity"; to: 1; duration: 180; easing.type: Easing.OutCubic }
        NumberAnimation { target: tarjeta; property: "scale"; to: 1; duration: 200; easing.type: Easing.OutCubic }
    }

    // Fondo oscurecido: clic = cerrar
    Rectangle {
        id: velo
        anchors.fill: parent
        color: Tema.velo

        MouseArea {
            anchors.fill: parent
            onClicked: sup.cerrar()
        }
    }

    Rectangle {
        id: tarjeta

        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.round(parent.height * sup.posicionY)
        // Nunca más ancha que la pantalla (24 px de margen a cada lado)
        width: Math.min(sup.ancho, parent.width - 48)
        height: cuerpo.implicitHeight + 36
        radius: 18
        color: Tema.fondoTarjeta
        border.width: 1
        border.color: Tema.borde

        // Evita que los clics dentro de la tarjeta cierren la ventana
        MouseArea {
            anchors.fill: parent
        }

        Column {
            id: cuerpo
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 18
            spacing: 14
        }
    }
}
