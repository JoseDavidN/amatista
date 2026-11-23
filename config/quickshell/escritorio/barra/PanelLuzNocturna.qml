// ==========================================================
// Panel de la luz nocturna: encender / apagar y horario
// ==========================================================
import QtQuick
import Quickshell
import qs.Comun
import qs.paneles

PanelEmergente {
    id: panel

    readonly property var s: ServicioLuzNocturna

    ancho: 340
    titulo: "Luz nocturna"
    icono: s.encendida ? "󰖔" : "󰖨"
    colorIcono: s.encendida ? Tema.ambar : Tema.tenue

    // Fila con texto a la izquierda y un interruptor a la derecha
    component Opcion: Rectangle {
        id: op
        property string texto: ""
        property string detalle: ""
        property bool activo: false
        signal alternado()

        width: parent ? parent.width : 300
        height: 56
        radius: 10
        color: Tema.conAlfa(Tema.campo, zonaOp.containsMouse ? 0.9 : 0.55)

        Column {
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.right: sw.left
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            Text {
                text: op.texto
                color: Tema.texto
                font.family: Tema.fuenteBarra
                font.pixelSize: 13
                font.bold: true
            }
            Text {
                width: parent.width
                text: op.detalle
                color: Tema.tenue
                font.family: Tema.fuenteBarra
                font.pixelSize: 11
                elide: Text.ElideRight
            }
        }
        MouseArea {
            id: zonaOp
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: op.alternado()
        }
        Interruptor {
            id: sw
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            activo: op.activo
            onAlternado: op.alternado()
        }
    }

    component Flecha: Text {
        id: fl
        property int n: 1
        signal clic()
        width: 44
        height: 20
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        text: String.fromCodePoint(n > 0 ? 0xf0143 : 0xf0140)
        color: zonaFl.containsMouse ? Tema.acento : Tema.tenue
        font.family: Tema.fuenteBarra
        font.pixelSize: 18
        MouseArea {
            id: zonaFl
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: fl.clic()
        }
    }

    // Hora o minutos: flechas o rueda del ratón
    component Rueda: Column {
        id: rueda
        property int valor: 0
        signal paso(int n)
        width: 44

        Flecha { n: 1; onClic: rueda.paso(1) }
        Rectangle {
            width: rueda.width
            height: 38
            radius: 8
            color: zonaR.containsMouse ? Tema.campoHover : Tema.campo
            Text {
                anchors.centerIn: parent
                text: String(rueda.valor).padStart(2, "0")
                color: Tema.texto
                font.family: Tema.fuenteBarra
                font.pixelSize: 18
                font.bold: true
            }
            MouseArea {
                id: zonaR
                anchors.fill: parent
                hoverEnabled: true
                property real acumulado: 0
                onWheel: w => {
                    acumulado += w.angleDelta.y;
                    const n = Math.trunc(acumulado / 120);
                    if (n === 0) return;
                    acumulado -= n * 120;
                    rueda.paso(n > 0 ? 1 : -1);
                }
            }
        }
        Flecha { n: -1; onClic: rueda.paso(-1) }
    }

    component Hora: Column {
        id: h
        property string texto: ""
        property int minutos: 0
        signal cambio(int m)
        spacing: 2

        // La hora y los minutos giran por separado (de 23 a 00, de 55 a 00)
        function mover(horas, pasos) {
            const hh = (Math.floor(minutos / 60) + horas + 24) % 24;
            const mm = (minutos % 60 + pasos * 5 + 60) % 60;
            cambio(hh * 60 + mm);
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: h.texto
            color: Tema.suave
            font.family: Tema.fuenteBarra
            font.pixelSize: 12
        }
        Row {
            spacing: 6
            Rueda { valor: Math.floor(h.minutos / 60); onPaso: n => h.mover(n, 0) }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: ":"
                color: Tema.texto
                font.family: Tema.fuenteBarra
                font.pixelSize: 18
                font.bold: true
            }
            Rueda { valor: h.minutos % 60; onPaso: n => h.mover(0, n) }
        }
    }

    Text {
        visible: !panel.s.instalado
        width: parent.width
        wrapMode: Text.Wrap
        text: "hyprsunset no está instalado"
        color: Tema.error
        font.family: Tema.fuenteBarra
        font.pixelSize: 12
    }

    Opcion {
        texto: panel.s.encendida ? "Encendida" : "Apagada"
        detalle: panel.s.horarioActivo && panel.s.horarioValido
            ? (panel.s.encendida ? "Se apaga a las " + panel.s.hora(panel.s.fin) : "Se enciende a las " + panel.s.hora(panel.s.inicio))
            : panel.s.encendida ? "Color cálido, " + panel.s.temperatura + " K" : "Colores normales"
        activo: panel.s.encendida
        onAlternado: panel.s.alternar()
    }

    Opcion {
        texto: "Horario automático"
        detalle: panel.s.horarioActivo ? "De " + panel.s.hora(panel.s.inicio) + " a " + panel.s.hora(panel.s.fin) : "Desactivado"
        activo: panel.s.horarioActivo
        onAlternado: panel.s.cambiarHorario(!panel.s.horarioActivo, panel.s.inicio, panel.s.fin)
    }

    Item {
        width: parent.width
        height: horas.implicitHeight
        opacity: panel.s.horarioActivo ? 1 : 0.5
        Behavior on opacity { NumberAnimation { duration: 140 } }

        Row {
            id: horas
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 36
            Hora {
                texto: "Encender"
                minutos: panel.s.inicio
                onCambio: m => panel.s.cambiarHorario(panel.s.horarioActivo, m, panel.s.fin)
            }
            Hora {
                texto: "Apagar"
                minutos: panel.s.fin
                onCambio: m => panel.s.cambiarHorario(panel.s.horarioActivo, panel.s.inicio, m)
            }
        }
    }

    Text {
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        text: !panel.s.horarioValido ? "Las dos horas son iguales: el horario no se aplica" : "Clic en las flechas o rueda del ratón"
        color: panel.s.horarioValido ? Tema.tenue : Tema.error
        font.family: Tema.fuenteBarra
        font.pixelSize: 11
    }
}
