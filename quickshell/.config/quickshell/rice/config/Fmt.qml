pragma Singleton
import QtQuick

// Shared text formatting.
QtObject {
    // Compact age: "now", "5m", "3h", "2d".
    function age(seconds) {
        const s = Math.max(0, seconds);
        if (s < 60) return "now";
        if (s < 3600) return Math.floor(s / 60) + "m";
        if (s < 86400) return Math.floor(s / 3600) + "h";
        return Math.floor(s / 86400) + "d";
    }
    // Age of a Date or a Unix timestamp in seconds.
    function since(t) {
        const ms = t instanceof Date ? t.getTime() : Number(t) * 1000;
        return age((Date.now() - ms) / 1000);
    }
}
