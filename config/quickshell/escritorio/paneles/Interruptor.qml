// Interruptor de encendido / apagado
import QtQuick
import qs.Comun

Rectangle {
    id: sw

    property bool activo: false
    signal alternado()

    width: 42
    height: 24
    radius: 12
    color: activo ? Tema.acento : Tema.campo
    border.width: 1
    border.color: activo ? Tema.acento : Tema.borde

    Behavior on color { ColorAnimation { duration: 160 } }

    Rectangle {
        width: 18
        height: 18
        radius: 9
        y: 3
        x: sw.activo ? sw.width - width - 3 : 3
        color: sw.activo ? Tema.fondo : Tema.tenue

        Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: sw.alternado()
    }
}
