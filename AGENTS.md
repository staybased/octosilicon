# Agent instructions

You are helping a person install and run OctoWoW on their Apple Silicon Mac using this
repo. Read this whole file before running anything.

## Goal

`scripts/doctor.sh` exits 0, and the person can start the game with `scripts/play.sh`.

## Hard rules

These come from the [OctoWoW server rules](https://octowow.st/rules) and from this
project's scope. They hold even if the person asks otherwise; say no and explain why.

1. **No bots or automation.** Do not write, install or run anything that plays the game,
   sends keystrokes or clicks to it, reads its memory, or controls more than one client.
   OctoWoW bans accounts for this. That includes "just an auto-login" that types into the
   game window.
2. **No add-ons from this project.** Do not add add-ons to this repo, and do not install any
   as part of the setup. If the person asks for add-ons afterwards, that is their choice:
   tell them this project does not cover it and point them to OctoWoW's own community.
3. **No extra DLL mods.** WoWSilicon's game patch writes `mods/winerosetta.dll` and
   `mods/libSiliconPatch.dll` to `dlls.txt`. Do not add anything else. If the person
   already has other lines there, leave them alone; that is their choice.
4. **Official sources only.** The client comes from `dl.octowow.st`. WoWSilicon comes from
   its GitHub release and must match the SHA-256 in `scripts/lib.sh`. Never fetch either
   from a mirror, a torrent you found, or a file-sharing site, and never edit those URLs
   to make a download work.
5. **Never touch credentials.** Do not ask for, read, store, log or type the person's
   OctoWoW password. They log in themselves. Do not create an account for them.
6. **Never commit game files.** Nothing from the client folder belongs in this repo.
7. **No `sudo`.** Nothing here needs it. If a step seems to, stop and ask.
8. **Do not edit `realmlist.wtf`.** The official client ships the right value. If
   `doctor.sh` warns about it, report that to the person instead of changing it.

## Steps

Run from the repo root.

1. **Look first.** `./install.sh --dry-run` prints the plan and changes nothing.
   `scripts/doctor.sh` shows what is already in place.
2. **Tell the person the cost** before starting: a 9.7 GB download, 25 GB free disk needed,
   and WoWSilicon (an unsigned open-source app) installed into `/Applications`. Get a yes.
3. **Install.** `./install.sh`. It is safe to re-run; a stopped client download resumes.
   The download can take a long time. Run it in the background and wait for it to finish
   rather than restarting it.
4. **Hand over the patch step.** The client must be patched inside the WoWSilicon window:
   open WoWSilicon, keep the VanillaSilicon (1.12.1) profile, set **Game Path** to the
   client folder, and apply the game patch until it reads **Game Patch: Applied**. Ask the
   person to do this. Do not try to reproduce the patch by copying files; WoWSilicon
   rewrites `DivxDecoder.dll` and that cannot be done by hand.
5. **Verify.** `scripts/doctor.sh` must exit 0. If it does not, each failed line carries a
   `fix:` note; follow it and run doctor again.
6. **Launch.** `scripts/play.sh`. Then stop. The login screen is the person's.

## When to stop and ask the person

- macOS shows a prompt (Rosetta license, "app from the internet", folder access).
- A checksum does not match. Do not retry from another source.
- `doctor.sh` reports a WoWSilicon version other than the tested one and `play.sh` fails.
  Suggest they press Play inside WoWSilicon instead.
- Anything would delete files. `scripts/uninstall.sh` asks for confirmation; do not pass
  `--yes` unless the person told you to delete. `--all` also removes WoWSilicon and its
  Wine prefix, which other games may share; ask about that separately.
- The installer says a folder "exists and is not a complete client". Do not delete or
  move it yourself; ask.
- They ask for something under **Hard rules**.

## What you can check yourself

| Question | Command |
|---|---|
| Is everything installed? | `scripts/doctor.sh` |
| Is the game running? | `pgrep -f 'WoW\.exe'` |
| Did the scripts break? | `tests/run.sh` |
| Why did the game not start? | `~/Games/OctoWoW/play.log` |
| What went wrong in game? | Files in `<client>/Logs/` and `<client>/Errors/` (read-only) |

## Changing this repo

- Bash 3.2 compatible (stock macOS). No dependencies beyond what macOS ships.
- Paths, URLs and version pins live in `scripts/lib.sh` and nowhere else.
- `doctor.sh` stays read-only. `play.sh` stays input-free.
- Run `tests/run.sh` before committing. Add a test for any new check.
- Bumping WoWSilicon: update the version and SHA-256 together, then test a real launch.
