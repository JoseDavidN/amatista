// ==========================================================
// Panel del clima (clic en la fecha y hora)
// Horizontal:  ahora (lluvia y humedad) | lluvia en 24 horas | próximos días
// El lugar se cambia con la lupa; el marcador vuelve a la ubicación actual.
// ==========================================================
import QtQuick
import Quickshell
import qs.Comun
import qs.paneles

PanelEmergente {
    id: panel

    readonly property var s: ServicioClima
    readonly property var d: ServicioClima.datos
    readonly property var ahora: d ? d.current : null
    readonly property var horas: d ? d.hourly : null
    readonly property var dias: d ? d.daily : null
    property bool buscando: false

    function grados(v) { return Math.round(v) + "°"; }
    function nombreDia(texto, i) {
        if (i === 0) return "Hoy";
        const p = texto.split("-");
        const n = new Date(+p[0], +p[1] - 1, +p[2]).toLocaleString(Qt.locale("es_CO"), "ddd").replace(".", "");
        return n.charAt(0).toUpperCase() + n.slice(1);
    }
    function terminarBusqueda() {
        buscando = false;
        s.limpiarBusqueda();
        campo.text = "";
        foco.forceActiveFocus();
    }
    function colorClima(c, dia) {
        if (c <= 2) return dia ? Tema.ambar : Tema.morado;
        if (c >= 95) return Tema.rosa;
        return c >= 51 ? Tema.cian : Tema.suave;
    }

    ancho: Math.min(940, (screen ? screen.width : 1920) - 24)
    titulo: s.lugar ? s.lugar.nombre : "Clima"
    icono: String.fromCodePoint(s.manual ? 0xf034e : 0xf01a4)

    onAbrio: s.actualizarSiHaceFalta()
    onCerro: { buscando = false; campo.text = ""; s.limpiarBusqueda(); }

    Timer {
        interval: 60000
        repeat: true
        running: panel.abierto
        onTriggered: panel.s.actualizarSiHaceFalta()
    }

    component Boton: Text {
        id: b
        property int glifo: 0
        property bool resaltado: false
        signal clic()
        text: String.fromCodePoint(glifo)
        color: zonaB.containsMouse || resaltado ? Tema.acento : Tema.tenue
        font.family: Tema.fuenteBarra
        font.pixelSize: 18
        MouseArea {
            id: zonaB
            anchors.fill: parent
            anchors.margins: -5
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: b.clic()
        }
    }

    accesorio: Row {
        spacing: 16
        Boton {   // volver a la ubicación actual
            visible: panel.s.manual
            glifo: 0xf01a4
            onClic: { panel.terminarBusqueda(); panel.s.usarActual(); }
        }
        Boton {   // buscar ciudad
            glifo: 0xf0349
            resaltado: panel.buscando
            onClic: {
                if (panel.buscando) { panel.terminarBusqueda(); return; }
                panel.buscando = true;
                campo.forceActiveFocus();
            }
        }
        Boton {   // actualizar
            glifo: 0xf0450
            opacity: panel.s.cargando ? 0.4 : 1
            onClic: if (!panel.s.cargando) panel.s.actualizar()
        }
    }

    // Recibe el teclado cuando se cierra la búsqueda
    Item {
        id: foco
        visible: true
        width: 1
        height: 0
        Keys.onEscapePressed: panel.cerrar()
    }

    // ---------- Búsqueda de ciudad ----------
    Column {
        visible: panel.buscando
        width: parent.width
        spacing: 4

        Rectangle {
            width: parent.width
            height: 38
            radius: Tema.radioPequeno
            color: Tema.campo
            border.width: 1
            border.color: campo.activeFocus ? Tema.acento : Tema.borde

            Text {
                visible: campo.text === ""
                anchors.left: campo.left
                anchors.verticalCenter: parent.verticalCenter
                text: "Buscar ciudad"
                color: Tema.tenue
                font.family: Tema.fuenteBarra
                font.pixelSize: 13
            }
            TextInput {
                id: campo
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 12
                anchors.verticalCenter: parent.verticalCenter
                clip: true
                color: Tema.texto
                selectionColor: Tema.acento
                font.family: Tema.fuenteBarra
                font.pixelSize: 13
                onTextChanged: if (panel.buscando) espera.restart()
                onAccepted: if (panel.s.resultados.length > 0) {
                    const l = panel.s.resultados[0];
                    panel.terminarBusqueda();
                    panel.s.elegir(l);
                }
                Keys.onEscapePressed: panel.terminarBusqueda()
            }
            Timer {
                id: espera
                interval: 350
                onTriggered: if (panel.buscando) panel.s.buscar(campo.text)
            }
        }

        Text {
            visible: panel.s.estadoBusqueda !== ""
            text: panel.s.estadoBusqueda
            color: Tema.tenue
            font.family: Tema.fuenteBarra
            font.pixelSize: 12
        }

        Repeater {
            model: panel.s.resultados
            Rectangle {
                id: fila
                required property var modelData
                width: parent.width
                height: 32
                radius: Tema.radioPequeno
                color: zonaF.containsMouse ? Tema.campoHover : "transparent"
                Text {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                    textFormat: Text.PlainText
                    text: fila.modelData.nombre + (fila.modelData.region ? "  ·  " + fila.modelData.region : "")
                    color: Tema.texto
                    font.family: Tema.fuenteBarra
                    font.pixelSize: 12
                }
                MouseArea {
                    id: zonaF
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        const l = fila.modelData;
                        panel.terminarBusqueda();
                        panel.s.elegir(l);
                    }
                }
            }
        }
    }

    // ---------- Sin datos: cargando o error ----------
    Column {
        visible: !panel.d
        width: parent.width
        topPadding: 24
        bottomPadding: 24
        spacing: 12
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: panel.s.error || "Consultando el clima…"
            color: panel.s.error ? Tema.error : Tema.tenue
            font.family: Tema.fuenteBarra
            font.pixelSize: 13
        }
        BotonTexto {
            visible: panel.s.error !== ""
            anchors.horizontalCenter: parent.horizontalCenter
            texto: "Reintentar"
            onClic: panel.s.actualizar()
        }
    }

    // ---------- Contenido ----------
    Row {
        id: contenido
        visible: !!panel.d
        width: parent.width
        height: 168
        spacing: 16

        readonly property real anchoAhora: 178
        readonly property real anchoDias: Math.min(380, (width - anchoAhora - 4 * spacing - 2) * 0.54)

        // ----- Ahora -----
        Item {
            width: contenido.anchoAhora
            height: contenido.height

            Row {
                id: filaAhora
                spacing: 12
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: panel.ahora ? panel.s.icono(panel.ahora.weather_code, panel.ahora.is_day === 1) : ""
                    color: panel.ahora ? panel.colorClima(panel.ahora.weather_code, panel.ahora.is_day === 1) : Tema.suave
                    font.family: Tema.fuenteBarra
                    font.pixelSize: 44
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: panel.ahora ? panel.grados(panel.ahora.temperature_2m) : ""
                    color: Tema.texto
                    font.family: Tema.fuenteBarra
                    font.pixelSize: 36
                    font.bold: true
                }
            }
            Text {
                id: descripcion
                anchors.top: filaAhora.bottom
                width: parent.width
                elide: Text.ElideRight
                text: panel.ahora ? panel.s.descripcion(panel.ahora.weather_code) : ""
                color: Tema.suave
                font.family: Tema.fuenteBarra
                font.pixelSize: 12
            }
            Row {
                anchors.bottom: parent.bottom
                width: parent.width
                spacing: 8
                Repeater {
                    model: [
                        { glifo: 0xf054a, nombre: "Lluvia", valor: panel.horas ? (panel.horas.precipitation_probability[0] ?? 0) + " %" : "—" },
                        { glifo: 0xf058e, nombre: "Humedad", valor: panel.ahora ? panel.ahora.relative_humidity_2m + " %" : "—" }
                    ]
                    Rectangle {
                        id: casilla
                        required property var modelData
                        width: (contenido.anchoAhora - 8) / 2
                        height: 58
                        radius: 10
                        color: Tema.conAlfa(Tema.campo, 0.55)
                        Column {
                            anchors.centerIn: parent
                            spacing: 3
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: casilla.modelData.nombre
                                color: Tema.tenue
                                font.family: Tema.fuenteBarra
                                font.pixelSize: 11
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: String.fromCodePoint(casilla.modelData.glifo) + " " + casilla.modelData.valor
                                color: Tema.cian
                                font.family: Tema.fuenteBarra
                                font.pixelSize: 15
                                font.bold: true
                            }
                        }
                    }
                }
            }
        }

        Rectangle { width: 1; height: contenido.height; color: Tema.borde }

        // ----- Lluvia en las próximas 24 horas -----
        Item {
            id: grafico
            width: contenido.width - contenido.anchoAhora - contenido.anchoDias - 4 * contenido.spacing - 2
            height: contenido.height

            readonly property int n: panel.horas ? panel.horas.time.length : 0
            readonly property real paso: n > 0 ? width / n : 1
            readonly property real altoBarras: height - 24 - 18 - 18

            TituloSeccion { texto: "Lluvia en 24 horas" }

            Repeater {
                model: grafico.n
                Item {
                    id: hora
                    required property int index
                    readonly property int prob: panel.horas ? panel.horas.precipitation_probability[index] ?? 0 : 0
                    x: index * grafico.paso
                    width: grafico.paso
                    height: grafico.height

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 18
                        width: Math.max(2, parent.width - 4)
                        height: Math.max(2, grafico.altoBarras * hora.prob / 100)
                        radius: Math.min(3, height / 2)
                        color: Tema.conAlfa(Tema.cian, 0.25 + 0.6 * hora.prob / 100)

                    }
                    // Porcentaje y hora, cada 3 horas
                    Text {
                        visible: hora.index % 3 === 1
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 24
                        text: hora.prob + "%"
                        color: Tema.cian
                        font.family: Tema.fuenteBarra
                        font.pixelSize: 10
                    }
                    Text {
                        visible: hora.index % 3 === 1
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        text: panel.horas ? Number(panel.horas.time[hora.index].slice(11, 13)) + "h" : ""
                        color: Tema.tenue
                        font.family: Tema.fuenteBarra
                        font.pixelSize: 10
                    }
                }
            }
        }

        Rectangle { width: 1; height: contenido.height; color: Tema.borde }

        // ----- Próximos días -----
        Item {
            width: contenido.anchoDias
            height: contenido.height

            TituloSeccion { texto: "Próximos días" }

            Row {
                id: semana
                anchors.bottom: parent.bottom
                width: parent.width
                height: parent.height - 24
                spacing: 6

                Repeater {
                    // Sin hoy: ya está a la izquierda
                    model: panel.dias ? panel.dias.time.length - 1 : 0
                    Rectangle {
                        id: dia
                        required property int index
                        readonly property int i: index + 1
                        width: (semana.width - 5 * semana.spacing) / 6
                        height: semana.height
                        radius: 10
                        color: Tema.conAlfa(Tema.campo, 0.55)

                        Column {
                            anchors.centerIn: parent
                            spacing: 6
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: panel.dias ? panel.nombreDia(panel.dias.time[dia.i], dia.i) : ""
                                color: Tema.suave
                                font.family: Tema.fuenteBarra
                                font.pixelSize: 12
                                font.bold: true
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: panel.dias ? panel.s.icono(panel.dias.weather_code[dia.i], true) : ""
                                color: panel.dias ? panel.colorClima(panel.dias.weather_code[dia.i], true) : Tema.suave
                                font.family: Tema.fuenteBarra
                                font.pixelSize: 24
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: panel.dias ? (panel.dias.precipitation_probability_max[dia.i] ?? 0) + "%" : ""
                                color: Tema.cian
                                font.family: Tema.fuenteBarra
                                font.pixelSize: 14
                                font.bold: true
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: panel.dias ? panel.grados(panel.dias.temperature_2m_max[dia.i]) + (dia.width < 52 ? "\n" : " ") + panel.grados(panel.dias.temperature_2m_min[dia.i]) : ""
                                horizontalAlignment: Text.AlignHCenter
                                color: Tema.tenue
                                font.family: Tema.fuenteBarra
                                font.pixelSize: 10
                            }
                        }
                    }
                }
            }
        }
    }

    // Solo si no se pudo actualizar
    Text {
        visible: !!panel.d && panel.s.error !== ""
        text: panel.s.error + " · datos de las " + (panel.s.actualizado ? Qt.formatTime(panel.s.actualizado, "HH:mm") : "")
        color: Tema.error
        font.family: Tema.fuenteBarra
        font.pixelSize: 11
    }
}
