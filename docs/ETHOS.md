# Why this project is so small

OctoWoW describes itself as "a project focused around awarding players for investing their
time and effort into a character's progression." Its [rules](https://octowow.st/rules) ask
players to keep the community as friendly as the one many of us found in 2004. This project
tries to deserve a place next to that.

## What the server asks, and how this project answers

| OctoWoW rule | What this project does |
|---|---|
| No "hack, cheat, or other client modification to gain an unfair advantage" | Applies only what the client needs to start on Apple Silicon. Nothing that changes how the game plays. |
| No "botting and automation" | `play.sh` launches the game and never sends it input. No auto-login, no key senders. |
| No software that controls or synchronizes several characters | No multibox tooling, and none will be accepted. |
| No paid progression or real-money trading | Free, MIT licensed, no donations, no paid tier. |

## Choices that follow from it

**No add-ons.** Which add-ons are fair is a question between each player and the server.
A setup tool that picks for you takes that decision away, and an add-on that is fine today
can be ruled out tomorrow. So this repo ships none and installs none.

**No extra DLL mods.** The client runs on Apple Silicon with two files:
`winerosetta.dll` and `libSiliconPatch.dll`. Those are compatibility shims. Everything
else is a choice the player makes with the server's rules in hand.

**No game files here.** OctoWoW hosts its own client. Downloading from the server keeps
players on the version the team actually publishes.

**No credentials.** A tool that never sees a password cannot leak one.

**Readable in one sitting.** Five short shell scripts and no build step. OctoWoW calls
itself zero-trust; a setup tool for it should be something you can read before you run.

## For contributors

A pull request that adds add-ons, mods, automation, an auto-login, bundled game files or
a non-official download source will be closed, however useful it is. Better Mac support,
clearer errors and better docs are all welcome.
