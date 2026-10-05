pragma Singleton
import QtQuick
import Quickshell.Io

// Hyprland binds (hyprctl binds -j) turned into readable rows for the
// launcher's keybinds mode. Loaded when wanted; workspace 1…0 binds collapse.
// rows: [{ keys, label, group, dispatcher, arg, runnable }]
QtObject {
    id: root

    property var rows: []

    function load() {
        if (!proc.running) proc.running = true;
    }

    readonly property var _mods: [[64, "SUPER"], [4, "CTRL"], [8, "ALT"], [1, "SHIFT"]]
    function _keys(b) {
        const parts = _mods.filter(m => b.modmask & m[0]).map(m => m[1]);
        const k = ({ "mouse:272": "LMB drag", "mouse:273": "RMB drag", mouse_down: "scroll ↓", mouse_up: "scroll ↑",
                     period: ".", comma: ",", slash: "/", Tab: "TAB", Print: "PRINT" })[b.key] || b.key.replace(/^XF86/, "");
        return parts.concat([k]).join(" + ");
    }

    function _describe(b) {
        const d = b.dispatcher, a = (b.arg || "").trim();
        const dir = { l: "left", r: "right", u: "up", d: "down" };
        if (d === "exec") {
            let m = a.match(/ipc call rice (\w+)\s*(.*)$/);
            if (m) {
                const arg = m[2].replace(/"/g, "").trim();
                const name = ({ quicksettings: "quick settings", dashboard: "dashboard", launcher: "launcher",
                                nightlight: "night light", dnd: "do not disturb", mail: "mail",
                                screenshot: "screenshot" })[m[1]] || m[1];
                return ["shell", name + (arg ? ": " + arg : "")];
            }
            m = a.match(/playerctl.*\s(play-pause|next|previous)$/);
            if (m) return ["media", { "play-pause": "play / pause", next: "next track", previous: "previous track" }[m[1]]];
            if (/wpctl set-volume.*\+/.test(a)) return ["hardware", "volume up"];
            if (/wpctl set-volume/.test(a)) return ["hardware", "volume down"];
            if (/wpctl set-mute.*SOURCE/.test(a)) return ["hardware", "mute microphone"];
            if (/wpctl set-mute/.test(a)) return ["hardware", "mute"];
            if (/brightnessctl.*\+/.test(a)) return ["hardware", "brightness up"];
            if (/brightnessctl/.test(a)) return ["hardware", "brightness down"];
            if (/grimblast/.test(a)) return ["tools", "screenshot (" + (a.split(/\s+/).find(w => ["area", "active", "output", "screen"].includes(w)) || "area") + ")"];
            m = a.match(/^(?:(?:alacritty|ghostty) -e )?(\S+)/);
            return ["apps", "open " + (m ? m[1].split("/").pop() : a)];
        }
        if (d === "workspace") return ["workspaces", /^e[+-]/.test(a) ? (a.startsWith("e+") ? "next workspace" : "previous workspace") : "go to workspace " + a];
        if (d === "movetoworkspace") return ["workspaces", "move window to workspace " + a];
        if (d === "movecurrentworkspacetomonitor") return ["workspaces", "move workspace to other monitor"];
        if (d === "movefocus") return ["windows", "focus " + (dir[a] || a)];
        if (d === "killactive") return ["windows", "close window"];
        if (d === "togglefloating") return ["windows", "toggle floating"];
        if (d === "fullscreen") return ["windows", "fullscreen"];
        if (d === "pseudo") return ["windows", "pseudo-tile"];
        if (d === "layoutmsg") return ["windows", a];
        if (d === "movewindow") return ["windows", "move window"];
        if (d === "resizewindow") return ["windows", "resize window"];
        if (d === "exit") return ["session", "exit Hyprland"];
        return ["other", d + (a ? " " + a : "")];
    }

    function _parse(list) {
        const out = [];
        const seen = {};
        for (const b of list) {
            if (b.submap) continue;
            const desc = b.has_description && b.description ? ["other", b.description] : _describe(b);
            // Collapse SUPER+1…0 style runs into one row.
            if ((b.dispatcher === "workspace" || b.dispatcher === "movetoworkspace") && /^\d+$/.test(b.arg)) {
                const key = b.dispatcher + b.modmask;
                if (seen[key]) continue;
                seen[key] = true;
                const keys = _keys(Object.assign({}, b, { key: "1…0" }));
                out.push({ keys, label: b.dispatcher === "workspace" ? "go to workspace 1–10" : "move window to workspace 1–10",
                           group: "workspaces", dispatcher: "", arg: "", runnable: false });
                continue;
            }
            const dedupe = b.modmask + b.key;
            if (seen[dedupe]) continue;      // e.g. XF86AudioPlay + Pause both bound
            seen[dedupe] = true;
            out.push({ keys: _keys(b), label: desc[1], group: desc[0], dispatcher: b.dispatcher, arg: b.arg,
                       runnable: !b.mouse && b.dispatcher !== "exit" && !/mouse/.test(b.key) });
        }
        const order = ["shell", "apps", "tools", "windows", "workspaces", "media", "hardware", "session", "other"];
        return out.sort((x, y) => order.indexOf(x.group) - order.indexOf(y.group));
    }

    readonly property var proc: Process {
        command: ["hyprctl", "binds", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.rows = root._parse(JSON.parse(this.text)); } catch (e) { root.rows = []; }
            }
        }
    }
}
