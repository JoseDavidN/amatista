// Deslizador (volumen, etc.): arrastrar, clic o rueda del raton
import QtQuick
import qs.Comun

Item {
    id: d

    property real valor: 0
    property real maximo: 1
    property real paso: 0.05
    property color colorRelleno: Tema.acento
    property bool apagado: false

    signal movido(real v)

    readonly property real fraccion: Math.max(0, Math.min(1, valor / maximo))

    implicitHeight: 24

    Rectangle {
        id: pista
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 6
        radius: 3
        color: Tema.campo

        Rectangle {
            width: Math.max(height, pista.width * d.fraccion)
            height: parent.height
            radius: 3
            color: d.apagado ? Tema.tenue : d.colorRelleno
        }
    }

    Rectangle {
        width: 16
        height: 16
        radius: 8
        anchors.verticalCenter: parent.verticalCenter
        x: d.fraccion * (d.width - width)
        color: Tema.texto
        opacity: zona.containsMouse || zona.pressed ? 1 : 0

        Behavior on opacity { NumberAnimation { duration: 120 } }
    }

    MouseArea {
        id: zona
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        function aplicar(x) {
            d.movido(Math.max(0, Math.min(1, x / d.width)) * d.maximo);
        }

        onPressed: m => aplicar(m.x)
        onPositionChanged: m => { if (pressed) aplicar(m.x); }
        onWheel: w => d.movido(Math.max(0, Math.min(d.maximo, d.valor + (w.angleDelta.y > 0 ? d.paso : -d.paso))))
    }
}
