#!/bin/bash
# Shared settings and helpers. Sourced by install.sh and everything in scripts/.
# Every value here can be overridden from the environment; nothing is user-specific.
# shellcheck disable=SC2034  # these are read by the scripts that source this file

# --- Where things live -------------------------------------------------------
OCTOWOW_HOME="${OCTOWOW_HOME:-$HOME/Games/OctoWoW}"
CLIENT_DIR="${OCTOWOW_CLIENT_DIR:-$OCTOWOW_HOME/client}"
WOWSILICON_APP="${WOWSILICON_APP:-/Applications/WoWSilicon.app}"
WINE_PREFIX="${OCTOWOW_WINEPREFIX:-$HOME/WoWSilicon}"

# --- Official sources only ---------------------------------------------------
# The client comes from OctoWoW's own download server. This repo never hosts it.
CLIENT_URL="${OCTOWOW_CLIENT_URL:-https://dl.octowow.st/download/client}"
EXPECTED_REALMLIST="play.octowow.st"

# WoWSilicon is pinned to a release we tested, and checked against its SHA-256.
WOWSILICON_VERSION="3.2.2"
WOWSILICON_DMG_URL="https://github.com/WoWSilicon/WoWSilicon/releases/download/v${WOWSILICON_VERSION}/WoWSilicon-${WOWSILICON_VERSION}.dmg"
WOWSILICON_DMG_SHA256="53771ef7595371cdd31db1a1269df481750c4e33f479ad862bb94376427d894c"

# --- Limits ------------------------------------------------------------------
MIN_MACOS_MAJOR=14        # WoWSilicon needs macOS 14 or newer
MIN_FREE_GB_FULL=25       # ~9.7 GB zip + ~9.1 GB unpacked, plus headroom
MIN_FREE_GB_UNPACK=12     # client zip already on disk

# The four files WoWSilicon's "Patch" step adds to a 1.12 client.
PATCH_FILES=(
  "d3d9.dll"
  "libDllLdr.dll"
  "mods/winerosetta.dll"
  "mods/libSiliconPatch.dll"
)
# The only DLL lines this project expects in dlls.txt. Anything else is the player's choice.
REQUIRED_DLL_LINES=(
  "mods/winerosetta.dll"
  "mods/libSiliconPatch.dll"
)

# --- Output ------------------------------------------------------------------
if [ -t 1 ]; then
  C_OK=$'\033[32m'; C_WARN=$'\033[33m'; C_ERR=$'\033[31m'; C_DIM=$'\033[2m'; C_OFF=$'\033[0m'
else
  C_OK=""; C_WARN=""; C_ERR=""; C_DIM=""; C_OFF=""
fi

say()  { printf '%s\n' "$*"; }
step() { printf '\n== %s\n' "$*"; }
ok()   { printf '%s  ok  %s %s\n' "$C_OK" "$C_OFF" "$*"; }
warn() { printf '%s warn %s %s\n' "$C_WARN" "$C_OFF" "$*"; }
bad()  { printf '%s FAIL %s %s\n' "$C_ERR" "$C_OFF" "$*"; }
note() { printf '%s      %s%s\n' "$C_DIM" "$*" "$C_OFF"; }
die()  { bad "$*" >&2; exit 1; }

# --- Checks ------------------------------------------------------------------
is_apple_silicon() {
  [ "$(uname -s)" = "Darwin" ] && [ "$(uname -m)" = "arm64" ]
}

macos_major() {
  sw_vers -productVersion 2>/dev/null | cut -d. -f1
}

has_rosetta() {
  /usr/bin/pgrep -q oahd 2>/dev/null || [ -d /Library/Apple/usr/share/rosetta ]
}

# Free space, in whole GB, on the volume that holds (or will hold) the given path.
free_gb() {
  local p="$1"
  while [ ! -e "$p" ] && [ "$p" != "/" ]; do p="$(dirname "$p")"; done
  df -g "$p" | awk 'NR==2 {print $4}'
}

# True when a WoW client is unpacked at the given folder.
client_present() {
  [ -f "$1/WoW.exe" ] && [ -d "$1/Data" ]
}

# Lists patch files missing from the client, one per line. Empty output = patched.
missing_patch_files() {
  local f
  for f in "${PATCH_FILES[@]}"; do
    [ -f "$CLIENT_DIR/$f" ] || printf '%s\n' "$f"
  done
  for f in "${REQUIRED_DLL_LINES[@]}"; do
    grep -qxF "$f" "$CLIENT_DIR/dlls.txt" 2>/dev/null || printf 'dlls.txt line: %s\n' "$f"
  done
}

# The realm host written in the client's realmlist.wtf, or empty.
client_realmlist() {
  sed -n 's/^[Ss][Ee][Tt] [Rr]ealmlist "\{0,1\}\([^" ]*\)"\{0,1\}.*/\1/p' "$CLIENT_DIR/realmlist.wtf" 2>/dev/null | head -1 | tr -d '\r'
}

# Add-ons that are not Blizzard's own, one per line.
third_party_addons() {
  local d="$CLIENT_DIR/Interface/AddOns" a
  [ -d "$d" ] || return 0
  for a in "$d"/*/; do
    [ -d "$a" ] || continue
    a="$(basename "$a")"
    case "$a" in Blizzard_*) ;; *) printf '%s\n' "$a" ;; esac
  done
}

# True when the game from THIS client folder is running. Wine shows it as a Windows path
# (Z:\Users\...\client\WoW.exe), so every separator is matched loosely.
game_running() {
  local pat
  pat="$(printf '%s' "$CLIENT_DIR" | sed 's/[^A-Za-z0-9_-]/./g')"
  /usr/bin/pgrep -f "${pat}.WoW\\.exe" >/dev/null 2>&1
}
