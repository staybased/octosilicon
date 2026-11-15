# Troubleshooting

Start with `scripts/doctor.sh`. Each failed line comes with a `fix:` note.

## Install

**The download stopped.**
Run `./install.sh` again. It resumes from where it stopped.

**"Could not unpack" or "No WoW.exe inside".**
The zip is incomplete. Run `./install.sh` again to finish the download.

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
Open WoWSilicon, pick the Vanilla 1.12.1 profile, choose your client folder, click Patch.
Copying the files in by hand does not work.

**The OctoWoW client updated and the game stopped starting.**
A client update can overwrite patched files. Patch again in WoWSilicon, then run doctor.

## Launching

**`play.sh` says "No Wine prefix".**
Open WoWSilicon once. It creates `~/WoWSilicon` on first run.

**`play.sh` starts nothing, or the game closes at once.**
Press Play inside WoWSilicon instead. If that works and `play.sh` does not, your WoWSilicon
version probably differs from the tested one (doctor shows both). Please open an issue.

**The first launch is slow or stutters.**
Shaders are compiled the first time each one is seen. It settles after a few minutes.

**Stuck on "Connecting".**
Check the realm status on [octowow.st](https://octowow.st). Do not edit `realmlist.wtf` to
an address from a forum post; the official client ships the right one.

## Asking for help

Open an issue with the full output of `scripts/doctor.sh`. It contains no account details.
For anything about your account, characters or the server itself, ask OctoWoW directly.
