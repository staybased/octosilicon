#!/bin/bash
# octosilicon installer: sets up OctoWoW on an Apple Silicon Mac.
#
#   ./install.sh                 full install into ~/Games/OctoWoW
#   ./install.sh --dry-run       print the plan, change nothing, download nothing
#   ./install.sh --client-zip ~/Downloads/wow-client.zip
#   ./install.sh --keep-zip      keep the 9.7 GB download after unpacking
#
# Safe to re-run: each step is skipped when its result is already in place.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=scripts/lib.sh
. "$ROOT/scripts/lib.sh"

DRY_RUN=0
KEEP_ZIP=0
CLIENT_ZIP=""
DEFAULT_ZIP="$OCTOWOW_HOME/wow-client.zip"

usage() { sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; }

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run)    DRY_RUN=1 ;;
    --keep-zip)   KEEP_ZIP=1 ;;
    --client-zip)
      [ $# -ge 2 ] && [ -n "$2" ] || die "--client-zip needs a path"
      CLIENT_ZIP="$(abs_path "$2")"; shift
      [ -f "$CLIENT_ZIP" ] || die "Client zip not found: $CLIENT_ZIP" ;;
    -h|--help)    usage; exit 0 ;;
    *)            die "Unknown option: $1 (try --help)" ;;
  esac
  shift
done

# Temporary things to remove however the script ends (failure and Ctrl-C included).
TMP_DIR=""; MOUNT_DIR=""; STAGE_DIR=""; PARTIAL_APP=""
cleanup() {
  [ -n "$MOUNT_DIR" ] && hdiutil detach "$MOUNT_DIR" -force >/dev/null 2>&1
  [ -n "$TMP_DIR" ] && rm -rf "$TMP_DIR"
  [ -n "$STAGE_DIR" ] && rm -rf "$STAGE_DIR"
  [ -n "$PARTIAL_APP" ] && rm -rf "$PARTIAL_APP"
  return 0
}
trap cleanup EXIT
trap 'exit 130' INT TERM

run() {
  if [ "$DRY_RUN" -eq 1 ]; then note "would run: $*"; else "$@"; fi
}

# --- 1. This Mac -------------------------------------------------------------
preflight() {
  step "1/4  Checking this Mac"
  is_apple_silicon || die "This needs an Apple Silicon Mac (M1 or newer)."
  ok "Apple Silicon"

  local major; major="$(macos_major)"
  [ "${major:-0}" -ge "$MIN_MACOS_MAJOR" ] || die "macOS $MIN_MACOS_MAJOR or newer is required (this Mac has ${major:-unknown})."
  ok "macOS $major"

  if has_rosetta; then
    ok "Rosetta 2"
  else
    say "Rosetta 2 is missing. Apple's installer will ask you to accept its license."
    run softwareupdate --install-rosetta
  fi

  # Space is needed where the client will be unpacked. A zip already on disk costs nothing more.
  local need="$MIN_FREE_GB_FULL" free where
  where="$(dirname "$CLIENT_DIR")"
  if client_present "$CLIENT_DIR"; then need=0
  elif [ -n "$CLIENT_ZIP" ] || [ -f "$DEFAULT_ZIP" ]; then need="$MIN_FREE_GB_UNPACK"; fi
  free="$(free_gb "$where")"
  [ "${free:-0}" -ge "$need" ] || die "Not enough disk space: ${free:-?} GB free, $need GB needed at $where."
  ok "Disk space (${free} GB free)"
}

# --- 2. WoWSilicon -----------------------------------------------------------
install_wowsilicon() {
  step "2/4  WoWSilicon (the Apple Silicon runtime)"
  if wowsilicon_present; then
    ok "Already installed at $WOWSILICON_APP"
    return
  fi
  if [ -e "$WOWSILICON_APP" ]; then
    die "$WOWSILICON_APP exists but is incomplete. Move it to the Trash, then run this again."
  fi
  if [ "$DRY_RUN" -eq 1 ]; then
    note "would download WoWSilicon $WOWSILICON_VERSION, check its SHA-256, and copy it to $WOWSILICON_APP"
    return
  fi

  local dmg sum
  TMP_DIR="$(mktemp -d)"
  dmg="$TMP_DIR/WoWSilicon.dmg"
  say "Downloading WoWSilicon $WOWSILICON_VERSION (160 MB)..."
  curl "${CURL_SAFE[@]}" --progress-bar -o "$dmg" "$WOWSILICON_DMG_URL"

  sum="$(shasum -a 256 "$dmg" | awk '{print $1}')"
  [ "$sum" = "$WOWSILICON_DMG_SHA256" ] || die "WoWSilicon download did not match its expected SHA-256. Nothing was installed."
  ok "Checksum matches"

  MOUNT_DIR="$TMP_DIR/mnt"; mkdir -p "$MOUNT_DIR"
  hdiutil attach "$dmg" -nobrowse -readonly -mountpoint "$MOUNT_DIR" >/dev/null
  [ -d "$MOUNT_DIR/WoWSilicon.app" ] || die "WoWSilicon.app was not inside the disk image."

  # Copy next to the destination, then rename: the app is never left half-installed.
  PARTIAL_APP="$WOWSILICON_APP.partial"
  rm -rf "$PARTIAL_APP"
  ditto "$MOUNT_DIR/WoWSilicon.app" "$PARTIAL_APP" \
    || die "Could not copy WoWSilicon to $(dirname "$WOWSILICON_APP"). Check that you can write there."
  mv "$PARTIAL_APP" "$WOWSILICON_APP"
  PARTIAL_APP=""

  # Done with the disk image: release it now rather than holding it through the client download.
  hdiutil detach "$MOUNT_DIR" >/dev/null 2>&1 || hdiutil detach "$MOUNT_DIR" -force >/dev/null 2>&1 || true
  MOUNT_DIR=""
  rm -rf "$TMP_DIR"; TMP_DIR=""
  ok "Installed $WOWSILICON_APP"
}

# --- 3. The OctoWoW client ---------------------------------------------------
download_client() {
  local zip="$1" have=0 total
  [ -f "$zip" ] && have="$(stat -f %z "$zip")"
  total="$(curl "${CURL_SAFE[@]}" --silent --head "$CLIENT_URL" | tr -d '\r' | awk 'tolower($1)=="content-length:" {n=$2} END {print n}')"
  if [ -n "$total" ] && [ "$have" = "$total" ]; then
    ok "Download already complete"
    return
  fi
  if [ -n "$total" ] && [ "$have" -gt "$total" ]; then
    note "The saved download is larger than the current client. Starting again."
    rm -f "$zip"
  fi
  say "Downloading the client from OctoWoW (9.7 GB). If it stops, run this again to resume."
  curl "${CURL_SAFE[@]}" --continue-at - --progress-bar -o "$zip" "$CLIENT_URL"
}

install_client() {
  step "3/4  OctoWoW client"
  if client_present "$CLIENT_DIR"; then
    ok "Already unpacked at $CLIENT_DIR"
    return
  fi

  # Never unpack over, or into, something that is already there.
  if [ -L "$CLIENT_DIR" ]; then
    die "$CLIENT_DIR is a symlink. Set OCTOWOW_CLIENT_DIR to the real folder instead."
  elif [ -d "$CLIENT_DIR" ]; then
    if [ -n "$(ls -A "$CLIENT_DIR")" ]; then
      die "$CLIENT_DIR exists, is not empty, and is not a complete client. Move it away, then run this again."
    fi
  elif [ -e "$CLIENT_DIR" ]; then
    die "$CLIENT_DIR exists and is not a folder."
  fi

  local zip="${CLIENT_ZIP:-$DEFAULT_ZIP}"
  if [ "$DRY_RUN" -eq 1 ]; then
    [ -n "$CLIENT_ZIP" ] || note "would download the client (9.7 GB) from $CLIENT_URL"
    note "would unpack $zip into $CLIENT_DIR"
    return
  fi

  mkdir -p "$OCTOWOW_HOME" "$(dirname "$CLIENT_DIR")"
  [ -n "$CLIENT_ZIP" ] || download_client "$zip"

  # Unpack beside the destination so the final move is a rename on the same volume.
  STAGE_DIR="$(dirname "$CLIENT_DIR")/.octosilicon-unpack"
  rm -rf "$STAGE_DIR"; mkdir -p "$STAGE_DIR"
  say "Unpacking..."
  if ! ditto -x -k "$zip" "$STAGE_DIR"; then
    if [ -n "$CLIENT_ZIP" ]; then
      die "Could not unpack $zip. The file is damaged or incomplete."
    fi
    rm -f "$zip"
    die "The download was damaged, so it was removed. Run this again for a clean download."
  fi

  # The zip may or may not wrap the client in a folder; find WoW.exe either way.
  local exe src
  exe="$(find "$STAGE_DIR" -maxdepth 3 -type f -name 'WoW.exe' -print -quit)"
  [ -n "$exe" ] || die "No WoW.exe inside $zip."
  src="$(dirname "$exe")"
  [ -d "$src/Data" ] || die "The unpacked client has no Data folder."

  [ -d "$CLIENT_DIR" ] && rmdir "$CLIENT_DIR"   # the empty folder checked above
  mv "$src" "$CLIENT_DIR"
  ok "Client unpacked to $CLIENT_DIR"

  if [ "$KEEP_ZIP" -eq 0 ] && [ -z "$CLIENT_ZIP" ]; then
    rm -f "$zip"
    note "Removed the download to free 9.7 GB (use --keep-zip to keep it)."
  fi
}

# --- 4. The one step a person does -------------------------------------------
finish() {
  step "4/4  Patch the client for Apple Silicon"
  if [ "$DRY_RUN" -eq 1 ]; then
    note "would check the client for WoWSilicon's Game Patch and print the next step"
    return
  fi
  if [ -z "$(missing_patch_files)" ]; then
    ok "Client is patched"
    say ""
    say "Ready. Start the game with:  $ROOT/scripts/play.sh"
    return
  fi
  cat <<EOF

One step is left, and WoWSilicon does it in its own window:

  1. Open WoWSilicon              (open -a WoWSilicon)
     If macOS blocks it, allow it under System Settings > Privacy & Security.
  2. Keep the VanillaSilicon (1.12.1) profile selected
  3. Set "Game Path" to:          $CLIENT_DIR
  4. Apply the game patch, until it reads "Game Patch: Applied"
  5. Quit WoWSilicon

Then confirm everything is in place:

  $ROOT/scripts/doctor.sh

and start the game:

  $ROOT/scripts/play.sh
EOF
}

preflight
install_wowsilicon
install_client
finish
