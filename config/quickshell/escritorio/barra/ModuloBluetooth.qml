// ==========================================================
// Bluetooth (modulo nativo de Quickshell)
//   Sin conexiones: 󰂯 azul · Conectado: 󰂱 cian + numero de dispositivos
// Clic: panel de Bluetooth · Derecho: encender / apagar
// ==========================================================
import QtQuick
import Quickshell
import Quickshell.Bluetooth
import qs.Comun
import qs.paneles

Pildora {
    id: mod

    readonly property var adaptador: Bluetooth.defaultAdapter
    readonly property bool encendido: adaptador !== null && adaptador.enabled
    readonly property var conectados: {
        const r = [];
        const lista = Bluetooth.devices.values;
        for (let i = 0; i < lista.length; i++) {
            if (lista[i].connected) r.push(lista[i]);
        }
        return r;
    }

    // Sin controlador Bluetooth el modulo no se muestra
    visible: adaptador !== null

    icono: encendido && conectados.length > 0 ? "󰂱" : "󰂯"
    colorIcono: encendido && conectados.length > 0 ? Tema.cian : Tema.acento
    texto: encendido && conectados.length > 0 ? String(conectados.length) : ""


    PanelBluetooth {
        id: panel
        objetivo: mod
    }

    activa: panel.abierto
    // El tooltip no hace falta: el panel muestra todo
    tooltip: ""
    onClicIzquierdo: panel.alternar()
    onClicDerecho: panel.energia(!encendido)
}
