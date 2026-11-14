// Titulo de una seccion dentro de un panel
import QtQuick
import qs.Comun

Item {
    property string texto: ""
    property string extra: ""

    width: parent ? parent.width : 300
    height: 20

    Text {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        text: parent.texto
        color: Tema.tenue
        font.family: Tema.fuenteBarra
        font.pixelSize: 12
        font.bold: true
    }

    Text {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        text: parent.extra
        color: Tema.tenue
        font.family: Tema.fuenteBarra
        font.pixelSize: 11
    }
}
