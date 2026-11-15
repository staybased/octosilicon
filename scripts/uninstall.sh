#!/bin/bash
# Removes what install.sh put on this Mac. Shows the list first and asks before deleting.
#
#   scripts/uninstall.sh              remove the OctoWoW client folder
#   scripts/uninstall.sh --all        also remove WoWSilicon.app and its Wine prefix
#   scripts/uninstall.sh --yes        do not ask (for scripted use)
#
# Your characters live on the server, not here. Local settings, keybinds and screenshots
# inside the client folder are deleted with it.
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
    -h|--help) sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "Unknown option: $arg" ;;
  esac
done

game_running && die "OctoWoW is running. Quit the game first."

TARGETS=()
[ -e "$CLIENT_DIR" ] && TARGETS+=("$CLIENT_DIR")
[ -e "$OCTOWOW_HOME/wow-client.zip" ] && TARGETS+=("$OCTOWOW_HOME/wow-client.zip")
if [ "$ALL" -eq 1 ]; then
  [ -e "$WOWSILICON_APP" ] && TARGETS+=("$WOWSILICON_APP")
  [ -e "$WINE_PREFIX" ] && TARGETS+=("$WINE_PREFIX")
fi

if [ "${#TARGETS[@]}" -eq 0 ]; then
  say "Nothing to remove."
  exit 0
fi

# Refuse anything that is not a deep, specific path.
for t in "${TARGETS[@]}"; do
  case "$t" in
    ""|"/"|"$HOME"|"$HOME/"|"/Applications"|"/Applications/") die "Refusing to remove '$t'." ;;
  esac
done

say "This will permanently delete:"
for t in "${TARGETS[@]}"; do
  say "  $t  ($(du -sh "$t" 2>/dev/null | awk '{print $1}'))"
done

if [ "$YES" -eq 0 ]; then
  printf 'Type "delete" to continue: '
  read -r answer || answer=""
  [ "$answer" = "delete" ] || { say "Cancelled. Nothing was removed."; exit 0; }
fi

for t in "${TARGETS[@]}"; do
  rm -rf "$t"
  ok "Removed $t"
done
