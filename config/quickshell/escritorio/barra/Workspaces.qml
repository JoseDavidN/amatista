// ==========================================================
// Workspaces con iconos de Star Wars, One Piece y Berserk
// - Siempre se muestran los 5 primeros (y los demas si existen)
// - Activo: fondo suave + subrayado azul · vacio: atenuado
// - Rueda: arriba = siguiente, abajo = anterior (como e+1 / e-1)
// ==========================================================
import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.Comun

Rectangle {
    id: ws

    readonly property int persistentes: 5

    readonly property var iconos: ({
        "1": { icono: "", color: Tema.cian },   // Star Wars · Orden Jedi
        "2": { icono: "󰨈", color: Tema.ambar },   // One Piece · bandera pirata
        "3": { icono: "󰞇", color: Tema.suave },   // Berserk · espadas cruzadas
        "4": { icono: "", color: Tema.error },   // Star Wars · Imperio
        "5": { icono: "󰠳", color: Tema.durazno },   // One Piece · timón
        "6": { icono: "󱢾", color: Tema.verde },   // Berserk · escudo y espada
        "7": { icono: "", color: Tema.naranja },   // Star Wars · Alianza Rebelde
        "8": { icono: "󱐟", color: Tema.rosa },   // One Piece · carne de Luffy
        "9": { icono: "", color: Tema.acento },   // Berserk · el Eclipse
        "10": { icono: "󰣘", color: Tema.tenue },   // Star Wars · Estrella de la Muerte
    })

    readonly property int activo: {
        const m = Hyprland.focusedMonitor;
        return m && m.activeWorkspace ? m.activeWorkspace.id : -1;
    }

    // Ids a mostrar: 1..5 siempre, y hasta el mayor que exista
    readonly property var lista: {
        let mayor = persistentes;
        const valores = Hyprland.workspaces.values;
        for (let i = 0; i < valores.length; i++) {
            const id = valores[i].id;
            if (id > mayor && id <= 10) mayor = id;
        }
        const r = [];
        for (let i = 1; i <= mayor; i++) r.push(i);
        return r;
    }

    function porId(id) {
        const valores = Hyprland.workspaces.values;
        for (let i = 0; i < valores.length; i++) {
            if (valores[i].id === id) return valores[i];
        }
        return null;
    }

    function ir(id) {
        Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.focus({ workspace = \"" + id + "\" })"]);
    }

    implicitWidth: fila.implicitWidth + 8
    implicitHeight: Tema.altoPildora
    radius: height / 2
    color: Tema.fondoTarjeta

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: wheel => {
            const i = ws.lista.indexOf(ws.activo);
            if (i < 0) return;
            if (wheel.angleDelta.y > 0 && i < ws.lista.length - 1) ws.ir(ws.lista[i + 1]);
            else if (wheel.angleDelta.y < 0 && i > 0) ws.ir(ws.lista[i - 1]);
        }
    }

    Row {
        id: fila
        anchors.centerIn: parent
        spacing: 2

        Repeater {
            model: ws.lista

            delegate: Rectangle {
                id: boton

                required property int modelData

                readonly property var datos: ws.porId(modelData)
                readonly property bool esActivo: modelData === ws.activo
                readonly property bool vacio: datos === null || datos.toplevels.values.length === 0
                readonly property bool urgente: datos !== null && datos.urgent === true
                readonly property var estilo: ws.iconos[String(modelData)] || ({ icono: String(modelData), color: Tema.textoBarra })

                width: icono.implicitWidth + 32
                height: Tema.altoPildora - 8
                radius: 18
                color: urgente ? Tema.conAlfa(Tema.error, 0.30)
                     : esActivo ? Tema.campoHover
                     : zona.containsMouse ? Tema.campo
                     : "transparent"
                opacity: esActivo || urgente || zona.containsMouse ? 1 : vacio ? 0.35 : 0.85

                Behavior on color { ColorAnimation { duration: 200 } }
                Behavior on opacity { NumberAnimation { duration: 200 } }

                Text {
                    id: icono
                    anchors.centerIn: parent
                    text: boton.estilo.icono
                    color: boton.estilo.color
                    font.family: Tema.fuenteIconos
                    font.pixelSize: 17
                }

                // Subrayado del activo (o rojo si es urgente)
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: boton.esActivo || boton.urgente ? parent.width - 20 : 0
                    height: 2
                    radius: 1
                    color: boton.urgente ? Tema.error : Tema.acento

                    Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                }

                MouseArea {
                    id: zona
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: ws.ir(boton.modelData)
                }
            }
        }
    }
}
