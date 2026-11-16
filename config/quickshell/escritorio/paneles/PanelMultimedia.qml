// ==========================================================
// Panel de multimedia (MPRIS nativo de Quickshell)
// - Selector de fuentes: burbujas con el icono de cada aplicacion
// - Caratula circular que gira, con ecualizador alrededor (cava)
// - Titulo, artista y album de lo que suena
// - Barra de progreso (clic o arrastre para adelantar)
// - Aleatorio · anterior · reproducir/pausa · siguiente · repetir
// ==========================================================
import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import qs.Comun

PanelEmergente {
    id: panel

    // Reproductor que se controla; lo decide ModuloMultimedia
    property var reproductor: null
    // Se emite al elegir otra fuente en la lista
    signal seleccionar(var r)

    readonly property var reproductores: Mpris.players.values
    readonly property var r: reproductor

    titulo: "Multimedia"
    icono: "󰎆"
    colorIcono: Tema.rosa
    ancho: 640

    // 83.4 s -> "1:23"
    function tiempo(s) {
        if (!s || s < 0 || !isFinite(s)) return "0:00";
        s = Math.floor(s);
        const h = Math.floor(s / 3600);
        const m = Math.floor((s % 3600) / 60);
        const ss = String(s % 60).padStart(2, "0");
        return h > 0 ? h + ":" + String(m).padStart(2, "0") + ":" + ss : m + ":" + ss;
    }

    function nombre(p) {
        return String(p.identity || p.desktopEntry || "Reproductor");
    }

    // La posicion no se actualiza sola en MPRIS: se refresca cada segundo
    // solo mientras el panel esta abierto y algo suena
    Timer {
        running: panel.abierto && panel.r !== null && panel.r.isPlaying
        interval: 1000
        repeat: true
        onTriggered: panel.r.positionChanged()
    }

    onAbrio: if (r) r.positionChanged()

    // Boton redondo de los controles
    component BotonControl: Rectangle {
        id: boton
        property string icono: ""
        property bool habilitado: true
        property bool encendido: false
        property bool principal: false
        signal clic()

        width: principal ? 52 : 40
        height: width
        radius: width / 2
        opacity: habilitado ? 1 : 0.35
        color: principal ? (zonaBoton.containsMouse && habilitado ? Tema.morado : Tema.acento)
             : zonaBoton.containsMouse && habilitado ? Tema.campoHover
             : encendido ? Tema.campo : "transparent"

        Behavior on color { ColorAnimation { duration: 120 } }

        Text {
            anchors.centerIn: parent
            text: boton.icono
            color: boton.principal ? Tema.fondo : boton.encendido ? Tema.acento : Tema.texto
            font.family: Tema.fuenteBarra
            font.pixelSize: boton.principal ? 24 : 18
        }

        MouseArea {
            id: zonaBoton
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: boton.habilitado ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: if (boton.habilitado) boton.clic()
        }
    }

    // ---------- Sin reproductores ----------
    Text {
        visible: panel.r === null
        width: parent.width
        horizontalAlignment: Text.AlignHCenter
        topPadding: 12
        bottomPadding: 12
        text: "No hay nada reproduciéndose"
        color: Tema.tenue
        font.family: Tema.fuenteBarra
        font.pixelSize: 13
    }

    // ---------- Fuentes: burbujas con las aplicaciones ----------
    SelectorFuentes {
        visible: panel.reproductores.length > 1
        width: parent.width
        reproductores: panel.reproductores
        actual: panel.reproductor
        onSeleccionar: r => panel.seleccionar(r)
    }

    // ---------- Fila principal: carátula a la izquierda, datos y controles a la derecha ----------
    Row {
        visible: panel.r !== null
        width: parent.width
        spacing: 18

        // ---------- Carátula circular con ecualizador ----------
        Visualizador {
            id: visualizador
            anchors.verticalCenter: parent.verticalCenter
            caratula: panel.r ? panel.r.trackArtUrl : ""
            sonando: panel.r !== null && panel.r.isPlaying
            activo: panel.abierto && sonando
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - visualizador.width - parent.spacing
            spacing: 14

            // ---------- Pista actual ----------
            Column {
                width: parent.width
                spacing: 3

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignLeft
                    text: panel.r && panel.r.trackTitle ? panel.r.trackTitle : "Sin título"
                    color: Tema.texto
                    font.family: Tema.fuenteBarra
                    font.pixelSize: 15
                    font.bold: true
                    elide: Text.ElideRight
                    maximumLineCount: 2
                    wrapMode: Text.Wrap
                }

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignLeft
                    visible: text !== ""
                    text: panel.r ? [panel.r.trackArtist, panel.r.trackAlbum].filter(t => t).join(" · ") : ""
                    color: Tema.suave
                    font.family: Tema.fuenteBarra
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignLeft
                    visible: panel.reproductores.length === 1
                    text: panel.r ? panel.nombre(panel.r) : ""
                    color: Tema.tenue
                    font.family: Tema.fuenteBarra
                    font.pixelSize: 11
                }
            }


            // ---------- Progreso ----------
            Column {
                visible: panel.r !== null && panel.r.lengthSupported && panel.r.length > 0
                width: parent.width
                spacing: 2

                Deslizador {
                    width: parent.width
                    valor: panel.r ? panel.r.position : 0
                    maximo: panel.r && panel.r.length > 0 ? panel.r.length : 1
                    paso: 5
                    colorRelleno: Tema.rosa
                    apagado: panel.r !== null && !panel.r.canSeek
                    onMovido: v => { if (panel.r && panel.r.canSeek) panel.r.position = v; }
                }

                Item {
                    width: parent.width
                    height: 14

                    Text {
                        anchors.left: parent.left
                        text: panel.r ? panel.tiempo(panel.r.position) : ""
                        color: Tema.tenue
                        font.family: Tema.fuenteBarra
                        font.pixelSize: 11
                    }
                    Text {
                        anchors.right: parent.right
                        text: panel.r ? panel.tiempo(panel.r.length) : ""
                        color: Tema.tenue
                        font.family: Tema.fuenteBarra
                        font.pixelSize: 11
                    }
                }
            }


            // ---------- Controles ----------
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 14

                BotonControl {
                    anchors.verticalCenter: parent.verticalCenter
                    icono: panel.r && panel.r.shuffle ? "󰒝" : "󰒞"
                    habilitado: panel.r !== null && panel.r.canControl && panel.r.shuffleSupported
                    encendido: panel.r !== null && panel.r.shuffle
                    onClic: panel.r.shuffle = !panel.r.shuffle
                }

                BotonControl {
                    anchors.verticalCenter: parent.verticalCenter
                    icono: "󰒮"
                    habilitado: panel.r !== null && panel.r.canGoPrevious
                    onClic: panel.r.previous()
                }

                BotonControl {
                    anchors.verticalCenter: parent.verticalCenter
                    principal: true
                    icono: panel.r && panel.r.isPlaying ? "󰏤" : "󰐊"
                    habilitado: panel.r !== null && panel.r.canTogglePlaying
                    onClic: panel.r.togglePlaying()
                }

                BotonControl {
                    anchors.verticalCenter: parent.verticalCenter
                    icono: "󰒭"
                    habilitado: panel.r !== null && panel.r.canGoNext
                    onClic: panel.r.next()
                }

                // Repetir: desactivado -> lista -> cancion
                BotonControl {
                    anchors.verticalCenter: parent.verticalCenter
                    icono: !panel.r ? "󰑗"
                         : panel.r.loopState === MprisLoopState.Track ? "󰑘"
                         : panel.r.loopState === MprisLoopState.Playlist ? "󰑖"
                         : "󰑗"
                    habilitado: panel.r !== null && panel.r.canControl && panel.r.loopSupported
                    encendido: panel.r !== null && panel.r.loopState !== MprisLoopState.None
                    onClic: {
                        const e = panel.r.loopState;
                        panel.r.loopState = e === MprisLoopState.None ? MprisLoopState.Playlist
                                          : e === MprisLoopState.Playlist ? MprisLoopState.Track
                                          : MprisLoopState.None;
                    }
                }
            }
        }
    }
}
