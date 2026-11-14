// ==========================================================
// Pildora generica de la barra: icono + texto, hover, clics,
// rueda del raton y tooltip. Todos los modulos la usan.
// ==========================================================
import QtQuick
import Quickshell
import qs.Comun

Rectangle {
    id: pildora

    property string icono: ""
    property color colorIcono: Tema.textoBarra
    property int tamanoIcono: 16
    property string texto: ""
    property color colorTexto: Tema.textoBarra
    // Segundo bloque opcional (por ejemplo, el reloj: hora + fecha)
    property string icono2: ""
    property color colorIcono2: Tema.textoBarra
    property string texto2: ""
    property string tooltip: ""
    property int relleno: 10
    property color colorFondo: Tema.pildora
    property color colorHover: Tema.pildoraHover
    property bool conHover: true
    // Resaltada mientras su panel esta abierto
    property bool activa: false

    signal clicIzquierdo()
    signal clicDerecho()
    signal clicCentral()
    signal rueda(int pasos)   // +1 hacia arriba, -1 hacia abajo

    readonly property bool encima: zona.containsMouse

    implicitWidth: fila.implicitWidth + relleno * 2
    implicitHeight: Tema.altoPildora
    radius: Tema.radioPildora
    color: (conHover && encima) || activa ? colorHover : colorFondo

    Behavior on color { ColorAnimation { duration: 120 } }
    Behavior on implicitWidth { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

    Row {
        id: fila
        anchors.centerIn: parent
        spacing: 8

        Text {
            visible: pildora.icono !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: pildora.icono
            color: pildora.colorIcono
            font.family: Tema.fuenteBarra
            font.pixelSize: pildora.tamanoIcono
        }

        Text {
            visible: pildora.texto !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: pildora.texto
            color: pildora.colorTexto
            font.family: Tema.fuenteBarra
            font.pixelSize: 14
            font.bold: true
        }

        Item {
            visible: pildora.icono2 !== "" || pildora.texto2 !== ""
            width: 6
            height: 1
        }

        Text {
            visible: pildora.icono2 !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: pildora.icono2
            color: pildora.colorIcono2
            font.family: Tema.fuenteBarra
            font.pixelSize: pildora.tamanoIcono
        }

        Text {
            visible: pildora.texto2 !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: pildora.texto2
            color: pildora.colorTexto
            font.family: Tema.fuenteBarra
            font.pixelSize: 14
            font.bold: true
        }
    }

    MouseArea {
        id: zona
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor

        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) pildora.clicDerecho();
            else if (mouse.button === Qt.MiddleButton) pildora.clicCentral();
            else pildora.clicIzquierdo();
        }

        onWheel: wheel => {
            if (wheel.angleDelta.y > 0) pildora.rueda(1);
            else if (wheel.angleDelta.y < 0) pildora.rueda(-1);
        }
    }

    // El tooltip aparece tras medio segundo con el raton encima
    Timer {
        id: retardo
        interval: 500
        running: pildora.encima && pildora.tooltip !== "" && !pildora.activa
    }

    Tooltip {
        objetivo: pildora
        texto: pildora.tooltip
        activo: pildora.encima && !retardo.running && pildora.tooltip !== "" && !pildora.activa
    }
}
