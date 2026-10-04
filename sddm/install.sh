#!/usr/bin/env bash
# Install the rice SDDM theme (needs sudo).
#   ./install.sh           theme + your avatar
#   ./install.sh wayland   also run the greeter on weston instead of Xorg
set -euo pipefail
here="$(dirname "$(realpath "$0")")"

sudo rm -rf /usr/share/sddm/themes/rice
sudo cp -r "$here/rice" /usr/share/sddm/themes/rice
sudo chmod -R a+rX /usr/share/sddm/themes/rice

# Theme selection (replaces the old gruvbox-minimal theme.conf; kept as .bak)
sudo install -d /etc/sddm.conf.d
[ -f /etc/sddm.conf.d/theme.conf ] && sudo cp /etc/sddm.conf.d/theme.conf /etc/sddm.conf.d/theme.conf.bak
sudo install -m644 "$here/theme.conf" /etc/sddm.conf.d/theme.conf

# Same face as the shell (~/.face.icon)
if [ -f "$HOME/.face.icon" ]; then
    sudo install -m644 "$HOME/.face.icon" "/usr/share/sddm/faces/$USER.face.icon"
fi

if [ "${1:-}" = wayland ]; then
    sudo install -m644 "$here/wayland.conf" /etc/sddm.conf.d/wayland.conf
    echo "wayland greeter enabled (takes effect on next boot / sddm restart)"
fi
echo "installed: /usr/share/sddm/themes/rice"
