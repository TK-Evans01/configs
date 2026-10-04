# sddm

`rice/` is an SDDM theme matching the quickshell rice bar and lock screen:
bar-style top strip (host, clock, session picker, suspend/reboot/power off —
click twice), big pixel clock, square card with your avatar, `>` prompt with a
block cursor, caps-lock and wrong-password messages.

- DepartureMono ships in `rice/fonts/` — the greeter user can't read `~/.local/share/fonts`.
- The background is pre-blurred and darkened (`make-background.sh <image>`), so
  no GPU effects are needed (works under weston / software rendering).

```
./install.sh            # theme + avatar (~/.face.icon) — sudo
./install.sh wayland    # + greeter on weston instead of Xorg (weston.ini mirrors DP-3 onto DP-2)
sddm-greeter-qt6 --test-mode --theme ./rice   # preview in a window
```

Undo the Wayland greeter from a TTY (Ctrl+Alt+F3):
`sudo rm /etc/sddm.conf.d/wayland.conf && sudo systemctl restart sddm`
