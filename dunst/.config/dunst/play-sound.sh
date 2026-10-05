#!/bin/sh
# Invoked by dunst. Args from dunst:
#   $1=appname  $2=summary  $3=body  $4=icon  $5=urgency (LOW|NORMAL|CRITICAL)
appname="$1"
summary="$2"
urgency="$5"

play() {
  for ext in '' .ogg .oga .wav .flac; do
    f="$HOME/.config/dunst/sounds/$1$ext"
    if [ -f "$f" ]; then
      paplay "$f" &
      return
    fi
  done
  paplay "/usr/share/sounds/freedesktop/stereo/$1.oga" &
}

case "$appname::$summary" in
  "Claude Code::Task finished")  play complete;              exit ;;
  "Claude Code::Awaiting input") play message-new-instant;   exit ;;
esac

case "$urgency" in
  CRITICAL) play dialog-warning ;;
  LOW)      : ;;
  *)        : ;;
esac
