#!/bin/bash
# Checks an OctoWoW install on Apple Silicon and says exactly what is missing.
# Read-only: it never changes a file. Exit code 0 = ready to play, 1 = something to fix.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=scripts/lib.sh
. "$ROOT/scripts/lib.sh"

FAILS=0
fail() { bad "$1"; [ $# -gt 1 ] && note "fix: $2"; FAILS=$((FAILS + 1)); }

step "This Mac"
if is_apple_silicon; then ok "Apple Silicon"; else fail "Not an Apple Silicon Mac" "this project only supports M-series Macs"; fi
major="$(macos_major)"
if [ "${major:-0}" -ge "$MIN_MACOS_MAJOR" ]; then ok "macOS $major"; else fail "macOS ${major:-unknown} is too old" "update to macOS $MIN_MACOS_MAJOR or newer"; fi
if has_rosetta; then ok "Rosetta 2"; else fail "Rosetta 2 is not installed" "softwareupdate --install-rosetta"; fi

step "WoWSilicon"
if wowsilicon_present; then
  ver="$(defaults read "$WOWSILICON_APP/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || echo unknown)"
  ok "$WOWSILICON_APP (version $ver)"
  [ "$ver" = "$WOWSILICON_VERSION" ] || warn "Tested with WoWSilicon $WOWSILICON_VERSION; you have $ver. scripts/play.sh may need the app's own Play button instead."
elif [ -e "$WOWSILICON_APP" ]; then
  fail "$WOWSILICON_APP is incomplete (no bundled Wine)" "move it to the Trash, then ./install.sh"
else
  fail "WoWSilicon is not installed" "./install.sh"
fi

step "OctoWoW client"
if client_present "$CLIENT_DIR"; then
  ok "$CLIENT_DIR"
  realm="$(client_realmlist)"
  if [ "$realm" = "$EXPECTED_REALMLIST" ]; then
    ok "realmlist points at $realm"
  else
    warn "realmlist is '${realm:-empty}', expected '$EXPECTED_REALMLIST'. Check octowow.st before changing it."
  fi
else
  fail "No client at $CLIENT_DIR" "./install.sh"
fi

step "Apple Silicon patch"
if client_present "$CLIENT_DIR"; then
  missing="$(missing_patch_files)"
  if [ -z "$missing" ]; then
    ok "All patch files present"
  else
    fail "Client is not patched yet" "open WoWSilicon, set Game Path to $CLIENT_DIR, apply the game patch"
    printf '%s\n' "$missing" | while IFS= read -r m; do note "missing: $m"; done
  fi
else
  note "skipped (no client)"
fi

step "Wine prefix"
if [ -d "$WINE_PREFIX/drive_c" ]; then
  ok "$WINE_PREFIX"
else
  warn "No Wine prefix at $WINE_PREFIX yet. WoWSilicon creates it the first time it runs."
fi

step "Add-ons and mods"
note "This project installs no add-ons and no extra DLL mods."
addons="$(third_party_addons)"
if [ -z "$addons" ]; then
  ok "Stock interface (Blizzard add-ons only)"
else
  note "Third-party add-ons found in this client (not from this project):"
  printf '%s\n' "$addons" | while IFS= read -r a; do note "  $a"; done
fi
if [ -f "$CLIENT_DIR/dlls.txt" ]; then
  extra="$(grep -v '^[[:space:]]*$' "$CLIENT_DIR/dlls.txt" | tr -d '\r' | grep -vxF -e "${REQUIRED_DLL_LINES[0]}" -e "${REQUIRED_DLL_LINES[1]}" || true)"
  if [ -n "$extra" ]; then
    note "Extra DLL mods enabled in dlls.txt (not from this project):"
    printf '%s\n' "$extra" | while IFS= read -r e; do note "  $e"; done
  fi
fi

say ""
if [ "$FAILS" -eq 0 ]; then
  ok "Ready to play: $ROOT/scripts/play.sh"
  exit 0
fi
bad "$FAILS thing(s) to fix above."
exit 1
