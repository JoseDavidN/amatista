// ==========================================================
// Tooltip flotante debajo de un elemento de la barra
// ==========================================================
import QtQuick
import Quickshell
import qs.Comun

PopupWindow {
    id: tip

    required property Item objetivo
    property string texto: ""
    property bool activo: false

    visible: activo && texto !== "" && objetivo.QsWindow.window !== null
    color: "transparent"
    implicitWidth: burbuja.implicitWidth
    implicitHeight: burbuja.implicitHeight

    anchor {
        window: tip.objetivo.QsWindow.window
        adjustment: PopupAdjustment.Slide
        edges: Edges.Top | Edges.Left
        gravity: Edges.Bottom | Edges.Right
        rect.width: 1
        rect.height: 1

        onAnchoring: {
            const v = tip.objetivo.QsWindow.window;
            if (!v) return;
            const p = v.contentItem.mapFromItem(
                tip.objetivo,
                tip.objetivo.width / 2 - tip.implicitWidth / 2,
                tip.objetivo.height + 8);
            tip.anchor.rect.x = Math.round(p.x);
            tip.anchor.rect.y = Math.round(p.y);
        }
    }

    Rectangle {
        id: burbuja
        implicitWidth: etiqueta.implicitWidth + 20
        implicitHeight: etiqueta.implicitHeight + 14
        radius: 10
        color: Tema.fondoTooltip
        border.width: 1
        border.color: Tema.borde

        Text {
            id: etiqueta
            anchors.centerIn: parent
            text: tip.texto
            color: Tema.textoBarra
            font.family: Tema.fuenteBarra
            font.pixelSize: 13
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
