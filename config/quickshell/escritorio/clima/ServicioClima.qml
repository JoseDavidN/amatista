// ==========================================================
// Clima (estado compartido por todas las barras)
//
// Pronóstico: Open-Meteo (sin clave).
// Ubicación: por la IP (ipwho.is), o una ciudad elegida a mano en el panel,
// que se recuerda en ~/.local/state/amatista/clima.json
//
// No consulta nada en segundo plano: solo con el panel abierto y si los
// datos tienen más de 10 minutos.
//
//   qs -c escritorio ipc call clima alternar
// ==========================================================
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: servicio

    readonly property int vigencia: 10 * 60 * 1000

    property var lugar: null        // { nombre, region, lat, lon }
    property bool manual: false     // true: ciudad elegida a mano
    property var datos: null        // respuesta del pronóstico
    property var actualizado: null  // Date de la última consulta correcta
    property bool cargando: false
    property string error: ""

    property var resultados: []     // búsqueda de ciudades
    property string estadoBusqueda: ""

    signal pedirPanel()

    // Cada actualización o búsqueda tiene un turno: las respuestas viejas se descartan
    property int turno: 0
    property int turnoBusqueda: 0

    // ---------- Consultas ----------
    // listo(json) si todo salió bien, listo(null) si no
    function pedir(url, listo) {
        const x = new XMLHttpRequest();
        x.onreadystatechange = () => {
            if (x.readyState !== XMLHttpRequest.DONE) return;
            let j = null;
            if (x.status === 200) {
                try { j = JSON.parse(x.responseText); } catch (e) { j = null; }
            }
            listo(j);
        };
        x.open("GET", url);
        x.send();
    }

    function actualizarSiHaceFalta() {
        if (cargando) return;
        if (!datos || !actualizado || Date.now() - actualizado.getTime() > vigencia) actualizar();
    }

    function actualizar() {
        const t = ++turno;
        cargando = true;
        error = "";
        limite.restart();
        if (manual && lugar) {
            consultar(t, lugar);
            return;
        }
        pedir("https://ipwho.is/?lang=es", j => {
            if (t !== turno) return;
            if (j && j.success && typeof j.latitude === "number")
                consultar(t, { nombre: j.city || j.region || "", region: [j.region, j.country].filter(p => p && p !== j.city).join(", "),
                               lat: j.latitude, lon: j.longitude });
            else if (lugar) consultar(t, lugar);   // última ubicación conocida
            else fallar("No se pudo obtener la ubicación");
        });
    }

    function consultar(t, l) {
        const base = "latitude=" + l.lat + "&longitude=" + l.lon + "&timezone=auto";
        pedir("https://api.open-meteo.com/v1/forecast?" + base
            + "&current=temperature_2m,relative_humidity_2m,is_day,weather_code"
            + "&hourly=precipitation_probability&forecast_hours=24"
            + "&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max&forecast_days=7",
            j => {
                if (t !== turno) return;
                if (!j || !j.current || !j.hourly || !j.daily) {
                    fallar("No se pudo consultar el clima");
                    return;
                }
                limite.stop();
                lugar = l;
                datos = j;
                actualizado = new Date();
                cargando = false;
            });
    }

    function fallar(mensaje) {
        limite.stop();
        turno++;
        cargando = false;
        error = mensaje;
    }

    Timer {
        id: limite
        interval: 15000
        onTriggered: servicio.fallar("Sin respuesta del servicio")
    }

    // ---------- Ubicación ----------
    function buscar(texto) {
        const t = ++turnoBusqueda;
        resultados = [];
        estadoBusqueda = "";
        texto = texto.trim();
        if (texto.length < 2) return;
        estadoBusqueda = "Buscando…";
        pedir("https://geocoding-api.open-meteo.com/v1/search?count=5&language=es&name=" + encodeURIComponent(texto), j => {
            if (t !== turnoBusqueda) return;
            resultados = j && j.results ? j.results.map(r => ({
                nombre: r.name, region: [r.admin1, r.country].filter(p => p && p !== r.name).join(", "),
                lat: r.latitude, lon: r.longitude })) : [];
            estadoBusqueda = !j ? "Sin conexión" : resultados.length === 0 ? "Sin resultados" : "";
        });
    }

    function limpiarBusqueda() {
        turnoBusqueda++;
        resultados = [];
        estadoBusqueda = "";
    }

    function elegir(l) {
        manual = true;
        lugar = l;
        cambiarLugar();
    }

    function usarActual() {
        manual = false;
        lugar = null;
        cambiarLugar();
    }

    function cambiarLugar() {
        datos = null;
        archivo.setText(JSON.stringify({ manual: manual ? lugar : null }) + "\n");
        actualizar();
    }

    Process {
        running: true
        command: ["mkdir", "-p", Quickshell.env("HOME") + "/.local/state/amatista"]
    }

    FileView {
        id: archivo
        path: Quickshell.env("HOME") + "/.local/state/amatista/clima.json"
        blockLoading: true
        printErrors: false
        onLoaded: {
            try {
                const g = JSON.parse(text()).manual;
                if (g && typeof g.lat === "number" && typeof g.lon === "number") {
                    servicio.lugar = g;
                    servicio.manual = true;
                }
            } catch (e) {}
        }
    }

    // ---------- Textos e iconos (códigos WMO) ----------
    function icono(codigo, dia) {
        const c = codigo;
        let g = 0xf0590;                                         // nublado
        if (c <= 1) g = dia ? 0xf0599 : 0xf0594;                 // despejado
        else if (c === 2) g = dia ? 0xf0595 : 0xf0f31;           // parcialmente nublado
        else if (c === 45 || c === 48) g = 0xf0591;              // niebla
        else if (c === 56 || c === 57 || c === 66 || c === 67) g = 0xf067f; // lluvia helada
        else if (c === 65 || c === 81 || c === 82) g = 0xf0596;  // lluvia fuerte
        else if ((c >= 51 && c <= 64) || c === 80) g = 0xf0597;  // lluvia
        else if ((c >= 71 && c <= 77) || c === 85 || c === 86) g = 0xf0598; // nieve
        else if (c === 95) g = 0xf067e;                          // tormenta
        else if (c === 96 || c === 99) g = 0xf0592;              // granizo
        return String.fromCodePoint(g);
    }

    readonly property var descripciones: ({
        0: "Despejado", 1: "Mayormente despejado", 2: "Parcialmente nublado", 3: "Nublado",
        45: "Niebla", 48: "Niebla con escarcha",
        51: "Llovizna ligera", 53: "Llovizna", 55: "Llovizna intensa",
        56: "Llovizna helada", 57: "Llovizna helada intensa",
        61: "Lluvia ligera", 63: "Lluvia", 65: "Lluvia fuerte",
        66: "Lluvia helada", 67: "Lluvia helada fuerte",
        71: "Nieve ligera", 73: "Nieve", 75: "Nieve fuerte", 77: "Granos de nieve",
        80: "Chubascos ligeros", 81: "Chubascos", 82: "Chubascos fuertes",
        85: "Chubascos de nieve", 86: "Chubascos de nieve fuertes",
        95: "Tormenta eléctrica", 96: "Tormenta con granizo", 99: "Tormenta con granizo fuerte"
    })
    function descripcion(codigo) { return descripciones[codigo] || "Desconocido"; }

    IpcHandler {
        target: "clima"
        function alternar(): void { servicio.pedirPanel(); }
        function actualizar(): void { servicio.actualizar(); }
        function estado(): string {
            if (servicio.error) return servicio.error;
            if (!servicio.datos) return servicio.cargando ? "cargando" : "sin datos";
            const a = servicio.datos.current;
            return servicio.lugar.nombre + ": " + Math.round(a.temperature_2m) + "°, " + servicio.descripcion(a.weather_code);
        }
    }
}
