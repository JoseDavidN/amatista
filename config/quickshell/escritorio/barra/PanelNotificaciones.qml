// ==========================================================
// Historial de notificaciones
// Clic en una: verla completa · X: borrarla
// ==========================================================
import QtQuick
import Quickshell
import qs.Comun
import qs.paneles
import qs.notificaciones

PanelEmergente {
    id: panel

    property real ahora: Date.now()

    function hace(hora) {
        const m = Math.floor((ahora - hora) / 60000);
        if (m < 1) return "ahora";
        if (m < 60) return "hace " + m + " min";
        const d = new Date(hora), h = new Date(ahora);
        const texto = Qt.formatTime(d, "HH:mm");
        return d.toDateString() === h.toDateString() ? texto : Qt.formatDate(d, "dd/MM") + " " + texto;
    }

    ancho: 420
    titulo: "Notificaciones"
    icono: String.fromCodePoint(Centro.noMolestar ? 0xf009b : 0xf009a)
    colorIcono: Centro.noMolestar ? Tema.tenue : Tema.rosa

    onAbrio: {
        ahora = Date.now();
        Centro.marcarLeidas();
    }
    onCerro: Centro.marcarLeidas()

    Timer {
        interval: 30000
        repeat: true
        running: panel.abierto
        onTriggered: panel.ahora = Date.now()
    }

    accesorio: Row {
        spacing: 10
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "No molestar"
            color: Tema.tenue
            font.family: Tema.fuenteBarra
            font.pixelSize: 12
        }
        Interruptor {
            activo: Centro.noMolestar
            onAlternado: Centro.noMolestar = !Centro.noMolestar
        }
    }

    Text {
        visible: Centro.historial.count === 0
        width: parent.width
        topPadding: 24
        bottomPadding: 24
        horizontalAlignment: Text.AlignHCenter
        text: "No hay notificaciones"
        color: Tema.tenue
        font.family: Tema.fuenteBarra
        font.pixelSize: 13
    }

    ListView {
        id: lista
        visible: count > 0
        width: parent.width
        height: Math.min(contentHeight, 480)
        clip: true
        spacing: 6
        boundsBehavior: Flickable.StopAtBounds
        model: Centro.historial

        delegate: Rectangle {
            id: fila

            required property int index
            required property string app
            required property string resumen
            required property string cuerpo
            required property string icono
            required property int urgencia
            required property real hora
            property bool completa: false

            width: lista.width
            height: textos.implicitHeight + 20
            radius: 12
            color: zona.containsMouse ? Tema.campoHover : Tema.conAlfa(Tema.campo, 0.55)
            border.width: urgencia === 2 ? 1 : 0
            border.color: Tema.error

            MouseArea {
                id: zona
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: fila.completa = !fila.completa
            }

            Item {
                id: zonaIcono
                x: 12
                y: 12
                width: 28
                height: 28
                Image {
                    id: imagen
                    anchors.fill: parent
                    source: fila.icono
                    sourceSize.width: 56
                    sourceSize.height: 56
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                    visible: status === Image.Ready
                }
                Text {
                    anchors.centerIn: parent
                    visible: !imagen.visible
                    text: fila.urgencia === 2 ? "󰀦" : "󰂚"
                    color: fila.urgencia === 2 ? Tema.error : Tema.acento
                    font.family: Tema.fuenteBarra
                    font.pixelSize: 20
                }
            }

            Column {
                id: textos
                anchors.left: zonaIcono.right
                anchors.leftMargin: 12
                anchors.right: parent.right
                anchors.rightMargin: 12
                y: 10
                spacing: 2

                Item {
                    width: parent.width
                    height: 16
                    Text {
                        anchors.left: parent.left
                        anchors.right: cerrarFila.left
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: fila.app + " · " + panel.hace(fila.hora)
                        textFormat: Text.PlainText
                        color: Tema.tenue
                        font.family: Tema.fuenteBarra
                        font.pixelSize: 11
                        elide: Text.ElideRight
                    }
                    Text {
                        id: cerrarFila
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: "󰅖"
                        color: zonaCerrar.containsMouse ? Tema.error : Tema.tenue
                        font.family: Tema.fuenteBarra
                        font.pixelSize: 14
                        MouseArea {
                            id: zonaCerrar
                            anchors.fill: parent
                            anchors.margins: -6
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Centro.quitar(fila.index)
                        }
                    }
                }
                Text {
                    width: parent.width
                    text: fila.resumen
                    textFormat: Text.PlainText
                    color: Tema.texto
                    font.family: Tema.fuenteBarra
                    font.pixelSize: 13
                    font.bold: true
                    wrapMode: Text.Wrap
                    maximumLineCount: fila.completa ? 4 : 1
                    elide: Text.ElideRight
                }
                Text {
                    width: parent.width
                    visible: fila.cuerpo !== ""
                    // Sin imágenes, para no cargar nada externo
                    text: fila.cuerpo.replace(/<img[^>]*>/gi, "")
                    textFormat: Text.StyledText
                    color: Tema.suave
                    linkColor: Tema.acento
                    font.family: Tema.fuenteBarra
                    font.pixelSize: 12
                    wrapMode: Text.Wrap
                    maximumLineCount: fila.completa ? 12 : 2
                    elide: Text.ElideRight
                }
            }
        }
    }

    BotonTexto {
        visible: Centro.historial.count > 0
        icono: String.fromCodePoint(0xf0a79)
        texto: "Borrar todo"
        onClic: Centro.limpiar()
    }
}
