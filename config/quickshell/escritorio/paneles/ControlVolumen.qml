// Icono (clic = silenciar) + deslizador + porcentaje para un nodo de PipeWire
import QtQuick
import Quickshell.Services.Pipewire
import qs.Comun

Item {
    id: control

    property var nodo: null
    property string icono: ""
    property string iconoSilencio: ""
    property color colorIcono: Tema.verde

    readonly property bool listo: nodo !== null && nodo.audio !== null
    readonly property bool silenciado: listo && nodo.audio.muted
    readonly property real volumen: listo ? nodo.audio.volume : 0

    width: parent ? parent.width : 300
    height: 32

    Text {
        id: botonSilencio
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: 26
        horizontalAlignment: Text.AlignHCenter
        text: control.silenciado ? control.iconoSilencio : control.icono
        color: control.silenciado ? Tema.error : control.colorIcono
        font.family: Tema.fuenteBarra
        font.pixelSize: 18

        MouseArea {
            anchors.fill: parent
            anchors.margins: -4
            cursorShape: Qt.PointingHandCursor
            onClicked: if (control.listo) control.nodo.audio.muted = !control.nodo.audio.muted
        }
    }

    Deslizador {
        anchors.left: botonSilencio.right
        anchors.leftMargin: 10
        anchors.right: porcentaje.left
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        valor: control.volumen
        apagado: control.silenciado
        colorRelleno: control.colorIcono
        onMovido: v => { if (control.listo) control.nodo.audio.volume = v; }
    }

    Text {
        id: porcentaje
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 40
        horizontalAlignment: Text.AlignRight
        text: Math.round(control.volumen * 100) + "%"
        color: control.silenciado ? Tema.tenue : Tema.texto
        font.family: Tema.fuenteBarra
        font.pixelSize: 12
        font.bold: true
    }
}
