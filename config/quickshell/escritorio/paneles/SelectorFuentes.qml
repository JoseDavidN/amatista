// ==========================================================
// Selector de fuentes del panel de multimedia
// Fila de "burbujas" con el icono de cada aplicación que reproduce algo.
// La elegida se agranda con un anillo; las que suenan llevan unas
// barritas animadas. Clic o rueda del ratón para cambiar.
// ==========================================================
import QtQuick
import Quickshell
import qs.Comun

Item {
    id: sel

    property var reproductores: []
    property var actual: null
    signal seleccionar(var r)

    implicitHeight: 84

    function nombre(p) {
        return String(p.identity || p.desktopEntry || "Reproductor");
    }

    // Icono real de la aplicación (desde su archivo .desktop)
    function rutaIcono(p) {
        let e = p.desktopEntry ? DesktopEntries.byId(p.desktopEntry) : null;
        if (!e && p.identity)
            e = DesktopEntries.heuristicLookup(p.identity);
        return e && e.icon ? Quickshell.iconPath(e.icon, true) : "";
    }

    // Respaldo si la aplicación no tiene icono
    function iconoTexto(p) {
        const t = (String(p.identity) + " " + String(p.desktopEntry) + " " + String(p.dbusName)).toLowerCase();
        if (t.includes("spotify")) return "󰓇";
        if (t.includes("firefox")) return "󰈹";
        if (t.includes("chrom") || t.includes("brave")) return "󰊯";
        if (t.includes("vlc")) return "󰕼";
        if (t.includes("mpv") || t.includes("celluloid")) return "󰐹";
        return "󰎆";
    }

    function mover(paso) {
        const l = reproductores;
        if (l.length < 2) return;
        const i = Math.max(0, l.indexOf(actual));
        seleccionar(l[(i + paso + l.length) % l.length]);
    }

    // Rueda del ratón sobre el selector: siguiente / anterior
    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => sel.mover(event.angleDelta.y < 0 || event.angleDelta.x < 0 ? 1 : -1)
    }

    Flickable {
        anchors.fill: parent
        contentWidth: fila.width
        contentHeight: height
        flickableDirection: Flickable.HorizontalFlick
        interactive: contentWidth > width
        clip: true

        Row {
            id: fila
            // Centrada si cabe; si no, desplazable
            x: Math.max(0, (sel.width - width) / 2)
            height: parent.height
            spacing: 10

            Repeater {
                model: sel.reproductores

                delegate: Item {
                    id: burbuja
                    required property var modelData
                    readonly property bool elegida: modelData === sel.actual
                    readonly property string icono: sel.rutaIcono(modelData)

                    width: 66
                    height: fila.height

                    Rectangle {
                        id: circulo
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 4
                        width: 48; height: 48; radius: 24
                        scale: burbuja.elegida ? 1.1 : zona.containsMouse ? 1.04 : 0.9
                        opacity: burbuja.elegida || zona.containsMouse ? 1 : 0.6
                        color: burbuja.elegida ? Tema.campoHover : Tema.campo
                        border.width: 2
                        border.color: burbuja.elegida ? Tema.acento : "transparent"

                        Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }
                        Behavior on opacity { NumberAnimation { duration: 150 } }
                        Behavior on border.color { ColorAnimation { duration: 150 } }

                        Image {
                            anchors.centerIn: parent
                            visible: burbuja.icono !== "" && status === Image.Ready
                            source: burbuja.icono
                            width: 28; height: 28
                            sourceSize.width: 56
                            sourceSize.height: 56
                        }

                        Text {
                            anchors.centerIn: parent
                            visible: burbuja.icono === ""
                            text: sel.iconoTexto(burbuja.modelData)
                            color: burbuja.elegida ? Tema.rosa : Tema.suave
                            font.family: Tema.fuenteBarra
                            font.pixelSize: 22
                        }

                        // Barritas animadas: esta fuente está sonando
                        Rectangle {
                            visible: burbuja.modelData.isPlaying
                            anchors.right: parent.right
                            anchors.bottom: parent.bottom
                            anchors.margins: -3
                            width: 20; height: 20; radius: 10
                            color: Tema.rosa

                            Row {
                                anchors.centerIn: parent
                                spacing: 2
                                Repeater {
                                    model: 3
                                    delegate: Rectangle {
                                        required property int index
                                        anchors.bottom: parent.bottom
                                        width: 2; radius: 1
                                        color: Tema.fondo
                                        height: 4
                                        SequentialAnimation on height {
                                            loops: Animation.Infinite
                                            running: burbuja.modelData.isPlaying
                                            PauseAnimation { duration: index * 120 }
                                            NumberAnimation { to: 10; duration: 260 }
                                            NumberAnimation { to: 4; duration: 260 }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: circulo.bottom
                        anchors.topMargin: 8
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: sel.nombre(burbuja.modelData)
                        color: burbuja.elegida ? Tema.texto : Tema.tenue
                        font.family: Tema.fuenteBarra
                        font.pixelSize: 11
                        font.bold: burbuja.elegida
                        elide: Text.ElideRight
                    }

                    MouseArea {
                        id: zona
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: sel.seleccionar(burbuja.modelData)
                    }
                }
            }
        }
    }
}
