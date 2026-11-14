// Fila de una lista (dispositivo, red, salida de audio...)
import QtQuick
import qs.Comun

Rectangle {
    id: fila

    property string icono: ""
    property color colorIcono: Tema.textoBarra
    property string titulo: ""
    property string subtitulo: ""
    property color colorSubtitulo: Tema.tenue
    property string detalle: ""
    property color colorDetalle: Tema.tenue
    property bool resaltada: false

    signal clic()

    width: parent ? parent.width : 300
    height: subtitulo !== "" ? 50 : 40
    radius: 10
    color: resaltada ? Tema.campoHover : zona.containsMouse ? Tema.campo : "transparent"
    border.width: resaltada ? 1 : 0
    border.color: Tema.conAlfa(Tema.acento, 0.35)

    Behavior on color { ColorAnimation { duration: 120 } }

    Text {
        id: textoIcono
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        width: 22
        horizontalAlignment: Text.AlignHCenter
        text: fila.icono
        color: fila.colorIcono
        font.family: Tema.fuenteBarra
        font.pixelSize: 18
    }

    Column {
        anchors.left: textoIcono.right
        anchors.leftMargin: 12
        anchors.right: textoDetalle.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        Text {
            width: parent.width
            text: fila.titulo
            color: Tema.texto
            font.family: Tema.fuenteBarra
            font.pixelSize: 13
            font.bold: fila.resaltada
            elide: Text.ElideRight
        }

        Text {
            width: parent.width
            visible: fila.subtitulo !== ""
            text: fila.subtitulo
            color: fila.colorSubtitulo
            font.family: Tema.fuenteBarra
            font.pixelSize: 11
            elide: Text.ElideRight
        }
    }

    Text {
        id: textoDetalle
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        text: fila.detalle
        color: fila.colorDetalle
        font.family: Tema.fuenteBarra
        font.pixelSize: 14
    }

    MouseArea {
        id: zona
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: fila.clic()
    }
}
