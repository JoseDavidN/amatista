// ==========================================================
// Servidor de notificaciones (reemplaza a mako)
//
// - Esquina superior derecha, maximo 5 visibles, la mas nueva arriba.
// - Baja: 3 s · Normal: 5 s · Critica: se queda hasta cerrarla.
// - Clic izquierdo: accion principal · derecho: cerrar · central: cerrar todas.
// - Historial de las ultimas 30 y modo "no molestar".
//
// Control desde la terminal o atajos de Hyprland:
//   qs -c escritorio ipc call notificaciones cerrar
//   qs -c escritorio ipc call notificaciones cerrarTodas
//   qs -c escritorio ipc call notificaciones restaurar
//   qs -c escritorio ipc call notificaciones noMolestar
// ==========================================================
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Notifications
import qs.Comun

Scope {
    id: servicio

    // ---------- Ajustes ----------
    readonly property int maxVisibles: 5
    readonly property int maxHistorial: 30
    readonly property int duracionBaja: 3000
    readonly property int duracionNormal: 5000
    readonly property int duracionMaxima: 30000

    // Apps con duracion propia (nombre de app -> milisegundos)
    readonly property var duracionPorApp: ({
        "networkmanager_dmenu": 3000,
        "Red": 3000
    })

    property bool noMolestar: false

    // ---------- Estado ----------
    // Las notificaciones vivas se guardan en un mapa, nunca en el modelo:
    // el servidor las destruye al cerrarse y un modelo con referencias
    // muertas hace fallar la siguiente lectura.
    property var vivas: ({})

    // Lo que se muestra en pantalla y el historial guardan solo copias de datos
    property ListModel popups: ListModel {}
    property ListModel historial: ListModel {}

    // ---------- Conversion de una notificacion a datos simples ----------
    function urgenciaDe(n) {
        if (n.urgency === NotificationUrgency.Critical) return 2;
        if (n.urgency === NotificationUrgency.Low) return 0;
        return 1;
    }

    function duracionPara(n) {
        if (n.urgency === NotificationUrgency.Critical) return 0;
        let base = n.urgency === NotificationUrgency.Low ? duracionBaja : duracionNormal;
        const app = String(n.appName || "");
        if (duracionPorApp[app] !== undefined) base = duracionPorApp[app];
        let pedida = Number(n.expireTimeout || 0);
        if (pedida > 0 && pedida < 100) pedida *= 1000;
        return pedida > 0 ? Math.min(duracionMaxima, pedida) : base;
    }

    function iconoPara(n) {
        const imagen = String(n.image || "");
        if (imagen !== "") return imagen.startsWith("/") ? "file://" + imagen : imagen;
        const icono = String(n.appIcon || "");
        if (icono === "") return "";
        if (icono.startsWith("/")) return "file://" + icono;
        if (icono.startsWith("file://")) return icono;
        return Quickshell.iconPath(icono, true);
    }

    function accionesDe(n) {
        const lista = [];
        const acciones = n.actions;
        for (let i = 0; i < acciones.length; i++)
            lista.push({ id: String(acciones[i].identifier), texto: String(acciones[i].text) });
        return JSON.stringify(lista);
    }

    function valorDe(n) {
        const hints = n.hints || {};
        return hints.value !== undefined ? Number(hints.value) : -1;
    }

    function datosDe(n) {
        return {
            nid: n.id,
            app: String(n.appName || "Sistema"),
            resumen: String(n.summary || ""),
            cuerpo: String(n.body || ""),
            icono: iconoPara(n),
            urgencia: urgenciaDe(n),
            duracion: duracionPara(n),
            acciones: accionesDe(n),
            valor: valorDe(n),
            hora: Date.now(),
            restaurada: false
        };
    }

    function copiar(o) {
        return {
            nid: o.nid, app: o.app, resumen: o.resumen, cuerpo: o.cuerpo,
            icono: o.icono, urgencia: o.urgencia, duracion: o.duracion,
            acciones: o.acciones, valor: o.valor, hora: o.hora,
            restaurada: o.restaurada
        };
    }

    function indiceEn(modelo, nid) {
        for (let i = 0; i < modelo.count; i++) {
            if (modelo.get(i).nid === nid) return i;
        }
        return -1;
    }

    // ---------- Flujo principal ----------
    function recibir(n) {
        n.tracked = true;
        vivas[n.id] = n;
        const datos = datosDe(n);
        const nid = datos.nid;

        // La app cerro la notificacion por su cuenta
        n.closed.connect(() => servicio.cerradaPorApp(nid));

        // Notificaciones que se actualizan (por ejemplo, el volumen)
        const refrescar = () => servicio.actualizar(nid);
        n.summaryChanged.connect(refrescar);
        n.bodyChanged.connect(refrescar);
        n.hintsChanged.connect(refrescar);

        // En "no molestar" solo pasan las criticas
        if (noMolestar && datos.urgencia < 2) {
            agregarAlHistorial(datos);
            delete vivas[nid];
            n.expire();
            return;
        }

        mostrar(datos);
    }

    function mostrar(datos) {
        const i = indiceEn(popups, datos.nid);
        if (i >= 0) popups.remove(i);
        popups.insert(0, datos);
        while (popups.count > maxVisibles)
            ocultar(popups.get(popups.count - 1).nid, "expirada");
    }

    function actualizar(nid) {
        const n = vivas[nid];
        const i = indiceEn(popups, nid);
        if (!n || i < 0) return;
        popups.set(i, {
            resumen: String(n.summary || ""),
            cuerpo: String(n.body || ""),
            valor: valorDe(n)
        });
    }

    // Quita la tarjeta, la guarda en el historial y avisa a la app
    function ocultar(nid, razon) {
        const i = indiceEn(popups, nid);
        if (i < 0) return;
        const datos = copiar(popups.get(i));
        popups.remove(i);
        agregarAlHistorial(datos);

        const n = vivas[nid];
        delete vivas[nid];
        if (n) {
            try {
                if (razon === "expirada") n.expire();
                else n.dismiss();
            } catch (e) {}
        }
    }

    function cerradaPorApp(nid) {
        delete vivas[nid];
        const i = indiceEn(popups, nid);
        if (i >= 0) popups.remove(i);
    }

    function agregarAlHistorial(datos) {
        const j = indiceEn(historial, datos.nid);
        if (j >= 0) historial.remove(j);
        datos.restaurada = false;
        historial.insert(0, datos);
        while (historial.count > maxHistorial)
            historial.remove(historial.count - 1);
    }

    function invocar(nid, accionId) {
        const n = vivas[nid];
        if (!n) {
            ocultar(nid, "descartada");
            return;
        }
        const acciones = n.actions;
        for (let i = 0; i < acciones.length; i++) {
            if (String(acciones[i].identifier) === accionId) {
                try { acciones[i].invoke(); } catch (e) {}
                break;
            }
        }
        if (vivas[nid] && !n.resident)
            ocultar(nid, "descartada");
    }

    function cerrarPrimera() {
        if (popups.count > 0) ocultar(popups.get(0).nid, "descartada");
    }

    function cerrarTodas() {
        while (popups.count > 0)
            ocultar(popups.get(0).nid, "descartada");
    }

    // Vuelve a mostrar la ultima notificacion cerrada (como "makoctl restore")
    function restaurar() {
        if (historial.count === 0) return;
        const datos = copiar(historial.get(0));
        historial.remove(0);
        datos.restaurada = true;
        if (datos.duracion === 0 && datos.urgencia < 2) datos.duracion = duracionNormal;
        mostrar(datos);
    }

    // ---------- Servidor D-Bus (org.freedesktop.Notifications) ----------
    NotificationServer {
        keepOnReload: false
        bodySupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        actionsSupported: true
        imageSupported: true
        persistenceSupported: true

        onNotification: n => servicio.recibir(n)
    }

    // ---------- Control por IPC (atajos de teclado, scripts) ----------
    IpcHandler {
        target: "notificaciones"

        function cerrar(): void { servicio.cerrarPrimera(); }
        function cerrarTodas(): void { servicio.cerrarTodas(); }
        function restaurar(): void { servicio.restaurar(); }
        function noMolestar(): string {
            servicio.noMolestar = !servicio.noMolestar;
            return servicio.noMolestar ? "No molestar: activado" : "No molestar: desactivado";
        }
    }

    // ---------- Ventana ----------
    // Ocupa toda la altura del lado derecho, pero la mascara solo deja
    // recibir clics sobre las tarjetas: el resto es transparente al raton.
    PanelWindow {
        id: ventana

        screen: Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
        color: "transparent"

        WlrLayershell.namespace: "notificaciones"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        // Respeta el espacio de Waybar para no taparla
        exclusionMode: ExclusionMode.Normal
        exclusiveZone: 0

        anchors {
            top: true
            bottom: true
            right: true
        }

        implicitWidth: Tema.anchoNotificacion + Tema.margenPantalla + 60

        mask: Region { item: lista }

        ListView {
            id: lista

            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: Tema.margenPantalla
            anchors.rightMargin: Tema.margenPantalla

            width: Tema.anchoNotificacion
            height: contentHeight
            spacing: 8
            interactive: false
            model: servicio.popups

            delegate: Tarjeta {
                onCerrar: nid => servicio.ocultar(nid, "descartada")
                onExpirar: nid => servicio.ocultar(nid, "expirada")
                onCerrarTodas: servicio.cerrarTodas()
                onAccion: (nid, accionId) => servicio.invocar(nid, accionId)
            }

            add: Transition {
                ParallelAnimation {
                    NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 220 }
                    NumberAnimation { property: "x"; from: 60; to: 0; duration: 280; easing.type: Easing.OutCubic }
                }
            }

            remove: Transition {
                ParallelAnimation {
                    NumberAnimation { property: "opacity"; to: 0; duration: 180 }
                    NumberAnimation { property: "x"; to: 60; duration: 200; easing.type: Easing.InCubic }
                }
            }

            displaced: Transition {
                NumberAnimation { property: "y"; duration: 240; easing.type: Easing.OutCubic }
            }
        }
    }
}
