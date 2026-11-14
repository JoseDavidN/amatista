// ==========================================================
// Quickshell - pantalla de bloqueo
// Ubicacion: ~/.config/quickshell/lock/shell.qml
// Lanzar con: qs -p ~/.config/quickshell/lock   (o el script "bloquear")
// ==========================================================
import Quickshell
import Quickshell.Wayland
import QtQuick

ShellRoot {
    LockContext {
        id: contexto

        onUnlocked: {
            bloqueo.locked = false;
            Qt.quit();
        }
    }

    // Protocolo de bloqueo oficial de Wayland: si este proceso falla,
    // la sesion sigue bloqueada.
    WlSessionLock {
        id: bloqueo
        locked: true

        // Se crea una superficie por cada monitor
        WlSessionLockSurface {
            LockSurface {
                anchors.fill: parent
                context: contexto
            }
        }
    }
}
