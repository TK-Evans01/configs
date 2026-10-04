#!/usr/bin/env bash
# Install the rice SDDM theme (needs sudo).
#   ./install.sh           theme + your avatar
#   ./install.sh wayland   also run the greeter on weston instead of Xorg
set -euo pipefail
here="$(dirname "$(realpath "$0")")"

sudo rm -rf /usr/share/sddm/themes/rice
sudo cp -r "$here/rice" /usr/share/sddm/themes/rice
sudo chmod -R a+rX /usr/share/sddm/themes/rice

# Theme selection. SDDM reads *every* file in sddm.conf.d (in name order), so
# the old file is backed up outside it — a theme.conf.bak there would win.
sudo install -d /etc/sddm.conf.d
if [ -f /etc/sddm.conf.d/theme.conf ] && ! grep -q 'Current=rice' /etc/sddm.conf.d/theme.conf; then
    sudo cp /etc/sddm.conf.d/theme.conf /etc/sddm.theme.conf.bak
fi
sudo rm -f /etc/sddm.conf.d/theme.conf.bak
sudo install -m644 "$here/theme.conf" /etc/sddm.conf.d/theme.conf

# Same face as the shell (~/.face.icon)
if [ -f "$HOME/.face.icon" ]; then
    sudo install -m644 "$HOME/.face.icon" "/usr/share/sddm/faces/$USER.face.icon"
fi

if [ "${1:-}" = wayland ]; then
    sudo install -D -m644 "$here/weston.ini" /etc/sddm/weston.ini
    sudo install -m644 "$here/wayland.conf" /etc/sddm.conf.d/wayland.conf
    echo "wayland greeter enabled (takes effect on next boot / sddm restart)"
fi
echo "installed: /usr/share/sddm/themes/rice"
