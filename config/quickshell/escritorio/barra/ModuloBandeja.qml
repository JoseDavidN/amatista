// ==========================================================
// Bandeja del sistema: solo se ve si hay apps en ella
// Clic: abrir la app · Derecho: su menú · Central: acción secundaria
// ==========================================================
import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import qs.Comun

Rectangle {
    id: mod

    readonly property var elementos: SystemTray.items.values

    visible: elementos.length > 0
    implicitWidth: fila.implicitWidth + 16
    implicitHeight: Tema.altoPildora
    radius: Tema.radioPildora
    color: Tema.pildora

    // Algunas apps dan "nombre?path=carpeta": el icono está en esa carpeta
    function iconoDe(e) {
        const i = String(e.icon || "");
        const k = i.indexOf("?path=");
        // Un icono que el tema no tiene se cambia por la inicial de la app
        if (k < 0) return i.startsWith("image://icon/") ? Quickshell.iconPath(i.slice(13), true) : i;
        const nombre = i.slice(0, k);
        return "file://" + i.slice(k + 6) + "/" + nombre.slice(nombre.lastIndexOf("/") + 1);
    }

    Row {
        id: fila
        anchors.centerIn: parent
        spacing: 2

        Repeater {
            model: SystemTray.items

            delegate: Rectangle {
                id: celda

                required property var modelData
                readonly property string nombre: String(modelData.tooltipTitle || modelData.title || modelData.id)

                width: 30
                height: 30
                radius: 10
                color: zona.containsMouse || panel.abierto ? Tema.pildoraHover : "transparent"

                function abrirMenu() {
                    if (modelData.hasMenu) panel.alternar();
                }

                IconImage {
                    id: imagen
                    anchors.centerIn: parent
                    implicitSize: 18
                    source: mod.iconoDe(celda.modelData)
                    visible: source != "" && status === Image.Ready
                }
                Text {
                    anchors.centerIn: parent
                    visible: !imagen.visible
                    text: celda.nombre.charAt(0).toUpperCase()
                    color: Tema.acento
                    font.family: Tema.fuenteBarra
                    font.pixelSize: 14
                    font.bold: true
                }
                // Punto: la app pide atención
                Rectangle {
                    visible: celda.modelData.status === Status.NeedsAttention
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.margins: 3
                    width: 7
                    height: 7
                    radius: 4
                    color: Tema.error
                }

                MouseArea {
                    id: zona
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                    onClicked: mouse => {
                        if (mouse.button === Qt.MiddleButton) celda.modelData.secondaryActivate();
                        else if (mouse.button === Qt.RightButton || celda.modelData.onlyMenu) celda.abrirMenu();
                        else celda.modelData.activate();
                    }
                    onWheel: w => celda.modelData.scroll(w.angleDelta.y, false)
                }

                Timer {
                    id: retardo
                    interval: 500
                    running: zona.containsMouse
                }
                Tooltip {
                    objetivo: celda
                    texto: celda.nombre
                    activo: zona.containsMouse && !retardo.running && !panel.abierto
                }

                PanelBandeja {
                    id: panel
                    objetivo: celda
                    elemento: celda.modelData
                    titulo: celda.nombre
                }
            }
        }
    }
}
