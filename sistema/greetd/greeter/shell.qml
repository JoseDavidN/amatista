// ==========================================================
// Greeter de inicio de sesión (greetd), con el estilo del bloqueo
//
// Lo lanza /etc/greetd/iniciar-greeter.sh como el usuario "greeter".
// Prueba sin greetd:  qs -p <esta carpeta>   (Esc para salir)
// ==========================================================
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Greetd

ShellRoot {
    id: raiz

    // ---------- Usuarios reales del sistema (UID 1000+, con shell) ----------
    FileView {
        id: archivoPasswd
        path: "/etc/passwd"
        blockLoading: true
    }

    readonly property var usuarios: {
        const lista = [];
        const lineas = String(archivoPasswd.text() || "").split("\n");
        for (const linea of lineas) {
            const c = linea.split(":");
            if (c.length < 7)
                continue;
            const uid = parseInt(c[2]);
            if (uid < 1000 || uid >= 60000 || /(nologin|false)$/.test(c[6]))
                continue;
            const nombre = (c[4] || "").split(",")[0];
            lista.push({ usuario: c[0], nombre: nombre !== "" ? nombre : c[0] });
        }
        return lista;
    }

    property int indiceUsuario: 0
    readonly property var actual: usuarios.length > 0
        ? usuarios[Math.min(indiceUsuario, usuarios.length - 1)]
        : { usuario: "", nombre: "" }

    function cambiarUsuario(paso) {
        if (usuarios.length < 2 || verificando)
            return;
        indiceUsuario = (indiceUsuario + paso + usuarios.length) % usuarios.length;
        mensaje = "";
    }

    // ---------- Estado del inicio de sesión ----------
    property string contrasena: ""
    property bool verificando: false
    property string mensaje: ""
    signal fallo()

    function entrar() {
        if (verificando || actual.usuario === "")
            return;
        if (!Greetd.available) {
            mensaje = "greetd no está disponible (modo de prueba)";
            return;
        }
        verificando = true;
        mensaje = "";
        Greetd.createSession(actual.usuario);
    }

    function reiniciarIntento(texto) {
        if (Greetd.state !== GreetdState.Inactive)
            Greetd.cancelSession();
        contrasena = "";
        verificando = false;
        mensaje = texto;
        fallo();
    }

    Connections {
        target: Greetd

        function onAuthMessage(message, error, responseRequired, echoResponse) {
            if (responseRequired)
                Greetd.respond(raiz.contrasena);
            else if (error)
                raiz.mensaje = message;
        }

        function onAuthFailure(message) {
            raiz.reiniciarIntento("Contraseña incorrecta");
        }

        function onReadyToLaunch() {
            // Abre la sesión real y cierra el greeter
            Greetd.launch(["/etc/greetd/iniciar-sesion.sh"], [
                "XDG_SESSION_TYPE=wayland",
                "XDG_CURRENT_DESKTOP=Hyprland",
                "XDG_SESSION_DESKTOP=Hyprland"
            ], true);
        }

        function onError(error) {
            raiz.reiniciarIntento(error);
        }
    }

    // ---------- Una superficie por monitor; el formulario va en el primero ----------
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: ventana
            required property var modelData
            readonly property bool principal: modelData === Quickshell.screens[0]

            screen: modelData
            anchors { left: true; right: true; top: true; bottom: true }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "greeter"
            WlrLayershell.keyboardFocus: principal ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            color: "#2a1f3d"

            Superficie {
                anchors.fill: parent
                greeter: raiz
                principal: ventana.principal
            }
        }
    }
}
