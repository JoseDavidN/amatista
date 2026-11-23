// Modo café compartido: lo cambian la barra, el IPC y los atajos, y lo
// obedece Inactividad. Al reiniciar el escritorio vuelve a estar activa.
pragma Singleton

import Quickshell

Singleton {
    property bool activa: true

    function alternar() {
        activa = !activa;
        Quickshell.execDetached(["notify-send", "-a", "Sistema", "-u", "low", "Inactividad",
            activa ? "Bloqueo automático activado" : "Modo café: no se bloqueará ni apagará la pantalla"]);
    }
}
