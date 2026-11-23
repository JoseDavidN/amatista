// Datos de una conexión en dos columnas. Clic en un dato = copiarlo
//   datos: [{ n: "IP", v: "10.0.0.5" }, ...]  (los vacíos no se muestran)
import QtQuick
import Quickshell
import qs.Comun

Grid {
    id: rejilla

    property var datos: []
    readonly property var visibles: datos.filter(d => d.v !== "" && d.v !== undefined && d.v !== null)
    // Se compara el texto para no rehacer las casillas si nada cambió
    readonly property string huella: JSON.stringify(visibles)
    property string copiado: ""

    width: parent ? parent.width : 400
    columns: 2
    spacing: 6

    Timer { id: finCopiado; interval: 1200; onTriggered: rejilla.copiado = "" }

    Repeater {
        model: JSON.parse(rejilla.huella)

        delegate: Rectangle {
            id: casilla
            required property var modelData

            // Los valores largos (IPv6, DNS) toman el ancho que cabe y se recortan
            width: (rejilla.width - rejilla.spacing) / 2
            height: 44
            radius: 10
            color: zona.containsMouse ? Tema.campoHover : Tema.conAlfa(Tema.campo, 0.55)

            Column {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 10
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1
                Text {
                    text: rejilla.copiado === casilla.modelData.n ? "Copiado" : casilla.modelData.n
                    color: rejilla.copiado === casilla.modelData.n ? Tema.verde : Tema.tenue
                    font.family: Tema.fuenteBarra
                    font.pixelSize: 10
                }
                Text {
                    width: parent.width
                    text: casilla.modelData.v
                    textFormat: Text.PlainText
                    color: Tema.texto
                    font.family: Tema.fuenteBarra
                    font.pixelSize: 12
                    elide: Text.ElideMiddle
                }
            }

            MouseArea {
                id: zona
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    Quickshell.execDetached(["wl-copy", "--", String(casilla.modelData.v)]);
                    rejilla.copiado = casilla.modelData.n;
                    finCopiado.restart();
                }
            }
        }
    }
}
