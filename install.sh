#!/bin/bash
# octowow-silicon installer: sets up OctoWoW on an Apple Silicon Mac.
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

usage() { sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; }

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run)    DRY_RUN=1 ;;
    --keep-zip)   KEEP_ZIP=1 ;;
    --client-zip) [ $# -ge 2 ] || die "--client-zip needs a path"; CLIENT_ZIP="$2"; KEEP_ZIP=1; shift ;;
    -h|--help)    usage; exit 0 ;;
    *)            die "Unknown option: $1 (try --help)" ;;
  esac
  shift
done

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
    run /usr/sbin/softwareupdate --install-rosetta
  fi

  local need="$MIN_FREE_GB_FULL" free
  if client_present "$CLIENT_DIR"; then need=0
  elif [ -n "$CLIENT_ZIP" ]; then need="$MIN_FREE_GB_UNPACK"; fi
  free="$(free_gb "$OCTOWOW_HOME")"
  [ "${free:-0}" -ge "$need" ] || die "Not enough disk space: ${free:-?} GB free, $need GB needed at $OCTOWOW_HOME."
  ok "Disk space (${free} GB free)"
}

# --- 2. WoWSilicon -----------------------------------------------------------
install_wowsilicon() {
  step "2/4  WoWSilicon (the Apple Silicon runtime)"
  if [ -d "$WOWSILICON_APP" ]; then
    ok "Already installed at $WOWSILICON_APP"
    return
  fi
  if [ "$DRY_RUN" -eq 1 ]; then
    note "would download WoWSilicon $WOWSILICON_VERSION, check its SHA-256, and copy it to $WOWSILICON_APP"
    return
  fi

  local tmp dmg mount sum
  tmp="$(mktemp -d)"
  dmg="$tmp/WoWSilicon.dmg"
  say "Downloading WoWSilicon $WOWSILICON_VERSION (160 MB)..."
  curl --fail --location --progress-bar -o "$dmg" "$WOWSILICON_DMG_URL"

  sum="$(shasum -a 256 "$dmg" | awk '{print $1}')"
  if [ "$sum" != "$WOWSILICON_DMG_SHA256" ]; then
    rm -rf "$tmp"
    die "WoWSilicon download did not match its expected SHA-256. Nothing was installed."
  fi
  ok "Checksum matches"

  mount="$tmp/mnt"; mkdir -p "$mount"
  hdiutil attach "$dmg" -nobrowse -readonly -mountpoint "$mount" >/dev/null
  if [ ! -d "$mount/WoWSilicon.app" ]; then
    hdiutil detach "$mount" >/dev/null || true; rm -rf "$tmp"
    die "WoWSilicon.app was not inside the disk image."
  fi
  ditto "$mount/WoWSilicon.app" "$WOWSILICON_APP"
  hdiutil detach "$mount" >/dev/null || true
  rm -rf "$tmp"

  # WoWSilicon is unsigned; its own README gives this as the way to let it open.
  xattr -dr com.apple.quarantine "$WOWSILICON_APP" 2>/dev/null || true
  ok "Installed $WOWSILICON_APP"
}

# --- 3. The OctoWoW client ---------------------------------------------------
install_client() {
  step "3/4  OctoWoW client"
  if client_present "$CLIENT_DIR"; then
    ok "Already unpacked at $CLIENT_DIR"
    return
  fi

  local zip="${CLIENT_ZIP:-$OCTOWOW_HOME/wow-client.zip}"
  if [ "$DRY_RUN" -eq 1 ]; then
    [ -n "$CLIENT_ZIP" ] || note "would download the client (9.7 GB) from $CLIENT_URL"
    note "would unpack $zip into $CLIENT_DIR"
    return
  fi

  mkdir -p "$OCTOWOW_HOME"
  if [ -z "$CLIENT_ZIP" ]; then
    say "Downloading the client from OctoWoW (9.7 GB). Re-run to resume if it stops."
    curl --fail --location --continue-at - --progress-bar -o "$zip" "$CLIENT_URL"
  fi
  [ -f "$zip" ] || die "Client zip not found: $zip"

  local stage="$OCTOWOW_HOME/.unpack" exe src
  rm -rf "$stage"; mkdir -p "$stage"
  say "Unpacking..."
  ditto -x -k "$zip" "$stage" || { rm -rf "$stage"; die "Could not unpack $zip. It may be incomplete; re-run to resume the download."; }

  # The zip may or may not wrap the client in a folder; find WoW.exe either way.
  exe="$(find "$stage" -maxdepth 3 -type f -name 'WoW.exe' | head -1)"
  [ -n "$exe" ] || { rm -rf "$stage"; die "No WoW.exe inside $zip."; }
  src="$(dirname "$exe")"
  [ -d "$src/Data" ] || { rm -rf "$stage"; die "The unpacked client has no Data folder."; }

  mkdir -p "$(dirname "$CLIENT_DIR")"
  mv "$src" "$CLIENT_DIR"
  rm -rf "$stage"
  ok "Client unpacked to $CLIENT_DIR"

  if [ "$KEEP_ZIP" -eq 0 ]; then
    rm -f "$zip"
    note "Removed the download to free 9.7 GB (use --keep-zip to keep it)."
  fi
}

# --- 4. The one step a person does -------------------------------------------
finish() {
  step "4/4  Patch the client for Apple Silicon"
  if [ "$DRY_RUN" -eq 1 ]; then
    note "would check the client for WoWSilicon's patch and print the next step"
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
  2. Pick the Vanilla 1.12.1 profile
  3. Choose this game folder:     $CLIENT_DIR
  4. Click Patch, then quit WoWSilicon

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
