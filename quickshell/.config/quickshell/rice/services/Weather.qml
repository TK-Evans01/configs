pragma Singleton
import QtQuick
import Quickshell.Io
import "../config"

// Forecast from Open-Meteo (no key) for Settings.weatherLat/Lon.
// current: { temp, feels, humidity, wind, code, isDay }
// hourly:  next 24h [{ time (Date), temp, code, pop, isDay }]
// daily:   7 days  [{ date (Date), code, max, min, pop, sunrise, sunset }]
QtObject {
    id: root

    property bool loading: false
    property string error: ""
    property date updated: new Date(0)
    property var current: null
    property var hourly: []
    property var daily: []

    readonly property string tempUnit: Settings.weatherImperial ? "°F" : "°C"
    readonly property string windUnit: Settings.weatherImperial ? "mph" : "km/h"

    // WMO weather code → [day glyph, night glyph, label]
    function _info(code) {
        if (code === 0) return ["󰖙", "󰖔", "clear"];
        if (code === 1) return ["󰖕", "󰼱", "mostly clear"];
        if (code === 2) return ["󰖕", "󰼱", "partly cloudy"];
        if (code === 3) return ["󰖐", "󰖐", "overcast"];
        if (code === 45 || code === 48) return ["󰖑", "󰖑", "fog"];
        if (code >= 51 && code <= 57) return ["󰖗", "󰖗", "drizzle"];
        if (code === 65 || code === 67 || code === 82) return ["󰖖", "󰖖", "heavy rain"];
        if ((code >= 61 && code <= 67) || (code >= 80 && code <= 82)) return ["󰖗", "󰖗", "rain"];
        if (code === 75 || code === 86) return ["󰼶", "󰼶", "heavy snow"];
        if ((code >= 71 && code <= 77) || code === 85 || code === 86) return ["󰖘", "󰖘", "snow"];
        if (code >= 95) return ["󰙾", "󰙾", "thunderstorm"];
        return ["󰖐", "󰖐", "—"];
    }
    function icon(code, isDay) { return _info(code)[isDay === false ? 1 : 0]; }
    function describe(code) { return _info(code)[2]; }
    function color(code, isDay) {
        if (code === 0 || code === 1) return isDay === false ? Theme.purple : Theme.yellow;
        if (code === 2) return isDay === false ? Theme.purpleDim : Theme.yellowBright;
        if (code >= 95) return Theme.orange;
        if ((code >= 71 && code <= 77) || code === 85 || code === 86) return Theme.textBright;
        if (code >= 51) return Theme.blue;
        return Theme.subtext;
    }
    function fmtTemp(t) { return Math.round(t) + "°"; }

    function refresh() {
        if (fetcher.running) return;
        loading = true;
        fetcher.running = true;
    }

    readonly property var fetcher: Process {
        command: ["curl", "-sf", "--max-time", "15",
            "https://api.open-meteo.com/v1/forecast"
            + "?latitude=" + Settings.weatherLat + "&longitude=" + Settings.weatherLon
            + "&current=temperature_2m,apparent_temperature,relative_humidity_2m,weather_code,is_day,wind_speed_10m"
            + "&hourly=temperature_2m,weather_code,precipitation_probability,is_day"
            + "&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max,sunrise,sunset"
            + (Settings.weatherImperial ? "&temperature_unit=fahrenheit&wind_speed_unit=mph" : "")
            + "&timezone=auto&forecast_days=7&forecast_hours=24"]
        stdout: StdioCollector {
            onStreamFinished: root._parse(this.text)
        }
        onExited: code => {
            root.loading = false;
            if (code !== 0) root.error = "fetch failed (curl " + code + ")";
        }
    }

    // Open-Meteo local times have no zone suffix; Date() reads them as local,
    // which is right while the forecast spot shares this machine's zone.
    function _parse(text) {
        let o;
        try { o = JSON.parse(text); } catch (e) { o = null; }
        if (!o || !o.current) { if (text) error = "bad response"; return; }
        const c = o.current;
        current = {
            temp: c.temperature_2m, feels: c.apparent_temperature, humidity: c.relative_humidity_2m,
            wind: c.wind_speed_10m, code: c.weather_code, isDay: c.is_day === 1
        };
        const h = o.hourly;
        hourly = h.time.map((t, i) => ({
            time: new Date(t), temp: h.temperature_2m[i], code: h.weather_code[i],
            pop: h.precipitation_probability[i] || 0, isDay: h.is_day[i] === 1
        }));
        const d = o.daily;
        daily = d.time.map((t, i) => ({
            date: new Date(t + "T12:00"), code: d.weather_code[i], max: d.temperature_2m_max[i],
            min: d.temperature_2m_min[i], pop: d.precipitation_probability_max[i] || 0,
            sunrise: new Date(d.sunrise[i]), sunset: new Date(d.sunset[i])
        }));
        error = "";
        updated = new Date();
    }

    readonly property var _timer: Timer {
        interval: Settings.weatherRefreshMin * 60000
        running: Settings.showWeather
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
