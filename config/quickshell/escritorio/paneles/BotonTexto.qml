// Boton pequeno con icono y texto
import QtQuick
import qs.Comun

Rectangle {
    id: boton

    property string icono: ""
    property string texto: ""
    property bool principal: false

    signal clic()

    implicitWidth: fila.implicitWidth + 24
    implicitHeight: 32
    radius: Tema.radioPequeno
    color: principal ? (zona.containsMouse ? Qt.lighter(Tema.acento, 1.1) : Tema.acento)
                     : (zona.containsMouse ? Tema.campoHover : Tema.campo)
    border.width: principal ? 0 : 1
    border.color: Tema.borde

    Behavior on color { ColorAnimation { duration: 120 } }

    Row {
        id: fila
        anchors.centerIn: parent
        spacing: 6

        Text {
            visible: boton.icono !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: boton.icono
            color: boton.principal ? Tema.fondo : Tema.texto
            font.family: Tema.fuenteBarra
            font.pixelSize: 14
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: boton.texto
            color: boton.principal ? Tema.fondo : Tema.texto
            font.family: Tema.fuenteBarra
            font.pixelSize: 12
            font.bold: boton.principal
        }
    }

    MouseArea {
        id: zona
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: boton.clic()
    }
}
