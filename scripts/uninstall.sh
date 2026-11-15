#!/bin/bash
# Removes OctoWoW from this Mac. Shows the list first and asks before deleting.
#
#   scripts/uninstall.sh              remove the OctoWoW client folder
#   scripts/uninstall.sh --all        also remove WoWSilicon.app and its Wine prefix
#   scripts/uninstall.sh --yes        do not ask (for scripted use)
#
# Your characters live on the server, not here. Local settings, keybinds and screenshots
# inside the client folder are deleted with it.
# --all removes WoWSilicon and its Wine prefix even if you had them before, and other
# games set up in WoWSilicon use the same prefix.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=scripts/lib.sh
. "$ROOT/scripts/lib.sh"

ALL=0
YES=0
for arg in "$@"; do
  case "$arg" in
    --all) ALL=1 ;;
    --yes) YES=1 ;;
    -h|--help) sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "Unknown option: $arg" ;;
  esac
done

game_running && die "OctoWoW is running. Quit the game first."

# A path is only ever deleted if it looks like the thing it is supposed to be.
TARGETS=()
consider() { # consider <path> <what it is> <test that proves it>
  local path="$1" what="$2" proof="$3"
  [ -e "$path" ] || [ -L "$path" ] || return 0
  if [ -L "$path" ]; then
    die "$path is a symlink to $(readlink "$path"). Remove the real folder yourself; nothing was deleted."
  fi
  case "$proof" in
    client) [ -f "$path/WoW.exe" ] || [ -d "$path/Data" ] ;;
    zip)    [ -f "$path" ] ;;
    app)    case "$path" in *.app) [ -f "$path/Contents/Info.plist" ] ;; *) false ;; esac ;;
    prefix) [ -d "$path/drive_c" ] ;;
  esac || die "$path does not look like $what. Nothing was deleted."
  TARGETS+=("$path")
}

consider "$CLIENT_DIR" "a WoW client folder" client
consider "$OCTOWOW_HOME/wow-client.zip" "the client download" zip
if [ "$ALL" -eq 1 ]; then
  consider "$WOWSILICON_APP" "WoWSilicon.app" app
  consider "$WINE_PREFIX" "a Wine prefix" prefix
fi

if [ "${#TARGETS[@]}" -eq 0 ]; then
  say "Nothing to remove."
  exit 0
fi

say "This will permanently delete:"
for t in "${TARGETS[@]}"; do
  say "  $t  ($(du -sh "$t" 2>/dev/null | awk '{print $1}'))"
done
if [ "$ALL" -eq 1 ]; then
  say ""
  say "WoWSilicon and its Wine prefix are shared with any other game you set up in WoWSilicon."
fi

if [ "$YES" -eq 0 ]; then
  printf 'Type "delete" to continue: '
  read -r answer || answer=""
  [ "$answer" = "delete" ] || { say "Cancelled. Nothing was removed."; exit 0; }
fi

for t in "${TARGETS[@]}"; do
  rm -rf "$t"
  ok "Removed $t"
done
