# Troubleshooting

Start with `scripts/doctor.sh`. Each failed line comes with a `fix:` note.

## Install

**The download stopped.**
Run `./install.sh` again. It resumes from where it stopped.

**"The download was damaged, so it was removed".**
Run `./install.sh` again. It starts a clean download.

**"Could not unpack" with your own `--client-zip`.**
That file is damaged or incomplete. Download it again, or drop the option and let the
installer fetch it.

**"exists, is not empty, and is not a complete client".**
Something is already in the install folder and the installer will not unpack over it.
Move that folder away, or pick another place with `OCTOWOW_HOME`.

**"WoWSilicon.app exists but is incomplete".**
An earlier copy was cut short. Move the app to the Trash and run `./install.sh` again.

**"WoWSilicon download did not match its expected SHA-256".**
Nothing was installed. Try once more on a different network. If it still fails, WoWSilicon
may have replaced the release file: open an issue here, and do not install it from
anywhere else in the meantime.

**"Not enough disk space".**
The install needs 25 GB free at its peak. To use another drive:
`OCTOWOW_HOME=/Volumes/YourDrive/OctoWoW ./install.sh`

**macOS says WoWSilicon "cannot be opened".**
The app is unsigned. Run
`xattr -dr com.apple.quarantine /Applications/WoWSilicon.app`
or allow it under System Settings, Privacy & Security, Open Anyway.

## Patching

**doctor says "Client is not patched yet".**
Open WoWSilicon, keep the VanillaSilicon (1.12.1) profile, set Game Path to your client
folder, and apply the game patch until it reads "Game Patch: Applied". Copying the files
in by hand does not work.

**The OctoWoW client updated and the game stopped starting.**
A client update can overwrite patched files. Patch again in WoWSilicon, then run doctor.

## Launching

**`play.sh` says "No Wine prefix".**
Open WoWSilicon once. It creates `~/WoWSilicon` on first run.

**`play.sh` starts nothing, or the game closes at once.**
Look at `~/Games/OctoWoW/play.log`, then press Play inside WoWSilicon instead. If that works and `play.sh` does not, your WoWSilicon
version probably differs from the tested one (doctor shows both). Please open an issue.

**The first launch is slow or stutters.**
Shaders are compiled the first time each one is seen. It settles after a few minutes.

**Stuck on "Connecting".**
Check the realm status on [octowow.st](https://octowow.st). Do not edit `realmlist.wtf` to
an address from a forum post; the official client ships the right one.

## Asking for help

Open an issue with the full output of `scripts/doctor.sh`. It contains no account details.
For anything about your account, characters or the server itself, ask OctoWoW directly.
