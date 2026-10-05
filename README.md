# configs

Dotfiles for an Arch + Hyprland desktop: a retro gruvbox-material Quickshell
shell ("rice"), SDDM theme, terminal tools. Managed with GNU stow: each top-level
directory is a package mirroring `$HOME`.

| Package | What |
|---------|------|
| `quickshell` | the shell — bar, dashboard, quick settings, launcher, lock screen ([README](quickshell/.config/quickshell/rice/README.md)) |
| `hypr` | Hyprland (`hyprland.conf`, `external/` keybinds + look & feel, hyprsunset, wallpaper script) |
| `alacritty` | terminal + gruvbox-material theme |
| `tmux` | tmux + tpm, gruvbox-material, resurrect/continuum (sessions survive reboots) |
| `nvim` | Neovim |
| `spotify-player` | spotify_player + gruvbox theme |
| `dunst` | notifications |
| `bash`, `git`, `starship` | shell, git identity + global ignore, prompt |
| `btop`, `zathura`, `gtk` | system monitor, PDF viewer, GTK icon theme |
| `mpd`, `ncmpcpp`, `beets` | local music: daemon, client, library manager (config only) |
| `sddm/` | login theme — not stowed, see `sddm/README.md` (`./install.sh [wayland]`) |
| `firefox/` | textfox + my `user.js` / CSS — not stowed (`./install.sh`) |
| `cron/` | crontab (wallpaper rotation) — `crontab cron/crontab` |

## Fresh install

```bash
# 1. packages (official repos)
sudo pacman -S --needed hyprland uwsm hyprsunset awww quickshell alacritty tmux dunst stow \
  wl-clipboard cliphist tesseract tesseract-data-eng playerctl grim slurp jq curl \
  spotify-player protonmail-bridge gnome-keyring python-dateutil python-gobject github-cli \
  btop zathura zathura-pdf-mupdf starship mpd ncmpcpp beets neovim \
  sddm weston capitaine-cursors docker
# AUR
yay -S grimblast-git mullvad-vpn-bin discordo-git

# 2. dotfiles
git clone git@github.com:TK-Evans01/configs.git ~/Projects/configs && cd ~/Projects/configs
for p in alacritty bash beets btop dunst git gtk hypr mpd ncmpcpp nvim quickshell spotify-player starship tmux zathura; do
  stow --no-folding -t ~ "$p"
done
crontab cron/crontab

# 3. font + icons (not packaged)
install -Dm644 sddm/rice/fonts/DepartureMonoNerdFontMono-Regular.otf ~/.local/share/fonts/DepartureMonoNerdFontMono-Regular.otf
fc-cache -f
curl -LO https://github.com/SylEleuth/gruvbox-plus-icon-pack/releases/download/v6.6.0/gruvbox-plus-icon-pack-6.6.0.zip
unzip -q gruvbox-plus-icon-pack-6.6.0.zip 'Gruvbox-Plus-Dark/*' -d ~/.local/share/icons/

# 4. tmux plugins
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
~/.tmux/plugins/tpm/bin/install_plugins

# 5. login screen, Firefox
sddm/install.sh wayland
firefox/install.sh        # with Firefox closed
```

## Secrets (never in git) — recreate in `~/.config/rice/` (mode 600)

| File | How |
|------|-----|
| `proton-bridge.netrc` | Bridge's IMAP user/password, see the rice README › Proton Mail |
| `proton-calendar.url` | Proton Calendar › Share via link |
| `spotify-client-id` | developer.spotify.com app (redirect `http://127.0.0.1:8989/login`), then `spotify_player authenticate` |

Also: `gh auth login`, sign in to Proton Mail Bridge once (needs the `login`
gnome-keyring unlocked by SDDM — use your login password for it).

## Adding a config

`./stow.sh init <name>` moves `~/.config/<name>` into a package and links it
back. For single files (keeping other files in place), move them into
`<pkg>/<path relative to $HOME>` and `stow --no-folding -t ~ <pkg>`.
