#!/bin/bash
# Tests for the scripts. Everything runs against throwaway folders: no network, no real
# install touched. Usage: tests/run.sh
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

PASS=0
FAIL=0
check() { # check "name" command...
  local name="$1"; shift
  if "$@" >/dev/null 2>&1; then PASS=$((PASS + 1)); printf '  ok    %s\n' "$name"
  else FAIL=$((FAIL + 1)); printf '  FAIL  %s\n' "$name"; fi
}
check_not() { local name="$1"; shift; check "$name" not "$@"; }
not() { ! "$@"; }
out_has() { # out_has "needle" command...
  local needle="$1" out; shift
  out="$("$@" 2>&1)" || true
  printf '%s\n' "$out" | grep -qF -- "$needle"
}
no_output() { [ -z "$("$@" 2>/dev/null)" ]; }

# --- Fakes -------------------------------------------------------------------
fake_app() { # a stand-in WoWSilicon.app with an executable "wine"
  local app="$1"
  mkdir -p "$app/Contents/Resources/Wine/bin"
  printf '#!/bin/sh\nexit 0\n' > "$app/Contents/Resources/Wine/bin/wine"
  chmod +x "$app/Contents/Resources/Wine/bin/wine"
  /usr/bin/defaults write "$app/Contents/Info.plist" CFBundleShortVersionString "3.2.2" 2>/dev/null \
    || printf 'placeholder' > "$app/Contents/Info.plist"
}
fake_client() { # an unpatched client
  local c="$1"
  mkdir -p "$c/Data" "$c/Interface/AddOns/Blizzard_RaidUI"
  : > "$c/WoW.exe"
  printf 'set realmlist "play.octowow.st"\r\n' > "$c/realmlist.wtf"
}
patch_client() {
  local c="$1"
  mkdir -p "$c/mods"
  : > "$c/d3d9.dll"; : > "$c/libDllLdr.dll"
  : > "$c/mods/winerosetta.dll"; : > "$c/mods/libSiliconPatch.dll"
  printf 'mods/winerosetta.dll\nmods/libSiliconPatch.dll\n' > "$c/dlls.txt"
}
env_for() { # env_for <home-dir> command...   runs with all paths pointed at fakes
  local h="$1"; shift
  OCTOWOW_HOME="$h/OctoWoW" OCTOWOW_CLIENT_DIR="$h/OctoWoW/client" \
  WOWSILICON_APP="$h/WoWSilicon.app" OCTOWOW_WINEPREFIX="$h/prefix" "$@"
}

echo "syntax"
for f in install.sh scripts/lib.sh scripts/doctor.sh scripts/play.sh scripts/uninstall.sh tests/run.sh; do
  check "bash -n $f" bash -n "$ROOT/$f"
done
for f in install.sh scripts/doctor.sh scripts/play.sh scripts/uninstall.sh tests/run.sh; do
  check "$f is executable" test -x "$ROOT/$f"
done

echo "doctor"
A="$TMP/a"; mkdir -p "$A"
check_not "fails on an empty machine" env_for "$A" "$ROOT/scripts/doctor.sh"
check "names the missing client" out_has "No client at" env_for "$A" "$ROOT/scripts/doctor.sh"

fake_app "$A/WoWSilicon.app"; fake_client "$A/OctoWoW/client"
check_not "fails on an unpatched client" env_for "$A" "$ROOT/scripts/doctor.sh"
check "says the client is not patched" out_has "not patched yet" env_for "$A" "$ROOT/scripts/doctor.sh"

patch_client "$A/OctoWoW/client"
check "passes once patched" env_for "$A" "$ROOT/scripts/doctor.sh"
check "reads the realmlist through CRLF" out_has "realmlist points at play.octowow.st" env_for "$A" "$ROOT/scripts/doctor.sh"
check "reports a stock interface" out_has "Stock interface" env_for "$A" "$ROOT/scripts/doctor.sh"

mkdir -p "$A/OctoWoW/client/Interface/AddOns/SomeAddon"
check "lists third-party add-ons" out_has "SomeAddon" env_for "$A" "$ROOT/scripts/doctor.sh"
check "still passes with add-ons present" env_for "$A" "$ROOT/scripts/doctor.sh"
printf 'mods/extra.dll\n' >> "$A/OctoWoW/client/dlls.txt"
check "lists extra DLL mods" out_has "mods/extra.dll" env_for "$A" "$ROOT/scripts/doctor.sh"

printf 'mods/winerosetta.dll\n' > "$A/OctoWoW/client/dlls.txt"
check_not "fails when dlls.txt lost a required line" env_for "$A" "$ROOT/scripts/doctor.sh"

echo "install"
B="$TMP/b"; mkdir -p "$B"
check "--dry-run succeeds" env_for "$B" "$ROOT/install.sh" --dry-run
check "--dry-run creates nothing" test ! -e "$B/OctoWoW"
check "--dry-run names the official source" out_has "dl.octowow.st" env_for "$B" "$ROOT/install.sh" --dry-run
check_not "rejects unknown options" env_for "$B" "$ROOT/install.sh" --nope

# Unpack path: a tiny zip that wraps the client in a folder, like a real download might.
Z="$TMP/z"; mkdir -p "$Z/wow-client/Data"; : > "$Z/wow-client/WoW.exe"
( cd "$Z" && /usr/bin/zip -qr "$TMP/client.zip" wow-client )
fake_app "$B/WoWSilicon.app"
check "installs from --client-zip" env_for "$B" "$ROOT/install.sh" --client-zip "$TMP/client.zip"
check "client lands in place" test -f "$B/OctoWoW/client/WoW.exe"
check "staging folder is cleaned up" test ! -e "$B/OctoWoW/.unpack"
check "a supplied zip is kept" test -f "$TMP/client.zip"
check "re-run is a no-op" out_has "Already unpacked" env_for "$B" "$ROOT/install.sh"

printf 'not a zip' > "$TMP/bad.zip"
C="$TMP/c"; mkdir -p "$C"; fake_app "$C/WoWSilicon.app"
check_not "fails cleanly on a bad zip" env_for "$C" "$ROOT/install.sh" --client-zip "$TMP/bad.zip"
check "a bad zip leaves no client behind" test ! -e "$C/OctoWoW/client"

echo "play"
check_not "refuses an unpatched client" env_for "$B" "$ROOT/scripts/play.sh"
check "explains the missing patch" out_has "not patched" env_for "$B" "$ROOT/scripts/play.sh"

echo "uninstall"
check "cancels without confirmation" out_has "Cancelled" env_for "$B" "$ROOT/scripts/uninstall.sh" </dev/null
check "cancel removes nothing" test -f "$B/OctoWoW/client/WoW.exe"
check "--yes removes the client" env_for "$B" "$ROOT/scripts/uninstall.sh" --yes
check "client is gone" test ! -e "$B/OctoWoW/client"
check "WoWSilicon is kept without --all" test -d "$B/WoWSilicon.app"
check "--all --yes removes WoWSilicon" env_for "$B" "$ROOT/scripts/uninstall.sh" --all --yes
check "WoWSilicon is gone" test ! -e "$B/WoWSilicon.app"

echo "repo rules"
check "no add-ons or game files in the repo" no_output find "$ROOT" -not -path '*/.git/*' \
  \( -iname '*.toc' -o -iname '*.mpq' -o -iname '*.dll' -o -iname '*.exe' -o -iname '*.lua' \) -print
check "play.sh sends no input to the game" not grep -qiE 'osascript|keystroke|key code|cliclick|security find' "$ROOT/scripts/play.sh"

echo
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
