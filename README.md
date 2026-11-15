# octowow-silicon

**OctoWoW on an Apple Silicon Mac, in one command.**

OctoWoW ships a launcher for Windows and Linux. This project covers the Mac: it installs
the runtime, fetches the client from OctoWoW's own download server, and checks the result.
No add-ons, no bots, no bundled game files.

> Unofficial and community-made. Not affiliated with the OctoWoW team or with Blizzard.

## Quick start

```sh
git clone https://github.com/staybased/octowow-silicon
cd octowow-silicon
./install.sh
```

Then do the one step the installer cannot do for you (it prints these too):

1. Open **WoWSilicon**
2. Pick the **Vanilla 1.12.1** profile
3. Choose the game folder: `~/Games/OctoWoW/client`
4. Click **Patch**, then quit WoWSilicon

Check it and play:

```sh
scripts/doctor.sh   # confirms every piece is in place
scripts/play.sh     # starts the game
```

Log in with your OctoWoW account. Make one at [octowow.st](https://octowow.st) first.

## Requirements

| | |
|---|---|
| Mac | Apple Silicon (M1 or newer) |
| macOS | 14 or newer |
| Disk | 25 GB free during install, about 10 GB after |
| Network | A 9.7 GB client download |

## What the installer does

| Step | What happens | Source |
|---|---|---|
| 1 | Checks the Mac, macOS version, Rosetta 2 and free disk space | |
| 2 | Installs [WoWSilicon](https://github.com/WoWSilicon/WoWSilicon) 3.2.2, verified by SHA-256 | WoWSilicon's GitHub release |
| 3 | Downloads and unpacks the OctoWoW client | `dl.octowow.st`, the official server |
| 4 | Tells you how to patch the client, and checks that it worked | |

Re-running is safe. Finished steps are skipped, and an interrupted download resumes.

Options:

```sh
./install.sh --dry-run                    # show the plan, change nothing
./install.sh --client-zip ~/Downloads/wow-client.zip   # use a zip you already have
./install.sh --keep-zip                   # keep the download after unpacking
OCTOWOW_HOME=/Volumes/Games/OctoWoW ./install.sh       # install somewhere else
```

## What this project will not do

These are rules, not missing features. They follow the
[OctoWoW server rules](https://octowow.st/rules); the reasoning is in [docs/ETHOS.md](docs/ETHOS.md).

- **No add-ons.** None are in this repo and none are installed. What you add is your call.
- **No bots, automation or multibox tools.** OctoWoW forbids them. `play.sh` starts the game
  and never sends it a keystroke or a click.
- **No extra DLL mods.** Only the two files Apple Silicon needs to run the client at all.
- **No game files.** The client is downloaded from OctoWoW, never from here.
- **No credentials.** Nothing here reads, stores or types your password.

## Using an AI agent

Coding agents (Claude Code, Codex, Cursor and others) can run this install for you. Point
one at this repo and ask it to install OctoWoW. [AGENTS.md](AGENTS.md) tells it what to
run, what to verify, where to stop and ask you, and what it must never do.

## Uninstall

```sh
scripts/uninstall.sh         # removes the client folder
scripts/uninstall.sh --all   # also removes WoWSilicon and its Wine prefix
```

It lists what will be deleted and asks first. Your characters live on the server.

## Problems

Run `scripts/doctor.sh` first; it names the fix for each failed check. More in
[docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md).

## Credits

- [WoWSilicon](https://github.com/WoWSilicon/WoWSilicon) does the hard part: Wine, RosettaX87
  and Direct3D 9 translation for old WoW clients on Apple Silicon. This project only automates
  the setup around it.
- [OctoWoW](https://octowow.st) and the Turtle WoW team before them, for Mysteries of Azeroth.

## License

MIT. See [LICENSE](LICENSE). World of Warcraft is a trademark of Blizzard Entertainment.
