#!/usr/bin/env bash
# textfox (latest main) + my overrides into the default Firefox profile.
#   ./install.sh            (close Firefox first; restart it afterwards)
set -euo pipefail
here="$(dirname "$(realpath "$0")")"
profile=$(find ~/.mozilla/firefox -maxdepth 1 -type d -name '*.default-release' | head -1)
[ -n "$profile" ] || { echo "no *.default-release Firefox profile found" >&2; exit 1; }

tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
git clone -q --depth 1 https://github.com/adriankarlen/textfox "$tmp/textfox"

[ -d "$profile/chrome" ] && mv "$profile/chrome" "$profile/chrome.bak-$(date +%F-%H%M)"
cp -r "$tmp/textfox/chrome" "$profile/chrome"
{ echo; cat "$here/userContent-overrides.css"; } >> "$profile/chrome/userContent.css"
# The rice shell's theme for textfox (theme-apply.py keeps it current).
theme_css="$HOME/.local/state/rice/theme/firefox.css"
[ -f "$theme_css" ] && cp "$theme_css" "$profile/chrome/config.css"

# user.js: textfox's prefs + mine (RAM/process tuning), linked so edits land in git
ln -sf "$here/user.js" "$profile/user.js"
echo "textfox installed into $profile (old chrome/ kept as chrome.bak-*)"
