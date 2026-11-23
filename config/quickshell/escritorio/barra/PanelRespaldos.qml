// Estado de los respaldos automáticos, historial y respaldo inmediato
import QtQuick
import Quickshell
import qs.Comun
import qs.paneles

PanelEmergente {
    id: panel

    readonly property var s: ServicioRespaldos

    function fecha(ms) {
        return ms > 0 ? new Date(ms).toLocaleString(Qt.locale("es_CO"), "ddd d MMM, HH:mm").replace(/\./g, "") : "—";
    }
    function tamano(b) { return b >= 1e12 ? (b / 1e12).toFixed(1) + " TB" : b >= 1e9 ? Math.round(b / 1e9) + " GB" : Math.round(b / 1e6) + " MB"; }

    ancho: Math.min(440, (screen ? screen.width : 1920) - 24)
    titulo: "Respaldos"
    icono: String.fromCodePoint(0xf006f)
    colorIcono: s.mal ? Tema.error : Tema.cian

    onAbrio: s.comprobar()

    FilaLista {
        icono: String.fromCodePoint(panel.s.mal ? 0xf0026 : panel.s.corriendo ? 0xf006f : 0xf05e0)
        colorIcono: panel.s.mal ? Tema.error : panel.s.corriendo ? Tema.cian : Tema.verde
        titulo: panel.s.corriendo ? "Respaldo en marcha" : panel.s.mal ? "Hay un problema" : "Al día"
        subtitulo: "Último correcto: " + panel.fecha(panel.s.ultimoBueno)
        resaltada: true
    }

    Text {
        visible: panel.s.mal
        width: parent.width
        wrapMode: Text.Wrap
        textFormat: Text.PlainText
        text: panel.s.problemas.join("\n")
        color: Tema.error
        font.family: Tema.fuenteBarra
        font.pixelSize: 12
    }

    DatosRed {
        datos: [
            { n: "Próximo", v: panel.s.habilitado ? panel.fecha(panel.s.proximo) : "Temporizador apagado" }
        ].concat(panel.s.discos.map(d => ({
            n: d.ruta,
            v: !d.montado ? "No montado" : panel.tamano(d.total - d.usado) + " libres de " + panel.tamano(d.total)
        })))
    }

    TituloSeccion { visible: panel.s.historial.length > 0; texto: "Historial" }

    Column {
        width: parent.width
        spacing: 2
        Repeater {
            model: panel.s.historial.slice(0, 6)
            Item {
                id: fila
                required property var modelData
                width: parent.width
                height: 38
                Text {
                    id: marca
                    anchors.verticalCenter: parent.verticalCenter
                    text: String.fromCodePoint(fila.modelData.ok ? 0xf012c : 0xf0156)
                    color: fila.modelData.ok ? Tema.verde : Tema.error
                    font.family: Tema.fuenteBarra
                    font.pixelSize: 16
                }
                Column {
                    anchors.left: marca.right
                    anchors.leftMargin: 12
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    Text {
                        text: panel.fecha(fila.modelData.hora)
                        color: Tema.texto
                        font.family: Tema.fuenteBarra
                        font.pixelSize: 12
                    }
                    Text {
                        width: parent.width
                        elide: Text.ElideRight
                        textFormat: Text.PlainText
                        text: fila.modelData.ok ? [fila.modelData.detalle, fila.modelData.guardado ? "nuevo " + fila.modelData.guardado : ""].filter(x => x).join(" · ")
                            : fila.modelData.interrumpido ? "Interrumpido" : fila.modelData.error || "Falló"
                        color: Tema.tenue
                        font.family: Tema.fuenteBarra
                        font.pixelSize: 11
                    }
                }
            }
        }
    }

    BotonTexto {
        principal: !panel.s.corriendo
        opacity: panel.s.corriendo ? 0.5 : 1
        icono: String.fromCodePoint(0xf006f)
        texto: panel.s.corriendo ? "En marcha…" : "Respaldar ahora"
        onClic: {
            if (panel.s.corriendo) return;
            // El panel se cierra para dejar ver la ventana de la contraseña
            panel.cerrar();
            panel.s.respaldar();
        }
    }
}
