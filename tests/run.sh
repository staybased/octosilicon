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
# Stand-ins for host tools, so results do not depend on the machine running the tests
# and nothing here can change it (no real softwareupdate).
STUBS="$TMP/stubs"; mkdir -p "$STUBS"
printf '#!/bin/sh\necho Darwin\n' > "$STUBS/uname"
printf '#!/bin/sh\necho 1\n' > "$STUBS/sysctl"
printf '#!/bin/sh\necho 15.0\n' > "$STUBS/sw_vers"
printf '#!/bin/sh\nexit 0\n' > "$STUBS/softwareupdate"
chmod +x "$STUBS"/*

env_for() { # env_for <home-dir> command...   runs with all paths pointed at fakes
  local h="$1"; shift
  PATH="$STUBS:$PATH" \
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

printf 'mods/winerosetta.dll\r\nmods/libSiliconPatch.dll\r\n' > "$A/OctoWoW/client/dlls.txt"
check "accepts a dlls.txt with Windows line endings" env_for "$A" "$ROOT/scripts/doctor.sh"
printf 'mods/winerosetta.dll\n' > "$A/OctoWoW/client/dlls.txt"
check_not "fails when dlls.txt lost a required line" env_for "$A" "$ROOT/scripts/doctor.sh"
rm -rf "$A/WoWSilicon.app/Contents/Resources"
check "flags a half-copied WoWSilicon" out_has "incomplete" env_for "$A" "$ROOT/scripts/doctor.sh"
check_not "installer refuses a half-copied WoWSilicon" env_for "$A" "$ROOT/install.sh"

echo "install"
B="$TMP/b"; mkdir -p "$B"
check "--dry-run succeeds" env_for "$B" "$ROOT/install.sh" --dry-run
check "--dry-run creates nothing" test ! -e "$B/OctoWoW"
check "--dry-run names the official source" out_has "dl.octowow.st" env_for "$B" "$ROOT/install.sh" --dry-run
check_not "rejects unknown options" env_for "$B" "$ROOT/install.sh" --nope
check_not "rejects an empty --client-zip" env_for "$B" "$ROOT/install.sh" --client-zip ""
check_not "rejects a --client-zip that does not exist" env_for "$B" "$ROOT/install.sh" --client-zip "$TMP/none.zip"
check "--dry-run works with a relative OCTOWOW_HOME" sh -c "cd '$B' && PATH='$STUBS':\$PATH OCTOWOW_HOME=rel WOWSILICON_APP='$B/x.app' '$ROOT/install.sh' --dry-run | grep -qF '$B/rel/client'"

# Unpack path: a tiny zip that wraps the client in a folder, like a real download might.
Z="$TMP/z"; mkdir -p "$Z/wow-client/Data"; : > "$Z/wow-client/WoW.exe"
( cd "$Z" && /usr/bin/zip -qr "$TMP/client.zip" wow-client )
fake_app "$B/WoWSilicon.app"
check "installs from --client-zip" env_for "$B" "$ROOT/install.sh" --client-zip "$TMP/client.zip"
check "client lands in place" test -f "$B/OctoWoW/client/WoW.exe"
check "staging folder is cleaned up" test ! -e "$B/OctoWoW/.octosilicon-unpack"
check "a supplied zip is kept" test -f "$TMP/client.zip"
check "re-run is a no-op" out_has "Already unpacked" env_for "$B" "$ROOT/install.sh"

printf 'not a zip' > "$TMP/bad.zip"
C="$TMP/c"; mkdir -p "$C"; fake_app "$C/WoWSilicon.app"
check_not "fails cleanly on a bad zip" env_for "$C" "$ROOT/install.sh" --client-zip "$TMP/bad.zip"
check "a bad zip leaves no client behind" test ! -e "$C/OctoWoW/client"

# A flat zip (how OctoWoW ships it), into an existing empty folder, at a path with spaces.
F="$TMP/f"; mkdir -p "$F/Data"; : > "$F/WoW.exe"
( cd "$F" && /usr/bin/zip -qr "$TMP/flat.zip" . )
D="$TMP/d with space"; mkdir -p "$D/OctoWoW/client"; fake_app "$D/WoWSilicon.app"
check "installs a flat zip into an empty folder, path with spaces" env_for "$D" "$ROOT/install.sh" --client-zip "$TMP/flat.zip"
check "client is not nested" test -f "$D/OctoWoW/client/WoW.exe"

# A folder that already has something in it is never unpacked over.
E="$TMP/e"; mkdir -p "$E/OctoWoW/client"; : > "$E/OctoWoW/client/keep.txt"; fake_app "$E/WoWSilicon.app"
check_not "refuses a non-empty folder that is not a client" env_for "$E" "$ROOT/install.sh" --client-zip "$TMP/flat.zip"
check "that folder is left untouched" test "$(ls -A "$E/OctoWoW/client")" = "keep.txt"

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

# Uninstall only deletes things that look like what they should be.
check_not "refuses a folder that is not a client" env_for "$E" "$ROOT/scripts/uninstall.sh" --yes
check "that folder survives" test -f "$E/OctoWoW/client/keep.txt"
G="$TMP/g"; mkdir -p "$G/OctoWoW" "$G/real/Data"; : > "$G/real/WoW.exe"; ln -s "$G/real" "$G/OctoWoW/client"
check_not "refuses a symlinked client" env_for "$G" "$ROOT/scripts/uninstall.sh" --yes
check "the symlink and its target survive" test -f "$G/OctoWoW/client/WoW.exe"
H="$TMP/h"; fake_app "$H/WoWSilicon.app"; mkdir -p "$H/prefix"; : > "$H/prefix/notes.txt"
check_not "--all refuses a prefix that is not a Wine prefix" env_for "$H" "$ROOT/scripts/uninstall.sh" --all --yes
check "nothing was removed on refusal" test -d "$H/WoWSilicon.app" -a -f "$H/prefix/notes.txt"
check_not "--all refuses an app path that is not an .app" env OCTOWOW_HOME="$H/none" WOWSILICON_APP="$H/prefix" OCTOWOW_WINEPREFIX="$H/none2" "$ROOT/scripts/uninstall.sh" --all --yes
check "that path survives" test -f "$H/prefix/notes.txt"

echo "repo rules"
check "download sources cannot be overridden" out_has "dl.octowow.st" env OCTOWOW_CLIENT_URL="https://example.invalid/x" PATH="$STUBS:$PATH" OCTOWOW_HOME="$TMP/o" WOWSILICON_APP="$TMP/o.app" "$ROOT/install.sh" --dry-run
check "no add-ons or game files in the repo" no_output find "$ROOT" -not -path '*/.git/*' \
  \( -iname '*.toc' -o -iname '*.mpq' -o -iname '*.dll' -o -iname '*.exe' -o -iname '*.lua' \) -print
check "play.sh sends no input to the game" not grep -qiE 'osascript|keystroke|key code|cliclick|security find' "$ROOT/scripts/play.sh"

echo
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
