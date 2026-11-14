// ==========================================================
// Panel de multimedia (MPRIS nativo de Quickshell)
// - Caratula, titulo, artista y album de lo que suena
// - Barra de progreso (clic o arrastre para adelantar)
// - Aleatorio · anterior · reproducir/pausa · siguiente · repetir
// - Fuentes: elegir de que reproductor se controla la musica
// ==========================================================
import QtQuick
import QtQuick.Effects
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
    ancho: 400

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

    function iconoReproductor(p) {
        const t = (String(p.identity) + " " + String(p.desktopEntry) + " " + String(p.dbusName)).toLowerCase();
        if (t.includes("spotify")) return "󰓇";
        if (t.includes("firefox")) return "󰈹";
        if (t.includes("chrom") || t.includes("brave")) return "󰊯";
        if (t.includes("vlc")) return "󰕼";
        if (t.includes("mpv") || t.includes("celluloid")) return "󰐹";
        return "󰎆";
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

    // ---------- Pista actual ----------
    Item {
        visible: panel.r !== null
        width: parent.width
        height: 96

        // Caratula con esquinas redondeadas
        Rectangle {
            id: marcoCaratula
            width: 96
            height: 96
            radius: 12
            color: Tema.campo

            Text {
                anchors.centerIn: parent
                visible: caratula.status !== Image.Ready
                text: "󰎆"
                color: Tema.rosa
                font.family: Tema.fuenteBarra
                font.pixelSize: 40
            }

            Image {
                id: caratula
                anchors.fill: parent
                source: panel.r ? panel.r.trackArtUrl : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                visible: false
                sourceSize.width: 192
                sourceSize.height: 192
            }

            Rectangle {
                id: mascara
                anchors.fill: parent
                radius: 12
                visible: false
                layer.enabled: true
            }

            MultiEffect {
                anchors.fill: parent
                visible: caratula.status === Image.Ready
                source: caratula
                maskEnabled: true
                maskSource: mascara
            }
        }

        Column {
            anchors.left: marcoCaratula.right
            anchors.leftMargin: 14
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            Text {
                width: parent.width
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
                visible: text !== ""
                text: panel.r ? (panel.r.trackArtist || "") : ""
                color: Tema.suave
                font.family: Tema.fuenteBarra
                font.pixelSize: 13
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                visible: text !== ""
                text: panel.r ? (panel.r.trackAlbum || "") : ""
                color: Tema.tenue
                font.family: Tema.fuenteBarra
                font.pixelSize: 12
                elide: Text.ElideRight
            }
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
        visible: panel.r !== null
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

    // ---------- Fuentes ----------
    TituloSeccion {
        visible: panel.reproductores.length > 0
        texto: "Fuentes"
        extra: panel.reproductores.length + (panel.reproductores.length === 1 ? " reproductor" : " reproductores")
    }

    Repeater {
        model: panel.reproductores

        delegate: FilaLista {
            required property var modelData
            icono: panel.iconoReproductor(modelData)
            colorIcono: modelData.isPlaying ? Tema.rosa : Tema.tenue
            titulo: panel.nombre(modelData)
            subtitulo: (modelData.isPlaying ? "▶ " : "⏸ ") + (modelData.trackTitle || "Sin título")
            resaltada: modelData === panel.reproductor
            detalle: resaltada ? "󰄬" : ""
            colorDetalle: Tema.acento
            onClic: panel.seleccionar(modelData)
        }
    }
}
