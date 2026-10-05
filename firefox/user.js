// userchrome.css usercontent.css activate
user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);

// Fill SVG Color
user_pref("svg.context-properties.content.enabled", true);

// CSS's `:has()` selector
user_pref("layout.css.has-selector.enabled", true);

// === Process model — fewer = less overhead ===
user_pref("dom.ipc.processCount", 4); // was 8 (default)
user_pref("dom.ipc.processCount.webIsolated", 1); // big RAM save, weakens site isolation

// === Tab unload — reclaim idle tabs ===
user_pref("browser.tabs.unloadOnLowMemory", true);
user_pref("browser.sessionstore.restore_on_demand", true);
user_pref("browser.sessionstore.restore_tabs_lazily", true);

// === Disable bfcache hoarding ===
user_pref("browser.sessionhistory.max_total_viewers", 2);
user_pref("browser.sessionhistory.max_entries", 25);

// === Image/media RAM caps ===
user_pref("image.mem.shared.unmap.min_expiration_ms", 30000);
user_pref("media.memory_cache_max_size", 65536);

// === Kill background bloat ===
user_pref("browser.newtabpage.activity-stream.feeds.section.topstories", false);
user_pref("browser.newtabpage.activity-stream.feeds.snippets", false);
user_pref("extensions.pocket.enabled", false);
user_pref("browser.discovery.enabled", false);
user_pref("toolkit.telemetry.enabled", false);
user_pref("toolkit.telemetry.unified", false);
user_pref("datareporting.healthreport.uploadEnabled", false);

// === Prefetch off (CPU/net savings, slight load delay) ===
user_pref("network.prefetch-next", false);
user_pref("network.dns.disablePrefetch", true);
user_pref("network.predictor.enabled", false);

// === DNS over HTTPS off (5 = off by choice) ===
// System DNS (Mullvad via systemd-resolved) stays authoritative, so local
// answers like the focus-mode blocklist apply in Firefox too.
user_pref("network.trr.mode", 5);

// Force prefers-color-scheme: dark on all sites
user_pref("layout.css.prefers-color-scheme-content-override", 0);
user_pref("ui.systemUsesDarkTheme", 1);
user_pref("browser.theme.content-theme", 0);

// === Display: UI + content scaling for 1440p ===
user_pref("layout.css.devPixelsPerPx", "1.2");

// === Wayland + VA-API hardware video decode (AMD radeonsi) ===
user_pref("media.ffmpeg.vaapi.enabled", true);
user_pref("media.hardware-video-decoding.force-enabled", true);
user_pref("gfx.webrender.all", true);

// === Color management for wide-gamut OLED (1 = manage all surfaces, untagged=sRGB) ===
user_pref("gfx.color_management.mode", 1);
user_pref("gfx.color_management.enablev4", true);

// === HDR on Wayland (experimental) ===
user_pref("gfx.wayland.hdr", true);

// === Refresh: -1 auto-tracks the monitor (360Hz / VRR) ===
user_pref("layout.frame_rate", -1);

// --- private-like normal windows (keeps container extensions working) ---
user_pref("browser.startup.page", 1);                       // homepage, not previous session
user_pref("browser.sessionstore.resume_from_crash", false); // no restore after crash either
user_pref("browser.sessionstore.privacy_level", 2);         // never store form data/cookies in session file
user_pref("privacy.sanitize.sanitizeOnShutdown", true);
user_pref("privacy.clearOnShutdown_v2.browsingHistoryAndDownloads", true);
user_pref("privacy.clearOnShutdown_v2.cookiesAndStorage", true);
user_pref("privacy.clearOnShutdown_v2.cache", true);
user_pref("privacy.clearOnShutdown_v2.formdata", true);
user_pref("places.history.enabled", false);
