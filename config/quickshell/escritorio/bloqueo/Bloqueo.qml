// ==========================================================
// Pantalla de bloqueo integrada en el escritorio (usa Tema.qml)
//
//   qs -c escritorio ipc call bloqueo bloquear
//   (o el script ~/.local/bin/bloquear, que tiene respaldo)
// ==========================================================
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Scope {
    id: bloqueo

    property bool activo: false

    function bloquear() {
        activo = true;
    }

    ContextoBloqueo {
        id: contexto
        onUnlocked: {
            bloqueo.activo = false;
            contexto.currentText = "";
        }
    }

    // Protocolo de bloqueo oficial de Wayland: si el escritorio falla
    // mientras esta bloqueado, la sesion sigue bloqueada.
    WlSessionLock {
        locked: bloqueo.activo

        // Una superficie por monitor
        WlSessionLockSurface {
            SuperficieBloqueo {
                anchors.fill: parent
                context: contexto
            }
        }
    }

    IpcHandler {
        target: "bloqueo"
        function bloquear(): void { bloqueo.bloquear(); }
        function estado(): string { return bloqueo.activo ? "bloqueado" : "desbloqueado"; }
    }
}
