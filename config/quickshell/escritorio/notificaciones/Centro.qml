// Historial de notificaciones y "no molestar", compartidos con la barra
pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: centro

    readonly property int maximo: 30
    property bool noMolestar: false
    property int sinLeer: 0
    property ListModel historial: ListModel {}

    function indice(nid) {
        for (let i = 0; i < historial.count; i++)
            if (historial.get(i).nid === nid) return i;
        return -1;
    }

    function contar() {
        let n = 0;
        for (let i = 0; i < historial.count; i++)
            if (!historial.get(i).leida) n++;
        sinLeer = n;
    }

    function agregar(datos, leida) {
        const j = indice(datos.nid);
        if (j >= 0) historial.remove(j);
        datos.restaurada = false;
        datos.leida = leida;
        historial.insert(0, datos);
        while (historial.count > maximo) historial.remove(historial.count - 1);
        contar();
    }

    function marcarLeidas() {
        for (let i = 0; i < historial.count; i++)
            historial.setProperty(i, "leida", true);
        sinLeer = 0;
    }

    function quitar(i) {
        if (i < 0 || i >= historial.count) return;
        historial.remove(i);
        contar();
    }

    function limpiar() {
        historial.clear();
        sinLeer = 0;
    }
}
