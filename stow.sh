#!/usr/bin/env bash
# Usage:
#   ./stow.sh init <pkg>   migrate ~/.config/<pkg> into repo, then symlink
#   ./stow.sh link <pkg>   symlink existing repo pkg into $HOME

set -euo pipefail
cd "$(dirname "$(realpath "$0")")"

usage() { echo "usage: $0 {init|link} <pkg>" >&2; exit 1; }

(($# == 2)) || usage
cmd=$1 pkg=$2

command -v stow >/dev/null || { echo "stow not installed" >&2; exit 1; }

case $cmd in
  init)
    src="$HOME/.config/$pkg"
    dest_parent="$pkg/.config"
    [[ -e $src ]] || { echo "missing: $src" >&2; exit 1; }
    [[ -L $src ]] && { echo "already symlink: $src" >&2; exit 1; }
    [[ -e "$dest_parent/$pkg" ]] && { echo "already in repo: $dest_parent/$pkg" >&2; exit 1; }
    mkdir -p "$dest_parent"
    mv "$src" "$dest_parent/"
    stow -v -t "$HOME" "$pkg"
    ;;
  link)
    [[ -d $pkg ]] || { echo "no such pkg dir: $pkg" >&2; exit 1; }
    stow -v -t "$HOME" "$pkg"
    ;;
  *) usage ;;
esac
