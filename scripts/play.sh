#!/bin/bash
# Starts OctoWoW through WoWSilicon's bundled Wine, without opening the WoWSilicon window.
# It launches the game and stops there: it never types, clicks, or sends input to the game,
# and it never reads or stores your password. You log in yourself.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=scripts/lib.sh
. "$ROOT/scripts/lib.sh"

RES="$WOWSILICON_APP/Contents/Resources"
WINE="$RES/Wine/bin/wine"
ROSETTAX87="$RES/WoWSilicon-swift_WoWSiliconSwift.bundle/Patching/rosettax87/rosettax87"

client_present "$CLIENT_DIR" || die "No client at $CLIENT_DIR. Run ./install.sh first."
[ -x "$WINE" ] || die "WoWSilicon is missing or incomplete at $WOWSILICON_APP. Run ./install.sh."
[ -z "$(missing_patch_files)" ] || die "The client is not patched for Apple Silicon yet. Run scripts/doctor.sh for the fix."
[ -d "$WINE_PREFIX/drive_c" ] || die "No Wine prefix at $WINE_PREFIX. Open WoWSilicon once so it can create it."

if game_running; then
  say "OctoWoW is already running."
  exit 0
fi

cd "$CLIENT_DIR"
ROSETTA_X87_PATH="$ROSETTAX87" \
WINEPREFIX="$WINE_PREFIX" \
DYLD_LIBRARY_PATH="$RES/Wine/lib/external" \
VK_DRIVER_FILES="$RES/Wine/lib/vulkan/icd.d/MoltenVK_icd.json" \
WINE_LARGE_ADDRESS_AWARE=1 \
WINEDLLOVERRIDES='d3d9=n' \
MVK_CONFIG_SYNCHRONOUS_QUEUE_SUBMITS=1 \
DXVK_ASYNC=1 \
MTL_HUD_ENABLED=0 \
  nohup "$WINE" "$CLIENT_DIR/WoW.exe" >/dev/null 2>&1 &

say "OctoWoW is starting. The first launch takes longer while shaders build."
