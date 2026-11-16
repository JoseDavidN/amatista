// ==========================================================
// Ayuda: lista de atajos de teclado (Super + A)
// - Los atajos salen de Hyprland (`hyprctl binds -j`), se leen solo
//   al abrir el panel, asi la lista nunca se desactualiza
// - Cada atajo de binds.lua lleva { description = "Categoria: Texto" };
//   se agrupa por categoria y los que comparten descripcion se juntan
//   en una fila (Super + 1…0 Ir al espacio). Sin descripcion = no aparece
// - Escribir filtra; Escape o clic fuera cierra
//
//   qs -c escritorio ipc call ayuda alternar
// ==========================================================
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Comun
import qs.menus

Scope {
    id: ayuda

    // 3 columnas en pantallas anchas; 2 o 1 si la tarjeta es angosta
    // (cada columna necesita unos 300 px para que las teclas no se monten)
    readonly property int numColumnas: Math.max(1, Math.min(3, Math.floor(filaColumnas.width / 300)))
    readonly property int separacion: 22

    property var atajos: []        // [{ categoria, texto, combos: [{ mods: [], tecla }] }]
    property string consulta: ""
    property bool cargando: false

    // ---------- Nombres legibles ----------
    readonly property var nombresTeclas: ({
        "left": "←", "right": "→", "up": "↑", "down": "↓",
        "mouse:272": "Clic izq.", "mouse:273": "Clic der.", "mouse:274": "Clic central",
        "mouse_down": "Rueda ↓", "mouse_up": "Rueda ↑",
        "mouse_left": "Rueda ←", "mouse_right": "Rueda →",
        "Print": "Impr Pant", "Return": "Enter", "space": "Espacio", "Escape": "Esc",
        "Tab": "Tab", "BackSpace": "Retroceso", "Delete": "Supr", "Home": "Inicio", "End": "Fin",
        "Prior": "Re Pág", "Next": "Av Pág",
        "KP_Divide": "Num /", "KP_Multiply": "Num *", "KP_Subtract": "Num −", "KP_Add": "Num +",
        "slash": "/", "minus": "-", "plus": "+", "period": ".", "comma": ",",
        "XF86AudioRaiseVolume": "Vol +", "XF86AudioLowerVolume": "Vol −",
        "XF86AudioMute": "Silencio", "XF86AudioMicMute": "Mic",
        "XF86AudioPlay": "Play", "XF86AudioPause": "Pausa",
        "XF86AudioNext": "Siguiente", "XF86AudioPrev": "Anterior", "XF86AudioStop": "Detener",
        "XF86MonBrightnessUp": "Brillo +", "XF86MonBrightnessDown": "Brillo −"
    })

    function nombreTecla(k) {
        const t = String(k);
        if (nombresTeclas[t] !== undefined) return nombresTeclas[t];
        if (t.startsWith("XF86")) return t.substring(4);
        if (t.length === 1) return t.toUpperCase();
        return t;
    }

    // modmask de Hyprland: 64 Super, 4 Ctrl, 8 Alt, 1 Shift
    function nombresMods(m) {
        const r = [];
        if (m & 64) r.push("Super");
        if (m & 4) r.push("Ctrl");
        if (m & 8) r.push("Alt");
        if (m & 1) r.push("Shift");
        return r;
    }

    function normalizar(t) {
        let s = String(t || "").toLowerCase();
        try { s = s.normalize("NFD").replace(/[̀-ͯ]/g, ""); } catch (e) {}
        return s;
    }

    // ---------- Convertir la salida de hyprctl ----------
    function procesar(json) {
        let binds = [];
        try { binds = JSON.parse(json); } catch (e) { binds = []; }

        const filas = [];
        const porDesc = {};
        for (let i = 0; i < binds.length; i++) {
            const b = binds[i];
            if (!b.has_description || !b.description || b.submap !== "") continue;
            const d = String(b.description);
            let f = porDesc[d];
            if (!f) {
                const sep = d.indexOf(": ");
                f = {
                    categoria: sep > 0 ? d.substring(0, sep) : "Otros",
                    texto: sep > 0 ? d.substring(sep + 2) : d,
                    crudos: []
                };
                porDesc[d] = f;
                filas.push(f);
            }
            f.crudos.push({ modmask: b.modmask, key: String(b.key) });
        }

        for (let i = 0; i < filas.length; i++) {
            const f = filas[i];
            const c = f.crudos;
            const mismosMods = c.every(x => x.modmask === c[0].modmask);
            const digitos = c.every(x => /^[0-9]$/.test(x.key));
            if (c.length >= 3 && mismosMods && digitos) {
                // Varias teclas numericas: 1…0 (el 0 va al final, como en el teclado)
                const n = c.map(x => x.key === "0" ? 10 : parseInt(x.key));
                const max = Math.max.apply(null, n);
                f.combos = [{ mods: nombresMods(c[0].modmask), tecla: Math.min.apply(null, n) + "…" + (max === 10 ? "0" : max) }];
            } else {
                f.combos = c.map(x => ({ mods: nombresMods(x.modmask), tecla: nombreTecla(x.key) }));
            }
            const teclas = f.combos.map(x => x.mods.join(" ") + " " + x.tecla).join(" ");
            f.busqueda = normalizar(f.categoria + " " + f.texto + " " + teclas);
            delete f.crudos;
        }
        atajos = filas;
    }

    // ---------- Grupos y columnas ----------
    readonly property var grupos: {
        const q = normalizar(consulta.trim());
        const lista = [];
        const indice = {};
        for (let i = 0; i < atajos.length; i++) {
            const a = atajos[i];
            if (q !== "" && !a.busqueda.includes(q)) continue;
            let g = indice[a.categoria];
            if (!g) {
                g = { nombre: a.categoria, filas: [] };
                indice[a.categoria] = g;
                lista.push(g);
            }
            g.filas.push(a);
        }
        return lista;
    }

    // Reparte los grupos en columnas parejas (cada grupo va a la mas corta)
    readonly property var columnas: {
        const cols = [];
        const altos = [];
        for (let i = 0; i < numColumnas; i++) { cols.push([]); altos.push(0); }
        for (let i = 0; i < grupos.length; i++) {
            let min = 0;
            for (let j = 1; j < numColumnas; j++) if (altos[j] < altos[min]) min = j;
            cols[min].push(grupos[i]);
            altos[min] += grupos[i].filas.length + 2;
        }
        return cols;
    }

    Process {
        id: lectura
        command: ["hyprctl", "binds", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                ayuda.procesar(this.text);
                ayuda.cargando = false;
            }
        }
    }

    IpcHandler {
        target: "ayuda"
        function alternar(): void { sup.alternar(); }
        function abrir(): void { sup.abrir(); }
        function cerrar(): void { sup.cerrar(); }
    }

    Superposicion {
        id: sup
        ancho: 1000
        posicionY: 0.1

        onAbrio: {
            campo.text = "";
            desplazable.contentY = 0;
            ayuda.cargando = true;
            lectura.running = true;
            Qt.callLater(() => campo.forceActiveFocus());
        }
        onCerro: ayuda.atajos = []

        // ---------- Cabecera: titulo y buscador ----------
        Item {
            width: parent.width
            height: 46

            Text {
                id: titulo
                anchors.left: parent.left
                anchors.leftMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                text: "󰌌  Atajos de teclado"
                color: Tema.texto
                font.family: Tema.fuenteBarra
                font.pixelSize: 19
                font.bold: true
            }

            Rectangle {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(320, parent.width * 0.45)
                height: 42
                radius: 12
                color: Tema.campo
                border.width: 1
                border.color: campo.activeFocus ? Tema.conAlfa(Tema.acento, 0.6) : Tema.borde

                Text {
                    id: lupa
                    anchors.left: parent.left
                    anchors.leftMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    text: "󰍉"
                    color: Tema.acento
                    font.family: Tema.fuenteBarra
                    font.pixelSize: 17
                }

                TextInput {
                    id: campo
                    anchors.left: lupa.right
                    anchors.leftMargin: 10
                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    color: Tema.texto
                    font.family: Tema.fuenteBarra
                    font.pixelSize: 14
                    clip: true
                    focus: true

                    onTextChanged: {
                        ayuda.consulta = text;
                        desplazable.contentY = 0;
                    }

                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Escape) {
                            sup.cerrar();
                        } else if (event.key === Qt.Key_Down || event.key === Qt.Key_PageDown) {
                            desplazable.flick(0, event.key === Qt.Key_Down ? -800 : -2400);
                        } else if (event.key === Qt.Key_Up || event.key === Qt.Key_PageUp) {
                            desplazable.flick(0, event.key === Qt.Key_Up ? 800 : 2400);
                        } else {
                            return;
                        }
                        event.accepted = true;
                    }
                }

                Text {
                    anchors.left: campo.left
                    anchors.verticalCenter: parent.verticalCenter
                    visible: campo.text.length === 0
                    text: "Filtrar atajos…"
                    color: Tema.tenue
                    font.family: Tema.fuenteBarra
                    font.pixelSize: 14
                }
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Tema.borde
        }

        // ---------- Columnas por categoria ----------
        Flickable {
            id: desplazable
            width: parent.width
            height: Math.min(contentHeight, Math.round(sup.height * 0.72))
            contentHeight: filaColumnas.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            visible: ayuda.grupos.length > 0

            Row {
                id: filaColumnas
                width: desplazable.width
                spacing: ayuda.separacion

                Repeater {
                    model: ayuda.columnas

                    Column {
                        id: columna
                        required property var modelData
                        width: (filaColumnas.width - ayuda.separacion * (ayuda.numColumnas - 1)) / ayuda.numColumnas
                        spacing: 18

                        Repeater {
                            model: columna.modelData

                            Column {
                                id: grupo
                                required property var modelData
                                width: columna.width
                                spacing: 8

                                Text {
                                    leftPadding: 2
                                    text: grupo.modelData.nombre
                                    color: Tema.acento
                                    font.family: Tema.fuenteBarra
                                    font.pixelSize: 12
                                    font.bold: true
                                    font.capitalization: Font.AllUppercase
                                    font.letterSpacing: 1
                                }

                                Repeater {
                                    model: grupo.modelData.filas

                                    // Una fila: descripcion a la izquierda, teclas a la derecha
                                    Item {
                                        id: fila
                                        required property var modelData
                                        width: grupo.width
                                        height: Math.max(descripcion.implicitHeight, teclas.implicitHeight)

                                        Text {
                                            id: descripcion
                                            anchors.left: parent.left
                                            anchors.leftMargin: 2
                                            anchors.right: teclas.left
                                            anchors.rightMargin: 10
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: fila.modelData.texto
                                            color: Tema.suave
                                            font.family: Tema.fuenteBarra
                                            font.pixelSize: 12
                                            wrapMode: Text.Wrap
                                        }

                                        // Combinaciones en una sola linea, separadas por "o"
                                        Row {
                                            id: teclas
                                            anchors.right: parent.right
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: 4

                                            Repeater {
                                                model: fila.modelData.combos

                                                Row {
                                                    id: combo
                                                    required property var modelData
                                                    required property int index
                                                    spacing: 3

                                                    // Separador con la combinacion anterior
                                                    Text {
                                                        visible: combo.index > 0
                                                        anchors.verticalCenter: parent.verticalCenter
                                                        rightPadding: 3
                                                        text: "o"
                                                        color: Tema.tenue
                                                        font.family: Tema.fuenteBarra
                                                        font.pixelSize: 11
                                                    }

                                                    Repeater {
                                                        model: combo.modelData.mods.concat([combo.modelData.tecla])

                                                        // Tecla estilo "keycap"
                                                        Rectangle {
                                                            id: chip
                                                            required property var modelData
                                                            readonly property bool esMod: ["Super", "Ctrl", "Alt", "Shift"].indexOf(modelData) >= 0
                                                            width: Math.max(24, etiqueta.implicitWidth + 14)
                                                            height: 24
                                                            radius: 6
                                                            color: esMod ? Tema.pildora : Tema.campo
                                                            border.width: 1
                                                            border.color: esMod ? Tema.borde : Tema.bordeFuerte

                                                            // Borde inferior mas grueso, como una tecla
                                                            Rectangle {
                                                                anchors.left: parent.left
                                                                anchors.right: parent.right
                                                                anchors.bottom: parent.bottom
                                                                anchors.leftMargin: 3
                                                                anchors.rightMargin: 3
                                                                height: 2
                                                                radius: 1
                                                                color: Tema.conAlfa(Tema.acento, chip.esMod ? 0.25 : 0.5)
                                                            }

                                                            Text {
                                                                id: etiqueta
                                                                anchors.centerIn: parent
                                                                anchors.verticalCenterOffset: -1
                                                                text: chip.modelData
                                                                color: chip.esMod ? Tema.suave : Tema.texto
                                                                font.family: Tema.fuenteBarra
                                                                font.pixelSize: 11
                                                                font.bold: !chip.esMod
                                                            }
                                                        }
                                                    }

                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // ---------- Sin resultados ----------
        Text {
            visible: ayuda.grupos.length === 0
            width: parent.width
            topPadding: 24
            bottomPadding: 24
            horizontalAlignment: Text.AlignHCenter
            text: ayuda.cargando ? "Leyendo atajos…"
                  : ayuda.consulta.trim() !== "" ? "Ningún atajo coincide con «" + ayuda.consulta.trim() + "»"
                  : "No hay atajos con descripción en binds.lua"
            color: Tema.tenue
            font.family: Tema.fuenteBarra
            font.pixelSize: 13
        }

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: "Escribe para filtrar   ·   Flechas desplazar   ·   Esc cerrar"
            color: Tema.conAlfa(Tema.tenue, 0.8)
            font.family: Tema.fuenteBarra
            font.pixelSize: 11
        }
    }
}
