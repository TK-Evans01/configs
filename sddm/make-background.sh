#!/usr/bin/env bash
# Bake the SDDM/rice background: scale to 2560 wide, blur, darken.
#   ./make-background.sh ~/Pictures/Wallpapers/dore/2434343.jpg
set -euo pipefail
src=${1:?usage: $0 <image>}
out="$(dirname "$(realpath "$0")")/rice/background.jpg"
ffmpeg -loglevel error -y -i "$src" \
  -vf "scale=2560:-1,gblur=sigma=28:steps=3,eq=brightness=-0.06:saturation=0.85,colorchannelmixer=rr=0.48:gg=0.48:bb=0.48" \
  -q:v 3 "$out"
echo "wrote $out"
