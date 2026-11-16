// ==========================================================
// Perfil de energía (power-profiles-daemon)
//
// Solo se activa en equipos con batería. El perfil se lee una vez al
// iniciar y después se escuchan los cambios por D-Bus con un único
// "gdbus monitor" persistente (sin sondeo).
// ==========================================================
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

Singleton {
    id: servicio

    readonly property var dispositivo: UPower.displayDevice
    readonly property bool hayBateria: dispositivo !== null && dispositivo.isLaptopBattery

    // true cuando powerprofilesctl responde (servicio net.hadess.PowerProfiles)
    property bool disponible: false
    property string perfil: ""

    readonly property var orden: ["power-saver", "balanced", "performance"]

    function ciclar() {
        if (!disponible) return;
        const i = orden.indexOf(perfil);
        const siguiente = orden[(i + 1) % orden.length];
        perfil = siguiente;            // respuesta inmediata; el monitor lo confirma
        Quickshell.execDetached(["powerprofilesctl", "set", siguiente]);
    }

    // Lectura inicial (solo si hay batería)
    Process {
        id: lectura
        running: servicio.hayBateria
        command: ["powerprofilesctl", "get"]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = this.text.trim();
                if (p !== "") {
                    servicio.perfil = p;
                    servicio.disponible = true;
                }
            }
        }
    }

    // Cambios hechos desde cualquier sitio (otra app, el propio daemon...)
    Process {
        running: servicio.disponible
        command: ["gdbus", "monitor", "--system",
                  "--dest", "net.hadess.PowerProfiles",
                  "--object-path", "/net/hadess/PowerProfiles"]
        stdout: SplitParser {
            onRead: linea => {
                const m = linea.match(/'ActiveProfile': <'([a-z-]+)'>/);
                if (m) servicio.perfil = m[1];
            }
        }
    }
}
